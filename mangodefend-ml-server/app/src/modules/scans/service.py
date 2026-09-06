import os
import json
import hashlib
import logging
import struct
import time
from typing import Optional, List, Tuple, Dict, Any
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status

from app.src.core.config import settings
from app.src.core.redis import get_redis
from app.src.core.rabbitmq import rabbitmq_publisher
from app.src.core.storage import supabase_storage
from app.src.engine.ml_runner import ml_engine, BinaryToImageTransformer
from app.src.modules.scans.enums import ScanVerdict, ScanSource
from app.src.modules.scans.models import MalwareSignature, ScanLog
from app.src.modules.scans.schemas import (
    HashLookupResponse,
    FileScanResponse,
    ScanLogSchema,
    SignatureImportItem,
    SignatureImportResponse
)
from app.src.modules.datasets.service import DatasetService
from app.src.modules.subscriptions.service import SubscriptionService

logger = logging.getLogger("mangodefend.scans_service")

REDIS_HASH_TTL_SECONDS = 86400  # 24 Jam TTL Cache

KNOWN_SAFE_WHITELIST = {
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "0000000000000000000000000000000000000000000000000000000000000000",
}


class CloudScanService:
    """Service layer khusus penanganan fitur Pemindaian File & Manajemen Master Signatures."""

    @staticmethod
    def calculate_file_hashes(file_bytes: bytes) -> Tuple[str, str]:
        """Menghitung hash SHA-256 dan MD5 dari byte biner file."""
        sha256 = hashlib.sha256(file_bytes).hexdigest().lower()
        md5 = hashlib.md5(file_bytes).hexdigest().lower()
        return sha256, md5

    @classmethod
    def check_subscription_limits(
        cls,
        db: Session,
        user_id: Optional[int] = None,
        scan_type: str = "upload",
        device_id: Optional[str] = None
    ) -> None:
        """
        Validasi batasan paket langganan pengguna & Mode Guest (Quota harian, Izin Fitur Scan, dan Batas Perangkat).
        """
        scan_type_clean = scan_type.lower().strip()

        # Mode Guest (Belum Login)
        if not user_id:
            guest_allowed_types = {"upload", "single", "file", "folder", "full_system"}
            if scan_type_clean not in guest_allowed_types:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Fitur '{scan_type}' (seperti Real-Time Protection atau Web Protection) merupakan fitur Premium. Silakan login atau upgrade paket untuk mengaktifkannya!"
                )

            # Batas Kuota Harian Guest: 15 Cloud AI Scans / hari per device
            GUEST_MAX_DAILY_SCANS = 15
            today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            today_scans_query = db.query(ScanLog).filter(ScanLog.scanned_at >= today_start)
            if device_id:
                today_scans_query = today_scans_query.filter(ScanLog.device_id == device_id)
            
            today_scans_count = today_scans_query.count()
            if today_scans_count >= GUEST_MAX_DAILY_SCANS:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Batas kuota harian pemindaian Cloud AI gratis tanpa login ({GUEST_MAX_DAILY_SCANS} scan/hari) pada perangkat ini telah habis. Silakan login / buat akun untuk mendapatkan kuota lebih besar!"
                )
            return

        # Mode User Login (Punya Subskripsi)
        user_sub = SubscriptionService.get_user_subscription(db=db, user_id=user_id)
        plan = user_sub.plan

        if not plan:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tidak ada paket langganan aktif yang ditemukan."
            )

        # 1. Validasi Izin Fitur Pemindaian Berdasarkan Jenis Scan (6 Fitur Utama Antivirus)
        permissions_map = {
            "upload": plan.can_upload_scans,
            "single": plan.can_upload_scans,
            "file": plan.can_upload_scans,
            "folder": plan.can_upload_folder,
            "full_system": plan.can_full_system_scan,
            "realtime": plan.can_realtime_protection,
            "realtime_monitoring": plan.can_realtime_protection,
            "realtime_protection": plan.can_realtime_protection,
            "apk_download": plan.can_realtime_protection,
            "file_download": plan.can_realtime_protection,
            "web_protection": plan.can_web_protection,
            "web": plan.can_web_protection,
            "scheduled_scan": plan.can_scheduled_scan,
            "scheduled": plan.can_scheduled_scan
        }

        is_allowed = permissions_map.get(scan_type_clean, plan.can_upload_scans)
        if not is_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Fitur pemindaian '{scan_type}' tidak diizinkan pada paket '{plan.plan_name}' Anda. Silakan upgrade ke paket Pro/Premium!"
            )

        # 2. Validasi Batas Kuota Pemindaian Harian (max_daily_scans)
        if plan.max_daily_scans != -1:
            today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            today_scans_query = db.query(ScanLog).filter(ScanLog.scanned_at >= today_start)
            if device_id:
                today_scans_query = today_scans_query.filter(ScanLog.device_id == device_id)
            else:
                today_scans_query = today_scans_query.filter(ScanLog.user_id == user_id)
            
            today_scans_count = today_scans_query.count()

            if today_scans_count >= plan.max_daily_scans:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Batas kuota harian pemindaian ({plan.max_daily_scans} scan/hari) pada paket '{plan.plan_name}' Anda telah habis. Silakan upgrade ke paket Pro/Premium!"
                )

    @classmethod
    async def _get_cached_hash(cls, sha256: str) -> Optional[Dict[str, Any]]:
        """Mengecek keberadaan hash di L1 Redis Cache."""
        try:
            client = await get_redis()
            cached_data = await client.get(f"malware:hash:{sha256}")
            if cached_data:
                return json.loads(cached_data)
        except Exception as e:
            logger.error(f"Redis cache read error for {sha256}: {e}")
        return None

    @classmethod
    async def _set_cached_hash(cls, sha256: str, data: Dict[str, Any]) -> None:
        """Menyimpan hasil reputasi hash ke L1 Redis Cache dengan TTL 24 Jam."""
        try:
            client = await get_redis()
            await client.setex(f"malware:hash:{sha256}", REDIS_HASH_TTL_SECONDS, json.dumps(data))
        except Exception as e:
            logger.error(f"Redis cache write error for {sha256}: {e}")

    @classmethod
    async def lookup_hash(cls, db: Session, sha256: str) -> HashLookupResponse:
        """Menangani fast lookup reputasi file (L1 Redis Cache -> L2 PostgreSQL Database)."""
        sha256_clean = sha256.lower().strip()

        # 0. Check Whitelist Lokal
        if sha256_clean in KNOWN_SAFE_WHITELIST:
            return HashLookupResponse(
                found=True,
                sha256=sha256_clean,
                status=ScanVerdict.BENIGN,
                source=ScanSource.CLOUD_DB
            )

        # 1. Check L1 Redis Cache
        cached = await cls._get_cached_hash(sha256_clean)
        if cached:
            raw_status = cached.get("status", "")
            if raw_status in ("MALICIOUS", "verified"):
                v = ScanVerdict.MALICIOUS
            elif raw_status in ("BENIGN", "FALSE_POSITIVE", "benign"):
                v = ScanVerdict.BENIGN
            else:
                v = ScanVerdict.UNKNOWN

            if v != ScanVerdict.UNKNOWN:
                return HashLookupResponse(
                    found=True,
                    sha256=sha256_clean,
                    status=v,
                    source=ScanSource.REDIS_CACHE
                )

        # 2. Check L2 PostgreSQL Master Signature Database
        signature = db.query(MalwareSignature).filter(MalwareSignature.sha256 == sha256_clean).first()
        if signature:
            st = signature.status
            if st in ("MALICIOUS", "verified", "PENDING_VERIFICATION"):
                await cls._set_cached_hash(sha256_clean, {"status": "MALICIOUS"})
                return HashLookupResponse(
                    found=True,
                    sha256=sha256_clean,
                    status=ScanVerdict.MALICIOUS,
                    source=ScanSource.CLOUD_DB
                )
            elif st in ("FALSE_POSITIVE", "BENIGN", "benign"):
                await cls._set_cached_hash(sha256_clean, {"status": "BENIGN"})
                return HashLookupResponse(
                    found=True,
                    sha256=sha256_clean,
                    status=ScanVerdict.BENIGN,
                    source=ScanSource.CLOUD_DB
                )

        # 3. Hash Tidak Ditemukan / Belum Terverifikasi
        return HashLookupResponse(
            found=False,
            sha256=sha256_clean,
            status=ScanVerdict.UNKNOWN,
            source=ScanSource.NOT_FOUND
        )

    @classmethod
    async def analyze_file(
        cls,
        db: Session,
        file_bytes: bytes,
        file_name: str,
        device_id: Optional[str] = None,
        user_id: Optional[int] = None,
        scan_type: str = "upload",
        session_id: Optional[str] = None,
    ) -> ScanLogSchema:
        """Memindai file biner dengan alur 3-Layer & Pembatasan Fitur Langganan."""
        # 1. Validasi Batasan Langganan Pengguna (jika terautentikasi)
        if user_id:
            cls.check_subscription_limits(db=db, user_id=user_id, scan_type=scan_type, device_id=device_id)

        sha256_hash, md5_hash = cls.calculate_file_hashes(file_bytes)
        storage_url: Optional[str] = None

        # Step 0: Cek Whitelist Lokal
        if sha256_hash in KNOWN_SAFE_WHITELIST:
            verdict = ScanVerdict.BENIGN
            scan_source = ScanSource.CLOUD_DB
        else:
            # Step 1: Cek apakah hash sudah ada di database/cache
            lookup = await cls.lookup_hash(db, sha256_hash)
            
            if lookup.found and lookup.status != ScanVerdict.UNKNOWN:
                verdict = lookup.status
                scan_source = lookup.source
            else:
                # Step 2: File asing -> Jalankan ML Inference Engine
                verdict_str = ml_engine.predict(file_bytes)
                verdict = ScanVerdict(verdict_str)
                scan_source = ScanSource.ML_INFERENCE

                # Step 3: Unggah file asing ke Supabase Storage
                target_bucket = settings.S3_BUCKET_QUARANTINE if verdict == ScanVerdict.MALICIOUS else settings.S3_BUCKET_RAW
                destination_key = f"unrecognized_samples/{sha256_hash}_{file_name}"
                storage_url = supabase_storage.upload_file(
                    file_bytes=file_bytes,
                    destination_key=destination_key,
                    bucket_name=target_bucket
                )

                # Step 4: Daftarkan signature baru ke Cloud DB langsung sebagai MALICIOUS jika terdeteksi malware oleh ML
                if verdict == ScanVerdict.MALICIOUS:
                    existing_sig = db.query(MalwareSignature).filter(MalwareSignature.sha256 == sha256_hash).first()
                    if not existing_sig:
                        new_sig = MalwareSignature(
                            sha256=sha256_hash,
                            md5=md5_hash,
                            file_name=file_name,
                            file_size=len(file_bytes),
                            status="MALICIOUS",
                            source="CLOUD_ML",
                            storage_url=storage_url
                        )
                        db.add(new_sig)
                        db.commit()

                # Step 5: Buat & Unggah Citra PNG 2D Grayscale Matrix ke S3 untuk Retraining ML Dataset
                try:
                    png_bytes = BinaryToImageTransformer.bytes_to_png_bytes(file_bytes)
                    cat = "malware" if verdict == ScanVerdict.MALICIOUS else "benign"
                    image_key = f"dataset/images/{cat}/{sha256_hash}.png"
                    dataset_image_url = supabase_storage.upload_file(
                        file_bytes=png_bytes,
                        destination_key=image_key,
                        bucket_name=settings.S3_BUCKET_RAW,
                        content_type="image/png"
                    )
                except Exception as e:
                    logger.error(f"[CloudScan] Failed to generate/upload dataset PNG image for {sha256_hash}: {e}")
                    dataset_image_url = None

                label = 0 if verdict == ScanVerdict.BENIGN else 1
                DatasetService.save_sample(
                    db=db,
                    sha256=sha256_hash,
                    file_name=file_name,
                    file_size=len(file_bytes),
                    label=label,
                    status_label=verdict.value,
                    source="AUTO_COLLECT",
                    image_url=dataset_image_url
                )

                # Set Redis Cache untuk status vonis (MALICIOUS / BENIGN)
                if verdict == ScanVerdict.MALICIOUS:
                    await cls._set_cached_hash(sha256_hash, {"status": "MALICIOUS"})
                elif verdict == ScanVerdict.BENIGN:
                    await cls._set_cached_hash(sha256_hash, {"status": "BENIGN"})

        # Step 6: Catat Histori Pemindaian Log
        scan_log = ScanLog(
            device_id=device_id,
            session_id=session_id,
            file_hash=sha256_hash,
            file_name=file_name,
            verdict=verdict.value,
            scan_source=scan_source.value
        )
        db.add(scan_log)
        db.commit()
        db.refresh(scan_log)

        # Step 7: Publikasi Event Pemindaian ke RabbitMQ Queue
        rabbitmq_publisher.publish_event(
            event_type="SCAN_COMPLETED",
            payload={
                "id": scan_log.id,
                "sha256": sha256_hash,
                "md5": md5_hash,
                "file_name": file_name,
                "verdict": verdict.value,
                "scan_source": scan_source.value,
                "device_id": device_id,
                "storage_url": storage_url,
                "timestamp": scan_log.scanned_at.isoformat() if scan_log.scanned_at else datetime.utcnow().isoformat()
            }
        )

        return ScanLogSchema.model_validate(scan_log)

    @classmethod
    def bulk_import_signatures(
        cls,
        db: Session,
        items: List[SignatureImportItem]
    ) -> SignatureImportResponse:
        """Import massal data signatures malware ke tabel malware_signatures."""
        if not items:
            return SignatureImportResponse(imported_count=0, skipped_count=0, total_processed=0)

        sha256_list = [item.sha256.lower().strip() for item in items]
        existing_hashes = set(
            h[0] for h in db.query(MalwareSignature.sha256).filter(MalwareSignature.sha256.in_(sha256_list)).all()
        )

        new_objects = []
        imported_count = 0
        skipped_count = 0

        for item in items:
            sha256_clean = item.sha256.lower().strip()
            if sha256_clean in existing_hashes:
                skipped_count += 1
                continue

            existing_hashes.add(sha256_clean)
            new_sig = MalwareSignature(
                sha256=sha256_clean,
                md5=item.md5.lower().strip() if item.md5 else None,
                file_name=item.file_name,
                file_size=item.file_size,
                status=item.status.value,
                source=item.source or "BULK_IMPORT"
            )
            new_objects.append(new_sig)
            imported_count += 1

        if new_objects:
            db.bulk_save_objects(new_objects)
            db.commit()

        return SignatureImportResponse(
            imported_count=imported_count,
            skipped_count=skipped_count,
            total_processed=len(items)
        )

    @staticmethod
    def get_device_history(db: Session, device_id: str, limit: int = 50) -> List[ScanLogSchema]:
        """Mengambil daftar histori pemindaian file milik perangkat client."""
        logs = db.query(ScanLog).filter(ScanLog.device_id == device_id).order_by(ScanLog.scanned_at.desc()).limit(limit).all()
        return [ScanLogSchema.model_validate(l) for l in logs]

    @classmethod
    def export_signatures_to_mdb1(cls, db: Session) -> Tuple[bytes, int]:
        """
        Mengambil seluruh signature malware dari PostgreSQL `malware_signatures`
        dan mengonversinya menjadi berkas biner MDB1 (Enterprise Standard Header 20-Bytes Big-Endian).
        """
        # Auto-verifikasi seluruh signature berstatus PENDING_VERIFICATION sebelum ekspor
        cls.verify_pending_signatures(db=db)

        # HANYA ekspor signature terverifikasi resmi (MALICIOUS)
        # Abaikan BENIGN dan FALSE_POSITIVE
        signatures = (
            db.query(MalwareSignature.sha256)
            .filter(MalwareSignature.status == "MALICIOUS")
            .all()
        )

        binary_hashes = []
        for (sha256_str,) in signatures:
            if sha256_str and len(sha256_str.strip()) == 64:
                try:
                    hash_bytes = bytes.fromhex(sha256_str.strip())
                    if len(hash_bytes) == 32:
                        binary_hashes.append(hash_bytes)
                except ValueError:
                    continue

        # Sort hashes lexicographically for O(log N) client binary search
        binary_hashes.sort()

        entry_count = len(binary_hashes)
        schema_version = 1
        timestamp_ms = int(time.time() * 1000)

        # Header 20 Bytes Big-Endian (>):
        # 0..3: magic 'MDB1'
        # 4..7: uint32 schema_version (1)
        # 8..11: uint32 entry_count
        # 12..19: uint64 timestamp_ms
        header = struct.pack(">4sIIQ", b"MDB1", schema_version, entry_count, timestamp_ms)
        payload = b"".join(binary_hashes)

        return header + payload, entry_count

    @classmethod
    def verify_pending_signatures(cls, db: Session) -> Dict[str, int]:
        """
        Memverifikasi seluruh signature berstatus 'PENDING_VERIFICATION' di PostgreSQL secara mandiri.
        Memeriksa Whitelist lokal dan mempromosikannya ke 'MALICIOUS' atau 'FALSE_POSITIVE'.
        """
        known_safe_whitelist = {
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "0000000000000000000000000000000000000000000000000000000000000000",
        }

        pending_items = db.query(MalwareSignature).filter(MalwareSignature.status == "PENDING_VERIFICATION").all()
        promoted_count = 0
        rejected_count = 0

        for sig in pending_items:
            sha256_clean = sig.sha256.lower().strip()

            # Cek Whitelist Lokal
            if sha256_clean in known_safe_whitelist:
                sig.status = "FALSE_POSITIVE"
                db.query(ScanLog).filter(ScanLog.file_hash == sha256_clean).update({"verdict": "FALSE_POSITIVE"})
                DatasetService.update_sample_status(db, sha256_clean, "FALSE_POSITIVE", label=0)
                rejected_count += 1
            else:
                sig.status = "MALICIOUS"
                db.query(ScanLog).filter(ScanLog.file_hash == sha256_clean).update({"verdict": "MALICIOUS"})
                DatasetService.update_sample_status(db, sha256_clean, "MALICIOUS", label=1)
                promoted_count += 1

        db.commit()
        return {
            "total_processed": len(pending_items),
            "promoted_to_verified": promoted_count,
            "rejected_false_positives": rejected_count,
        }

    @classmethod
    async def mark_as_whitelist(cls, db: Session, sha256: str) -> Dict[str, Any]:
        """
        Menandai hash SHA-256 sebagai FALSE_POSITIVE / Whitelist di PostgreSQL DB
        dan menghapus/meng-update cache-nya dari Redis agar tidak dianggap malware lagi.
        """
        sha256_clean = sha256.lower().strip()
        
        # 1. Jika parameter yang dikirim adalah file path / file name alih-alih 64-char hex SHA256
        if len(sha256_clean) != 64:
            basename = os.path.basename(sha256_clean)
            sig = db.query(MalwareSignature).filter(
                (MalwareSignature.file_name == basename) | (MalwareSignature.sha256 == sha256_clean)
            ).first()
            if not sig:
                scan_log = db.query(ScanLog).filter(
                    (ScanLog.file_name == basename) | (ScanLog.file_name == sha256_clean)
                ).order_by(ScanLog.scanned_at.desc()).first()
                if scan_log:
                    sha256_clean = scan_log.file_hash
                    sig = db.query(MalwareSignature).filter(MalwareSignature.sha256 == sha256_clean).first()
            else:
                sha256_clean = sig.sha256

        # 2. Update/Cari di PostgreSQL MalwareSignature, DatasetSample, & ScanLog
        if not sig:
            sig = db.query(MalwareSignature).filter(MalwareSignature.sha256 == sha256_clean).first()
        if sig:
            sig.status = "FALSE_POSITIVE"
            # Jika file sebelumnya berada di bucket quarantine-files, pindahkan ke raw-uploads
            if sig.storage_url and settings.S3_BUCKET_QUARANTINE in sig.storage_url:
                source_key = f"unrecognized_samples/{sig.sha256}_{sig.file_name}"
                new_url = supabase_storage.move_file(
                    source_bucket=settings.S3_BUCKET_QUARANTINE,
                    source_key=source_key,
                    dest_bucket=settings.S3_BUCKET_RAW,
                    dest_key=source_key
                )
                if new_url:
                    sig.storage_url = new_url
        
        db.query(ScanLog).filter(ScanLog.file_hash == sha256_clean).update({"verdict": "FALSE_POSITIVE"})
        db.commit()
        
        DatasetService.update_sample_status(db, sha256_clean, "FALSE_POSITIVE", label=0)
            
        # 2. Hapus/Update Cache dari Redis
        try:
            client = await get_redis()
            await client.setex(f"malware:hash:{sha256_clean}", REDIS_HASH_TTL_SECONDS, json.dumps({"status": "FALSE_POSITIVE"}))
        except Exception as e:
            logger.error(f"Redis cache update error for {sha256_clean}: {e}")
            
        return {
            "success": True,
            "sha256": sha256_clean,
            "status": "FALSE_POSITIVE",
            "message": "Berhasil ditandai sebagai Whitelist / FALSE_POSITIVE"
        }

    @classmethod
    async def sync_offline_telemetry(
        cls,
        db: Session,
        device_id: Optional[str],
        items: list,
        user_id: Optional[int] = None
    ):
        synced_count = 0
        batch_session_id = f"session_offline_sync_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"
        for item in items:
            item_session = getattr(item, 'session_id', None) or batch_session_id
            scan_log = ScanLog(
                device_id=device_id,
                session_id=item_session,
                file_hash=item.file_hash,
                file_name=item.file_name,
                verdict=item.verdict.upper() if item.verdict else "BENIGN",
                scan_source=item.scan_source or "OFFLINE_HEURISTIC",
                scanned_at=item.scanned_at or datetime.utcnow()
            )
            db.add(scan_log)
            synced_count += 1
        
        db.commit()
        logger.info(f"Berhasil men-sync {synced_count} log pemindaian offline ke cloud untuk device_id: {device_id} (Session: {batch_session_id})")
        return {
            "synced_count": synced_count,
            "message": f"Berhasil sinkronisasi {synced_count} log telemetri pemindaian ke cloud server."
        }

    @classmethod
    def get_guest_quota_usage(cls, db: Session, device_id: str) -> dict:
        """
        Mengambil jumlah sesi pemindaian harian yang telah digunakan oleh device_id motherboard tertentu.
        Menghitung sesi pemindaian unik (batch) agar 1 kali Full System Scan / Folder Scan 
        tidak memotong kuota 65x lipat per file.
        """
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        
        distinct_sessions = db.query(
            func.count(func.distinct(func.coalesce(ScanLog.session_id, func.to_char(ScanLog.scanned_at, 'YYYY-MM-DD HH24:MI'))))
        ).filter(
            ScanLog.device_id == device_id,
            ScanLog.scanned_at >= today_start
        ).scalar() or 0

        max_quota = 15
        remaining = max(0, max_quota - distinct_sessions)
        return {
            "device_id": device_id,
            "used_scans": distinct_sessions,
            "max_quota": max_quota,
            "remaining_scans": remaining,
            "is_quota_exceeded": distinct_sessions >= max_quota
        }

    @classmethod
    def reset_guest_quota_usage(cls, db: Session, device_id: str) -> dict:
        """
        Mereset pemindaian harian guest untuk device_id tertentu.
        """
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        deleted = db.query(ScanLog).filter(
            ScanLog.device_id == device_id,
            ScanLog.scanned_at >= today_start
        ).delete(synchronize_session=False)
        db.commit()
        logger.info(f"Mereset {deleted} log pemindaian hari ini untuk device_id: {device_id}")
        return {
            "device_id": device_id,
            "deleted_count": deleted,
            "used_scans": 0,
            "remaining_scans": 15,
            "message": f"Berhasil mereset kuota scan harian untuk perangkat {device_id}."
        }



