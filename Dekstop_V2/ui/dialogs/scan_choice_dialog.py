"""
Dialog untuk memilih jenis scanning: File atau Full Device
"""
from PySide6.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QPushButton, QLabel, QWidget
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont


class ScanChoiceDialog(QDialog):
    """Dialog untuk memilih antara file scanning atau full device scanning"""

    file_scan_selected = Signal()
    device_scan_selected = Signal()

    def __init__(self, parent=None, is_dark_mode=False):
        super().__init__(parent)
        self.is_dark_mode = is_dark_mode
        self.choice = None
        self.init_ui()
        self.apply_style(is_dark_mode)

    def init_ui(self):
        """Initialize UI"""
        self.setWindowTitle("Pilih Jenis Pemindaian")
        self.setModal(True)
        self.setFixedSize(500, 350)

        # Main layout
        layout = QVBoxLayout()
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(25)

        # Icon
        icon_label = QLabel("🔍")
        icon_label.setObjectName("dialogIcon")
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_label.setFixedHeight(80)
        layout.addWidget(icon_label)

        # Title
        title = QLabel("Pilih Jenis Pemindaian")
        title.setObjectName("dialogTitle")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)

        # Description
        desc = QLabel("Pilih apakah Anda ingin memindai file tertentu\natau melakukan pemindaian penuh pada device.")
        desc.setObjectName("dialogDesc")
        desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc.setWordWrap(True)
        layout.addWidget(desc)

        layout.addSpacing(10)

        # Buttons container
        buttons_widget = QWidget()
        buttons_layout = QVBoxLayout()
        buttons_layout.setSpacing(15)
        buttons_widget.setLayout(buttons_layout)

        # File scan button
        self.file_btn = QPushButton("📄 Pindai File")
        self.file_btn.setObjectName("choiceButton")
        self.file_btn.setFixedHeight(60)
        self.file_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.file_btn.clicked.connect(self.on_file_scan_clicked)
        buttons_layout.addWidget(self.file_btn)

        # Device scan button
        self.device_btn = QPushButton("💻 Pindai Full Device")
        self.device_btn.setObjectName("choiceButton")
        self.device_btn.setFixedHeight(60)
        self.device_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.device_btn.clicked.connect(self.on_device_scan_clicked)
        buttons_layout.addWidget(self.device_btn)

        layout.addWidget(buttons_widget)

        layout.addSpacing(5)

        # Cancel button
        cancel_btn = QPushButton("Batal")
        cancel_btn.setObjectName("cancelButton")
        cancel_btn.setFixedHeight(40)
        cancel_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        cancel_btn.clicked.connect(self.reject)
        layout.addWidget(cancel_btn)

        self.setLayout(layout)

    def on_file_scan_clicked(self):
        """Handle file scan selection"""
        self.choice = "file"
        self.file_scan_selected.emit()
        self.accept()

    def on_device_scan_clicked(self):
        """Handle device scan selection"""
        self.choice = "device"
        self.device_scan_selected.emit()
        self.accept()

    def get_choice(self):
        """Return the selected choice"""
        return self.choice

    def apply_style(self, is_dark_mode):
        """Apply theme based on dark mode setting"""
        self.is_dark_mode = is_dark_mode

        if is_dark_mode:
            self.setStyleSheet("""
                /* DARK MODE */
                QDialog {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                        stop:0 #1A1A1A, stop:1 #252525);
                    border: 2px solid #FFA500;
                    border-radius: 15px;
                }

                QLabel#dialogIcon {
                    font-size: 64px;
                    color: #FFA500;
                }

                QLabel#dialogTitle {
                    color: #FFFFFF;
                    font-size: 24px;
                    font-weight: bold;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }

                QLabel#dialogDesc {
                    color: #CCCCCC;
                    font-size: 14px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                    line-height: 1.6;
                }

                QPushButton#choiceButton {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 rgba(40, 40, 40, 0.95), stop:1 rgba(30, 30, 30, 0.95));
                    border: 3px solid #FFA500;
                    border-radius: 12px;
                    color: #FFA500;
                    font-size: 16px;
                    font-weight: 600;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }

                QPushButton#choiceButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #FFA500, stop:1 #FF8C00);
                    color: white;
                    border: 3px solid #FFB732;
                }

                QPushButton#choiceButton:pressed {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #FF8C00, stop:1 #FF7F00);
                }

                QPushButton#cancelButton {
                    background: transparent;
                    border: 2px solid #666666;
                    border-radius: 10px;
                    color: #999999;
                    font-size: 14px;
                    font-weight: 600;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }

                QPushButton#cancelButton:hover {
                    background: rgba(102, 102, 102, 0.2);
                    border: 2px solid #888888;
                    color: #CCCCCC;
                }
            """)
        else:
            self.setStyleSheet("""
                /* LIGHT MODE */
                QDialog {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                        stop:0 #FFFFFF, stop:1 #FFF5E6);
                    border: 2px solid #FF8C00;
                    border-radius: 15px;
                }

                QLabel#dialogIcon {
                    font-size: 64px;
                    color: #FF8C00;
                }

                QLabel#dialogTitle {
                    color: #2C2C2C;
                    font-size: 24px;
                    font-weight: bold;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }

                QLabel#dialogDesc {
                    color: #444444;
                    font-size: 14px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                    line-height: 1.6;
                }

                QPushButton#choiceButton {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 rgba(255, 255, 255, 0.95), stop:1 rgba(255, 250, 240, 0.95));
                    border: 3px solid #FF8C00;
                    border-radius: 12px;
                    color: #2C2C2C;
                    font-size: 16px;
                    font-weight: 600;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }

                QPushButton#choiceButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #FFA500, stop:1 #FF8C00);
                    color: white;
                    border: 3px solid #FFB732;
                }

                QPushButton#choiceButton:pressed {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #FF8C00, stop:1 #FF7F00);
                }

                QPushButton#cancelButton {
                    background: transparent;
                    border: 2px solid #CCCCCC;
                    border-radius: 10px;
                    color: #666666;
                    font-size: 14px;
                    font-weight: 600;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }

                QPushButton#cancelButton:hover {
                    background: rgba(0, 0, 0, 0.05);
                    border: 2px solid #999999;
                    color: #333333;
                }
            """)
