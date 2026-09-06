from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Float, Boolean, ForeignKey
from sqlalchemy.orm import relationship

from app.src.core.database import Base


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(Integer, primary_key=True, index=True)
    plan_name = Column(String(50), nullable=False)
    price = Column(Float, nullable=False)
    duration_days = Column(Integer, nullable=False, default=30)
    max_daily_scans = Column(Integer, nullable=False)
    max_devices = Column(Integer, nullable=False, default=1)
    can_upload_scans = Column(Boolean, default=True)
    can_upload_folder = Column(Boolean, default=True)
    can_full_system_scan = Column(Boolean, default=True)
    can_realtime_protection = Column(Boolean, default=False)
    can_web_protection = Column(Boolean, default=False)
    can_scheduled_scan = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user_subscriptions = relationship("UserSubscription", back_populates="plan")
    payment_transactions = relationship("PaymentTransaction", back_populates="plan")


class UserSubscription(Base):
    __tablename__ = "user_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    plan_id = Column(Integer, ForeignKey("subscription_plans.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(String(50), nullable=False, default="ACTIVE")  # ACTIVE, EXPIRED, PENDING
    start_date = Column(DateTime, default=datetime.utcnow)
    end_date = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    plan = relationship("SubscriptionPlan", back_populates="user_subscriptions")


class PaymentTransaction(Base):
    __tablename__ = "payment_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    plan_id = Column(Integer, ForeignKey("subscription_plans.id", ondelete="CASCADE"), nullable=False, index=True)
    amount = Column(Float, nullable=False)
    payment_method = Column(String(50), nullable=False)
    transaction_id = Column(String(255), unique=True, nullable=False, index=True)
    status = Column(String(50), nullable=False, default="PENDING")  # PENDING, SUCCESS, FAILED
    snap_token = Column(String(255), nullable=True)
    payment_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    plan = relationship("SubscriptionPlan", back_populates="payment_transactions")