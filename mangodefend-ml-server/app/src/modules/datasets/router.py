from typing import Optional
from fastapi import APIRouter, Depends, UploadFile, File, Query, HTTPException, status
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.modules.datasets.schemas import DatasetSampleSchema, DatasetExportResponse
from app.src.modules.datasets.service import DatasetService

router = APIRouter(prefix="/datasets", tags=["ML Dataset Management"])


@router.get(
    "/export",
    response_model=DatasetExportResponse,
    summary="Ekspor Dataset Benign & Malware untuk Training ML",
    description="Mengunduh seluruh sampel dataset beserta vektor fiturnya (Byte Entropy, Histogram, Ukuran File)."
)
async def export_dataset(
    label: Optional[str] = Query(None, description="Filter dataset: 'benign', 'malware', atau kosongkan untuk semua"),
    db: Session = Depends(get_db)
):
    return DatasetService.export_dataset(db=db, label_filter=label)
