import logging
import boto3
from botocore.exceptions import BotoCoreError, ClientError
from typing import Optional

from app.src.core.config import settings

logger = logging.getLogger("mangodefend.storage")


class SupabaseStorageService:
    """Service client untuk mengunggah file ke Supabase Storage (S3 Compatible API)."""

    def __init__(self):
        self.endpoint_url = settings.S3_ENDPOINT_URL
        self.access_key = settings.S3_ACCESS_KEY_ID
        self.secret_key = settings.S3_SECRET_ACCESS_KEY
        self.region = settings.S3_REGION

    def is_configured(self) -> bool:
        """Mengecek apakah kredensial S3 valid dan diisi (bukan dummy/placeholder)."""
        if not self.endpoint_url or not self.access_key or not self.secret_key:
            return False
        
        dummy_keywords = ["your-supabase-url", "your_access_key", "your_secret_key", "example.com"]
        for kw in dummy_keywords:
            if kw in self.endpoint_url or kw in self.access_key or kw in self.secret_key:
                return False
                
        return True

    def check_credentials_and_warn(self) -> None:
        """Memeriksa file .env dan memberikan peringatan jika kredensial S3 masih dummy / belum diisi."""
        if not self.is_configured():
            logger.warning(
                "\n"
                "========================================================================\n"
                "[S3 CONFIG WARNING] Kredensial S3 / Supabase Storage BELUM dikonfigurasi!\n"
                "Harap isi variabel berikut di file .env Anda:\n"
                "  - S3_ENDPOINT_URL (contoh: https://<project-ref>.supabase.co/storage/v1/s3)\n"
                "  - S3_ACCESS_KEY_ID (Kunci akses S3 dari provider)\n"
                "  - S3_SECRET_ACCESS_KEY (Kunci rahasia S3 dari provider)\n"
                "Pengunggahan file ke S3 Storage akan dilewati sampai kredensial diisi.\n"
                "========================================================================"
            )

    def _get_s3_client(self):
        """Membuat instance Boto3 S3 Client."""
        if not self.is_configured():
            return None

        try:
            return boto3.client(
                "s3",
                endpoint_url=self.endpoint_url,
                aws_access_key_id=self.access_key,
                aws_secret_access_key=self.secret_key,
                region_name=self.region
            )
        except Exception as e:
            logger.error(f"[SupabaseStorage] Failed to initialize S3 Boto3 Client: {e}")
            return None

    def ensure_buckets_exist(self) -> None:
        """Secara otomatis memeriksa dan membuat bucket & folder hirarki yang dibutuhkan di S3 Storage."""
        if not self.is_configured():
            return

        s3_client = self._get_s3_client()
        if not s3_client:
            return

        required_buckets = [settings.S3_BUCKET_RAW, settings.S3_BUCKET_QUARANTINE]
        for bucket in required_buckets:
            try:
                s3_client.head_bucket(Bucket=bucket)
                logger.info(f"[SupabaseStorage] Verified S3 bucket: '{bucket}'")
            except ClientError as e:
                error_code = str(e.response.get("Error", {}).get("Code", ""))
                if error_code in ("404", "NoSuchBucket", "403"):
                    try:
                        logger.info(f"[SupabaseStorage] Creating missing S3 bucket: '{bucket}'...")
                        s3_client.create_bucket(Bucket=bucket)
                        logger.info(f"[SupabaseStorage] Successfully created bucket: '{bucket}'.")
                    except Exception as create_err:
                        logger.error(f"[SupabaseStorage] Failed to create bucket '{bucket}': {create_err}")
                else:
                    logger.warning(f"[SupabaseStorage] Bucket check warning for '{bucket}': {e}")

        # Inisialisasi folder placeholder yang dibutuhkan
        required_folders = [
            (settings.S3_BUCKET_RAW, "unrecognized_samples/"),
            (settings.S3_BUCKET_RAW, "dataset/images/benign/"),
            (settings.S3_BUCKET_RAW, "dataset/images/malware/"),
            (settings.S3_BUCKET_QUARANTINE, "unrecognized_samples/"),
        ]
        for b_name, folder_path in required_folders:
            try:
                s3_client.put_object(Bucket=b_name, Key=folder_path, Body=b"")
            except Exception:
                pass

    def upload_file(
        self,
        file_bytes: bytes,
        destination_key: str,
        bucket_name: Optional[str] = None,
        content_type: str = "application/octet-stream"
    ) -> Optional[str]:
        """
        Mengunggah file biner ke Supabase S3 Storage Bucket.
        
        Args:
            file_bytes: Byte mentah file
            destination_key: Path/Nama file tujuan di bucket (misal: "samples/sha256_sample.bin")
            bucket_name: Nama bucket Supabase (default: settings.S3_BUCKET_RAW)
            content_type: MIME type file
            
        Returns:
            Optional[str]: URL/Key penyimpanan jika berhasil, None jika gagal/unconfigured.
        """
        bucket = bucket_name or settings.S3_BUCKET_RAW
        s3_client = self._get_s3_client()
        
        if s3_client is None:
            logger.warning(f"[SupabaseStorage] Skipping upload for '{destination_key}' (S3 Client disabled).")
            return None

        try:
            s3_client.put_object(
                Bucket=bucket,
                Key=destination_key,
                Body=file_bytes,
                ContentType=content_type
            )
            file_url = f"{self.endpoint_url}/{bucket}/{destination_key}"
            logger.info(f"[SupabaseStorage] Successfully uploaded unrecognized file to Supabase Storage: {destination_key}")
            return file_url

        except (BotoCoreError, ClientError) as e:
            logger.error(f"[SupabaseStorage] Failed to upload file '{destination_key}' to Supabase: {e}")
            return None

    def move_file(
        self,
        source_bucket: str,
        source_key: str,
        dest_bucket: str,
        dest_key: str
    ) -> Optional[str]:
        """Memindahkan file dari satu bucket ke bucket lain di S3 Storage."""
        s3_client = self._get_s3_client()
        if s3_client is None:
            return None

        try:
            s3_client.copy_object(
                Bucket=dest_bucket,
                Key=dest_key,
                CopySource={'Bucket': source_bucket, 'Key': source_key}
            )
            s3_client.delete_object(Bucket=source_bucket, Key=source_key)
            file_url = f"{self.endpoint_url}/{dest_bucket}/{dest_key}"
            logger.info(f"[SupabaseStorage] Successfully moved file from '{source_bucket}/{source_key}' to '{dest_bucket}/{dest_key}'.")
            return file_url
        except Exception as e:
            logger.error(f"[SupabaseStorage] Failed to move file from '{source_bucket}' to '{dest_bucket}': {e}")
            return None


# Singleton instance storage service
supabase_storage = SupabaseStorageService()
