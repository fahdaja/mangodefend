import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.src.core.database import Base
from app.src.modules.subscriptions.models import SubscriptionPlan
from app.src.modules.subscriptions.service import SubscriptionService


@pytest.fixture
def db_session():
    """SQLite In-Memory DB Session untuk pengujian isolasi."""
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


def test_seed_default_plans_if_empty(db_session):
    """Memastikan paket langganan default (Free, Pro Monthly, Pro Annual) otomatis di-seed jika database kosong."""
    assert db_session.query(SubscriptionPlan).count() == 0

    plans = SubscriptionService.seed_default_plans_if_empty(db_session)
    assert len(plans) == 3

    plan_names = [p.plan_name for p in plans]
    assert "Free" in plan_names
    assert "Pro Monthly" in plan_names
    assert "Pro Annual" in plan_names

    # Panggilan kedua tidak boleh membuat duplikat
    plans_retry = SubscriptionService.seed_default_plans_if_empty(db_session)
    assert len(plans_retry) == 3
    assert db_session.query(SubscriptionPlan).count() == 3
