from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.modules.auth.dependencies import get_current_user
from app.src.modules.users.models import User
from app.src.modules.users.schemas import UserProfileResponse, UpdatePasswordRequest, UpdatePasswordResponse
from app.src.modules.users.service import get_user_profile, change_password

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Endpoint untuk mendapatkan informasi profil pengguna yang sedang login."""
    return await get_user_profile(db=db, user_id=current_user.id)


@router.post("/change-password", response_model=UpdatePasswordResponse)
async def update_password(
    req: UpdatePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Endpoint untuk memperbarui/mengubah password pengguna."""
    return await change_password(db=db, user_id=current_user.id, req=req)
