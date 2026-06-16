"""
Update View - Model Update Center
Modern UI with version display, model info, and update history
"""
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QFrame, QPushButton, QProgressBar, QScrollArea, QGridLayout
)
from PySide6.QtCore import Qt, Signal
from ui.widgets.glass_card import GlassCard
from ui.styles.figma_theme import Colors, Typography, StyleHelper, Sizes
from datetime import datetime
import os
from pathlib import Path


class UpdateView(QWidget):
    """
    Model update center view with modern design.
    
    Features:
    - Current model version with model file info
    - Check for updates with progress
    - Update history with changelogs
    
    Signals:
        check_update_requested: Emitted when user clicks check for updates
        download_update_requested: Emitted when user clicks download
    """
    
    check_update_requested = Signal()
    download_update_requested = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.is_dark = True
        self.current_version = "v3.0"
        self.latest_version = "v3.0"
        self.is_checking = False
        self.is_downloading = False
        
        self.setup_ui()
    
    def setup_ui(self):
        """Build update view UI"""
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        
        scroll_content = QWidget()
        scroll_content.setStyleSheet("background: transparent;")
        layout = QVBoxLayout(scroll_content)
        layout.setContentsMargins(32, 24, 32, 32)
        layout.setSpacing(24)
        
        # ===== VERSION HEADER CARD =====
        version_card = self._create_version_card()
        layout.addWidget(version_card)
        
        # ===== MODEL INFO CARDS =====
        info_header = QLabel(" Informasi Model")
        info_header.setStyleSheet(StyleHelper.section_header())
        layout.addWidget(info_header)
        
        info_grid = QGridLayout()
        info_grid.setSpacing(16)
        
        # Get model info
        model_name, model_size = self._get_model_info()
        
        self.info_model = self._create_info_card("Model", model_name, Colors.ORANGE_500)
        self.info_size = self._create_info_card("Ukuran", model_size, Colors.EMERALD_500)
        self.info_engine = self._create_info_card("Engine", "ONNX Runtime", "#8B5CF6")
        self.info_status = self._create_info_card("Status", "Terbaru", Colors.GREEN_500)
        
        info_grid.addWidget(self.info_model, 0, 0)
        info_grid.addWidget(self.info_size, 0, 1)
        info_grid.addWidget(self.info_engine, 1, 0)
        info_grid.addWidget(self.info_status, 1, 1)
        
        layout.addLayout(info_grid)
        
        # ===== UPDATE CENTER CARD =====
        update_card = self._create_update_card()
        layout.addWidget(update_card)
        
        # ===== UPDATE HISTORY =====
        history_header = QLabel("Riwayat Pembaruan")
        history_header.setStyleSheet(StyleHelper.section_header())
        layout.addWidget(history_header)
        
        history_items = [
            ("v3.0", "Maret 2026", "ONNX Runtime", "Migrasi ke ONNX untuk performa lebih cepat dan ukuran lebih kecil"),
            ("v2.5", "Februari 2026", "Peningkatan Akurasi", "Perbaikan model dengan dataset lebih besar, akurasi naik 3%"),
            ("v2.0", "Januari 2026", "Full Device Scan", "Ditambahkan fitur scan seluruh perangkat dengan mode agresif"),
        ]
        
        for version, date, title, desc in history_items:
            history_card = self._create_history_item(version, date, title, desc)
            layout.addWidget(history_card)
        
        layout.addStretch()
        
        scroll.setWidget(scroll_content)
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)
    
    def _create_version_card(self) -> GlassCard:
        """Create version display card with large version number."""
        card = GlassCard()
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(40, 36, 40, 36)
        layout.setSpacing(16)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Icon with glow
        icon_frame = QFrame()
        icon_frame.setFixedSize(80, 80)
        icon_frame.setStyleSheet("""
            QFrame {
                background: qradialgradient(cx:0.5, cy:0.5, radius:0.5,
                    stop:0 rgba(255, 165, 0, 0.3),
                    stop:1 rgba(255, 165, 0, 0.0));
                border-radius: 40px;
            }
        """)
        
        # Label
        label = QLabel("Versi Model AI")
        label.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 13px;
            font-weight: 600;
            letter-spacing: 1px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(label)
        
        # Version number (solid color, no broken gradient text)
        self.version_display = QLabel(self.current_version)
        self.version_display.setStyleSheet(f"""
            color: {Colors.ORANGE_500};
            font-size: 48px;
            font-weight: bold;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        self.version_display.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.version_display)
        
        # Status badge
        self.version_status = QLabel("Model terbaru")
        self.version_status.setStyleSheet(StyleHelper.status_badge(Colors.GREEN_500))
        self.version_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        badge_row = QHBoxLayout()
        badge_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        badge_row.addWidget(self.version_status)
        layout.addLayout(badge_row)
        
        return card
    
    def _create_info_card(self, label: str, value: str, color: str) -> GlassCard:
        """Create a small info card with icon, label, and value."""
        card = GlassCard()
        card.setMinimumHeight(90)
        
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(20, 16, 20, 16)
        card_layout.setSpacing(6)
        
        # Top row: icon + label
        top_row = QHBoxLayout()
        top_row.setSpacing(8)
        
        label_lbl = QLabel(label)
        label_lbl.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.5px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        top_row.addWidget(label_lbl)
        top_row.addStretch()
        
        card_layout.addLayout(top_row)
        
        # Value
        value_lbl = QLabel(value)
        value_lbl.setStyleSheet(f"""
            color: {color};
            font-size: 16px;
            font-weight: 700;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        card_layout.addWidget(value_lbl)
        
        return card
    
    def _create_update_card(self) -> GlassCard:
        """Create update center card with check/download buttons."""
        card = GlassCard()
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(28, 24, 28, 24)
        layout.setSpacing(16)
        
        # Header row
        header_row = QHBoxLayout()
        header_row.setSpacing(10)
        
        header = QLabel("Pusat Pembaruan")
        header.setStyleSheet(f"""
            color: white;
            font-size: 18px;
            font-weight: bold;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        header_row.addWidget(header)
        header_row.addStretch()
        layout.addLayout(header_row)
        
        # Status message
        self.status_message = QLabel("Periksa apakah tersedia pembaruan model AI terbaru")
        self.status_message.setWordWrap(True)
        self.status_message.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 13px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        layout.addWidget(self.status_message)
        
        # Progress bar (hidden by default)
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.progress_bar.setTextVisible(True)
        self.progress_bar.setFixedHeight(28)
        self.progress_bar.hide()
        layout.addWidget(self.progress_bar)
        
        # Button row
        button_row = QHBoxLayout()
        button_row.setSpacing(12)
        button_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.check_btn = QPushButton("Periksa Pembaruan")
        self.check_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.check_btn.setFixedHeight(48)
        self.check_btn.setFixedWidth(220)
        self.check_btn.setStyleSheet(StyleHelper.pill_button_primary(Sizes.BTN_HEIGHT_MD))
        self.check_btn.clicked.connect(self._check_for_updates)
        button_row.addWidget(self.check_btn)
        
        self.download_btn = QPushButton("Unduh Pembaruan")
        self.download_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.download_btn.setFixedHeight(48)
        self.download_btn.setFixedWidth(220)
        self.download_btn.setStyleSheet(StyleHelper.pill_button_outline(Sizes.BTN_HEIGHT_MD))
        self.download_btn.clicked.connect(self._download_update)
        self.download_btn.hide()
        button_row.addWidget(self.download_btn)
        
        layout.addLayout(button_row)
        
        return card
    
    def _create_history_item(self, version: str, date: str, title: str, desc: str) -> GlassCard:
        """Create a history card with version, date, title, and description."""
        card = GlassCard()
        
        card_layout = QHBoxLayout(card)
        card_layout.setContentsMargins(24, 18, 24, 18)
        card_layout.setSpacing(16)
        
        # Version badge on the left
        ver_frame = QFrame()
        ver_frame.setFixedSize(56, 56)
        ver_frame.setStyleSheet(f"""
            QFrame {{
                background: rgba(255, 165, 0, 0.12);
                border: 1px solid rgba(255, 165, 0, 0.25);
                border-radius: 14px;
            }}
        """)
        ver_inner = QVBoxLayout(ver_frame)
        ver_inner.setContentsMargins(0, 0, 0, 0)
        ver_lbl = QLabel(version)
        ver_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        ver_lbl.setStyleSheet(f"""
            color: {Colors.ORANGE_400};
            font-size: 13px;
            font-weight: 700;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        ver_inner.addWidget(ver_lbl)
        card_layout.addWidget(ver_frame)
        
        # Text content
        text_widget = QWidget()
        text_widget.setStyleSheet("background: transparent;")
        text_layout = QVBoxLayout(text_widget)
        text_layout.setContentsMargins(0, 0, 0, 0)
        text_layout.setSpacing(4)
        
        # Title row
        title_row = QHBoxLayout()
        title_row.setSpacing(10)
        
        title_lbl = QLabel(title)
        title_lbl.setStyleSheet(f"""
            color: white;
            font-size: 14px;
            font-weight: 600;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        title_row.addWidget(title_lbl)
        
        date_lbl = QLabel(date)
        date_lbl.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 11px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        title_row.addWidget(date_lbl)
        title_row.addStretch()
        
        text_layout.addLayout(title_row)
        
        desc_lbl = QLabel(desc)
        desc_lbl.setWordWrap(True)
        desc_lbl.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 12px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        text_layout.addWidget(desc_lbl)
        
        card_layout.addWidget(text_widget, 1)
        
        return card
    
    def _get_model_info(self) -> tuple:
        """Get current model file info."""
        model_path = Path(__file__).resolve().parent.parent.parent / "models" / "Modelv3.onnx"
        if model_path.exists():
            size_mb = model_path.stat().st_size / (1024 * 1024)
            return "Modelv3.onnx", f"{size_mb:.1f} MB"
        return "Modelv3.onnx", "N/A"
    
    def _check_for_updates(self):
        """Check for available updates"""
        if not self.is_checking:
            self.is_checking = True
            self.check_btn.setEnabled(False)
            self.check_btn.setText(" Memeriksa...")
            self.status_message.setText("Memeriksa pembaruan yang tersedia...")
            self.check_update_requested.emit()
    
    def _download_update(self):
        """Start downloading update"""
        if not self.is_downloading:
            self.is_downloading = True
            self.download_btn.setEnabled(False)
            self.progress_bar.show()
            self.status_message.setText("Mengunduh pembaruan...")
            self.download_update_requested.emit()
    
    def set_check_result(self, has_update: bool, latest_version: str = None):
        """Display check result"""
        self.is_checking = False
        self.check_btn.setEnabled(True)
        self.check_btn.setText("Periksa Pembaruan")
        
        if has_update:
            self.latest_version = latest_version
            self.status_message.setText(f"Versi baru tersedia: {latest_version}")
            self.version_status.setText(f"⚠  Pembaruan tersedia → {latest_version}")
            self.version_status.setStyleSheet(StyleHelper.status_badge(Colors.ORANGE_500))
            self.download_btn.show()
            self.info_status.findChild(QLabel, "").setText("Tersedia Update")
        else:
            self.status_message.setText("Anda sudah menggunakan versi terbaru")
            self.download_btn.hide()
    
    def set_download_progress(self, progress: int):
        """Update download progress"""
        self.progress_bar.setValue(progress)
        
        if progress >= 100:
            self.is_downloading = False
            self.progress_bar.hide()
            self.status_message.setText("Pembaruan berhasil diinstal!")
            self.current_version = self.latest_version
            self.version_display.setText(self.current_version)
            self.version_status.setText("Model terbaru")
            self.version_status.setStyleSheet(StyleHelper.status_badge(Colors.GREEN_500))
            self.download_btn.hide()
            self.download_btn.setEnabled(True)
    
    def set_theme(self, is_dark: bool):
        """Update theme"""
        self.is_dark = is_dark
