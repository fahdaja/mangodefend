"""
Sidebar Navigation Component
Modern sidebar with logo, navigation, and controls
"""
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
    QLabel, QFrame, QButtonGroup
)
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QPixmap, QFont
from ui.styles.figma_theme import Colors
import os
import sys


def _asset(relative: str) -> str:
    """Resolve asset path for both dev and PyInstaller frozen mode."""
    if getattr(sys, 'frozen', False):
        base = sys._MEIPASS
    else:
        # sidebar.py lives in ui/components/ — go up 2 levels to app root
        base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(base, relative)


class Sidebar(QWidget):
    """
    Modern sidebar navigation matching Figma design.
    
    Features:
    - Logo section with branding
    - Protection status badge
    - 4 navigation tabs
    - Threats counter
    - Theme toggle
    
    Signals:
        tab_changed(str): Emitted when navigation tab is clicked
        theme_toggled(bool): Emitted when theme button is clicked
    """
    
    # Signals
    tab_changed = Signal(str)  # tab_id: 'dashboard', 'scan', 'protection', 'update'
    theme_toggled = Signal(bool)  # is_dark
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("sidebar")
        self.setFixedWidth(320)
        self.is_dark = True
        self.threats_count = 0
        
        self.setup_ui()
        
    def setup_ui(self):
        """Build sidebar UI"""
        layout = QVBoxLayout(self)
        layout.setContentsMargins(32, 32, 32, 32)
        layout.setSpacing(20)
        
        # ===== LOGO SECTION =====
        logo_section = self._create_logo_section()
        layout.addWidget(logo_section)
        
        layout.addSpacing(12)
        
        # ===== STATUS BADGE =====
        status_badge = self._create_status_badge()
        layout.addWidget(status_badge)
        
        layout.addSpacing(24)
        
        # ===== NAVIGATION BUTTONS =====
        nav_section = self._create_navigation()
        layout.addLayout(nav_section)
        
        layout.addStretch()
        
        # ===== BOTTOM SECTION =====
        bottom_section = self._create_bottom_section()
        layout.addLayout(bottom_section)
    
    def _create_logo_section(self) -> QWidget:
        """Create logo section"""
        container = QWidget()
        layout = QHBoxLayout(container)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(16)
        
        # Logo icon
        logo_label = QLabel()
        icon_path = _asset(os.path.join('assets', 'mango_icon.png'))
        if os.path.exists(icon_path):
            pixmap = QPixmap(icon_path)
            scaled = pixmap.scaled(64, 64, Qt.AspectRatioMode.KeepAspectRatio,
                                  Qt.TransformationMode.SmoothTransformation)
            logo_label.setPixmap(scaled)
        else:
            # Fallback emoji
            logo_label.setStyleSheet("font-size: 48px;")
        
        logo_label.setFixedSize(64, 64)
        layout.addWidget(logo_label)
        
        # Text section
        text_container = QWidget()
        text_layout = QVBoxLayout(text_container)
        text_layout.setContentsMargins(0, 0, 0, 0)
        text_layout.setSpacing(4)
        
        # Title
        title = QLabel("MANGO DEFEND")
        title.setObjectName("logoTitle")
        text_layout.addWidget(title)
        
        # Subtitle
        subtitle = QLabel("Mango Defends")
        subtitle.setObjectName("logoSubtitle")
        text_layout.addWidget(subtitle)
        
        layout.addWidget(text_container)
        
        return container
    
    def _create_status_badge(self) -> QFrame:
        """Create protection status badge"""
        badge = QFrame()
        badge.setObjectName("statusBadge")
        
        layout = QVBoxLayout(badge)
        layout.setContentsMargins(20, 16, 20, 16)
        layout.setSpacing(12)
        
        # Header row
        header_row = QHBoxLayout()
        header_row.setSpacing(12)
        
        # Text
        text_container = QWidget()
        text_layout = QVBoxLayout(text_container)
        text_layout.setContentsMargins(0, 0, 0, 0)
        text_layout.setSpacing(2)
        
        status_label = QLabel("System Status")
        status_label.setStyleSheet(f"color: {Colors.GREEN_500}; font-size: 11px; font-weight: 600;")
        text_layout.addWidget(status_label)
        
        self.status_text = QLabel("Unprotected")
        self.status_text.setStyleSheet(f"color: #FF6B35; font-size: 18px; font-weight: bold;")
        text_layout.addWidget(self.status_text)

        header_row.addWidget(text_container, 1)

        # Pulse indicator — saved as attribute so update_status() can change its color
        self.pulse_indicator = QLabel("●")
        self.pulse_indicator.setStyleSheet(f"color: #FF6B35; font-size: 12px;")
        header_row.addWidget(self.pulse_indicator)
        
        layout.addLayout(header_row)
        
        # Progress bar (visual only)
        progress_bg = QFrame()
        progress_bg.setFixedHeight(6)
        progress_bg.setStyleSheet(f"""
            background: rgba(0, 0, 0, 0.3);
            border-radius: 3px;
        """)
        
        progress_fill = QFrame(progress_bg)
        progress_fill.setGeometry(0, 0, int(badge.width() * 0.95), 6)
        progress_fill.setStyleSheet(f"""
            background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                stop:0 {Colors.GREEN_500}, stop:1 {Colors.EMERALD_500});
            border-radius: 3px;
        """)
        
        layout.addWidget(progress_bg)
        
        return badge
    
    def _create_navigation(self) -> QVBoxLayout:
        """Create navigation buttons"""
        layout = QVBoxLayout()
        layout.setSpacing(8)
        
        # Navigation items
        nav_items = [
            ("dashboard", "Dashboard"),
            ("scan", "Scan"),
            ("protection", "Protection"),
            ("update", "Update")
        ]
        
        # Button group for exclusive selection
        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)
        
        for tab_id, label in nav_items:
            btn = QPushButton(f"{label}")
            btn.setObjectName("navButton")
            btn.setCheckable(True)
            btn.setProperty("tab_id", tab_id)
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.setMinimumHeight(56)
            
            # Connect signal
            btn.clicked.connect(lambda checked, tid=tab_id: self.tab_changed.emit(tid))
            
            self.nav_group.addButton(btn)
            layout.addWidget(btn)
        
        # Set dashboard as default
        self.nav_group.buttons()[0].setChecked(True)
        
        return layout
    
    def _create_bottom_section(self) -> QVBoxLayout:
        """Create bottom section with stats and theme toggle"""
        layout = QVBoxLayout()
        layout.setSpacing(12)
        
        # Threats counter
        threats_card = QFrame()
        threats_card.setStyleSheet(f"""
            QFrame {{
                background: rgba(255, 255, 255, 0.05);
                border: 1px solid rgba(255, 255, 255, 0.1);
                border-radius: 16px;
                padding: 16px;
            }}
        """)
        
        threats_layout = QHBoxLayout(threats_card)
        threats_layout.setContentsMargins(12, 12, 12, 12)
        
        label = QLabel("Threats Blocked")
        label.setStyleSheet(f"color: {Colors.DARK_TEXT_SECONDARY}; font-size: 12px;")
        threats_layout.addWidget(label)
        
        threats_layout.addStretch()
        
        self.threats_label = QLabel("0")
        self.threats_label.setStyleSheet(f"""
            color: {Colors.ORANGE_400};
            font-size: 32px;
            font-weight: bold;
        """)
        threats_layout.addWidget(self.threats_label)
        
        layout.addWidget(threats_card)
        
        # Theme toggle button
        self.theme_btn = QPushButton(" Dark Mode")
        self.theme_btn.setObjectName("secondaryButton")
        self.theme_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.theme_btn.setMinimumHeight(48)
        self.theme_btn.clicked.connect(self._toggle_theme)
        layout.addWidget(self.theme_btn)
        
        return layout
    
    def _toggle_theme(self):
        """Toggle between dark and light theme"""
        self.is_dark = not self.is_dark
        
        if self.is_dark:
            self.theme_btn.setText(" Dark Mode")
        else:
            self.theme_btn.setText(" Light Mode")
        
        self.theme_toggled.emit(self.is_dark)
    
    def set_active_tab(self, tab_id: str):
        """Set active navigation tab programmatically"""
        for btn in self.nav_group.buttons():
            if btn.property("tab_id") == tab_id:
                btn.setChecked(True)
                break
    
    def update_threats_count(self, count: int):
        """Update threats blocked counter"""
        self.threats_count = count
        self.threats_label.setText(str(count))
    
    def update_status(self, status: str, is_protected: bool = True):
        """Update protection status

        Args:
            status: Status text to display
            is_protected: If True, show green; if False, show orange
        """
        self.status_text.setText(status)
        if is_protected:
            color = Colors.GREEN_500
        else:
            color = "#FF6B35"
        self.status_text.setStyleSheet(f"color: {color}; font-size: 18px; font-weight: bold;")
        self.pulse_indicator.setStyleSheet(f"color: {color}; font-size: 12px;")
