from datetime import datetime
from pydantic import BaseModel, EmailStr


class UserProfileResponse(BaseModel):
    id: int
    full_name: str
    email: EmailStr
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


class UpdatePasswordRequest(BaseModel):
    old_password: str
    new_password: str


class UpdatePasswordResponse(BaseModel):
    message: str
