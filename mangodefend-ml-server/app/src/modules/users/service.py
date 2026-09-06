from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.src.modules.users.models import User
from app.src.modules.users.schemas import UserProfileResponse, UpdatePasswordRequest, UpdatePasswordResponse
from app.src.utils.hash import hash_password, verify_password
from app.src.core.redis import revoke_all_user_sessions


async def get_user_profile(db: Session, user_id: int) -> UserProfileResponse:
    """Mengambil profil pengguna berdasarkan user_id."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    return user


async def change_password(db: Session, user_id: int, req: UpdatePasswordRequest) -> UpdatePasswordResponse:
    """Mengubah password pengguna setelah memverifikasi password lama."""
    existing_user = db.query(User).filter(User.id == user_id).first()
    if not existing_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if not verify_password(req.old_password, existing_user.password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect old password"
        )

    if req.old_password == req.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password cannot be the same as the old password"
        )

    existing_user.password = hash_password(req.new_password)
    db.commit()
    db.refresh(existing_user)

    await revoke_all_user_sessions(user_id=user_id)

    return UpdatePasswordResponse(message="Password successfully updated")
