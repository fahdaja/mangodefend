import hashlib
import logging
from typing import Optional
from sqlalchemy.orm import Session

from app.src.core.config import settings
from app.src.core.storage import supabase_storage
from app.src.modules.scans.enums import DatasetSource
from app.src.modules.datasets.models import DatasetSample
from app.src.modules.datasets.schemas import DatasetSampleSchema, DatasetExportResponse

logger = logging.getLogger("mangodefend.datasets_service")


class DatasetService:
    """Service layer khusus pengumpulan dan manajemen dataset ML (Benign & Malware)."""

    @classmethod
    def save_sample(
        cls,
        db: Session,
        sha256: str,
        file_name: str,
        file_size: int,
        label: int,
        status_label: str,
        source: str = DatasetSource.AUTO_COLLECT.value,
        image_url: Optional[str] = None
    ) -> DatasetSample:
        """Menyimpan sampel file ke tabel dataset."""
        sample = DatasetSample(
            sha256=sha256.lower().strip(),
            file_name=file_name,
            file_size=file_size,
            label=label,
            status_label=status_label,
            image_url=image_url,
            features_json="{}",
            source=source
        )
        db.add(sample)
        db.commit()
        db.refresh(sample)
        return sample

    @staticmethod
    def update_sample_status(db: Session, sha256: str, status_label: str, label: int) -> None:
        """Memperbarui status_label dan label sampel dataset saat verifikasi selesai, serta memindahkan citra PNG di S3 jika perlu."""
        sha256_clean = sha256.lower().strip()
        sample = db.query(DatasetSample).filter(DatasetSample.sha256 == sha256_clean).first()
        if sample:
            sample.status_label = status_label
            sample.label = label

            # Jika direklasifikasi sebagai FALSE_POSITIVE / BENIGN (label 0), pindahkan citra PNG di S3 dari malware/ ke benign/
            if label == 0 and sample.image_url and "dataset/images/malware/" in sample.image_url:
                old_key = f"dataset/images/malware/{sha256_clean}.png"
                new_key = f"dataset/images/benign/{sha256_clean}.png"
                new_url = supabase_storage.move_file(
                    source_bucket=settings.S3_BUCKET_RAW,
                    source_key=old_key,
                    dest_bucket=settings.S3_BUCKET_RAW,
                    dest_key=new_key
                )
                if new_url:
                    sample.image_url = new_url

            db.commit()

    @staticmethod
    def export_dataset(db: Session, label_filter: Optional[str] = None) -> DatasetExportResponse:
        """Mengekspor sampel dataset (HANYA MALICIOUS yang terverifikasi untuk sampel malware)."""
        query = db.query(DatasetSample)
        if label_filter:
            clean_filter = label_filter.lower().strip()
            if clean_filter in ["benign", "safe"]:
                query = query.filter(DatasetSample.label == 0)
            elif clean_filter in ["malware", "malicious"]:
                query = query.filter(
                    DatasetSample.label == 1,
                    DatasetSample.status_label.in_(["MALICIOUS", "verified"])
                )

        samples = query.all()
        benign_count = sum(1 for s in samples if s.label == 0)
        malware_count = sum(1 for s in samples if s.label == 1 and s.status_label in ["MALICIOUS", "verified"])

        return DatasetExportResponse(
            total_samples=len(samples),
            benign_count=benign_count,
            malware_count=malware_count,
            samples=[DatasetSampleSchema.model_validate(s) for s in samples if s.label == 0 or s.status_label in ["MALICIOUS", "verified"]]
        )
