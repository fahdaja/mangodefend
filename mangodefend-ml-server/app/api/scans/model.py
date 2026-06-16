# app/api/scans/model.py
from sqlalchemy import Column, Integer, String, BigInteger, DateTime
from sqlalchemy.sql import func

from app.db.database import Base


class ScanLog(Base):
    """Model untuk mencatat log setiap file yang di-scan."""

    __tablename__ = "scan_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    filename = Column(String(255), nullable=False, comment="Nama file yang di-scan")
    file_size = Column(BigInteger, nullable=False, comment="Ukuran file dalam bytes")
    label = Column(String(50), nullable=False, comment="Hasil prediksi: malware / benign")
    app_platform = Column(
        String(50),
        nullable=False,
        server_default="Unknown",
        comment="Platform asal request: Desktop atau Mobile",
    )
    scanned_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="Waktu scan dilakukan",
    )
