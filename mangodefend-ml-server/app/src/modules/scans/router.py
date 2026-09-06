from typing import List, Optional
from fastapi import APIRouter, Depends, UploadFile, File, Form, Query, HTTPException, status, Response
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.modules.auth.dependencies import get_optional_current_user
from app.src.modules.auth.models import User
from app.src.modules.scans.schemas import (
    HashLookupRequest,
    HashLookupResponse,
    FileScanResponse,
    ScanLogSchema,
    SignatureImportRequest,
    SignatureImportResponse,
    TelemetrySyncRequest,
    TelemetrySyncResponse
)
from app.src.modules.scans.service import CloudScanService

router = APIRouter(prefix="/scans", tags=["Cloud Scans"])


@router.post(
    "/lookup",
    response_model=HashLookupResponse,
    summary="Fast Cloud Hash Lookup",
    description="Pengecekan cepat status reputasi file berdasarkan hash SHA-256 via Redis L1 Cache & PostgreSQL L2 Database."
)
async def lookup_hash(
    payload: HashLookupRequest,
    db: Session = Depends(get_db)
):
    return await CloudScanService.lookup_hash(db=db, sha256=payload.sha256)


@router.post(
    "/analyze",
    response_model=ScanLogSchema,
    summary="Cloud ML Analysis",
    description="Mengunggah file biner untuk pemindaian ML dan pengecekan tingkat keamanan file dengan batasan paket langganan."
)
async def analyze_file(
    file: UploadFile = File(..., description="File binary yang akan di-scan"),
    device_id: Optional[str] = Form(None, description="ID Perangkat Client (Opsional)"),
    session_id: Optional[str] = Form(None, description="ID Sesi Pemindaian unik untuk batch scan"),
    scan_type: str = Form("upload", description="Tipe Scan: upload, folder, full_system, apk_download, file_download, realtime_monitoring"),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_current_user)
):
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File binary tidak boleh kosong (0 bytes)."
        )

    file_name = file.filename or "unknown_sample.bin"
    user_id = current_user.id if current_user else None

    return await CloudScanService.analyze_file(
        db=db,
        file_bytes=file_bytes,
        file_name=file_name,
        device_id=device_id,
        user_id=user_id,
        scan_type=scan_type,
        session_id=session_id
    )


@router.get(
    "/signatures/latest",
    summary="Export Signatures to MDB1 Binary",
    description="Membaca tabel malware_signatures di PostgreSQL dan mengonversinya menjadi berkas biner MDB1.",
    responses={
        200: {
            "content": {"application/octet-stream": {}},
            "description": "Berkas biner database signature MDB1."
        }
    }
)
async def get_latest_signatures_mdb1(
    db: Session = Depends(get_db)
):
    binary_data, count = CloudScanService.export_signatures_to_mdb1(db=db)
    return Response(
        content=binary_data,
        media_type="application/octet-stream",
        headers={
            "Content-Disposition": 'attachment; filename="signatures_latest.mdb1"',
            "X-Signature-Count": str(count),
            "X-Format-Version": "MDB1"
        }
    )


@router.post(
    "/signatures/import",
    response_model=SignatureImportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Import Massal Malware Signatures",
    description="Meng-import daftar hash SHA-256 malware yang sudah ada sebelumnya ke dalam master database."
)
async def import_signatures(
    payload: SignatureImportRequest,
    db: Session = Depends(get_db)
):
    return CloudScanService.bulk_import_signatures(db=db, items=payload.signatures)


@router.post(
    "/signatures/verify-pending",
    summary="Verifikasi Signature Pending",
    description="Memverifikasi seluruh signature berstatus PENDING_VERIFICATION dan mempromosikannya ke VERIFIED_MALICIOUS atau FALSE_POSITIVE."
)
async def verify_pending_signatures(
    db: Session = Depends(get_db)
):
    return CloudScanService.verify_pending_signatures(db=db)


@router.post(
    "/signatures/whitelist/{sha256:path}",
    summary="Tandai Hash sebagai Whitelist / False Positive",
    description="Mengubah status signature di PostgreSQL menjadi FALSE_POSITIVE dan menghapus cache Redis-nya."
)
async def mark_signature_as_whitelist(
    sha256: str,
    db: Session = Depends(get_db)
):
    return await CloudScanService.mark_as_whitelist(db=db, sha256=sha256)


@router.get(
    "/history/{device_id}",
    response_model=List[ScanLogSchema],
    summary="Dapatkan Histori Pemindaian Perangkat",
    description="Mengambil daftar histori pemindaian file milik perangkat client tertentu."
)
async def get_device_scan_history(
    device_id: str,
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db)
):
    return CloudScanService.get_device_history(db=db, device_id=device_id, limit=limit)


@router.post(
    "/sync-telemetry",
    response_model=TelemetrySyncResponse,
    status_code=status.HTTP_200_OK,
    summary="Sync Telemetri Pemindaian Offline",
    description="Menerima antrean log pemindaian offline dari perangkat client saat terhubung kembali ke internet."
)
async def sync_offline_telemetry(
    payload: TelemetrySyncRequest,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_current_user)
):
    user_id = current_user.id if current_user else None
    res = await CloudScanService.sync_offline_telemetry(
        db=db,
        device_id=payload.device_id,
        items=payload.items,
        user_id=user_id
    )
    return TelemetrySyncResponse(**res)


@router.get(
    "/guest-quota/{device_id}",
    status_code=status.HTTP_200_OK,
    summary="Cek Sisa Kuota Pemindaian Guest per Perangkat Hardware",
    description="Mengembalikan statistik penggunaan kuota scan harian gratis berdasarkan Motherboard Hardware Device ID."
)
def get_guest_quota(
    device_id: str,
    db: Session = Depends(get_db)
):
    return CloudScanService.get_guest_quota_usage(db=db, device_id=device_id)


@router.post(
    "/guest-quota/reset/{device_id}",
    status_code=status.HTTP_200_OK,
    summary="Reset Kuota Pemindaian Guest per Perangkat Hardware",
    description="Mereset statistik pemindaian harian guest untuk perangkat tertentu."
)
def reset_guest_quota(
    device_id: str,
    db: Session = Depends(get_db)
):
    return CloudScanService.reset_guest_quota_usage(db=db, device_id=device_id)

