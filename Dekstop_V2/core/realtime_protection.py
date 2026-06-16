"""
Real-time Protection - Pseudo-Blocking Mode
Uses Windows file locks to block access to new files while scanning.

Flow:
  1. Watchdog detects new file (e.g., .exe downloaded)
  2. IMMEDIATELY acquire exclusive lock on file (blocks all access)
  3. Scan file with AI model (ONNX)
  4. If clean → release lock (file can be opened normally)
  5. If malware → quarantine/delete, then release lock

This provides near-kernel-level protection without requiring a signed
kernel driver, making the app fully standalone.
"""

import os
import sys
import time
import ctypes
import threading
import logging
import shutil
from pathlib import Path
from typing import Set, Callable, Optional, List
from queue import Queue, Empty

from .scanner import MalwareScanner

logger = logging.getLogger(__name__)

# ================================================================
# Windows File Locking via CreateFileW
# ================================================================

if sys.platform == "win32":
    import ctypes.wintypes

    kernel32 = ctypes.windll.kernel32

    GENERIC_READ = 0x80000000
    OPEN_EXISTING = 3
    FILE_ATTRIBUTE_NORMAL = 0x00000080
    FILE_FLAG_BACKUP_SEMANTICS = 0x02000000
    INVALID_HANDLE_VALUE = ctypes.wintypes.HANDLE(-1).value

    # Share modes
    FILE_SHARE_NONE = 0x00000000      # Exclusive lock (no sharing)
    FILE_SHARE_READ = 0x00000001      # Allow others to read


class FileLock:
    """
    Locks a file using Windows CreateFileW with no sharing mode.
    While locked, no other process can open/execute the file.
    """

    def __init__(self, file_path: str):
        self.file_path = file_path
        self._handle = None
        self._locked = False

    def acquire(self, max_retries: int = 5, retry_delay: float = 0.3) -> bool:
        """
        Acquire exclusive lock on the file.
        Returns True if lock acquired, False otherwise.
        """
        if sys.platform != "win32":
            return False

        for attempt in range(max_retries):
            try:
                handle = kernel32.CreateFileW(
                    self.file_path,
                    GENERIC_READ,
                    FILE_SHARE_NONE,    # NO SHARING = exclusive lock
                    None,
                    OPEN_EXISTING,
                    FILE_ATTRIBUTE_NORMAL,
                    None
                )

                if handle != INVALID_HANDLE_VALUE:
                    self._handle = handle
                    self._locked = True
                    return True

                # File might still be in use (e.g., being downloaded)
                error_code = kernel32.GetLastError()
                if error_code == 32:  # ERROR_SHARING_VIOLATION
                    time.sleep(retry_delay)
                    continue
                else:
                    return False

            except Exception as e:
                logger.debug(f"Lock attempt {attempt + 1} failed for {self.file_path}: {e}")
                time.sleep(retry_delay)

        return False

    def release(self):
        """Release the file lock."""
        if self._handle and self._locked:
            try:
                kernel32.CloseHandle(self._handle)
            except Exception:
                pass
            finally:
                self._handle = None
                self._locked = False

    @property
    def is_locked(self) -> bool:
        return self._locked

    def __enter__(self):
        self.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.release()
        return False


# ================================================================
# FILE EXTENSION FILTERS
# ================================================================

# Extensions to SKIP (clearly safe, non-executable files)
SKIP_EXTENSIONS = {
    # Images
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.ico', '.svg', '.webp', '.tiff',
    # Videos
    '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm',
    # Audio
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma',
    # Documents (text-based)
    '.txt', '.md', '.csv', '.json', '.xml', '.yaml', '.yml', '.ini', '.cfg',
    '.log', '.html', '.css',
    # Fonts
    '.ttf', '.otf', '.woff', '.woff2',
    # Archives (scan these!)
    # '.zip', '.rar', '.7z', '.tar', '.gz',  # NOT skipped
    # Temporary/system
    '.tmp', '.temp', '.lock', '.gitignore', '.gitattributes',
}

