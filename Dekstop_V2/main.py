"""
RMAV Desktop - AI-Powered Malware Detection
Main entry point for the desktop application
"""
import sys
import os
import logging

# ── Require Administrator on Windows ───────────────────────────────────────
if sys.platform == "win32":
    import ctypes
    def _is_admin() -> bool:
        try:
            return bool(ctypes.windll.shell32.IsUserAnAdmin())
        except Exception:
            return False

    if not _is_admin():
        # Re-launch the same script / frozen exe with elevated privileges.
        # ShellExecuteW with "runas" triggers the UAC prompt.
        script = sys.executable if getattr(sys, "frozen", False) else __file__
        params = " ".join(f'"{a}"' for a in sys.argv[1:]) if not getattr(sys, "frozen", False) else ""
        ctypes.windll.shell32.ShellExecuteW(
            None, "runas", sys.executable,
            f'"{script}" {params}'.strip(), None, 1
        )
        sys.exit(0)
# ───────────────────────────────────────────────────────────────────────────

from PySide6.QtWidgets import QApplication, QMessageBox
from PySide6.QtGui import QIcon
from ui.modern_window import ModernWindow
from core.sync_manager import SyncManager
from core.config_manager import get_config
from core.realtime_protection import RealtimeProtection
from core.notification_manager import NotificationManager
from core.model_updater import ModelUpdater
from core.embedded_backend import EmbeddedBackend

logger = logging.getLogger(__name__)



def on_malware_detected(file_path: str, scan_result: dict):
    """
    Callback function yang dipanggil saat malware terdeteksi oleh real-time protection.
    
    Fungsi ini akan:
    1. Print informasi malware ke console
    2. Menampilkan notifikasi Windows kepada user
    
    Args:
        file_path (str): Path lengkap ke file yang terdeteksi sebagai malware
                        Contoh: "C:\\Downloads\\virus.exe"
        scan_result (dict): Dictionary berisi hasil scan dengan keys:
                           - 'result': "Malware" atau "Benign"
                           - 'confidence': float (0.0-1.0)
                           - 'timestamp': waktu scan
    
    Example:
        >>> on_malware_detected("C:\\Downloads\\virus.exe", {
        ...     "result": "Malware",
        ...     "confidence": 0.95
        ... })
        # Output: Print info + tampilkan notifikasi Windows
    """
    logger.warning("MALWARE DETECTED: %s — result: %s", file_path, scan_result.get('result'))

    try:
        notif = NotificationManager()
        notif.show_malware_alert(
            file_path=file_path,
            file_name=os.path.basename(file_path),
            threat_level="High"
        )
    except Exception as e:
        logger.error("Failed to show malware notification: %s", e)


def main():
    """
    Entry point utama aplikasi MangoDefend.
    
    Fungsi ini menjalankan seluruh aplikasi dengan urutan:
    1. Inisialisasi Qt Application
    2. Load konfigurasi dari config.ini
    3. Start embedded backend server (AI engine)
    4. Start sync manager (sinkronisasi data ke server)
    5. Start real-time protection (monitoring file system)
    6. Buka main window (UI aplikasi)
    7. Run event loop (tunggu user interaksi)
    8. Cleanup saat aplikasi ditutup
    
    Semua komponen dijalankan secara independen menggunakan threading,
    sehingga aplikasi tetap responsive.
    
    Returns:
        int: Exit code aplikasi (0 = sukses, non-zero = error)
    
    Example:
        >>> if __name__ == "__main__":
        ...     main()
    """
    # Configure logging for the whole application
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    )

    # 1. Qt Application
    app = QApplication(sys.argv)
    app.setApplicationName("MangoDefend - RMAV Desktop")
    app.setOrganizationName("MangoDefend")
    
    # Set application icon jika ada
    icon_path = os.path.join(os.path.dirname(__file__), "assets", "mango_icon.png")
    if os.path.exists(icon_path):
        app.setWindowIcon(QIcon(icon_path))

    # 2. Configuration
    config = get_config()
    
    # 3. Embedded Backend Server
    embedded_backend = None
    if config.get_bool('Backend', 'use_embedded', True):
        try:
            embedded_backend = EmbeddedBackend(host="127.0.0.1", port=8000)
            if embedded_backend.start():
                logger.info("Embedded backend started at http://127.0.0.1:8000")
                config.set('Backend', 'url', 'http://127.0.0.1:8000')
            else:
                logger.warning("Failed to start embedded backend — running in offline mode")
                config.set('Sync', 'enabled', 'false')
        except Exception as e:
            logger.error("Embedded backend error: %s", e)
            config.set('Sync', 'enabled', 'false')
    
    # 4. Sync Manager
    sync_manager = None
    if config.is_sync_enabled():
        try:
            sync_manager = SyncManager(
                backend_url=config.get_backend_url(),
                sync_interval=config.get_sync_interval(),
                batch_size=config.get_sync_batch_size()
            )
            if config.is_auto_sync():
                sync_manager.start()
                logger.info("Sync manager started (backend: %s)", config.get_backend_url())
        except Exception as e:
            logger.error("Failed to start sync manager: %s", e)
    
    # 5. Real-time Protection
    # Always instantiate so the UI toggle can start/stop it.
    # Only auto-start if 'enabled = true' in config.
    realtime_protection = None
    try:
        scan_delay = config.get_int('RealtimeProtection', 'scan_delay', 5)
        max_queue = config.get_int('RealtimeProtection', 'max_queue_size', 100)

        realtime_protection = RealtimeProtection(
            scan_delay=scan_delay,
            max_queue_size=max_queue,
            on_malware_detected=on_malware_detected
        )

        whitelist_ext = config.get('RealtimeProtection', 'whitelist_extensions', '.txt,.log,.md')
        for ext in whitelist_ext.split(','):
            realtime_protection.whitelist_extensions.add(ext.strip())

        if config.get_bool('RealtimeProtection', 'enabled', False):
            realtime_protection.start()
            logger.info("Real-time protection auto-started (enabled in config)")
        else:
            logger.info("Real-time protection ready (disabled in config, can be toggled from UI)")

    except Exception as e:
        logger.error("Failed to initialize real-time protection: %s", e)
    
    # 6. Model Updater
    model_updater = None
    if config.get_bool('ModelUpdate', 'enabled', True):
        try:
            model_api_url = config.get('ModelUpdate', 'model_api_url', 'http://localhost:8000')
            model_updater = ModelUpdater(backend_url=model_api_url)
            logger.info("Model updater initialized")
        except Exception as e:
            logger.error("Failed to initialize model updater: %s", e)

    # 7. Main Window
    window = ModernWindow()
    
    # Pass managers ke window agar bisa dikontrol dari UI
    if sync_manager:
        window.sync_manager = sync_manager
    # Always pass realtime_protection so the UI toggle can control it
    if realtime_protection:
        window.realtime_protection = realtime_protection
        realtime_protection.malware_bridge = window.malware_bridge
    if model_updater:
        window.model_updater = model_updater
    
    # Set window icon
    if os.path.exists(icon_path):
        window.setWindowIcon(QIcon(icon_path))
    
    # Tampilkan window
    window.show()

    # 8. Event loop
    exit_code = app.exec()

    # 9. Shutdown
    logger.info("Shutting down services...")

    if embedded_backend:
        logger.info("Stopping embedded backend...")
        embedded_backend.stop()

    if sync_manager:
        logger.info("Stopping sync manager...")
        sync_manager.stop()

    if realtime_protection:
        logger.info("Stopping real-time protection...")
        realtime_protection.stop()

    sys.exit(exit_code)


if __name__ == "__main__":
    main()

