from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey

from app.src.core.database import Base


class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    device_id = Column(String(255), unique=True, nullable=False, index=True)
    device_name = Column(String(255), nullable=True)
    os_version = Column(String(100), nullable=True)
    last_active_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
