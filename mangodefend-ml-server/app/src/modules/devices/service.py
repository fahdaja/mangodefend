from typing import List
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.src.modules.devices.models import Device
from app.src.modules.devices.schemas import DeviceResponse, DeleteDeviceResponse


async def get_my_devices(db: Session, user_id: int) -> List[DeviceResponse]:
    """Mengambil seluruh daftar perangkat terhubung milik user."""
    devices = db.query(Device).filter(Device.user_id == user_id).order_by(Device.last_active_at.desc()).all()
    return devices


async def delete_user_device(db: Session, user_id: int, device_id: str) -> DeleteDeviceResponse:
    """Menghapus pendaftaran perangkat milik pengguna."""
    existing_device = db.query(Device).filter(
        Device.user_id == user_id,
        Device.device_id == device_id
    ).first()

    if not existing_device:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found for this user"
        )
    
    db.delete(existing_device)
    db.commit()
    return DeleteDeviceResponse(message="Device successfully deleted")
