from enum import Enum
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, EmailStr


# Role Enum
class UserRole(str, Enum):
    ADMIN = "admin"
    CLIENT = "client"


# Register request
class RegisterRequest(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None
    os_version: Optional[str] = None
    role: Optional[UserRole] = UserRole.CLIENT


# Register response
class RegisterResponse(BaseModel):
    id: int
    full_name: str
    message: str


# Token response
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime


# Refresh token request
class RefreshTokenRequest(BaseModel):
    refresh_token: str


# Token payload
class TokenData(BaseModel):
    id: int
    email: str
    role: UserRole


# Login request
class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    device_id: Optional[str] = None
    device_name: Optional[str] = None
    os_version: Optional[str] = None
    role: Optional[UserRole] = None


# Google OAuth request
class GoogleOAuthRequest(BaseModel):
    id_token: str
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    device_id: Optional[str] = None
    device_name: Optional[str] = None
    os_version: Optional[str] = None
    is_registration: Optional[bool] = False



# Login response
class LoginResponse(BaseModel):
    success: bool
    message: str
    data: dict


# Logout request
class LogoutRequest(BaseModel):
    user_id: int
    session_token: str


# Logout response
class LogoutResponse(BaseModel):
    message: str


# Update password request
class UpdatePasswordRequest(BaseModel):
    old_password: str
    new_password: str


# Update password response
class UpdatePasswordResponse(BaseModel):
    message: str