# Executable/dangerous extensions — also includes all file types the ML model can scan.
# These are locked by the prescan on startup so they can't be opened before scanning.
DANGEROUS_EXTENSIONS = {
    # Executables & scripts
    '.exe', '.dll', '.scr', '.bat', '.cmd',
    '.ps1', '.vbs', '.js', '.jar', '.msi',
    '.com', '.pif', '.wsf', '.hta', '.cpl', '.sys',
    # Images (ML model scans these directly as pixel data)
    '.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tiff', '.webp',
    # Archives & documents (model converts to image for scanning)
    '.zip', '.rar', '.7z',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    # Other binary formats the converter handles
    '.bin', '.dat', '.iso',
}

# Max file size per category for prescan locking
_IMAGE_EXTS   = {'.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tiff', '.webp'}
_MAX_SIZE_IMG = 50 * 1024 * 1024   # 50 MB
_MAX_SIZE_EXE = 10 * 1024 * 1024   # 10 MB


class RealtimeProtection:
    """
    Real-time file system protection with pseudo-blocking.

    When a new dangerous file appears (e.g., .exe), it is immediately
    locked (exclusive file handle) so no process can execute it.
    The file is then scanned with AI. If clean, the lock is released.
    If malware, the file is quarantined/deleted.
    """

    def __init__(
        self,
        monitored_paths: Optional[List[str]] = None,
        scan_delay: int = 1,
        max_queue_size: int = 10000,
        on_malware_detected: Optional[Callable] = None,
        quarantine_dir: Optional[str] = None,
    ):
        """
        Initialize real-time protection.

        Args:
            monitored_paths: Paths to monitor (default: all user folders)
            scan_delay: Delay before scanning newly created files (seconds)
            max_queue_size: Max scan queue size
            on_malware_detected: Callback(file_path, scan_result)
            quarantine_dir: Directory to move malware files to
        """
        self.monitored_paths = monitored_paths
        self.scan_delay = max(scan_delay, 1)
        self.max_queue_size = min(max_queue_size, 10000)
        self.on_malware_detected = on_malware_detected
        self.malware_bridge = None  # Set from UI (MalwareAlertBridge)

        # Quarantine directory
        if quarantine_dir:
            self.quarantine_dir = Path(quarantine_dir)
        else:
            self.quarantine_dir = Path.home() / ".Mangodefend" / "Karintina"

        # Components
        self.scanner = MalwareScanner()

        # State
        self.running = False
        self.mode = "none"
        self._scan_threads: List[threading.Thread] = []
        self._observer = None
        self._scan_queue = None
        self._active_locks: dict = {}  # file_path -> FileLock
        self._lock_mutex = threading.Lock()

        # Statistics
        self.stats = {
            "files_scanned": 0,
            "malware_detected": 0,
            "files_blocked": 0,
            "files_quarantined": 0,
            "processes_suspended": 0,
            "processes_killed": 0,
            "start_time": None,
            "mode": "none"
        }

        # Shutdown event — set when stop() is called to unblock waiting threads
        self._shutdown_event = threading.Event()

        # Scan cache (avoid re-scanning known clean files)
        self.scan_cache: Set[str] = set()
        self.cache_ttl = 300  # 5 minutes

        # Whitelist extensions (files to skip scanning)
        self.whitelist_extensions: Set[str] = set()

        # Process monitor state
        self._known_pids: Set[int] = set()

        logger.info("RealtimeProtection initialized (pseudo-blocking + scan-on-execute)")

    def _perform_scan(self, file_path: str) -> dict:
        """
        Perform scan on a file.
        Uses ML server (cloud) if use_embedded is False, otherwise scans locally.
        Falls back to local scan if ML server is offline.
        """
        from core.config_manager import get_config
        from core.api_client import BackendClient
        from datetime import datetime
        import os

        config = get_config()
        use_embedded = config.get_bool('Backend', 'use_embedded', True)

        if not use_embedded:
            try:
                logger.info(f"Uploading and scanning via ML Server: {file_path}")
                client = BackendClient(base_url=config.get_backend_url())
                api_resp = client.upload_and_scan_file(file_path, app_platform="Desktop")
                if api_resp:
                    label = api_resp.get("label", "benign").capitalize()
                    return {
                        "result": label,
                        "timestamp": datetime.now().strftime("%d-%m-%Y %H:%M:%S") if "scanned_at" not in api_resp else api_resp.get("scanned_at"),
                        "device": {"device": "Cloud Server"},
                        "file": {
                            "file_name": api_resp.get("file_name", os.path.basename(file_path)),
                            "file_path": file_path,
                            "file_size": api_resp.get("file_size", os.path.getsize(file_path)),
                            "file_hash": "Cloud"
                        }
                    }
                else:
                    logger.error(f"Cloud scan failed for {file_path}, falling back to local scan")
            except Exception as e:
                logger.error(f"Error during cloud scan for {file_path}: {e}. Falling back to local scan")

        return self.scanner.scan_file(file_path)

    # ================================================================
    # START / STOP
    # ================================================================

    def start(self):
        """Start real-time protection with pseudo-blocking."""
        if self.running:
            logger.warning("Protection already running")
            return

        self.running = True
        self.stats["start_time"] = time.time()

        # Ensure quarantine directory exists
        self.quarantine_dir.mkdir(parents=True, exist_ok=True)

        # Start both protection layers
        self._start_watchdog_mode()
        self._start_process_monitor()

    def stop(self):
        """Stop real-time protection."""
        if not self.running:
            return

        logger.info("Stopping real-time protection...")
        self.running = False

        # Unblock any scan threads waiting in _ask_user_decision or _wait_for_stable_file
        self._shutdown_event.set()

        # Stop watchdog observer
        if self._observer:
            self._observer.stop()
            self._observer.join(timeout=2)
            self._observer = None

        # Wait for scan threads (they will exit quickly now that shutdown_event is set)
        for t in self._scan_threads:
            t.join(timeout=3)
        self._scan_threads.clear()

        # Reset shutdown event for next start()
        self._shutdown_event.clear()

        # Release any remaining locks
        with self._lock_mutex:
            for file_path, lock in self._active_locks.items():
                lock.release()
                logger.debug(f"Released remaining lock: {file_path}")
            self._active_locks.clear()

        self.mode = "none"
        self.stats["mode"] = "none"
        logger.info("Real-time protection stopped")

    # ================================================================
    # WATCHDOG + PSEUDO-BLOCKING
    # ================================================================

    def _start_watchdog_mode(self):
        """Start watchdog monitoring with pseudo-blocking."""
        try:
            from watchdog.observers import Observer
            from watchdog.events import FileSystemEventHandler
        except ImportError:
            logger.error("watchdog not installed! Run: pip install watchdog")
            self.running = False
            return

        if not self.monitored_paths:
            self.monitored_paths = self._get_default_paths()

        self._scan_queue = Queue(maxsize=self.max_queue_size)

        # Create event handler
        protection = self

        class PseudoBlockHandler(FileSystemEventHandler):
            """Intercept ALL new files and scan them."""

            def on_created(self, event):
                if event.is_directory:
                    return
                protection._on_new_file(event.src_path)

            def on_modified(self, event):
                if event.is_directory:
                    return
                file_path = event.src_path

                # Only scan modified files if not already being handled
                if file_path not in protection.scan_cache:
                    with protection._lock_mutex:
                        if file_path not in protection._active_locks:
                            protection._on_new_file(file_path)

        # Start observer
        self._observer = Observer()
        handler = PseudoBlockHandler()

        for path in self.monitored_paths:
            try:
                if os.path.exists(path):
                    self._observer.schedule(handler, path, recursive=True)
                    logger.info(f"📂 Monitoring: {path}")
            except Exception as e:
                logger.error(f"Failed to monitor {path}: {e}")

        self._observer.start()

        # Start scan workers (4 threads — more parallelism needed because
        # prescan now locks images too, so more files need rapid scan+release)
        for i in range(4):
            t = threading.Thread(
                target=self._scan_worker,
                daemon=True,
                name=f"ScanWorker-{i}"
            )
            t.start()
            self._scan_threads.append(t)

        # Start cache cleanup thread
        t_cache = threading.Thread(
            target=self._cache_cleanup_worker,
            daemon=True,
            name="CacheCleanup"
        )
        t_cache.start()
        self._scan_threads.append(t_cache)

        self.mode = "pseudo-blocking"
        self.stats["mode"] = "pseudo-blocking"
        logger.info("✅ Real-time protection started (PSEUDO-BLOCKING MODE)")

    def _prescan_existing_files(self):
        """
        On startup: walk monitored paths and immediately lock + queue
        any dangerous file already on disk that hasn't been scanned.
        This ensures files sitting in Downloads/Desktop are blocked
        BEFORE the user double-clicks them.
        """
        if not self.monitored_paths:
            return

        logger.info("🔍 Pre-scanning existing files in monitored paths...")
        count = 0

        for base_path in self.monitored_paths:
            if not self.running:
                break
            try:
                for root, dirs, filenames in os.walk(base_path):
                    if not self.running:
                        break
                    # Skip hidden / system folders
                    dirs[:] = [d for d in dirs if not d.startswith('.')
                               and d not in ('$Recycle.Bin', 'System Volume Information',
                                             'Windows', '__pycache__', 'venv', '.venv')]
                    for fname in filenames:
                        if not self.running:
                            break
                        ext = Path(fname).suffix.lower()
                        if ext not in DANGEROUS_EXTENSIONS:
                            continue
                        fpath = os.path.join(root, fname)
                        if fpath in self.scan_cache:
                            continue
                        with self._lock_mutex:
                            if fpath in self._active_locks:
                                continue
                        try:
                            size = os.path.getsize(fpath)
                            max_sz = _MAX_SIZE_IMG if ext in _IMAGE_EXTS else _MAX_SIZE_EXE
                            if size <= 0 or size > max_sz:
                                continue
                        except OSError:
                            continue
                        self._on_new_file(fpath)
                        count += 1
            except (OSError, PermissionError):
                pass

        logger.info(f"✅ Pre-scan queued {count} existing dangerous files")

    def _on_new_file(self, file_path: str):
        """
        Handle a newly detected file:
        1. Try to acquire exclusive lock immediately (blocks access)
        2. Queue for scanning regardless — scan worker will retry lock
        """
        if file_path in self.scan_cache:
            return

        # Try to acquire lock immediately
        lock = FileLock(file_path)
        got_lock = lock.acquire(max_retries=5, retry_delay=0.1)

        if got_lock:
            with self._lock_mutex:
                self._active_locks[file_path] = lock
            self.stats["files_blocked"] += 1
            logger.info(f"🔒 LOCKED: {file_path}")
        else:
            # File in use (e.g., still downloading) — queue anyway.
            # Scan worker will wait for file to stabilise and re-lock.
            logger.debug(f"Could not lock immediately, will retry in worker: {file_path}")

        try:
            self._scan_queue.put(file_path, block=False)
        except Exception:
            # Queue full
            if got_lock:
                lock.release()
                with self._lock_mutex:
                    self._active_locks.pop(file_path, None)

    def _wait_for_stable_file(self, file_path: str, stable_secs: float = 0.5,
                               max_wait: float = 30.0) -> bool:
        """
        Wait until a file's size stops changing (fully written).
        Returns True when stable, False if timed out or file gone.
        """
        deadline = time.monotonic() + max_wait
        last_size = -1
        unchanged_for = 0.0
        poll = 0.2  # check every 200ms

        while time.monotonic() < deadline:
            # Exit immediately if protection is being stopped
            if self._shutdown_event.is_set() or not self.running:
                return False
            try:
                size = os.path.getsize(file_path)
            except OSError:
                return False
            if size == last_size:
                unchanged_for += poll
                if unchanged_for >= stable_secs:
                    return True
            else:
                last_size = size
                unchanged_for = 0.0
            time.sleep(poll)

        return False  # timed out

    def _ensure_locked(self, file_path: str) -> bool:
        """
        Ensure the file is locked before scanning.
        If already locked by us, returns True immediately.
        Otherwise waits for the file to stabilise then acquires lock.
        Returns True if lock is held after this call.
        """
        with self._lock_mutex:
            if file_path in self._active_locks:
                return True  # already locked

        # File not locked yet — wait for it to stabilise, then lock
        if not self._wait_for_stable_file(file_path):
            return False

        lock = FileLock(file_path)
        if lock.acquire(max_retries=10, retry_delay=0.2):
            with self._lock_mutex:
                self._active_locks[file_path] = lock
            self.stats["files_blocked"] += 1
            logger.info(f"🔒 LOCKED (after stabilise): {file_path}")
            return True

        logger.warning(f"Could not acquire lock even after stabilise: {file_path}")
        return False

    def _scan_worker(self):
        """Worker thread: scan files and decide allow/quarantine."""
        logger.info(f"Scan worker started: {threading.current_thread().name}")

        while self.running:
            try:
                try:
                    file_path = self._scan_queue.get(timeout=1)
                except Empty:
                    continue

                if not os.path.exists(file_path):
                    self._release_lock(file_path)
                    continue

                # ── CRITICAL: ensure file is locked BEFORE scanning ──
                # If lock was acquired in _on_new_file, this is instant.
                # If not (browser was writing), this waits for stability then locks.
                locked = self._ensure_locked(file_path)
                if not locked:
                    # Could not lock — skip to avoid false positives but warn
                    logger.warning(f"Scanning without lock (access not blocked): {file_path}")

                # Scan the file (lock is held, so user CANNOT open/execute it)
                is_malware = False
                scan_result = None

                try:
                    scan_result = self._perform_scan(file_path)
                    self.stats["files_scanned"] += 1

                    if scan_result and scan_result.get('result') == 'Malware':
                        is_malware = True
                        self.stats["malware_detected"] += 1

                except Exception as e:
                    logger.error(f"Scan error for {file_path}: {e}")
                    self._release_lock(file_path)
                    continue

                if is_malware:
                    logger.warning(f"🚨 MALWARE BLOCKED: {file_path}")
                    # Lock is still held — ask user (file remains unexecutable)
                    action = self._ask_user_decision(file_path, scan_result)
                    # Release lock BEFORE quarantine (need to move file)
                    self._release_lock(file_path)
                    if action == 1:  # quarantine
                        self._quarantine_file(file_path)
                    else:
                        logger.info(f"▶️ User allowed: {os.path.basename(file_path)}")
                        self.scan_cache.add(file_path)
                else:
                    # Clean — release lock, add to whitelist cache
                    self._release_lock(file_path)
                    self.scan_cache.add(file_path)
                    logger.info(f"✅ Clean: {os.path.basename(file_path)}")

            except Exception as e:
                logger.error(f"Scan worker error: {e}")
                time.sleep(1)

        logger.info(f"Scan worker stopped: {threading.current_thread().name}")

    def _release_lock(self, file_path: str):
        """Release file lock if held."""
        with self._lock_mutex:
            lock = self._active_locks.pop(file_path, None)
            if lock:
                lock.release()
                logger.debug(f"🔓 Unlocked: {file_path}")

    def _quarantine_file(self, file_path: str):
        """Move malware file to quarantine directory."""
        try:
            src = Path(file_path)
            if not src.exists():
                return

            # Create unique quarantine name
            timestamp = int(time.time())
            quarantine_name = f"{timestamp}_{src.name}.quarantined"
            dest = self.quarantine_dir / quarantine_name

            # Retry loop: on Windows, file lock from killed process may linger briefly
            last_err = None
            for attempt in range(6):
                try:
                    shutil.move(str(src), str(dest))
                    self.stats["files_quarantined"] += 1
                    logger.info(f"Quarantined: {src.name} → {dest}")
                    return
                except PermissionError as e:
                    last_err = e
                    logger.debug(f"Quarantine attempt {attempt+1} blocked, retrying... ({e})")
                    time.sleep(0.5)

            raise last_err  # All retries exhausted

        except Exception as e:
            logger.error(f"Failed to quarantine {file_path}: {e}")
            # Try to delete instead
            try:
                os.remove(file_path)
                logger.info(f"Deleted malware: {file_path}")
            except Exception:
                logger.error(f"Could not delete malware file: {file_path}")

    def _cache_cleanup_worker(self):
        """Periodically clean scan cache to re-scan files."""
        while self.running:
            time.sleep(60)
            if len(self.scan_cache) > 1000:
                self.scan_cache.clear()
                logger.debug("Scan cache cleared")

    # ================================================================
    # HELPER METHODS
    # ================================================================

    def _get_default_paths(self) -> List[str]:
        """Get default paths to monitor (user-focused, not all drives)."""
        home = Path.home()
        paths = [
            str(home / "Downloads"),
            str(home / "Desktop"),
            str(home / "Documents"),
        ]

        # Add common temp/download locations
        temp = os.environ.get("TEMP", "")
        if temp and os.path.exists(temp):
            paths.append(temp)

        return [p for p in paths if os.path.exists(p)]

    def is_running(self) -> bool:
        """Check if protection is running."""
        return self.running

    def get_mode(self) -> str:
        """Get current protection mode."""
        return self.mode

    def get_stats(self) -> dict:
        """Get protection statistics."""
        uptime = 0
        if self.stats["start_time"]:
            uptime = time.time() - self.stats["start_time"]

        return {
            **self.stats,
            "uptime_seconds": round(uptime, 1),
            "cache_size": len(self.scan_cache),
            "active_locks": len(self._active_locks),
        }


    # ================================================================
    # SCAN-ON-EXECUTE (Process Monitor)
    # ================================================================

    def _start_process_monitor(self):
        """
        Start monitoring new process creation.
        When a new .exe runs, suspend it → scan → resume or kill.
        """
        try:
            import psutil
            # Take snapshot of currently running PIDs
            self._known_pids = set(psutil.pids())

            t = threading.Thread(
                target=self._process_monitor_worker,
                daemon=True,
                name="ProcessMonitor"
            )
            t.start()
            self._scan_threads.append(t)
            logger.info("Process monitor started (scan-on-execute)")

        except ImportError:
            logger.warning("psutil not installed, scan-on-execute disabled. Run: pip install psutil")

    def _process_monitor_worker(self):
        """
        Poll for new processes and scan:
        1. The executable itself (if not a system process)
        2. Any file being opened (from command-line arguments)
        
        This catches BOTH new executables AND existing files being clicked.
        """
        import psutil

        logger.info("Process monitor worker started (scan-on-click for all files)")

        while self.running:
            try:
                current_pids = set(psutil.pids())
                new_pids = current_pids - self._known_pids
                self._known_pids = current_pids

                for pid in new_pids:
                    if not self.running:
                        break

                    try:
                        proc = psutil.Process(pid)

                        # ── SUSPEND IMMEDIATELY ──────────────────────────────
                        # Freeze the process BEFORE reading exe/cmdline so it
                        # cannot render or execute anything while we decide.
                        # We resume it if it turns out to be clean/safe.
                        pre_suspended = False
                        try:
                            exe_path = proc.exe()
                            if exe_path and not self._is_system_process(exe_path):
                                proc.suspend()
                                pre_suspended = True
                                self.stats["processes_suspended"] += 1
                                logger.debug(f"Pre-suspended: {proc.name()} (PID={pid})")
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
                        # ─────────────────────────────────────────────────────

                        exe_path = proc.exe() if not exe_path else exe_path

                        if not exe_path:
                            if pre_suspended:
                                try: proc.resume()
                                except Exception: pass
                            continue

                        exe_ext = Path(exe_path).suffix.lower()
                        if exe_ext not in DANGEROUS_EXTENSIONS:
                            # Check opened file args for all processes
                            try:
                                cmdline = proc.cmdline()
                                handled = False
                                if len(cmdline) > 1:
                                    for arg in cmdline[1:]:
                                        clean_arg = arg.strip().strip('"').strip("'")
                                        if clean_arg.startswith('-') or clean_arg.startswith('/'):
                                            continue
                                        try:
                                            clean_arg = os.path.normpath(clean_arg)
                                        except Exception:
                                            continue
                                        if os.path.isfile(clean_arg) and clean_arg not in self.scan_cache:
                                            arg_ext = Path(clean_arg).suffix.lower()
                                            if arg_ext in DANGEROUS_EXTENSIONS:
                                                logger.info(f"Dangerous file opened: {os.path.basename(clean_arg)} by {proc.name()}")
                                                # Pass pre_suspended so _scan_opened_file
                                                # knows the process is already frozen.
                                                self._scan_opened_file(
                                                    proc, pid, clean_arg,
                                                    already_suspended=pre_suspended
                                                )
                                                pre_suspended = False  # ownership transferred
                                                handled = True
                                                break
                                if not handled and pre_suspended:
                                    try: proc.resume()
                                    except Exception: pass
                            except (psutil.NoSuchProcess, psutil.AccessDenied):
                                if pre_suspended:
                                    try: proc.resume()
                                    except Exception: pass
                            continue

                        is_system = self._is_system_process(exe_path)

                        # ── LAYER A: Scan the executable itself ──
                        if not is_system and exe_path not in self.scan_cache:
                            # Process already pre-suspended — pass that context
                            self._scan_and_handle_process(
                                proc, pid, exe_path,
                                already_suspended=pre_suspended
                            )
                            pre_suspended = False
                            continue

                        # ── LAYER B: Scan files being OPENED by this process ──
                        try:
                            cmdline = proc.cmdline()
                            logger.info(f" New process: {proc.name()} PID={pid} args={len(cmdline)-1}")
                            handled = False

                            if len(cmdline) > 1:
                                for arg in cmdline[1:]:
                                    clean_arg = arg.strip().strip('"').strip("'")
                                    if clean_arg.startswith('-') or clean_arg.startswith('/'):
                                        continue
                                    try:
                                        clean_arg = os.path.normpath(clean_arg)
                                    except Exception:
                                        continue
                                    if os.path.isfile(clean_arg):
                                        if clean_arg in self.scan_cache:
                                            continue
                                        logger.info(f"📂 File opened: {os.path.basename(clean_arg)} by {proc.name()}")
                                        self._scan_opened_file(
                                            proc, pid, clean_arg,
                                            already_suspended=pre_suspended
                                        )
                                        pre_suspended = False  # ownership transferred
                                        handled = True
                                        break
                            if not handled and pre_suspended:
                                try: proc.resume()
                                except Exception: pass
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            if pre_suspended:
                                try: proc.resume()
                                except Exception: pass

                    except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                        continue
                    except Exception as e:
                        logger.debug(f"Process monitor error for PID {pid}: {e}")

                # Poll interval: 5ms — tight enough to catch processes before first render
                time.sleep(0.005)

            except Exception as e:
                logger.error(f"Process monitor error: {e}")
                time.sleep(1)

        logger.info("Process monitor worker stopped")

    def _scan_and_handle_process(self, proc, pid: int, exe_path: str, already_suspended: bool = False):
        """Suspend process, scan its executable, ask user if malware."""
        import psutil

        try:
            if not already_suspended:
                proc.suspend()
                self.stats["processes_suspended"] += 1
                logger.info(f"⏸️ SUSPENDED process: {proc.name()} (PID={pid})")
            else:
                logger.info(f"⏸️ Already suspended: {proc.name()} (PID={pid})")

            result = self._perform_scan(exe_path)
            self.stats["files_scanned"] += 1

            if result and result.get('result') == 'Malware':
                # Ask user what to do
                action = self._ask_user_decision(exe_path, result)

                if action == 1:  # ACTION_KILL
                    logger.warning(f"🚨 KILLED malware process: {proc.name()} (PID={pid})")
                    proc.kill()
                    try:
                        proc.wait(timeout=3)
                    except Exception:
                        pass
                    self.stats["malware_detected"] += 1
                    self.stats["processes_killed"] += 1
                    self._quarantine_file(exe_path)
                else:
                    # User chose to continue
                    logger.info(f"▶️ User allowed process: {proc.name()} (PID={pid})")
                    proc.resume()
                    self.scan_cache.add(exe_path)
            else:
                proc.resume()
                self.scan_cache.add(exe_path)
                logger.info(f"▶️ Resumed clean process: {proc.name()} (PID={pid})")

        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
        except Exception as e:
            logger.error(f"Scan error for PID {pid}: {e}")
            try:
                proc.resume()
            except Exception:
                pass

    def _scan_opened_file(self, proc, pid: int, file_path: str, already_suspended: bool = False):
        """
        Scan a file being opened by a process.
        IMMEDIATELY suspend the opener so it cannot render/execute the file
        while the scan is in progress.
        """
        import psutil

        suspended = already_suspended
        try:
            logger.info(f"🔍 Scanning opened file: {os.path.basename(file_path)} (opened by {proc.name()}, PID={pid})")

            # ── Suspend the opener process RIGHT AWAY (if not already done) ──
            if not already_suspended:
                try:
                    proc.suspend()
                    suspended = True
                    self.stats["processes_suspended"] += 1
                    logger.info(f"⏸️ SUSPENDED opener: {proc.name()} (PID={pid}) while scanning")
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass  # Process died or no permission — scan anyway
            else:
                logger.info(f"⏸️ Already suspended opener: {proc.name()} (PID={pid}) while scanning")

            result = self._perform_scan(file_path)
            self.stats["files_scanned"] += 1

            if result and result.get('result') == 'Malware':
                # Alert while opener is frozen → user sees the dialog, NOT the file
                action = self._ask_user_decision(file_path, result)

                if action == 1:  # Kill & Quarantine
                    logger.warning(f"🚨 MALWARE found: {file_path}")
                    logger.warning(f"🚨 KILLING process: {proc.name()} (PID={pid})")
                    try:
                        proc.kill()
                        try:
                            proc.wait(timeout=3)
                        except Exception:
                            pass
                        suspended = False  # Killed, no need to resume
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass
                    self.stats["malware_detected"] += 1
                    self.stats["processes_killed"] += 1
                    self._quarantine_file(file_path)
                else:
                    # User chose to allow — resume the opener
                    logger.info(f"▶️ User allowed file: {os.path.basename(file_path)}")
                    self.scan_cache.add(file_path)
                    if suspended:
                        try:
                            proc.resume()
                            suspended = False
                        except (psutil.NoSuchProcess, psutil.AccessDenied):
                            pass
            else:
                # Clean — resume opener normally
                self.scan_cache.add(file_path)
                logger.info(f"✅ Clean file: {os.path.basename(file_path)}")
                if suspended:
                    try:
                        proc.resume()
                        suspended = False
                    except (psutil.NoSuchProcess, psutil.AccessDenied):
                        pass

        except Exception as e:
            logger.error(f"Error scanning opened file {file_path}: {e}")
            # Safety: always resume on unexpected error
            if suspended:
                try:
                    proc.resume()
                except Exception:
                    pass

    def _ask_user_decision(self, file_path: str, scan_result: dict) -> int:
        """
        Ask user via UI what to do with detected malware.
        Returns: 0 = continue/allow, 1 = kill & quarantine
        Always waits for the user to click a button — never auto-kills.
        """
        if self.malware_bridge:
            import threading as _threading
            response_event = _threading.Event()
            response_holder = []  # Will hold [action_int]

            alert_data = {
                "file_path": file_path,
                "scan_result": scan_result,
                "response_event": response_event,
                "response_holder": response_holder,
            }

            # Emit signal to UI thread
            self.malware_bridge.malware_detected.emit(alert_data)

            # Wait for user to click a button, but also watch for shutdown.
            # Uses chunked waits so threads unblock quickly when stop() is called.
            while not response_event.wait(timeout=0.3):
                if self._shutdown_event.is_set() or not self.running:
                    # Protection stopped while dialog was open — allow the file
                    # (the dialog will be cleaned up by the UI on its own)
                    logger.info("Protection stopped while waiting for user decision — defaulting to allow")
                    return 0

            if response_holder:
                return response_holder[0]

        # No UI bridge — default to ALLOW (never auto-kill without user consent)
        return 0

    def _is_system_process(self, exe_path: str) -> bool:
        """Check if exe is a system/trusted process (skip scanning)."""
        exe_lower = exe_path.lower()
        system_paths = [
            os.environ.get("SYSTEMROOT", "C:\\Windows").lower(),
            os.path.join(os.environ.get("PROGRAMFILES", "C:\\Program Files")).lower(),
            os.path.join(os.environ.get("PROGRAMFILES(X86)", "C:\\Program Files (x86)")).lower(),
        ]
        # Skip our own process
        if os.getpid() == os.getpid():  # Always skip self
            try:
                import psutil
                if exe_lower == psutil.Process(os.getpid()).exe().lower():
                    return True
            except Exception:
                pass

        for sys_path in system_paths:
            if exe_lower.startswith(sys_path):
                return True
        return False


# ================================================================
# CLI Entry Point
# ================================================================

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    def on_malware(file_path, result):
        print(f"\n🚨 MALWARE ALERT!")
        print(f"File: {file_path}")
        print(f"Result: {result.get('result', 'Unknown')}")
        print(f"Confidence: {result.get('confidence', 0):.1%}")

    protection = RealtimeProtection(
        scan_delay=2,
        on_malware_detected=on_malware,
    )

    protection.start()

    print(f"\n🛡️ Real-time protection running (mode: {protection.get_mode()})")
    print("Press Ctrl+C to stop\n")

    try:
        while True:
            time.sleep(10)
            stats = protection.get_stats()
            print(f"[Stats] Scanned: {stats['files_scanned']} | "
                  f"Blocked: {stats['files_blocked']} | "
                  f"Malware: {stats['malware_detected']} | "
                  f"Killed: {stats['processes_killed']} | "
                  f"Locks: {stats['active_locks']}")
    except KeyboardInterrupt:
        print("\nStopping...")
        protection.stop()
