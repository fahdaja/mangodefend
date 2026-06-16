from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Any


class ScanResponse(BaseModel):
    """Response dari endpoint scan file."""
    id: int = Field(..., description="ID scan log di database")
    file_name: str = Field(..., description="Nama file yang di-scan")
    file_size: int = Field(..., description="Ukuran file dalam bytes")
    label: str = Field(..., description="Hasil klasifikasi: 'malware' atau 'benign'")
    app_platform: str = Field(default="Unknown", description="Platform asal request: Desktop atau Mobile")
    scanned_at: datetime = Field(..., description="Waktu scan dilakukan")


class PaginatedScanLogsResponse(BaseModel):
    """Response paginasi untuk log scan."""
    total: int = Field(..., description="Total log scan yang cocok")
    page: int = Field(..., description="Halaman aktif saat ini")
    limit: int = Field(..., description="Jumlah item per halaman")
    pages: int = Field(..., description="Total halaman yang tersedia")
    logs: List[ScanResponse] = Field(..., description="Daftar log scan")


class ScanStatsResponse(BaseModel):
    """Response untuk data statistik scan."""
    total_scans: int = Field(..., description="Total file yang di-scan")
    malware_count: int = Field(..., description="Jumlah file malware")
    benign_count: int = Field(..., description="Jumlah file benign")
    total_size_bytes: int = Field(..., description="Total ukuran file yang di-scan")
    malware_percentage: float = Field(..., description="Persentase malware")
    recent_activity: List[Any] = Field(..., description="Aktivitas harian scan")


class ErrorResponse(BaseModel):
    """Response untuk error."""
    detail: str

