from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field

from app.src.modules.scans.enums import ScanVerdict, ScanSource


class HashLookupRequest(BaseModel):
    sha256: str = Field(..., min_length=64, max_length=64, description="Hash SHA-256 (64 karakter hex)")


class HashLookupResponse(BaseModel):
    found: bool
    sha256: str
    status: ScanVerdict
    source: ScanSource


class FileScanResponse(BaseModel):
    sha256: str
    md5: str
    file_name: Optional[str] = None
    verdict: ScanVerdict
    scan_source: ScanSource


class ScanLogSchema(BaseModel):
    id: int
    device_id: Optional[str] = None
    file_hash: str
    file_name: Optional[str] = None
    verdict: ScanVerdict
    scan_source: ScanSource
    scanned_at: datetime

    class Config:
        from_attributes = True


# ==========================================
# BULK SIGNATURE IMPORT SCHEMAS
# ==========================================

class SignatureImportItem(BaseModel):
    sha256: str = Field(..., min_length=64, max_length=64)
    md5: Optional[str] = None
    file_name: Optional[str] = None
    file_size: Optional[int] = None
    status: ScanVerdict = ScanVerdict.MALICIOUS
    source: Optional[str] = "BULK_IMPORT"


class SignatureImportRequest(BaseModel):
    signatures: List[SignatureImportItem]


class SignatureImportResponse(BaseModel):
    imported_count: int
    skipped_count: int
    total_processed: int


# ==========================================
# OFFLINE TELEMETRY SYNC SCHEMAS
# ==========================================

class TelemetrySyncItem(BaseModel):
    file_hash: str = Field(..., description="Hash SHA-256 berkas")
    file_name: Optional[str] = None
    verdict: str = Field(..., description="Scan verdict: malicious atau safe")
    scan_source: ScanSource = Field(ScanSource.OFFLINE_HEURISTIC, description="Sumber scan")
    scanned_at: Optional[datetime] = None


class TelemetrySyncRequest(BaseModel):
    device_id: Optional[str] = None
    items: List[TelemetrySyncItem]


class TelemetrySyncResponse(BaseModel):
    synced_count: int
    message: str

