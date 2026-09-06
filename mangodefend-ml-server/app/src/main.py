import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from sqlalchemy import text
from app.src.core.config import settings
from app.src.core.database import engine, Base
from app.src.core.redis import init_redis
from app.src.core.storage import supabase_storage
from app.src.modules.auth.router import router as auth_router
from app.src.modules.devices.router import router as devices_router
from app.src.modules.users.router import router as users_router
from app.src.modules.scans.router import router as scans_router
from app.src.modules.datasets.router import router as datasets_router
from app.src.modules.subscriptions.router import router as subscriptions_router

# Import all SQLAlchemy models to register them with Base.metadata
import app.src.modules.users.models  # noqa
import app.src.modules.devices.models  # noqa
import app.src.modules.scans.models  # noqa
import app.src.modules.datasets.models  # noqa
import app.src.modules.subscriptions.models  # noqa

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("mangodefend")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan handler: Inisialisasi Database, Redis, & S3 Storage saat Startup."""
    logger.info("[MangoDefend] Starting up application...")
    
    # 1. Buat tabel database jika belum ada & migrasi kolom baru
    Base.metadata.create_all(bind=engine)
    try:
        with engine.connect() as conn:
            conn.execute(text("ALTER TABLE dataset_samples ADD COLUMN IF NOT EXISTS image_url VARCHAR(512);"))
            conn.execute(text("ALTER TABLE devices ADD COLUMN IF NOT EXISTS device_name VARCHAR(255) DEFAULT 'Perangkat Terhubung';"))
            conn.execute(text("ALTER TABLE devices ADD COLUMN IF NOT EXISTS os_version VARCHAR(100) DEFAULT 'Android';"))
            conn.execute(text("ALTER TABLE devices ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;"))
            conn.commit()
    except Exception as e:
        logger.warning(f"[MangoDefend] Migration check warning: {e}")
    logger.info("[MangoDefend] Database tables created/verified.")
    
    # Seed default subscription plans (Free, Pro Monthly, Pro Annual) jika belum ada di database
    try:
        from app.src.core.database import SessionLocal
        from app.src.modules.subscriptions.service import SubscriptionService
        with SessionLocal() as db:
            SubscriptionService.seed_default_plans_if_empty(db)
    except Exception as e:
        logger.error(f"[MangoDefend] Failed to seed default subscription plans: {e}")
    
    # 2. Inisialisasi Redis Connection
    await init_redis()
    
    # 3. Verifikasi & Otomatisasi Bucket S3 Storage
    supabase_storage.check_credentials_and_warn()
    supabase_storage.ensure_buckets_exist()
    
    yield
    logger.info("[MangoDefend] Shutting down application...")


app = FastAPI(
    title=settings.APP_NAME,
    description="API Backend Antivirus MangoDefend ML Server",
    version="1.0.0",
    lifespan=lifespan
)

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register Routers
app.include_router(auth_router, prefix="/api/v1")
app.include_router(devices_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(scans_router, prefix="/api/v1")
app.include_router(datasets_router, prefix="/api/v1")
app.include_router(subscriptions_router, prefix="/api/v1")







@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": settings.APP_NAME}
