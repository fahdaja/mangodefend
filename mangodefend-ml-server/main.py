# main.py
import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.responses import HTMLResponse

from app.db.database import engine as db_engine, Base
from app.api.scans.model import ScanLog  # noqa: F401 — import agar model ter-register
from app.api.scans.router import router as scans_router

# Unified server log file path
SERVER_LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "app", "uvicorn_server.log")

# Truncate log file at startup so it starts fresh
try:
    with open(SERVER_LOG_FILE, "w", encoding="utf-8") as f:
        f.write("INFO:     [MangoDefend ML Server] Logging started...\n")
except Exception:
    pass

class UvicornFileHandler(logging.FileHandler):
    pass

def setup_file_logging():
    for name in ["uvicorn", "uvicorn.error", "uvicorn.access"]:
        logger_obj = logging.getLogger(name)
        # Avoid duplicate handlers on reload
        logger_obj.handlers = [h for h in logger_obj.handlers if not isinstance(h, UvicornFileHandler)]
        fh = UvicornFileHandler(SERVER_LOG_FILE, mode='a', encoding='utf-8')
        fh.setLevel(logging.INFO)
        fh.setFormatter(logging.Formatter("%(levelname)s:     %(message)s"))
        logger_obj.addHandler(fh)

# Initial setup
setup_file_logging()

logger = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Buat tabel di database saat aplikasi startup."""
    Base.metadata.create_all(bind=db_engine)
    
    # Re-apply file logging on startup to make sure it attaches to uvicorn's worker loggers
    setup_file_logging()
    
    # Check and dynamically add app_platform column to scan_logs if it doesn't exist
    from sqlalchemy import text
    with db_engine.connect() as conn:
        try:
            res = conn.execute(text("SHOW COLUMNS FROM scan_logs LIKE 'app_platform'")).fetchone()
            if not res:
                logger.info("[MangoDefend DB] Column 'app_platform' not found in 'scan_logs'. Adding it...")
                conn.execute(text("ALTER TABLE scan_logs ADD COLUMN app_platform VARCHAR(50) NOT NULL DEFAULT 'Unknown'"))
                conn.commit()
                logger.info("[MangoDefend DB] Column 'app_platform' successfully added to 'scan_logs'.")
        except Exception as e:
            logger.error(f"[MangoDefend DB] Error altering table scan_logs: {e}")
            
    yield


from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="MangoDefend ML API",
    description=(
        "API Backend untuk deteksi malware menggunakan Machine Learning. "
        "File yang di-upload akan dikonversi menjadi grayscale image "
        "dan dianalisis menggunakan model ONNX. "
        "Setiap scan dicatat ke database MySQL."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(scans_router, prefix="/api/v1")



def get_dashboard_html():
    """Membaca isi file template dashboard HTML."""
    template_path = os.path.join(os.path.dirname(__file__), "app", "templates", "dashboard.html")
    if not os.path.exists(template_path):
        return "<h1>Dashboard Template Not Found</h1>"
    with open(template_path, "r", encoding="utf-8") as f:
        return f.read()


@app.get("/", response_class=HTMLResponse, tags=["Dashboard"])
async def serve_dashboard_root():
    """Tampilkan Dashboard Pemantauan Scan Real-time pada root url."""
    return HTMLResponse(content=get_dashboard_html())


@app.get("/dashboard", response_class=HTMLResponse, tags=["Dashboard"])
async def serve_dashboard():
    """Tampilkan Dashboard Pemantauan Scan Real-time."""
    return HTMLResponse(content=get_dashboard_html())


@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "service": "MangoDefend ML API"}
