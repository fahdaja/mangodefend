from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field

from app.src.modules.scans.enums import ScanVerdict


class DatasetCollectionRequest(BaseModel):
    file_name: str
    sha256: str
    file_size: int
    label: int = Field(..., description="0 untuk BENIGN (Aman), 1 untuk MALICIOUS (Berbahaya)")


class DatasetSampleSchema(BaseModel):
    id: int
    sha256: str
    file_name: Optional[str] = None
    file_size: int
    label: int
    status_label: ScanVerdict
    image_url: Optional[str] = None
    source: str
    created_at: datetime

    class Config:
        from_attributes = True


class DatasetExportResponse(BaseModel):
    total_samples: int
    benign_count: int
    malware_count: int
    samples: List[DatasetSampleSchema]
