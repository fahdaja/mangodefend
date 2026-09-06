from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.src.modules.auth.schemas import (
    RegisterRequest, 
    RegisterResponse, 
    LoginRequest, 
    GoogleOAuthRequest,
    LoginResponse, 
    TokenResponse,
    LogoutResponse,
    RefreshTokenRequest
)
from app.src.modules.auth.models import User
from app.src.modules.devices.models import Device
from app.src.utils.hash import hash_password, verify_password
from app.src.core.security import create_access_token, create_refresh_token, decode_token
from app.src.core.redis import create_user_session, revoke_session, revoke_all_user_sessions
from app.src.core.config import settings




async def sign_up(db: Session, user: RegisterRequest) -> RegisterResponse:
    # 1. Check if email already exists
    existing_user = db.query(User).filter(User.email == user.email).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email sudah terdaftar"
        )
    
    # 2. Hash raw password
    hashed_pwd = hash_password(user.password)

    # 3. Create & insert User model
    role_str = user.role.value if hasattr(user.role, "value") else str(user.role)
    new_user = User(
        full_name=user.full_name,
        email=user.email,
        password=hashed_pwd,
        role=role_str
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # 4. Create device entry if device_id provided and not already registered
    if user.device_id:
        dev_name = user.device_name 
        os_ver = user.os_version
        existing_device = db.query(Device).filter(Device.device_id == user.device_id).first()
        if not existing_device:
            new_device = Device(
                user_id=new_user.id,
                device_id=user.device_id,
                device_name=dev_name,
                os_version=os_ver
            )
            db.add(new_device)
        else:
            existing_device.user_id = new_user.id
            if user.device_name:
                existing_device.device_name = user.device_name
            if user.os_version:
                existing_device.os_version = user.os_version
        db.commit()

    return RegisterResponse(
        id=new_user.id,
        full_name=new_user.full_name,
        message="User successfully registered"
    )


async def sign_in(db: Session, user: LoginRequest) -> LoginResponse:
    # 1. Cari user berdasarkan Email di Database
    existing_user = db.query(User).filter(User.email == user.email).first()

    if not existing_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email belum terdaftar. Silakan buat akun baru terlebih dahulu."
        )

    # 2. Jika akun terdaftar via Google OAuth (password awal: oauth_google_protected)
    #    dan user mencoba login via Form Input, otomatis daftarkan password baru ini!
    if verify_password("oauth_google_protected", existing_user.password):
        existing_user.password = hash_password(user.password)
        db.commit()
        db.refresh(existing_user)
    elif not verify_password(user.password, existing_user.password):
        # 3. Verifikasi kecocokan bcrypt password
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Password yang Anda masukkan salah. Silakan coba lagi."
        )

    # 3. Verifikasi role jika disertakan
    if user.role:
        req_role = user.role.value if hasattr(user.role, "value") else str(user.role)
        if existing_user.role != req_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied for this role"
            )

    # 4. Catat perangkat baru ke database jika device_id dikirim dan belum terdaftar
    if user.device_id:
        dev_name = user.device_name or "Perangkat Terhubung"
        os_ver = user.os_version or "Android"
        existing_device = db.query(Device).filter(
            Device.device_id == user.device_id
        ).first()

        if not existing_device:
            new_device = Device(
                user_id=existing_user.id,
                device_id=user.device_id,
                device_name=dev_name,
                os_version=os_ver
            )
            db.add(new_device)
        else:
            existing_device.user_id = existing_user.id
            if user.device_name:
                existing_device.device_name = user.device_name
            if user.os_version:
                existing_device.os_version = user.os_version
        db.commit()

    # 5. Generate JWT Access Token & Refresh Token
    token_payload = {
        "sub": str(existing_user.id),
        "email": existing_user.email,
        "role": existing_user.role
    }
    
    access_token = create_access_token(subject=token_payload)
    refresh_token = create_refresh_token(subject=token_payload)
    expire_seconds = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    expires_at = datetime.utcnow() + timedelta(seconds=expire_seconds)

    # 5. MANAJEMEN SESSION VIA REDIS
    await create_user_session(
        user_id=existing_user.id,
        token=access_token,
        expire_seconds=expire_seconds
    )

    # 6. Return response
    return LoginResponse(
        success= True,
        message='Login successful',
        data={
            'id': existing_user.id,
            'full_name': existing_user.full_name,
            'email': existing_user.email,
            'token': TokenResponse(
                access_token=access_token,
                refresh_token=refresh_token,
                token_type="bearer",
                expires_at=expires_at
            )
        }
    )


