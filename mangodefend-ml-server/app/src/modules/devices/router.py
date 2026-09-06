from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.modules.auth.dependencies import get_current_user
from app.src.modules.auth.models import User
from app.src.modules.devices.schemas import DeviceResponse, DeleteDeviceResponse, DeleteDeviceRequest
from app.src.modules.devices.service import get_my_devices, delete_user_device

router = APIRouter(prefix="/devices", tags=["Devices"])


@router.get("", response_model=List[DeviceResponse])
async def list_my_devices(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Endpoint untuk mendapatkan daftar seluruh perangkat yang terdaftar milik pengguna."""
    return await get_my_devices(db=db, user_id=current_user.id)

@router.delete("/{device_id}", response_model=DeleteDeviceResponse)
async def remove_device_by_path(
    device_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Endpoint alternatif untuk menghapus perangkat terhubung via Path Parameter."""
    return await delete_user_device(db=db, user_id=current_user.id, device_id=device_id)
