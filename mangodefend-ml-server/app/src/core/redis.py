import logging
import redis.asyncio as aioredis
from typing import Optional

from app.src.core.config import settings

logger = logging.getLogger(__name__)

# Redis Client Instance
redis_client: Optional[aioredis.Redis] = None


async def init_redis():
    """Inisialisasi koneksi Redis saat aplikasi startup."""
    global redis_client
    try:
        redis_client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True
        )
        await redis_client.ping()  # type: ignore
        logger.info("[Redis] Successfully connected to Redis server.")
    except Exception as e:
        logger.error(f"[Redis] Failed to connect to Redis: {e}")


async def get_redis() -> aioredis.Redis:
    """Dependency injection / getter untuk mendapatkan instance Redis client."""
    global redis_client
    if redis_client is None:
        redis_client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True
        )
    return redis_client


# ==========================================
# HELPER FUNGSI MANAJEMEN SESSION VIA REDIS
# ==========================================

async def create_user_session(user_id: int, token: str, expire_seconds: int = 86400) -> bool:
    """
    Menyimpan session token pengguna ke Redis dengan batas waktu (TTL).
    Key: session:<user_id>:<token>
    """
    client = await get_redis()
    key = f"session:{user_id}:{token}"
    try:
        await client.setex(name=key, time=expire_seconds, value="active")
        return True
    except Exception as e:
        logger.error(f"[Redis] Error creating session for user {user_id}: {e}")
        return False


async def is_session_valid(user_id: int, token: str) -> bool:
    """
    Memeriksa apakah session token masih aktif di Redis (belum logout / belum kedaluwarsa).
    """
    client = await get_redis()
    key = f"session:{user_id}:{token}"
    try:
        exists = await client.exists(key)
        return exists == 1
    except Exception as e:
        logger.error(f"[Redis] Error checking session validity: {e}")
        # Fallback ke True jika Redis error agar aplikasi tidak down total (opsional)
        return True


async def revoke_session(user_id: int, token: str) -> bool:
    """
    Menghapus session token spesifik dari Redis saat user logout.
    """
    client = await get_redis()
    key = f"session:{user_id}:{token}"
    try:
        await client.delete(key)
        return True
    except Exception as e:
        logger.error(f"[Redis] Error revoking session: {e}")
        return False


async def revoke_all_user_sessions(user_id: int) -> bool:
    """
    Fitur Force Logout Semua Perangkat: Menghapus semua session milik user_id.
    """
    client = await get_redis()
    pattern = f"session:{user_id}:*"
    try:
        keys = await client.keys(pattern)
        if keys:
            await client.delete(*keys)
        return True
    except Exception as e:
        logger.error(f"[Redis] Error revoking all sessions for user {user_id}: {e}")
        return False
