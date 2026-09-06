from datetime import datetime
from pydantic import BaseModel


from typing import Optional

class DeviceResponse(BaseModel):
    id: int
    user_id: int
    device_id: str
    device_name: Optional[str] = None
    os_version: Optional[str] = None
    last_active_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class DeleteDeviceRequest(BaseModel):
    device_id: str


class DeleteDeviceResponse(BaseModel):
    message: str
