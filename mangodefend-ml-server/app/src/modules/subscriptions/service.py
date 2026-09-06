import uuid
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.src.modules.users.models import User
from app.src.modules.subscriptions.models import SubscriptionPlan, UserSubscription, PaymentTransaction
from app.src.modules.subscriptions.schemas import (
    SubscriptionPlanResponse,
    UserSubscriptionResponse,
    CheckoutRequest,
    CheckoutResponse
)
from app.src.services.midtrans_service import MidtransService

logger = logging.getLogger("mangodefend.subscriptions_service")


class SubscriptionService:
    """Service layer untuk menangani Paket Langganan, Checkout Pembayaran, dan Webhook Midtrans."""

    @classmethod
    def seed_default_plans_if_empty(cls, db: Session) -> List[SubscriptionPlan]:
        """Secara otomatis mengisi data 3 paket bawaan (Free, Pro, Premium) jika tabel kosong."""
        existing_count = db.query(SubscriptionPlan).count()
        if existing_count == 0:
            logger.info("[SubscriptionService] Seeding default subscription plans...")
            default_plans = [
                SubscriptionPlan(
                    plan_name="Free",
                    price=0.0,
                    duration_days=3650,  # 10 tahun (Gratis selamanya)
                    max_daily_scans=30,
                    max_devices=1,
                    can_upload_scans=True,
                    can_upload_folder=True,
                    can_full_system_scan=True,
                    can_realtime_protection=False,
                    can_web_protection=False,
                    can_scheduled_scan=False,
                    is_active=True
                ),
                SubscriptionPlan(
                    plan_name="Pro Monthly",
                    price=49000.0,
                    duration_days=30,
                    max_daily_scans=200,
                    max_devices=3,
                    can_upload_scans=True,
                    can_upload_folder=True,
                    can_full_system_scan=True,
                    can_realtime_protection=True,
                    can_scheduled_scan=True,
                    is_active=True
                ),
                SubscriptionPlan(
                    plan_name="Pro Annual",
                    price=449000.0,
                    duration_days=365,
                    max_daily_scans=-1,  # Unlimited
                    max_devices=10,
                    can_upload_scans=True,
                    can_upload_folder=True,
                    can_full_system_scan=True,
                    can_realtime_protection=True,
                    can_scheduled_scan=True,
                    is_active=True
                )
            ]
            db.bulk_save_objects(default_plans)
            db.commit()
            logger.info("[SubscriptionService] Default plans seeded successfully.")

        return db.query(SubscriptionPlan).filter(SubscriptionPlan.is_active == True).all()

    @classmethod
    def list_plans(cls, db: Session) -> List[SubscriptionPlanResponse]:
        """Mengambil daftar seluruh paket langganan aktif."""
        plans = cls.seed_default_plans_if_empty(db)
        return [SubscriptionPlanResponse.model_validate(p) for p in plans]

    @classmethod
    def get_user_subscription(cls, db: Session, user_id: int) -> UserSubscriptionResponse:
        """
        Mengambil status langganan aktif milik pengguna.
        Jika pengguna belum memiliki paket, otomatis didaftarkan paket 'Free'.
        """
        sub = db.query(UserSubscription).filter(
            UserSubscription.user_id == user_id,
            UserSubscription.status == "ACTIVE"
        ).order_by(UserSubscription.created_at.desc()).first()

        # Cek jika langganan sudah kedaluwarsa
        if sub and sub.end_date < datetime.utcnow():
            sub.status = "EXPIRED"
            db.commit()
            sub = None

        # Auto-assign Free plan jika belum punya langganan aktif
        if not sub:
            free_plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.plan_name == "Free").first()
            if not free_plan:
                cls.seed_default_plans_if_empty(db)
                free_plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.plan_name == "Free").first()

            start_date = datetime.utcnow()
            end_date = start_date + timedelta(days=free_plan.duration_days)

            sub = UserSubscription(
                user_id=user_id,
                plan_id=free_plan.id,
                status="ACTIVE",
                start_date=start_date,
                end_date=end_date
            )
            db.add(sub)
            db.commit()
            db.refresh(sub)

        return UserSubscriptionResponse.model_validate(sub)

    @classmethod
    def checkout_plan(
        cls,
        db: Session,
        user_id: int,
        plan_id: int,
        payment_method: str = "QRIS"
    ) -> CheckoutResponse:
        """
        Melakukan transaksi checkout paket langganan dan menghasilkan order_id serta link pembayaran Midtrans.
        """
        plan = db.query(SubscriptionPlan).filter(
            SubscriptionPlan.id == plan_id,
            SubscriptionPlan.is_active == True
        ).first()

        if not plan:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Paket langganan tidak ditemukan atau sudah tidak aktif."
            )

        # 1. Generate Order ID Unik (misal: INV-20260822-XXXX)
        transaction_id = f"INV-{datetime.utcnow().strftime('%Y%m%d')}-{uuid.uuid4().hex[:8].upper()}"

        # 2. Jika paket Gratis (Free), langsung aktifkan tanpa pembayaran
        if plan.price == 0.0:
            start_date = datetime.utcnow()
            end_date = start_date + timedelta(days=plan.duration_days)

            # Nonaktifkan langganan lama
            db.query(UserSubscription).filter(UserSubscription.user_id == user_id).update({"status": "EXPIRED"})

            user_sub = UserSubscription(
                user_id=user_id,
                plan_id=plan.id,
                status="ACTIVE",
                start_date=start_date,
                end_date=end_date
            )
            db.add(user_sub)

            tx = PaymentTransaction(
                user_id=user_id,
                plan_id=plan.id,
                amount=0.0,
                payment_method="FREE",
                transaction_id=transaction_id,
                status="SUCCESS"
            )
            db.add(tx)
            db.commit()

            return CheckoutResponse(
                transaction_id=transaction_id,
                amount=0.0,
                payment_method="FREE",
                status="SUCCESS",
                payment_url=None,
                snap_token=None,
                created_at=datetime.utcnow()
            )

        # 3. Paket Berbayar (Pro / Premium) -> Buat transaksi PENDING via Midtrans API
        user = db.query(User).filter(User.id == user_id).first()
        user_name = user.full_name if user else f"User {user_id}"
        user_email = user.email if user else f"user{user_id}@mangodefend.id"

        try:
            midtrans_res = MidtransService.create_snap_transaction(
                order_id=transaction_id,
                gross_amount=plan.price,
                item_name=f"Paket {plan.plan_name} MangoDefend",
                customer_name=user_name,
                customer_email=user_email
            )
            snap_token = midtrans_res.get("snap_token")
            payment_url = midtrans_res.get("payment_url")
        except Exception as e:
            logger.error(f"[SubscriptionService] Failed to create Midtrans Snap transaction: {e}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Gagal menghubungkan ke Midtrans Payment Gateway: {str(e)}"
            )

        tx = PaymentTransaction(
            user_id=user_id,
            plan_id=plan.id,
            amount=plan.price,
            payment_method=payment_method,
            transaction_id=transaction_id,
            status="PENDING",
            snap_token=snap_token,
            payment_url=payment_url
        )
        db.add(tx)
        db.commit()

        logger.info(f"[SubscriptionService] Created checkout transaction {transaction_id} for user {user_id}")

        return CheckoutResponse(
            transaction_id=transaction_id,
            amount=plan.price,
            payment_method=payment_method,
            status="PENDING",
            payment_url=payment_url,
            snap_token=snap_token,
            created_at=datetime.utcnow()
        )

    @classmethod
    def webhook_notification(cls, db: Session, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Menangani webhook callback notifikasi dari Payment Gateway Midtrans.
        Verifikasi signature SHA-512 & otomatis mengaktifkan langganan pengguna jika status pembayaran 'settlement' / 'capture'.
        """
        transaction_id = payload.get("order_id") or payload.get("transaction_id")
        payment_status = payload.get("transaction_status") or payload.get("status")
        signature_key = payload.get("signature_key")
        status_code = payload.get("status_code", "")
        gross_amount = payload.get("gross_amount", "")

        if not transaction_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Payload webhook tidak valid: Missing transaction_id/order_id."
            )

        # Verifikasi signature key jika ada
        if signature_key and status_code and gross_amount:
            is_valid_signature = MidtransService.verify_signature(
                order_id=transaction_id,
                status_code=str(status_code),
                gross_amount=str(gross_amount),
                signature_key=signature_key
            )
            if not is_valid_signature:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Signature key notifikasi Midtrans tidak valid."
                )

        tx = db.query(PaymentTransaction).filter(PaymentTransaction.transaction_id == transaction_id).first()
        if not tx:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Transaksi dengan ID '{transaction_id}' tidak ditemukan."
            )

        fraud_status = payload.get("fraud_status", "accept")

        # Cek status sukses dari Midtrans ('settlement', 'capture' dengan fraud_status 'accept', 'SUCCESS')
        if (payment_status in ["settlement", "SUCCESS", "success"]) or (payment_status == "capture" and fraud_status == "accept"):
            tx.status = "SUCCESS"
            
            # Ambil detail paket
            plan = db.query(SubscriptionPlan).filter(SubscriptionPlan.id == tx.plan_id).first()
            if plan:
                start_date = datetime.utcnow()
                end_date = start_date + timedelta(days=plan.duration_days)

                # Expire-kan paket lama pengguna
                db.query(UserSubscription).filter(UserSubscription.user_id == tx.user_id).update({"status": "EXPIRED"})

                # Aktifkan paket baru
                new_sub = UserSubscription(
                    user_id=tx.user_id,
                    plan_id=plan.id,
                    status="ACTIVE",
                    start_date=start_date,
                    end_date=end_date
                )
                db.add(new_sub)

            db.commit()
            logger.info(f"[Webhook] Payment {transaction_id} SUCCESS. User {tx.user_id} plan activated.")
            return {"status": "success", "message": f"Payment {transaction_id} verified and subscription activated."}

        elif payment_status in ["expire", "cancel", "deny", "FAILED", "failed"]:
            tx.status = "FAILED"
            db.commit()
            logger.info(f"[Webhook] Payment {transaction_id} marked as FAILED.")
            return {"status": "failed", "message": f"Payment {transaction_id} marked as failed."}

        return {"status": "pending", "message": f"Payment status '{payment_status}' received."}

    @classmethod
    def get_transaction_status(cls, db: Session, transaction_id: str) -> Dict[str, Any]:
        """
        Mengecek status transaksi di Database dan query status real-time ke API Midtrans Core.
        """
        tx = db.query(PaymentTransaction).filter(PaymentTransaction.transaction_id == transaction_id).first()
        if not tx:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Transaksi dengan ID '{transaction_id}' tidak ditemukan."
            )

        midtrans_details = MidtransService.get_transaction_status(transaction_id)
        return {
            "transaction_id": tx.transaction_id,
            "db_status": tx.status,
            "amount": tx.amount,
            "payment_method": tx.payment_method,
            "snap_token": tx.snap_token,
            "payment_url": tx.payment_url,
            "midtrans_details": midtrans_details
        }

    @classmethod
    def cancel_user_subscription(cls, db: Session, user_id: int) -> Dict[str, Any]:
        """
        Membatalkan langganan aktif milik pengguna dan mengembalikannya ke paket Starter Free.
        """
        # Nonaktifkan langganan aktif pengguna
        active_sub = db.query(UserSubscription).filter(
            UserSubscription.user_id == user_id,
            UserSubscription.status == "ACTIVE"
        ).first()

        if active_sub:
            active_sub.status = "EXPIRED"
            db.commit()

        # Pastikan pengguna mendapatkan kembali paket Free
        cls.get_user_subscription(db=db, user_id=user_id)

        logger.info(f"[SubscriptionService] User {user_id} active subscription cancelled successfully.")
        return {"status": "success", "message": "Langganan berhasil dibatalkan. Akun Anda kembali ke Paket Starter Free."}

        
        