# app/api/scans/service.py
import logging
import time
from fastapi import UploadFile
from sqlalchemy.orm import Session

from app.utils.file_converter import FileConverter
from app.ml.engine import engine
from app.api.scans.model import ScanLog

# Set up uvicorn logging to integrate with output terminal stream
logger = logging.getLogger("uvicorn.error")

# Setup dedicated logger untuk waktu proses internal (hanya menulis ke file log)
scan_logger = logging.getLogger("mangodefend.scans")
scan_logger.setLevel(logging.INFO)
scan_logger.propagate = False  # Jangan di-propagate agar tidak duplikat dengan uvicorn logger

# Buat file handler agar log tersimpan di file
import os
log_file = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "mangodefend_scan.log")
if not any(isinstance(h, logging.FileHandler) for h in scan_logger.handlers):
    f_handler = logging.FileHandler(log_file, mode='a', encoding='utf-8')
    f_handler.setLevel(logging.INFO)
    f_format = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    f_handler.setFormatter(f_format)
    scan_logger.addHandler(f_handler)

# Batas ukuran file: 50 MB
MAX_FILE_SIZE = 50 * 1024 * 1024


async def scan_file(file: UploadFile, db: Session, app_platform: str = "Unknown") -> dict:
    """
    Pipeline lengkap untuk scan satu file:
    1. Baca bytes dari file yang di-upload
    2. Konversi bytes → grayscale image (via FileConverter)
    3. Jalankan inferensi model ML
    4. Simpan log ke database
    5. Return label hasil prediksi + detail waktu proses internal
    """
    filename = file.filename or "unknown"
    logger.info(f"[MangoDefend] Memulai alur pemindaian file: '{filename}'")

    # 1. Baca seluruh isi file
    start_read = time.perf_counter()
    file_bytes = await file.read()
    file_size = len(file_bytes)
    end_read = time.perf_counter()
    read_time = (end_read - start_read) * 1000
    logger.info(f"[MangoDefend] File '{filename}' berhasil dibaca. Ukuran: {file_size} bytes.")

    if file_size == 0:
        logger.error(f"[MangoDefend] Gagal memindai '{filename}': File kosong tidak valid.")
        raise ValueError("File kosong tidak dapat di-scan.")

    if file_size > MAX_FILE_SIZE:
        logger.error(
            f"[MangoDefend] Gagal memindai '{filename}': Ukuran file ({file_size} bytes) "
            f"melebihi batas maksimum ({MAX_FILE_SIZE} bytes)."
        )
        raise ValueError(
            f"Ukuran file ({file_size / (1024*1024):.1f} MB) melebihi batas maksimum "
            f"({MAX_FILE_SIZE / (1024*1024):.0f} MB)."
        )

    # 2. Konversi bytes ke grayscale image menggunakan FileConverter
    logger.info(f"[MangoDefend] Mengonversi file '{filename}' ke in-memory grayscale image...")
    start_conv = time.perf_counter()
    grayscale_image = FileConverter.bytes_to_image(file_bytes)
    end_conv = time.perf_counter()
    conv_time = (end_conv - start_conv) * 1000

    # 3. Jalankan prediksi melalui ML engine
    logger.info(f"[MangoDefend] Menjalankan inferensi model ML (ONNX Runtime) untuk '{filename}'...")
    start_inf = time.perf_counter()
    label = engine.predict(grayscale_image)
    end_inf = time.perf_counter()
    inf_time = (end_inf - start_inf) * 1000
    logger.info(f"[MangoDefend] Hasil prediksi ML untuk '{filename}': {label.upper()}")

    # 4. Simpan log ke database
    start_db = time.perf_counter()
    scan_log = ScanLog(
        filename=filename,
        file_size=file_size,
        label=label,
        app_platform=app_platform,
    )
    db.add(scan_log)
    db.commit()
    db.refresh(scan_log)
    end_db = time.perf_counter()
    db_time = (end_db - start_db) * 1000
    logger.info(f"[MangoDefend] Log pemindaian disimpan ke MySQL. ID Record: #{scan_log.id}")

    # Hitung total waktu dan persentase kontribusi masing-masing proses
    total_time = read_time + conv_time + inf_time + db_time
    if total_time > 0:
        read_pct = (read_time / total_time) * 100
        conv_pct = (conv_time / total_time) * 100
        inf_pct = (inf_time / total_time) * 100
        db_pct = (db_time / total_time) * 100
    else:
        read_pct = conv_pct = inf_pct = db_pct = 0.0

    # Cetak log berformat indah ke console server & file log
    log_msg = (
        f"\n[MangoDefend] ⏱️ Detail Waktu Proses Internal (ID Scan #{scan_log.id} - Ukuran: {file_size} bytes / {file_size/1024:.1f} KB):\n"
        f"  - Baca File (Read)     : {read_time:.2f} ms ({read_pct:.1f}%)\n"
        f"  - Konversi Gambar      : {conv_time:.2f} ms ({conv_pct:.1f}%)\n"
        f"  - Inferensi Model ML   : {inf_time:.2f} ms ({inf_pct:.1f}%)\n"
        f"  - Simpan ke Database   : {db_time:.2f} ms ({db_pct:.1f}%)\n"
        f"  ---------------------------------------------------\n"
        f"  Total Waktu Proses     : {total_time:.2f} ms (100.0%)"
    )
    logger.debug(log_msg)      # Simpan di debug level saja untuk console
    scan_logger.info(log_msg)  # Tulis ke file mangodefend_scan.log secara background

    # 5. Return hasil scan
    return {
        "id": scan_log.id,
        "file_name": filename,
        "file_size": file_size,
        "label": label,
        "app_platform": scan_log.app_platform,
        "scanned_at": scan_log.scanned_at,
    }
