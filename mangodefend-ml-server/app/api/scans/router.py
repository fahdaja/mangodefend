# app/api/scans/router.py
import json
import asyncio
import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, status, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func, case

from app.api.scans.schema import (
    ScanResponse, 
    ErrorResponse, 
    PaginatedScanLogsResponse, 
    ScanStatsResponse,
    ScanInput
)
from app.api.scans.service import scan_file
from app.api.scans.model import ScanLog
from app.api.scans.pubsub import pubsub
from app.db.database import get_db

# Initialize uvicorn logger integration
logger = logging.getLogger("uvicorn.error")

router = APIRouter(prefix="/scans", tags=["Scans"])


@router.post(
    "/scan",
    response_model=ScanResponse,
    summary="Scan file untuk deteksi malware",
    description=(
        "Upload sebuah file melalui multipart/form-data. "
        "File akan dikonversi menjadi grayscale image dan dianalisis "
        "menggunakan model Machine Learning untuk mendeteksi malware. "
        "Hasil scan akan dicatat ke database dan di-broadcast secara real-time."
    ),
    responses={
        400: {"model": ErrorResponse, "description": "File tidak valid"},
        413: {"model": ErrorResponse, "description": "File terlalu besar"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def scan_uploaded_file(
    file: UploadFile = File(..., description="File yang akan di-scan untuk deteksi malware"),
    input_data: ScanInput = Depends(ScanInput.as_form),
    db: Session = Depends(get_db),
):
    """
    Endpoint untuk scan satu file.

    - Menerima file melalui multipart/form-data
    - Mengkonversi file menjadi grayscale image
    - Menjalankan inferensi model ML
    - Mencatat log scan ke database MySQL
    - Mengembalikan hasil prediksi (malware / benign)
    - Menyiarkan hasil ke subscriber real-time (SSE)
    """
    try:
        result = await scan_file(file, db, input_data.app_platform)
        
        # Publish ke real-time log pubsub
        # Serialisasi timestamp ke format ISO
        scanned_at_iso = (
            result["scanned_at"].isoformat() 
            if hasattr(result["scanned_at"], "isoformat") 
            else str(result["scanned_at"])
        )
        
        event_data = {
            "id": result["id"],
            "file_name": result["file_name"],
            "file_size": result["file_size"],
            "label": result["label"],
            "app_platform": result["app_platform"],
            "scanned_at": scanned_at_iso
        }
        
        logger.info(f"[MangoDefend API] Menyiarkan log scan '{result['file_name']}' ke subscriber...")
        await pubsub.publish(event_data)
        
        return ScanResponse(**result)

    except ValueError as e:
        logger.warning(f"[MangoDefend API] Permintaan tidak valid pada /scan: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    except Exception as e:
        logger.error(f"[MangoDefend API] Terjadi error saat memproses /scan: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Terjadi kesalahan saat memproses file: {str(e)}",
        )


@router.get(
    "/logs",
    response_model=PaginatedScanLogsResponse,
    summary="Dapatkan log scan dengan paginasi dan filter",
    description="Mengambil daftar log scan dari database dengan pencarian nama file, filter label, dan paginasi.",
)
async def get_scan_logs(
    page: int = 1,
    limit: int = 20,
    search: str = None,
    label: str = None,
    db: Session = Depends(get_db),
):
    logger.info(
        f"[MangoDefend API] Mengambil riwayat log (Halaman: {page}, Limit: {limit}, "
        f"Cari: '{search or ''}', Filter: '{label or 'semua'}')"
    )
    if page < 1:
        page = 1
    if limit < 1 or limit > 100:
        limit = 20

    query = db.query(ScanLog)

    if search:
        query = query.filter(ScanLog.filename.like(f"%{search}%"))

    if label:
        query = query.filter(ScanLog.label == label)

    total = query.count()
    pages = (total + limit - 1) // limit if total > 0 else 1

    logs = query.order_by(ScanLog.scanned_at.desc()).offset((page - 1) * limit).limit(limit).all()

    logs_response = []
    for log in logs:
        logs_response.append({
            "id": log.id,
            "file_name": log.filename,
            "file_size": log.file_size,
            "label": log.label,
            "app_platform": log.app_platform,
            "scanned_at": log.scanned_at,
        })

    return {
        "total": total,
        "page": page,
        "limit": limit,
        "pages": pages,
        "logs": logs_response,
    }


@router.get(
    "/stats",
    response_model=ScanStatsResponse,
    summary="Dapatkan statistik deteksi malware",
    description="Mengambil metrik ringkasan scan dan data aktivitas deteksi harian untuk visualisasi grafik.",
)
async def get_scan_stats(days: int = 7, db: Session = Depends(get_db)):
    logger.info(f"[MangoDefend API] Memproses perhitungan statistik data scan untuk {days} hari...")
    # Total scans
    total_scans = db.query(ScanLog).count()

    # Malware scans
    malware_count = db.query(ScanLog).filter(ScanLog.label == "malware").count()

    # Benign scans
    benign_count = total_scans - malware_count

    # Total size in bytes
    total_size_bytes = db.query(func.sum(ScanLog.file_size)).scalar() or 0

    # Malware percentage
    malware_percentage = (malware_count / total_scans * 100) if total_scans > 0 else 0.0

    # Recent activity (last N days)
    time_threshold = datetime.utcnow() - timedelta(days=days)
    
    activity_query = db.query(
        func.date(ScanLog.scanned_at).label("date"),
        func.sum(case((ScanLog.label == "malware", 1), else_=0)).label("malware"),
        func.sum(case((ScanLog.label == "benign", 1), else_=0)).label("benign"),
        func.count(ScanLog.id).label("total")
    ).filter(ScanLog.scanned_at >= time_threshold)\
     .group_by(func.date(ScanLog.scanned_at))\
     .order_by("date").all()

    # Pre-populate past N days
    today = datetime.utcnow().date()
    activity_dict = {}
    for i in range(days - 1, -1, -1):
        d = today - timedelta(days=i)
        d_str = d.strftime("%Y-%m-%d")
        activity_dict[d_str] = {"date": d_str, "malware": 0, "benign": 0, "total": 0}

    # Fill data from database
    for row in activity_query:
        d_str = row.date.strftime("%Y-%m-%d") if hasattr(row.date, "strftime") else str(row.date)
        if d_str in activity_dict:
            activity_dict[d_str]["malware"] = int(row.malware or 0)
            activity_dict[d_str]["benign"] = int(row.benign or 0)
            activity_dict[d_str]["total"] = int(row.total or 0)

    recent_activity = list(activity_dict.values())

    return {
        "total_scans": total_scans,
        "malware_count": malware_count,
        "benign_count": benign_count,
        "total_size_bytes": total_size_bytes,
        "malware_percentage": round(malware_percentage, 2),
        "recent_activity": recent_activity
    }


@router.get(
    "/stream",
    summary="Stream data scan secara real-time",
    description="Endpoint Server-Sent Events (SSE) untuk menerima notifikasi real-time saat ada file yang di-scan.",
)
async def stream_scans():
    async def event_generator():
        q = pubsub.subscribe()
        logger.info("[MangoDefend Stream] Client terhubung ke saluran real-time SSE.")
        try:
            # Yield ping koneksi pertama
            yield "data: {\"event\": \"connected\"}\n\n"
            while True:
                # Menunggu log scan baru
                log_data = await q.get()
                yield f"data: {json.dumps(log_data)}\n\n"
        except asyncio.CancelledError:
            logger.info("[MangoDefend Stream] Transmisi SSE ke client dibatalkan.")
            pubsub.unsubscribe(q)
        finally:
            logger.info("[MangoDefend Stream] Client terputus dari saluran real-time SSE.")
            pubsub.unsubscribe(q)

    return StreamingResponse(
        event_generator(),
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Content-Type": "text/event-stream",
        }
    )


@router.get(
    "/system-logs",
    summary="Dapatkan log sistem waktu proses internal",
    description="Membaca dan mengembalikan baris-baris terakhir dari file log uvicorn_server.log untuk ditampilkan di dashboard.",
)
async def get_system_logs(lines: int = 100):
    import os
    from collections import deque
    
    # Path file log di app/uvicorn_server.log
    log_file_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "uvicorn_server.log"
    )
    
    try:
        if not os.path.exists(log_file_path):
            return {"logs": [f"Log file not found at {log_file_path}"]}
            
        with open(log_file_path, "r", encoding="utf-8") as f:
            last_lines = list(deque(f, maxlen=lines))
            # Clean up newlines
            clean_lines = [line.rstrip("\r\n") for line in last_lines]
            return {"logs": clean_lines}
    except Exception as e:
        return {"logs": [f"Error reading log file: {str(e)}"]}

