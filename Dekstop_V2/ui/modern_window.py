"""
RMAV Desktop - MangoDefend Modern UI
Main window with Figma-inspired design and sidebar navigation
"""
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QHBoxLayout, QStackedWidget
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QIcon
import os
from datetime import datetime

# Import new components
from ui.components import (
    Sidebar, DashboardView, ScanView,
    ProtectionView, UpdateView
)

# Import existing dialogs (preserved from old window)
from ui.dialogs import ScanningDialog, ResultDialog
from ui.dialogs.malware_alert import MalwareAlertDialog, MalwareAlertBridge

# Import theme system
from ui.styles.figma_theme import get_theme_stylesheet

# Import existing thread and scanner
from ui.threads import ScanThread, BatchScanThread


class ModernWindow(QMainWindow):
    """
    Main application window with Figma-inspired UI.
    
    Features:
    - Modern sidebar navigation
    - 4 tab views (Dashboard, Scan, Protection, Update)
    - Dark/Light theme support
    - Glassmorphism effects
    - Integration with existing scan/protection functionality
    """
    
    def __init__(self):
        super().__init__()
        
        # State
        self.is_dark_mode = True
        self.current_tab = "dashboard"
        self.threats_detected = 0
        self.last_scan = datetime.now()
        
        # Scan state
        self.scan_worker = None
        self.scan_dialog = None
        self.result_dialog = None
        
        # Manager references (set from main.py)
        self.sync_manager = None
        self.realtime_protection = None
        self.model_updater = None
        
        # Malware alert bridge (thread-safe: background → UI)
        self.malware_bridge = MalwareAlertBridge()
        self.malware_bridge.malware_detected.connect(self._on_malware_alert)
        
        self.init_ui()
        self.apply_theme()
    
    def init_ui(self):
        """Initialize UI components"""
        self.setWindowTitle("MangoDefend - AI Malware Protection")
        self.setGeometry(100, 100, 1400, 900)
        self.setMinimumSize(1200, 800)
        
        # Main container
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QHBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # ===== SIDEBAR =====
        self.sidebar = Sidebar()
        self.sidebar.tab_changed.connect(self._on_tab_changed)
        self.sidebar.theme_toggled.connect(self._on_theme_toggled)
        main_layout.addWidget(self.sidebar)
        
        # ===== CONTENT AREA (Stacked Widget for tab switching) =====
        self.content_stack = QStackedWidget()
        
        # Create all tab views
        self.dashboard_view = DashboardView()
        self.scan_view = ScanView()
        self.protection_view = ProtectionView()
        self.update_view = UpdateView()
        
        # Add views to stack
        self.content_stack.addWidget(self.dashboard_view)  # index 0
        self.content_stack.addWidget(self.scan_view)       # index 1
        self.content_stack.addWidget(self.protection_view) # index 2
        self.content_stack.addWidget(self.update_view)     # index 3
        
        # Connect view signals
        self._connect_view_signals()
        
        main_layout.addWidget(self.content_stack, 1)
        
        # Set default view
        self.content_stack.setCurrentIndex(0)
    
    def _connect_view_signals(self):
        """Connect signals from all views"""
        # Scan view
        self.scan_view.scan_requested.connect(self.run_scanner)
        self.scan_view.folder_scan_requested.connect(self._run_folder_scan)
        self.scan_view.device_scan_requested.connect(self._run_device_scan)
        
        # Protection view
        self.protection_view.protection_toggled.connect(self._toggle_realtime_protection)
        
        # Update view
        self.update_view.check_update_requested.connect(self._check_for_updates)
        self.update_view.download_update_requested.connect(self._download_update)
    
    def _on_tab_changed(self, tab_id: str):
        """Handle tab navigation"""
        self.current_tab = tab_id
        
        # Map tab_id to stack index
        tab_map = {
            "dashboard": 0,
            "scan": 1,
            "protection": 2,
            "update": 3
        }
        
        if tab_id in tab_map:
            self.content_stack.setCurrentIndex(tab_map[tab_id])
    
    def _on_theme_toggled(self, is_dark: bool):
        """Handle theme toggle"""
        self.is_dark_mode = is_dark
        self.apply_theme()
    
    def apply_theme(self):
        """Apply current theme to entire application"""
        stylesheet = get_theme_stylesheet(self.is_dark_mode)
        self.setStyleSheet(stylesheet)
        
        # Update all views
        self.dashboard_view.set_theme(self.is_dark_mode)
        self.scan_view.set_theme(self.is_dark_mode)
        self.protection_view.set_theme(self.is_dark_mode)
        self.update_view.set_theme(self.is_dark_mode)
        
        # Update dialogs if they exist
        if self.scan_dialog:
            self.scan_dialog.apply_style(self.is_dark_mode)
    
    # =================================================================
    # SCAN FUNCTIONALITY (Preserved from old window)
    # =================================================================
    
    def run_scanner(self, file_path: str = None):
        """Start malware scan
        
        Args:
            file_path: Path to file to scan. If None, show file dialog.
        """
        if not file_path:
            from PySide6.QtWidgets import QFileDialog
            file_path, _ = QFileDialog.getOpenFileName(
                self, "Pilih File untuk Dipindai", "", "All Files (*.*)"
            )
        
        if not file_path:
            return
        
        # Show scanning dialog
        if not self.scan_dialog:
            self.scan_dialog = ScanningDialog(self)
            self.scan_dialog.set_cancel_callback(self._cancel_scan)
        
        self.scan_dialog.apply_style(self.is_dark_mode)
        self.scan_dialog.start()
        
        # Create and start scan thread
        self.scan_worker = ScanThread(file_path)
        self.scan_worker.progress.connect(self._on_scan_progress)
        self.scan_worker.finished.connect(self._on_scan_finished)
        self.scan_worker.error.connect(self._on_scan_error)
        self.scan_worker.start()
    
    def _on_scan_progress(self, value: int, message: str):
        """Update scan progress"""
        if self.scan_dialog:
            self.scan_dialog.update_progress(value, message)
    
    def _on_scan_finished(self, result: dict):
        """Handle scan completion"""
        if self.scan_dialog:
            self.scan_dialog.finish()
        
        # Update last scan time
        self.last_scan = datetime.now()
        self.dashboard_view.update_last_scan(self.last_scan)
        
        # Update threats count if malware detected
        if result.get('result') == 'Malware':
            self.threats_detected += 1
            self.sidebar.update_threats_count(self.threats_detected)
            self.dashboard_view.update_threats_count(self.threats_detected)
        
        # Add to scan history
        file_info = result.get('file', {})
        file_name = file_info.get('file_name', 'Unknown')
        file_path = file_info.get('file_path', '')
        scan_result = result.get('result', 'Unknown')
        timestamp = datetime.now().strftime("%H:%M")
        self.scan_view.add_to_history(file_name, scan_result, timestamp, file_path)
        
        # Show result dialog
        self.result_dialog = ResultDialog(result, self)
        self.result_dialog.show_dialog()
    
    def _on_scan_error(self, error_msg: str):
        """Handle scan error"""
        if self.scan_dialog:
            self.scan_dialog.finish()
        
        from PySide6.QtWidgets import QMessageBox
        QMessageBox.critical(self, "Scan Error", f"Terjadi kesalahan: {error_msg}")
    
    def _cancel_scan(self):
        """Cancel ongoing scan"""
        if self.scan_worker and self.scan_worker.isRunning():
            self.scan_worker.cancel()
            self.scan_worker.wait()
        
        if hasattr(self, 'batch_worker') and self.batch_worker and self.batch_worker.isRunning():
            self.batch_worker.cancel()
            self.batch_worker.wait()
        
        if self.scan_dialog:
            self.scan_dialog.finish()
    
    # =================================================================
    # FOLDER & DEVICE SCAN
    # =================================================================
    
    def _run_folder_scan(self, folder_path: str):
        """Start scanning all files in a folder."""
        if hasattr(self, 'batch_worker') and self.batch_worker and self.batch_worker.isRunning():
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.information(self, "Scan Berjalan", "Scan batch sedang berjalan. Tunggu hingga selesai.")
            return
        self._start_batch_scan(folder_path=folder_path)

    def _run_device_scan(self):
        """Start full device scan."""
        if hasattr(self, 'batch_worker') and self.batch_worker and self.batch_worker.isRunning():
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.information(self, "Scan Berjalan", "Scan batch sedang berjalan. Tunggu hingga selesai.")
            return
        from PySide6.QtWidgets import QMessageBox
        reply = QMessageBox.question(
            self, "Scan Seluruh Perangkat",
            "Scan akan memeriksa seluruh file berbahaya di perangkat Anda.\n"
            "Proses ini mungkin memakan waktu beberapa menit.\n\nLanjutkan?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._start_batch_scan(full_device=True)
    
    def _start_batch_scan(self, folder_path: str = None, full_device: bool = False):
        """Start batch scanning with progress dialog."""
        # Always create a fresh dialog to avoid stale state from previous scans
        self.scan_dialog = ScanningDialog(self)
        self.scan_dialog.set_cancel_callback(self._cancel_scan)
        self.scan_dialog.apply_style(self.is_dark_mode)
        if full_device:
            self.scan_dialog.title_label.setText("Scan Seluruh Perangkat")
            self.scan_dialog.status_label.setText("Mengumpulkan file berbahaya...")
        else:
            self.scan_dialog.title_label.setText("Scan Folder")
            self.scan_dialog.status_label.setText("Mengumpulkan file di folder...")
        self.scan_dialog.start()
        
        self.batch_worker = BatchScanThread(
            folder_path=folder_path,
            full_device=full_device
        )
        self.batch_worker.progress.connect(self._on_scan_progress)
        self.batch_worker.limit_reached.connect(self._on_batch_limit_reached)
        self.batch_worker.file_scanned.connect(self._on_batch_file_scanned)
        self.batch_worker.batch_finished.connect(self._on_batch_finished)
        self.batch_worker.error.connect(self._on_scan_error)
        self.batch_worker.start()

    def _on_batch_limit_reached(self, info: dict):
        """Ask user whether device scan should continue beyond the default file limit."""
        if not hasattr(self, 'batch_worker') or not self.batch_worker:
            return

        from PySide6.QtWidgets import QMessageBox

        limit = info.get('limit', 2000)
        file_count = info.get('file_count', limit)

        reply = QMessageBox.question(
            self,
            "Lanjutkan Scan Semua File?",
            "Batas aman scan perangkat telah tercapai.\n\n"
            f"File yang sudah terkumpul: {file_count}\n"
            f"Batas default: {limit} file\n\n"
            "Pilih 'Yes' untuk lanjut scan semua file yang ditemukan.\n"
            "Pilih 'No' untuk berhenti di batas default agar proses tetap lebih cepat.",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )

        self.batch_worker.set_limit_decision(
            reply == QMessageBox.StandardButton.Yes
        )
    
    def _on_batch_file_scanned(self, result: dict):
        """Handle individual malware detection during batch scan."""
        file_info = result.get('file', {})
        file_name = file_info.get('file_name', 'Unknown')
        file_path = file_info.get('file_path', '')
        scan_result = result.get('result', 'Unknown')
        timestamp = datetime.now().strftime('%H:%M')
        self.scan_view.add_to_history(file_name, scan_result, timestamp, file_path)
        
        if scan_result == 'Malware':
            self.threats_detected += 1
            self.sidebar.update_threats_count(self.threats_detected)
            self.dashboard_view.update_threats_count(self.threats_detected)
    
    def _on_batch_finished(self, summary: dict):
        """Handle batch scan completion."""
        if self.scan_dialog:
            self.scan_dialog.finish()
        
        self.last_scan = datetime.now()
        self.dashboard_view.update_last_scan(self.last_scan)
        
        # Show summary
        from PySide6.QtWidgets import QMessageBox
        total = summary.get('scanned', 0)
        malware = summary.get('malware', 0)
        clean = summary.get('clean', 0)
        errors = summary.get('errors', 0)

        msg = QMessageBox(self)
        msg.setWindowTitle("Hasil Scan")
        body = (
            f"Scan selesai!\n\n"
            f"Total file discan: {total}\n"
            f" Aman: {clean}\n"
            f" Malware: {malware}\n"
        )
        if summary.get('continued_beyond_limit'):
            body += " Mode: lanjut scan semua file setelah melewati batas default\n"
        if errors:
            body += f"Gagal discan: {errors} file\n"
        msg.setText(body)
        if malware > 0:
            msg.setInformativeText(
                f"{malware} file malware ditemukan.\n"
                "Apakah ingin mengkarantina semua file malware?"
            )
            msg.setStandardButtons(
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            msg.setDefaultButton(QMessageBox.StandardButton.Yes)
            msg.button(QMessageBox.StandardButton.Yes).setText("Karantina Semua")
            msg.button(QMessageBox.StandardButton.No).setText("Abaikan")
        msg.exec()

        if malware > 0 and msg.result() == QMessageBox.StandardButton.Yes:
            self._quarantine_batch_results(summary.get('results', []))

    def _quarantine_batch_results(self, malware_results: list):
        """Move all detected malware files to quarantine folder."""
        import shutil
        import time
        from pathlib import Path as _Path

        quarantine_dir = _Path.home() / ".Mangodefend" / "Karintina"
        quarantine_dir.mkdir(parents=True, exist_ok=True)

        success, failed = 0, 0
        for result in malware_results:
            file_path = result.get("file", {}).get("file_path", "")
            if not file_path or not _Path(file_path).exists():
                failed += 1
                continue
            try:
                src = _Path(file_path)
                dest = quarantine_dir / f"{int(time.time())}_{src.name}.quarantined"
                shutil.move(str(src), str(dest))
                success += 1
            except Exception:
                failed += 1

        from PySide6.QtWidgets import QMessageBox
        info = f"Karantina selesai!\n\n Berhasil: {success} file"
        if failed:
            info += f"\n Gagal: {failed} file"
        QMessageBox.information(self, "Karantina Selesai", info)

    # =================================================================
    # REALTIME PROTECTION
    # =================================================================

    def _toggle_realtime_protection(self, enabled: bool):
        """Toggle real-time protection on/off"""
        if self.realtime_protection:
            if enabled:
                try:
                    self.realtime_protection.start()
                    self.sidebar.update_status("Protected", True)
                except Exception as e:
                    print(f"Failed to start protection: {e}")
                    self.protection_view.set_protection_state(False)
            else:
                # Run stop() on a background thread — it joins worker threads
                # which could be blocked; calling from UI thread causes freeze.
                import threading as _threading
                def _do_stop():
                    try:
                        self.realtime_protection.stop()
                    except Exception as e:
                        print(f"Failed to stop protection: {e}")
                _threading.Thread(target=_do_stop, daemon=True, name="StopProtection").start()
                self.sidebar.update_status("Unprotected", False)
        else:
            self.protection_view.set_protection_state(False)
    
    def _on_malware_alert(self, alert_data: dict):
        """
        Handle malware detection from background thread (via Qt signal).
        Shows dialog and signals back the user's decision.
        """
        file_path = alert_data.get("file_path", "Unknown")
        scan_result = alert_data.get("scan_result", {})
        response_event = alert_data.get("response_event")  # threading.Event
        response_holder = alert_data.get("response_holder")  # list to store action

        file_name = os.path.basename(file_path) if file_path and file_path != "Unknown" else "Unknown"
        timestamp = datetime.now().strftime('%H:%M')
        self.scan_view.add_to_history(file_name, "Malware (Realtime)", timestamp, file_path)

        dialog = MalwareAlertDialog(file_path, scan_result, self)
        dialog.exec()

        action = dialog.get_action()

        # Send decision back to background thread
        if response_holder is not None:
            response_holder.append(action)
        if response_event is not None:
            response_event.set()

        # Update dashboard threat counter
        if action == MalwareAlertDialog.ACTION_KILL:
            self.threats_detected += 1
            self.dashboard_view.update_threats(self.threats_detected)
    
    # =================================================================
    # MODEL UPDATE
    # =================================================================
    
    def _check_for_updates(self):
        """Check for model updates"""
        if self.model_updater:
            try:
                # Check for updates
                has_update, latest_version = self.model_updater.check_for_updates()
                self.update_view.set_check_result(has_update, latest_version)
                
                if has_update:
                    print(f"Update available: {latest_version}")
                else:
                    print("Already up to date")
            except Exception as e:
                print(f"Failed to check updates: {e}")
                self.update_view.set_check_result(False)
        else:
            print("⚠ Model updater not available")
            self.update_view.set_check_result(False)
    
    def _download_update(self):
        """Download and install model update"""
        if self.model_updater:
            try:
                # Simulate download progress
                for progress in range(0, 101, 10):
                    self.update_view.set_download_progress(progress)
                    # In real implementation, this would be async
                    import time
                    time.sleep(0.1)
                
                print("Update installed successfully")
            except Exception as e:
                print(f"Failed to download update: {e}")
        else:
            print("Model updater not available")
    
    # =================================================================
    # INITIALIZATION FROM MAIN.PY
    # =================================================================
    
    def initialize_protection(self):
        """Initialize protection state from realtime_protection manager"""
        if self.realtime_protection:
            # Set protection view state
            is_enabled = self.realtime_protection.is_running()
            self.protection_view.set_protection_state(is_enabled)
            
            # Update sidebar status
            if is_enabled:
                self.sidebar.update_status("Protected", True)
            else:
                self.sidebar.update_status("Unprotected", False)
    
    def closeEvent(self, event):
        """Handle window close"""
        # Cancel any ongoing scans
        self._cancel_scan()
        
        # Accept close
        event.accept()
