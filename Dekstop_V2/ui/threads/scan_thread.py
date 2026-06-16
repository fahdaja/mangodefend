"""
Scan Thread
Background worker thread for malware scanning (single file and batch)
"""
import os
from pathlib import Path
from PySide6.QtCore import QThread, Signal
from core.scanner import MalwareScanner


class ScanThread(QThread):
    """Thread for running malware scan on a single file."""
    finished = Signal(dict)
    error = Signal(str)
    progress = Signal(int, str)

    def __init__(self, file_path):
        super().__init__()
        self.file_path = file_path
        self.scanner = MalwareScanner()
        self.is_canceled = False

    def run(self):
        try:
            stages = [
                (10, "Memulai pemindaian..."),
                (25, "Menganalisis file..."),
                (40, "Memproses dengan AI..."),
                (60, "Mendeteksi malware..."),
                (80, "Menyelesaikan analisis..."),
                (95, "Hampir selesai...")
            ]

            for value, message in stages:
                if self.is_canceled:
                    return
                self.progress.emit(value, message)
                self.msleep(200)

            from core.config_manager import get_config
            from core.api_client import BackendClient
            
            config = get_config()
            use_embedded = config.get_bool('Backend', 'use_embedded', True)
            
            if use_embedded:
                self.progress.emit(70, "Scan On-Device (Lokal)...")
                result = self.scanner.scan_file(self.file_path)
            else:
                self.progress.emit(70, "Upload & Scan via Cloud Server...")
                client = BackendClient(base_url=config.get_backend_url())
                api_resp = client.upload_and_scan_file(self.file_path, app_platform="Desktop (Manual)")
                if not api_resp:
                    raise Exception("Gagal mendapatkan respons dari server Cloud.")
                
                import os
                from datetime import datetime
                result = {
                    "result": api_resp.get("label", "Unknown").capitalize(),
                    "timestamp": datetime.now().strftime("%d-%m-%Y %H:%M:%S"),
                    "device": {"device": "Cloud Server"},
                    "file": {
                        "file_name": api_resp.get("file_name", os.path.basename(self.file_path)),
                        "file_path": self.file_path,
                        "file_size": api_resp.get("file_size", 0),
                        "file_hash": "Cloud"
                    }
                }

            self.progress.emit(100, "Selesai!")
            self.msleep(200)
            self.finished.emit(result)

        except Exception as e:
            self.error.emit(str(e))

    def cancel(self):
        self.is_canceled = True


