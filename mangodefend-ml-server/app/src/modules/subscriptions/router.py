from typing import List, Dict, Any
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.src.core.database import get_db
from app.src.modules.auth.dependencies import get_current_user
from app.src.modules.auth.models import User
from app.src.modules.subscriptions.schemas import (
    SubscriptionPlanResponse,
    UserSubscriptionResponse,
    CheckoutRequest,
    CheckoutResponse
)
from app.src.modules.subscriptions.service import SubscriptionService

router = APIRouter(prefix="/subscriptions", tags=["Subscriptions & Payment System"])


@router.get(
    "/plans",
    response_model=List[SubscriptionPlanResponse],
    summary="Dapatkan Daftar Paket Langganan",
    description="Mengambil daftar paket langganan (Free, Pro, Premium) beserta rincian izin fiturnya."
)
def list_subscription_plans(
    db: Session = Depends(get_db)
):
    return SubscriptionService.list_plans(db=db)


@router.get(
    "/my-subscription",
    response_model=UserSubscriptionResponse,
    summary="Dapatkan Status Langganan Aktif Pengguna",
    description="Mengambil status langganan aktif pengguna beserta rincian kuota scan dan fitur yang didapat."
)
def get_my_subscription(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return SubscriptionService.get_user_subscription(db=db, user_id=current_user.id)


@router.post(
    "/checkout",
    response_model=CheckoutResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Checkout Paket Langganan",
    description="Melakukan pesanan langganan baru dan mendapatkan token/link pembayaran (QRIS, Virtual Account, dll)."
)
def checkout_subscription(
    payload: CheckoutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return SubscriptionService.checkout_plan(
        db=db,
        user_id=current_user.id,
        plan_id=payload.plan_id,
        payment_method=payload.payment_method
    )


@router.post(
    "/payments/webhook",
    summary="Webhook Callback Notifikasi Pembayaran",
    description="Endpoint webhook callback dari Payment Gateway Midtrans untuk verifikasi pembayaran otomatis."
)
def payment_webhook_callback(
    payload: Dict[str, Any],
    db: Session = Depends(get_db)
):
    return SubscriptionService.webhook_notification(db=db, payload=payload)


@router.get(
    "/payments/{transaction_id}/status",
    summary="Cek Status Pembayaran Transaksi",
    description="Mengecek status pembayaran transaksi di database dan mengecek status terkini langsung ke Midtrans Core API."
)
def get_payment_status(
    transaction_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return SubscriptionService.get_transaction_status(db=db, transaction_id=transaction_id)


@router.post(
    "/cancel",
    summary="Batalkan Langganan Aktif Pengguna",
    description="Membatalkan paket langganan aktif pengguna dan mengembalikan akun ke Paket Starter Free."
)
def cancel_subscription(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return SubscriptionService.cancel_user_subscription(db=db, user_id=current_user.id)


