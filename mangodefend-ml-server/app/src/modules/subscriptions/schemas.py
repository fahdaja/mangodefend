from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict


# ==========================================
# 1. SUBSCRIPTION PLAN SCHEMAS
# ==========================================

class SubscriptionPlanRequest(BaseModel):
    plan_name: str = Field(..., description="Nama Paket (misal: Free, Pro, Premium)")
    price: float = Field(..., ge=0.0, description="Harga paket (IDR)")
    duration_days: int = Field(30, ge=1, description="Durasi aktif dalam hari")
    max_daily_scans: int = Field(..., description="Batas scan per hari (-1 untuk unlimited)")
    max_devices: int = Field(1, ge=1, description="Batas jumlah perangkat terhubung")
    can_upload_scans: bool = True
    can_upload_folder: bool = True
    can_full_system_scan: bool = True
    can_realtime_protection: bool = False
    can_web_protection: bool = False
    can_scheduled_scan: bool = False
    is_active: bool = True


class SubscriptionPlanResponse(SubscriptionPlanRequest):
    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# 2. USER SUBSCRIPTION SCHEMAS
# ==========================================

class UserSubscriptionRequest(BaseModel):
    plan_id: int = Field(..., description="ID Paket Langganan yang dipilih")


class UserSubscriptionResponse(BaseModel):
    id: int
    user_id: int
    plan_id: int
    status: str  # ACTIVE, EXPIRED, PENDING
    start_date: datetime
    end_date: datetime
    created_at: datetime
    updated_at: datetime
    plan: Optional[SubscriptionPlanResponse] = None

    model_config = ConfigDict(from_attributes=True)


# ==========================================
# 3. PAYMENT TRANSACTION SCHEMAS
# ==========================================

class CheckoutRequest(BaseModel):
    plan_id: int = Field(..., description="ID Paket yang dibeli")
    payment_method: str = Field("QRIS", description="Metode Pembayaran (QRIS, VA_BCA, GOPAY, dll)")



class CheckoutResponse(BaseModel):
    transaction_id: str
    amount: float
    payment_method: str
    status: str  # PENDING, SUCCESS, FAILED
    payment_url: Optional[str] = None
    snap_token: Optional[str] = None
    created_at: datetime


class PaymentTransactionResponse(BaseModel):
    id: int
    user_id: int
    plan_id: int
    amount: float
    payment_method: str
    transaction_id: str
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)