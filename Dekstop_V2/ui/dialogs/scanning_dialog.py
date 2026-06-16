"""
Scanning Dialog
Overlay dialog untuk menampilkan progress scanning
"""
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, 
    QPushButton, QProgressBar, QFrame
)
from PySide6.QtCore import Qt
from PySide6.QtGui import QFont
from ui.components.spinner import AnimatedSpinner


class ScanningDialog(QWidget):
    """Scanning overlay with mango theme"""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("scanningOverlay")
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self._cancel_callback = None
        self.setup_ui()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # Card container
        card = QFrame()
        card.setObjectName("spinnerContainer")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(40, 40, 40, 40)
        card_layout.setSpacing(20)
        card_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # Animated spinner
        self.spinner = AnimatedSpinner()
        card_layout.addWidget(self.spinner, alignment=Qt.AlignmentFlag.AlignCenter)

        # Title
        self.title_label = QLabel("Memindai File")
        self.title_label.setObjectName("spinnerTitle")
        self.title_label.setFont(QFont("Arial", 20, QFont.Weight.Bold))
        self.title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.addWidget(self.title_label)

        # Status
        self.status_label = QLabel("Menyiapkan...")
        self.status_label.setObjectName("statusText")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status_label.setWordWrap(True)
        card_layout.addWidget(self.status_label)

        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.progress_bar.setTextVisible(True)
        self.progress_bar.setFixedHeight(24)
        card_layout.addWidget(self.progress_bar)

        # Cancel button
        self.cancel_btn = QPushButton("Batalkan")
        self.cancel_btn.setObjectName("cancelScanButton")
        self.cancel_btn.clicked.connect(self._handle_cancel)
        btn_layout = QHBoxLayout()
        btn_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        btn_layout.addWidget(self.cancel_btn)
        card_layout.addLayout(btn_layout)

        layout.addWidget(card)

        self.apply_style()

    def apply_style(self, is_dark=False):
        if is_dark:
            self.setStyleSheet("""
                QWidget#scanningOverlay {
                    background: rgba(0, 0, 0, 180);
                }
                QFrame#spinnerContainer {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                        stop:0 #252525, stop:0.5 #1F1F1F, stop:1 #1A1A1A);
                    border: 4px solid #FFA500;
                    border-radius: 35px;
                    padding: 10px;
                }
                QLabel#spinnerTitle {
                    color: #FFA500;
                    font-weight: 700;
                    font-size: 22px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }
                QLabel#statusText {
                    color: #CCCCCC;
                    font-size: 15px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }
                QProgressBar {
                    border: 3px solid #FFA500;
                    border-radius: 14px;
                    color: #FFA500;
                    text-align: center;
                    font-weight: 600;
                    font-size: 13px;
                    background: rgba(30, 30, 30, 0.8);
                }
                QProgressBar::chunk {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                        stop:0 #FFA500, stop:0.5 #FF8C00, stop:1 #FF7F00);
                    border-radius: 11px;
                }
                QPushButton#cancelScanButton {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #FF6B35, stop:1 #E64A19);
                    color: white;
                    border: 2px solid #FF8C00;
                    padding: 12px 28px;
                    border-radius: 22px;
                    font-weight: 600;
                    font-size: 14px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }
                QPushButton#cancelScanButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #E64A19, stop:1 #D84315);
                    border: 2px solid #FFA500;
                }
            """)
        else:
            self.setStyleSheet("""
                QWidget#scanningOverlay {
                    background: rgba(0, 0, 0, 150);
                }
                QFrame#spinnerContainer {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
                        stop:0 #FFFFFF, stop:0.5 #FFF5E6, stop:1 #FFE4B5);
                    border: 4px solid #FF8C00;
                    border-radius: 35px;
                    padding: 10px;
                }
                QLabel#spinnerTitle {
                    color: #2C2C2C;
                    font-weight: 700;
                    font-size: 22px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }
                QLabel#statusText {
                    color: #444444;
                    font-size: 15px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }
                QProgressBar {
                    border: 3px solid #FF8C00;
                    border-radius: 14px;
                    color: #2C2C2C;
                    text-align: center;
                    font-weight: 600;
                    font-size: 13px;
                    background: rgba(255, 255, 255, 0.8);
                }
                QProgressBar::chunk {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                        stop:0 #FFA500, stop:0.5 #FF8C00, stop:1 #FF7F00);
                    border-radius: 11px;
                }
                QPushButton#cancelScanButton {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #FF6B35, stop:1 #E64A19);
                    color: white;
                    border: 2px solid #FF8C00;
                    padding: 12px 28px;
                    border-radius: 22px;
                    font-weight: 600;
                    font-size: 14px;
                    font-family: 'Segoe UI', Arial, sans-serif;
                }
                QPushButton#cancelScanButton:hover {
                    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                        stop:0 #E64A19, stop:1 #D84315);
                    border: 2px solid #FFA500;
                }
            """)

    def set_cancel_callback(self, callback):
        self._cancel_callback = callback

    def _handle_cancel(self):
        if self._cancel_callback:
            self._cancel_callback()

    def update_progress(self, value, message):
        self.progress_bar.setValue(value)
        self.status_label.setText(message)

    def start(self):
        if self.parent():
            self.setGeometry(self.parent().rect())
        self.show()
        self.raise_()

    def finish(self):
        self.hide()