async def refresh_user_token(db: Session, req: RefreshTokenRequest) -> TokenResponse:
    """
    Memperbarui Access Token menggunakan Refresh Token tanpa perlu re-login.
    """
    # 1. Dekode Refresh Token
    payload = decode_token(req.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = int(payload.get("sub"))
    
    # 2. Verifikasi keberadaan User di DB
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    # 3. Buat Access Token & Refresh Token baru
    token_payload = {
        "sub": str(user.id),
        "email": user.email,
        "role": user.role
    }
    new_access_token = create_access_token(subject=token_payload)
    new_refresh_token = create_refresh_token(subject=token_payload)
    expire_seconds = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    expires_at = datetime.utcnow() + timedelta(seconds=expire_seconds)

    # 4. Daftarkan Access Token baru ke Redis Session
    await create_user_session(
        user_id=user.id,
        token=new_access_token,
        expire_seconds=expire_seconds
    )

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_at=expires_at
    )


async def sign_out(user_id: int, token: str) -> LogoutResponse:
    """Logout dari perangkat saat ini (Hapus token spesifik dari Redis)."""
    await revoke_session(user_id=user_id, token=token)
    return LogoutResponse(message="Successfully logged out from current device")


async def sign_out_all_devices(user_id: int) -> LogoutResponse:
    """Force Logout dari SEMUA perangkat (Hapus seluruh session user dari Redis)."""
    await revoke_all_user_sessions(user_id=user_id)
    return LogoutResponse(message="Successfully logged out from all devices")


async def sign_in_with_google(db: Session, req: GoogleOAuthRequest) -> LoginResponse:
    """Authentication handler for Google OAuth id_token."""
    token_suffix = req.id_token[-8:] if len(req.id_token) >= 8 else req.id_token
    email = req.email or f"user_{token_suffix}@gmail.com"
    full_name = req.full_name or f"Google User {token_suffix}"

    existing_user = db.query(User).filter(User.email == email).first()
    is_new_user = False
    if not existing_user:
        if not req.is_registration:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email/Akun Google belum terdaftar. Silakan buat akun baru terlebih dahulu di halaman Registrasi."
            )
        is_new_user = True
        existing_user = User(
            full_name=full_name,
            email=email,
            password=hash_password("oauth_google_protected"),
            role="client"
        )
        db.add(existing_user)
        db.commit()
        db.refresh(existing_user)
    else:
        if req.full_name and existing_user.full_name != req.full_name:
            existing_user.full_name = req.full_name
            db.commit()
            db.refresh(existing_user)

    if req.device_id:
        dev_name = req.device_name or "Perangkat Terhubung"
        os_ver = req.os_version or "Android"
        existing_device = db.query(Device).filter(
            Device.device_id == req.device_id
        ).first()

        if not existing_device:
            new_device = Device(
                user_id=existing_user.id,
                device_id=req.device_id,
                device_name=dev_name,
                os_version=os_ver
            )
            db.add(new_device)
        else:
            existing_device.user_id = existing_user.id
            if req.device_name:
                existing_device.device_name = req.device_name
            if req.os_version:
                existing_device.os_version = req.os_version
        db.commit()

    token_payload = {
        "sub": str(existing_user.id),
        "email": existing_user.email,
        "role": existing_user.role
    }

    access_token = create_access_token(subject=token_payload)
    refresh_token = create_refresh_token(subject=token_payload)
    expire_seconds = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    expires_at = datetime.utcnow() + timedelta(seconds=expire_seconds)

    await create_user_session(
        user_id=existing_user.id,
        token=access_token,
        expire_seconds=expire_seconds
    )

    return LoginResponse(
        success=True,
        message="Google OAuth login successful",
        data={
            "id": existing_user.id,
            "full_name": existing_user.full_name,
            "email": existing_user.email,
            "is_new_user": is_new_user,
            "token": TokenResponse(
                access_token=access_token,
                refresh_token=refresh_token,
                token_type="bearer",
                expires_at=expires_at
            )
        }
    )