class BatchScanThread(QThread):
    """Thread for scanning multiple files (folder or device scan)."""
    file_scanned = Signal(dict)   # result for each file
    batch_finished = Signal(dict)  # summary
    error = Signal(str)
    progress = Signal(int, str)   # percentage, message

    # Extensions to scan in batch mode (dangerous types)
    SCAN_EXTENSIONS = frozenset({
        ".exe", ".dll", ".scr", ".bat", ".cmd",
        ".ps1", ".vbs", ".js", ".jar", ".msi",
        ".com", ".pif", ".wsf", ".hta", ".cpl",
        ".sys", ".drv", ".bin", ".dat",
    })

    # Max files to scan per device scan to avoid scanning forever
    _DEVICE_SCAN_FILE_LIMIT = 2000

    def __init__(self, folder_path: str = None, full_device: bool = False):
        super().__init__()
        self.folder_path = folder_path
        self.full_device = full_device
        self.scanner = MalwareScanner()
        self.is_canceled = False

    def run(self):
        try:
            self.scanner.load_model(aggressive=True)

            # Collect files to scan
            self.progress.emit(0, "Mengumpulkan file...")
            files = self._collect_files()

            if not files:
                self.progress.emit(100, "Tidak ada file yang perlu discan")
                self.batch_finished.emit({
                    "total": 0, "scanned": 0,
                    "malware": 0, "clean": 0, "errors": 0,
                    "results": []
                })
                return

            total = len(files)
            scanned = 0
            malware_count = 0
            clean_count = 0
            error_count = 0
            results = []

            for i, file_path in enumerate(files):
                if self.is_canceled:
                    break

                # Progress
                pct = int((i / total) * 100)
                fname = Path(file_path).name
                self.progress.emit(pct, f"Memindai ({i+1}/{total}): {fname}")

                try:
                    # For folder scan (not full_device), scan all collected files
                    # For device scan (full_device), apply extension filter in scanner
                    result = self.scanner.scan_file(file_path, is_full_scan=self.full_device)
                    if result is None:
                        continue  # skipped by scanner (device scan extension filter)

                    scanned += 1
                    result_type = result.get("result", "Unknown")

                    # Emit ALL results to history (malware and benign)
                    self.file_scanned.emit(result)

                    if result_type == "Malware":
                        malware_count += 1
                        results.append(result)
                    else:
                        clean_count += 1

                except (OSError, PermissionError):
                    error_count += 1
                except Exception:  # noqa: BLE001
                    # Per-file errors are counted but don't abort the scan
                    error_count += 1

            self.progress.emit(100, f"Selesai! {scanned} file discan")

            summary = {
                "total": total,
                "scanned": scanned,
                "malware": malware_count,
                "clean": clean_count,
                "errors": error_count,
                "results": results,
            }
            self.batch_finished.emit(summary)

        except Exception as e:
            self.error.emit(str(e))

    def _collect_files(self) -> list:
        """Collect files to scan."""
        files = []

        if self.full_device:
            # Device scan: target the most common malware hotspots only.
            # Scanning entire drives takes too long and requires admin rights.
            home = Path.home()
            scan_dirs = [
                home / "Downloads",
                home / "Desktop",
                home / "Documents",
                home / "AppData" / "Local" / "Temp",
                home / "AppData" / "Roaming",
                home / "AppData" / "Local",
            ]
            # Add other drive roots (D:, E:, etc.) — root level only, not recurse blindly
            import string
            for letter in string.ascii_uppercase:
                if letter == "C":
                    continue
                drive = Path(f"{letter}:/")
                if drive.exists():
                    scan_dirs.append(drive)
        else:
            # Folder scan: scan ALL files the user selected
            scan_dirs = [Path(self.folder_path)] if self.folder_path else []

        seen: set[str] = set()

        for scan_dir in scan_dirs:
            if self.is_canceled:
                break
            if not scan_dir.exists():
                continue
            try:
                for root, dirs, filenames in os.walk(scan_dir):
                    if self.is_canceled:
                        break

                    # Cap total files for device scan
                    if self.full_device and len(files) >= self._DEVICE_SCAN_FILE_LIMIT:
                        return files

                    # Skip system / hidden / irrelevant directories
                    dirs[:] = [
                        d for d in dirs
                        if not d.startswith(".")
                        and d not in (
                            "$Recycle.Bin", "System Volume Information",
                            "Windows", "node_modules", ".git",
                            "__pycache__", "venv", ".venv",
                            "WinSxS", "assembly",
                        )
                    ]

                    for fname in filenames:
                        if self.is_canceled:
                            break
                        fpath = os.path.join(root, fname)

                        # Skip duplicates
                        if fpath in seen:
                            continue
                        seen.add(fpath)

                        ext = Path(fname).suffix.lower()

                        # For device scan: filter to dangerous extensions only
                        if self.full_device and ext not in self.SCAN_EXTENSIONS:
                            continue

                        try:
                            size = os.path.getsize(fpath)
                            if 0 < size <= 10 * 1024 * 1024:  # 1 byte – 10 MB
                                files.append(fpath)
                        except (OSError, PermissionError):
                            pass

                        # Cap inside inner loop too
                        if self.full_device and len(files) >= self._DEVICE_SCAN_FILE_LIMIT:
                            return files

            except (OSError, PermissionError):
                pass

        return files

    def cancel(self):
        self.is_canceled = True