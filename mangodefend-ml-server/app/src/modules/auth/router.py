from fastapi import APIRouter, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.modules.auth.schemas import (
    RegisterRequest, 
    RegisterResponse, 
    LoginRequest, 
    GoogleOAuthRequest,
    LoginResponse,
    LogoutResponse,
    RefreshTokenRequest,
    TokenResponse
)
from app.src.modules.auth.service import (
    sign_up, 
    sign_in, 
    sign_in_with_google,
    sign_out, 
    sign_out_all_devices,
    refresh_user_token
)
from app.src.modules.auth.dependencies import get_current_user
from app.src.modules.users.models import User

router = APIRouter(prefix="/auth", tags=["Auth"])
security = HTTPBearer()


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register_user(user: RegisterRequest, db: Session = Depends(get_db)):
    """Endpoint untuk mendaftarkan akun baru."""
    return await sign_up(db=db, user=user)


@router.post("/login", response_model=LoginResponse)
async def login_user(user: LoginRequest, db: Session = Depends(get_db)):
    """Endpoint untuk login dan mendapatkan JWT Token & Redis Session."""
    return await sign_in(db=db, user=user)


@router.post("/google", response_model=LoginResponse)
async def login_google(req: GoogleOAuthRequest, db: Session = Depends(get_db)):
    """Endpoint untuk autentikasi Google OAuth id_token."""
    return await sign_in_with_google(db=db, req=req)


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(req: RefreshTokenRequest, db: Session = Depends(get_db)):
    """Endpoint untuk memperbarui Access Token menggunakan Refresh Token."""
    return await refresh_user_token(db=db, req=req)


@router.post("/logout", response_model=LogoutResponse)
async def logout_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    current_user: User = Depends(get_current_user)
):
    """Logout dari perangkat saat ini (Hapus session token dari Redis)."""
    return await sign_out(user_id=current_user.id, token=credentials.credentials)


@router.post("/logout-all", response_model=LogoutResponse)
async def logout_all_devices(
    current_user: User = Depends(get_current_user)
):
    """Force Logout dari seluruh perangkat (Hapus semua session user di Redis)."""
    return await sign_out_all_devices(user_id=current_user.id)




