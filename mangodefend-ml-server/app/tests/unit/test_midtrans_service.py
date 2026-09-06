import hashlib
import pytest
from app.src.core.config import settings
from app.src.services.midtrans_service import MidtransService


def test_midtrans_auth_header():
    """Memastikan Authorization Header Midtrans dibuat dengan format HTTP Basic Auth yang tepat."""
    headers = MidtransService.get_auth_header()
    assert "Authorization" in headers
    assert headers["Authorization"].startswith("Basic ")
    assert headers["Content-Type"] == "application/json"


def test_midtrans_create_snap_transaction_mock():
    """Memastikan fallback mock snap token berjalan saat Server Key dalam mode placeholder."""
    order_id = "INV-TEST-001"
    original_key = settings.MIDTRANS_SERVER_KEY
    try:
        settings.MIDTRANS_SERVER_KEY = "your_server_key"
        res = MidtransService.create_snap_transaction(
            order_id=order_id,
            gross_amount=49000.0,
            item_name="Paket Pro Test",
            customer_name="Budi Santoso",
            customer_email="budi@example.com"
        )

        assert "snap_token" in res
        assert "payment_url" in res
        assert res["snap_token"] == f"SNAP-MOCK-{order_id}"
    finally:
        settings.MIDTRANS_SERVER_KEY = original_key


def test_midtrans_signature_verification():
    """Memastikan verifikasi signature key SHA-512 bekerja dengan akurat."""
    order_id = "INV-20260904-TEST"
    status_code = "200"
    gross_amount = "49000.00"
    server_key = "test_server_key_secret_123"

    # Hitung SHA-512 buatan
    raw_str = f"{order_id}{status_code}49000{server_key}"
    valid_signature = hashlib.sha512(raw_str.encode("utf-8")).hexdigest()

    # Set temporary settings untuk test
    original_key = settings.MIDTRANS_SERVER_KEY
    try:
        settings.MIDTRANS_SERVER_KEY = server_key
        
        # Test 1: Signature valid
        is_valid = MidtransService.verify_signature(
            order_id=order_id,
            status_code=status_code,
            gross_amount=gross_amount,
            signature_key=valid_signature
        )
        assert is_valid is True

        # Test 2: Signature invalid
        is_invalid = MidtransService.verify_signature(
            order_id=order_id,
            status_code=status_code,
            gross_amount=gross_amount,
            signature_key="invalid_signature_hash_xyz"
        )
        assert is_invalid is False
    finally:
        settings.MIDTRANS_SERVER_KEY = original_key


def test_midtrans_get_transaction_status_mock():
    """Memastikan status transaksi mock terfasilitasi dengan baik."""
    order_id = "INV-TEST-002"
    original_key = settings.MIDTRANS_SERVER_KEY
    try:
        settings.MIDTRANS_SERVER_KEY = "your_server_key"
        status_res = MidtransService.get_transaction_status(order_id)
        assert "transaction_status" in status_res
        assert status_res["order_id"] == order_id
    finally:
        settings.MIDTRANS_SERVER_KEY = original_key
