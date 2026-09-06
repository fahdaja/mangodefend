from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text

from app.src.core.database import Base
from app.src.modules.scans.enums import ScanVerdict


class MalwareSignature(Base):
    """Master database signatures malware & reputasi file cloud terpusat."""
    __tablename__ = "malware_signatures"

    id = Column(Integer, primary_key=True, index=True)
    sha256 = Column(String(64), unique=True, nullable=False, index=True)
    md5 = Column(String(32), nullable=True, index=True)
    file_name = Column(String(255), nullable=True)
    file_size = Column(Integer, nullable=True)
    status = Column(String(32), nullable=False, default=ScanVerdict.MALICIOUS.value) 
    source = Column(String(64), default="CLOUD_ML")  
    storage_url = Column(Text, nullable=True)  
    first_seen = Column(DateTime, default=datetime.utcnow)
    last_scanned = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ScanLog(Base):
    """Histori log pemindaian file dari perangkat client."""
    __tablename__ = "scan_logs"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String(255), nullable=True, index=True)
    session_id = Column(String(255), nullable=True, index=True)
    file_hash = Column(String(64), nullable=False, index=True)
    file_name = Column(String(255), nullable=True)
    verdict = Column(String(32), nullable=False)
    scan_source = Column(String(32), default="CLOUD_LOOKUP")
    scanned_at = Column(DateTime, default=datetime.utcnow)
