from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime

from app.src.core.database import Base


class DatasetSample(Base):
    """Tabel pengumpulan sampel file (Benign & Malware) untuk retraining model ML."""
    __tablename__ = "dataset_samples"

    id = Column(Integer, primary_key=True, index=True)
    sha256 = Column(String(64), nullable=False, index=True)
    file_name = Column(String(255), nullable=True)
    file_size = Column(Integer, nullable=False)
    label = Column(Integer, nullable=False)  # 0 = BENIGN, 1 = MALICIOUS
    status_label = Column(String(32), nullable=False)
    image_url = Column(String(512), nullable=True)
    features_json = Column(String, nullable=True, default="{}")
    source = Column(String(64), default="AUTO_COLLECT")
    created_at = Column(DateTime, default=datetime.utcnow)
