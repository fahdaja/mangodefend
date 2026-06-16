"""
Scan Thread Worker
Thread untuk menjalankan malware scanning secara asynchronous
"""

from PySide6.QtCore import QThread, Signal
from core.scanner import MalwareScanner
from pathlib import Path


# ========================================
# PERFORMANCE CONFIG
# ========================================
STAGE_DELAY_MS = 0
FILE_SCAN_DELAY_MS = 0
MAX_FILES_TO_SCAN = 2000
COLLECTION_PAUSE_MS = 300

# File extensions included in a full device scan
SCAN_EXTENSIONS = frozenset({
    '.exe', '.dll', '.bat', '.cmd', '.ps1', '.vbs', '.js',
    '.jar', '.apk', '.msi', '.scr', '.com',
    '.zip', '.rar', '.7z',
    '.png', '.jpg', '.jpeg', '.bmp',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx',
})


class ScanThread(QThread):
    finished = Signal(dict)
    error = Signal(str)
    progress = Signal(int, str)

    def __init__(self, file_path: str, is_full_scan: bool = False):
        super().__init__()
        self.file_path = file_path
        self.is_full_scan = is_full_scan
        self.scanner = MalwareScanner()
        self.is_canceled = False

    # ====================================================
    def cancel(self):
        self.is_canceled = True

    # ====================================================
    def run(self):
        try:
            if self.is_full_scan:
                self._run_full_scan()
            else:
                self._run_single_scan()
        except Exception as e:
            self.error.emit(str(e))

    # ====================================================
    # SINGLE FILE SCAN
    # ====================================================
    def _run_single_scan(self):
        stages = [
            (10, "Memulai pemindaian..."),
            (30, "Menganalisis file..."),
            (50, "Memproses dengan AI..."),
            (75, "Mendeteksi ancaman..."),
            (95, "Menyelesaikan analisis...")
        ]

        for value, msg in stages:
            if self.is_canceled:
                return
            self.progress.emit(value, msg)
            self.msleep(STAGE_DELAY_MS)

        try:
            result = self.scanner.scan_file(self.file_path)
        except Exception as e:
            self.finished.emit({
                "is_full_scan": False,
                "result": "Unknown",
                "confidence": 0,
                "details": f"File tidak dapat dipindai: {e}"
            })
            return

        self.progress.emit(100, "Selesai")
        self.finished.emit(result)

    # ====================================================
    # FULL SCAN
    # ====================================================
    def _run_full_scan(self):
        base_path = Path(self.file_path)

        self.progress.emit(5, "Mengumpulkan file untuk dipindai...")
        files_to_scan = []

        try:
            if base_path.is_dir():
                for f in base_path.rglob("*"):
                    if self.is_canceled:
                        return
                    if f.is_file() and f.suffix.lower() in SCAN_EXTENSIONS:
                        files_to_scan.append(f)
                    if MAX_FILES_TO_SCAN and len(files_to_scan) >= MAX_FILES_TO_SCAN:
                        break
            else:
                files_to_scan.append(base_path)
        except PermissionError:
            pass

        total_files = len(files_to_scan)

        if total_files == 0:
            self.finished.emit({
                "is_full_scan": True,
                "details": "Tidak ada file yang cocok untuk dipindai.",
                "files_scanned": 0,
                "malware_found": 0,
                "corrupt_count": 0
            })
            return

        self.progress.emit(10, f"Ditemukan {total_files} file")
        self.msleep(COLLECTION_PAUSE_MS)

        # ===============================
        # STATISTICS
        # ===============================
        safe_files = 0
        malware_found = 0
        corrupt_files = []
        threats_found = []

        # ===============================
        # SCAN LOOP
        # ===============================
        for idx, file_path in enumerate(files_to_scan, start=1):
            if self.is_canceled:
                return

            percent = 10 + int((idx / total_files) * 85)
            self.progress.emit(
                percent,
                f"Memindai {idx}/{total_files}: {file_path.name}"
            )

            try:
                result = self.scanner.scan_file(str(file_path))

                if result.get("result") == "Malware":
                    malware_found += 1
                    threats_found.append({
                        "file": str(file_path),
                        "name": file_path.name,
                        "threat": "Malware"
                    })
                else:
                    safe_files += 1

            except Exception as e:
                corrupt_files.append({
                    "file": str(file_path),
                    "name": file_path.name,
                    "error": str(e)
                })

            self.msleep(FILE_SCAN_DELAY_MS)

        # ===============================
        # FINAL RESULT
        # ===============================
        summary = {
            "is_full_scan": True,
            "files_scanned": total_files,
            "safe_count": safe_files,
            "malware_found": malware_found,
            "corrupt_count": len(corrupt_files),
            "threats": threats_found,
            "corrupt_files": corrupt_files,
            "details": (
                f"Pemindaian selesai!\n\n"
                f"Total file dipindai: {total_files}\n"
                f"File aman: {safe_files}\n"
                f"Ancaman terdeteksi: {malware_found}\n"
                f"File gagal dipindai: {len(corrupt_files)}"
            )
        }

        self.progress.emit(100, "Selesai")
        self.finished.emit(summary)
