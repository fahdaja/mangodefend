import base64
import hashlib
import logging
from typing import Dict, Any, Optional
import httpx

from app.src.core.config import settings

logger = logging.getLogger("mangodefend.midtrans_service")


class MidtransService:
    """
    Service layer untuk integrasi Midtrans Payment Gateway (Snap API & Core API).
    Mendukung environment Sandbox dan Production.
    """

    @classmethod
    def is_production_mode(cls) -> bool:
        """Deteksi apakah menggunakan mode Production berdasarkan settings atau prefix Server Key."""
        server_key = settings.MIDTRANS_SERVER_KEY or ""
        if settings.MIDTRANS_IS_PRODUCTION:
            return True
        if server_key.startswith("Mid-server-") and not server_key.startswith("SB-Mid-server-"):
            return True
        return False

    @classmethod
    def get_snap_url(cls) -> str:
        """Mengembalikan URL Snap API berbasis mode Sandbox / Production."""
        if cls.is_production_mode():
            return "https://app.midtrans.com/snap/v1/transactions"
        return "https://app.sandbox.midtrans.com/snap/v1/transactions"

    @classmethod
    def get_core_url(cls) -> str:
        """Mengembalikan URL Core API berbasis mode Sandbox / Production."""
        if cls.is_production_mode():
            return "https://api.midtrans.com/v2"
        return "https://api.sandbox.midtrans.com/v2"

    @classmethod
    def get_auth_header(cls) -> Dict[str, str]:
        """
        Menghasilkan Authorization header dengan HTTP Basic Auth.
        Midtrans menggunakan Server Key sebagai username dan password kosong.
        """
        server_key = settings.MIDTRANS_SERVER_KEY or ""
        encoded_key = base64.b64encode(f"{server_key}:".encode("utf-8")).decode("utf-8")
        return {
            "Authorization": f"Basic {encoded_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

    @classmethod
    def create_snap_transaction(
        cls,
        order_id: str,
        gross_amount: float,
        item_name: str,
        customer_name: str,
        customer_email: str
    ) -> Dict[str, Any]:
        """
        Membuat transaksi Snap di Midtrans.
        Mengembalikan dictionary berisi:
        - snap_token (str)
        - payment_url (str / redirect_url)
        """
        payload = {
            "transaction_details": {
                "order_id": order_id,
                "gross_amount": int(gross_amount)
            },
            "item_details": [
                {
                    "id": order_id,
                    "price": int(gross_amount),
                    "quantity": 1,
                    "name": item_name[:50]
                }
            ],
            "customer_details": {
                "first_name": customer_name,
                "email": customer_email
            }
        }

        server_key = settings.MIDTRANS_SERVER_KEY or ""
        # Fallback ke Mock Token jika Server Key masih bernilai placeholder/default
        if not server_key or "your_server_key" in server_key or server_key.startswith("SB-Mid-server-YOUR"):
            logger.warning("[MidtransService] Server key placeholder terdeteksi. Menggunakan Mock Snap Token untuk dev.")
            mock_token = f"SNAP-MOCK-{order_id}"
            mock_url = f"https://app.sandbox.midtrans.com/snap/v2/vtweb/{mock_token}"
            return {
                "snap_token": mock_token,
                "payment_url": mock_url
            }

        url = cls.get_snap_url()
        headers = cls.get_auth_header()

        try:
            with httpx.Client(timeout=15.0) as client:
                response = client.post(url, json=payload, headers=headers)
                response_data = response.json()

                if response.status_code in [200, 201]:
                    token = response_data.get("token")
                    redirect_url = response_data.get("redirect_url")
                    logger.info(f"[MidtransService] Transaction {order_id} successfully created. Token: {token}")
                    return {
                        "snap_token": token,
                        "payment_url": redirect_url
                    }
                elif response.status_code == 401 and not cls.is_production_mode():
                    logger.warning(f"[MidtransService] Midtrans Sandbox 401 Unauthorized (Server Key salah/tidak aktif). Menggunakan Mock Snap Token.")
                    mock_token = f"SNAP-MOCK-{order_id}"
                    mock_url = f"https://app.sandbox.midtrans.com/snap/v2/vtweb/{mock_token}"
                    return {
                        "snap_token": mock_token,
                        "payment_url": mock_url
                    }
                else:
                    error_msg = response_data.get("error_messages", [str(response_data)])
                    logger.error(f"[MidtransService] Snap API error: {error_msg}")
                    raise Exception(f"Midtrans API Error: {error_msg}")
        except httpx.HTTPError as exc:
            logger.error(f"[MidtransService] HTTP Request failed: {exc}")
            raise Exception(f"Koneksi ke Midtrans gagal: {exc}")

    @classmethod
    def verify_signature(
        cls,
        order_id: str,
        status_code: str,
        gross_amount: str,
        signature_key: str
    ) -> bool:
        """
        Memverifikasi keabsahan Signature Key SHA-512 dari Midtrans Webhook.
        Rumus: SHA512(order_id + status_code + gross_amount + ServerKey)
        """
        server_key = settings.MIDTRANS_SERVER_KEY or ""

        if not server_key or "your_server_key" in server_key or server_key.startswith("SB-Mid-server-YOUR"):
            logger.warning("[MidtransService] Skipping signature verification (Placeholder Server Key).")
            return True

        # Memastikan gross_amount terformat dengan rapi jika dikirim angka murni / float
        formatted_amount = str(gross_amount)
        if formatted_amount.endswith(".0"):
            formatted_amount = formatted_amount[:-2]
        elif formatted_amount.endswith(".00"):
            formatted_amount = formatted_amount[:-3]

        raw_string = f"{order_id}{status_code}{formatted_amount}{server_key}"
        computed_signature = hashlib.sha512(raw_string.encode("utf-8")).hexdigest()

        is_valid = computed_signature.lower() == signature_key.lower()
        if not is_valid:
            logger.warning(
                f"[MidtransService] Invalid signature for order {order_id}. "
                f"Computed: {computed_signature}, Received: {signature_key}"
            )
        return is_valid

    @classmethod
    def get_transaction_status(cls, order_id: str) -> Dict[str, Any]:
        """
        Mengecek status transaksi secara real-time via Midtrans Core API (/v2/{order_id}/status).
        """
        server_key = settings.MIDTRANS_SERVER_KEY or ""
        if not server_key or "your_server_key" in server_key or server_key.startswith("SB-Mid-server-YOUR"):
            return {
                "transaction_status": "settlement",
                "order_id": order_id,
                "gross_amount": "49000.00",
                "payment_type": "qris",
                "status_message": "Mock transaction status (Placeholder Server Key)"
            }

        url = f"{cls.get_core_url()}/{order_id}/status"
        headers = cls.get_auth_header()

        try:
            with httpx.Client(timeout=15.0) as client:
                response = client.get(url, headers=headers)
                return response.json()
        except httpx.HTTPError as exc:
            logger.error(f"[MidtransService] Get status failed for {order_id}: {exc}")
            raise Exception(f"Gagal mengambil status transaksi Midtrans: {exc}")

    @classmethod
    def cancel_transaction(cls, order_id: str) -> Dict[str, Any]:
        """
        Membatalkan transaksi PENDING via Midtrans Core API (/v2/{order_id}/cancel).
        """
        server_key = settings.MIDTRANS_SERVER_KEY or ""
        if not server_key or "your_server_key" in server_key or server_key.startswith("SB-Mid-server-YOUR"):
            return {"status_code": "200", "transaction_status": "cancel", "order_id": order_id}

        url = f"{cls.get_core_url()}/{order_id}/cancel"
        headers = cls.get_auth_header()

        try:
            with httpx.Client(timeout=15.0) as client:
                response = client.post(url, headers=headers)
                return response.json()
        except httpx.HTTPError as exc:
            logger.error(f"[MidtransService] Cancel transaction failed for {order_id}: {exc}")
            raise Exception(f"Gagal membatalkan transaksi Midtrans: {exc}")
