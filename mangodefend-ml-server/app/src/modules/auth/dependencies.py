from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.core.security import decode_token
from app.src.core.redis import is_session_valid
from app.src.modules.users.models import User

security = HTTPBearer()
security_optional = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Dependency Guard:
    1. Dekode dan validasi tanda tangan JWT.
    2. Cek apakah token masih aktif di Redis (belum di-revoke/logout).
    3. Ambil data User dari database PostgreSQL.
    """
    token = credentials.credentials
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials or session has expired",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # 1. Decode JWT Token
    payload = decode_token(token)
    if not payload:
        raise credentials_exception

    user_id_str: str = payload.get("sub")
    if not user_id_str:
        raise credentials_exception

    user_id = int(user_id_str)

    # 2. Cek Keaktifan Session di Redis 
    session_active = await is_session_valid(user_id=user_id, token=token)
    if not session_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session has been revoked or logged out",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 3. Query User dari Database
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise credentials_exception

    return user


async def get_optional_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_optional),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """Dependency Guard Opsional: Mengembalikan User jika token valid, atau None jika tanpa token."""
    if not credentials or not credentials.credentials:
        return None
    try:
        return await get_current_user(credentials=credentials, db=db)
    except Exception:
        return None
