"""
Protection View - Real-time Protection Control
Modern UI with live stats, animated toggle, and protection feature cards
"""
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QFrame, QPushButton, QScrollArea, QGridLayout, QSizePolicy
)
from PySide6.QtCore import Qt, Signal, QTimer
from ui.widgets.glass_card import GlassCard
from ui.styles.figma_theme import Colors, Typography, StyleHelper, Sizes


class ProtectionView(QWidget):
    """
    Real-time protection control view with modern design.
    
    Features:
    - Animated status header with shield icon
    - Live statistics (files scanned, threats blocked, etc.)
    - Protection feature cards with status indicators
    - ON/OFF toggle button
    
    Signals:
        protection_toggled(bool): Emitted when protection is toggled
    """
    
    protection_toggled = Signal(bool)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.is_dark = True
        self.protection_enabled = False
        
        # Stats timer for live updates
        self._stats_timer = QTimer(self)
        self._stats_timer.timeout.connect(self._update_live_stats)
        self._stats_timer.setInterval(2000)  # Update every 2s
        
        self.setup_ui()
    
    def setup_ui(self):
        """Build protection view UI"""
        # Scroll area for content
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
        
        # ===== STATUS HEADER CARD =====
        self.status_card = GlassCard()
        status_layout = QVBoxLayout(self.status_card)
        status_layout.setContentsMargins(40, 36, 40, 36)
        status_layout.setSpacing(16)
        status_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Shield icon with glow
        self.shield_container = QFrame()
        self.shield_container.setFixedSize(100, 100)
        self.shield_container.setStyleSheet("""
            QFrame {
                background: qradialgradient(cx:0.5, cy:0.5, radius:0.5,
                    stop:0 rgba(255, 107, 53, 0.3),
                    stop:1 rgba(255, 107, 53, 0.0));
                border-radius: 50px;
            }
        """)
        shield_icon_layout = QVBoxLayout(self.shield_container)
        shield_icon_layout.setContentsMargins(0, 0, 0, 0)
        self.shield_icon = QLabel("")
        self.shield_icon.setStyleSheet("font-size: 56px; background: transparent;")
        self.shield_icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        shield_icon_layout.addWidget(self.shield_icon)
        
        shield_row = QHBoxLayout()
        shield_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        shield_row.addWidget(self.shield_container)
        status_layout.addLayout(shield_row)
        
        # Title
        title = QLabel("Real-time Protection")
        title.setStyleSheet(f"""
            color: white;
            font-size: 28px;
            font-weight: bold;
            font-family: {Typography.FONT_FAMILY};
            background: transparent;
        """)
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        status_layout.addWidget(title)
        
        # Status badge
        self.status_badge = QFrame()
        self.status_badge.setFixedHeight(32)
        badge_layout = QHBoxLayout(self.status_badge)
        badge_layout.setContentsMargins(16, 0, 16, 0)
        badge_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        
        self.status_label = QLabel("TIDAK AKTIF")
        self.status_label.setStyleSheet(f"""
            color: {Colors.RED_500};
            font-size: 12px;
            font-weight: 700;
            letter-spacing: 1.5px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        badge_layout.addWidget(self.status_label)
        
        self.status_badge.setStyleSheet(f"""
            QFrame {{
                background: rgba(255, 107, 53, 0.15);
                border: none;
                border-radius: 16px;
            }}
        """)
        
        badge_row = QHBoxLayout()
        badge_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        badge_row.addWidget(self.status_badge)
        status_layout.addLayout(badge_row)
        
        # Description
        desc = QLabel("Memantau dan melindungi sistem Anda secara real-time\ndari ancaman malware menggunakan AI")
        desc.setWordWrap(True)
        desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 13px;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        status_layout.addWidget(desc)
        
        status_layout.addSpacing(8)
        
        # Toggle Button
        self.toggle_btn = QPushButton("Aktifkan Perlindungan")
        self.toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.toggle_btn.setFixedWidth(260)
        self.toggle_btn.setFixedHeight(52)
        self.toggle_btn.setStyleSheet(StyleHelper.pill_button_primary(Sizes.BTN_HEIGHT_LG))
        self.toggle_btn.clicked.connect(self._toggle_protection)
        
        btn_row = QHBoxLayout()
        btn_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        btn_row.addWidget(self.toggle_btn)
        status_layout.addLayout(btn_row)
        
        layout.addWidget(self.status_card)
        
        # ===== LIVE STATS SECTION =====
        stats_header = QLabel("Statistik Real-time")
        stats_header.setStyleSheet(StyleHelper.section_header())
        layout.addWidget(stats_header)
        
        stats_grid = QGridLayout()
        stats_grid.setSpacing(16)
        
        self.stat_scanned = self._create_stat_card("0", "File Discan", Colors.ORANGE_500)
        self.stat_threats = self._create_stat_card("0", "Ancaman Diblokir", Colors.RED_500)
        self.stat_quarantine = self._create_stat_card("0", "Dikarantina",  "#8B5CF6")
        self.stat_processes = self._create_stat_card("0", "Proses Dipantau", Colors.EMERALD_500)
        
        stats_grid.addWidget(self.stat_scanned["card"], 0, 0)
        stats_grid.addWidget(self.stat_threats["card"], 0, 1)
        stats_grid.addWidget(self.stat_quarantine["card"], 1, 0)
        stats_grid.addWidget(self.stat_processes["card"], 1, 1)
        
        layout.addLayout(stats_grid)
        
        # ===== PROTECTION LAYERS SECTION =====
        layers_header = QLabel("Lapisan Perlindungan")
        layers_header.setStyleSheet(StyleHelper.section_header())
        layout.addWidget(layers_header)
        
        layers = [
            ("", "Layer 1 — File Monitor",
             "Memantau file baru di Downloads, Desktop, Documents. "
             "File langsung dikunci dan discan sebelum bisa dibuka.",
             "Pseudo-Blocking"),
            ("", "Layer 2 — Process Guard",
             "Memantau setiap program yang dijalankan. "
             "Proses di-suspend dan discan sebelum diizinkan berjalan.",
             "Scan-on-Execute"),
            ("", "Layer 3 — Click Shield",
             "Memindai file yang dibuka pengguna, termasuk file lama. "
             "Mendeteksi malware dari argument command-line proses.",
             "Scan-on-Click"),
        ]
        
        for icon, title, desc, badge_text in layers:
            layer_card = self._create_layer_card(icon, title, desc, badge_text)
            layout.addWidget(layer_card)
        
        layout.addStretch()
        
        scroll.setWidget(scroll_content)
        
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)
    
    def _create_stat_card(self, value: str, label: str, accent_color: str) -> dict:
        """Create a statistics card with value, label, and accent color."""
        card = GlassCard()
        card.setMinimumHeight(100)
        
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(20, 18, 20, 18)
        card_layout.setSpacing(8)
        
        # Top row: icon + value
        top_row = QHBoxLayout()
        top_row.setSpacing(12)
        
        icon_frame = QFrame()
        icon_frame.setFixedSize(40, 40)
        icon_frame.setStyleSheet(f"""
            QFrame {{
                background: {accent_color}20;
                border-radius: 10px;
            }}
        """)

        value_label = QLabel(value)
        value_label.setStyleSheet(f"""
            color: {accent_color};
            font-size: 32px;
            font-weight: bold;
            font-family: {Typography.FONT_FAMILY};
            background: transparent;
        """)
        top_row.addWidget(value_label)
        top_row.addStretch()
        
        card_layout.addLayout(top_row)
        
        # Label
        label_widget = QLabel(label)
        label_widget.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 12px;
            font-weight: 600;
            font-family: {Typography.FONT_FAMILY};
            background: transparent;
        """)
        card_layout.addWidget(label_widget)
        
        return {"card": card, "value": value_label}
    
    def _create_layer_card(self, icon: str, title: str, desc: str, badge_text: str) -> GlassCard:
        """Create a protection layer card with icon, title, description, and badge."""
        card = GlassCard()
        
        card_layout = QHBoxLayout(card)
        card_layout.setContentsMargins(24, 20, 24, 20)
        card_layout.setSpacing(16)
        
        # Icon
        icon_label = QLabel(icon)
        icon_label.setStyleSheet("font-size: 32px; background: transparent;")
        icon_label.setFixedWidth(40)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignHCenter)
        card_layout.addWidget(icon_label)
        
        # Text content
        text_container = QWidget()
        text_container.setStyleSheet("background: transparent;")
        text_layout = QVBoxLayout(text_container)
        text_layout.setContentsMargins(0, 0, 0, 0)
        text_layout.setSpacing(6)
        
        # Title row with badge
        title_row = QHBoxLayout()
        title_row.setSpacing(10)
        
        title_label = QLabel(title)
        title_label.setStyleSheet(f"""
            color: white;
            font-size: 15px;
            font-weight: 700;
            font-family: {Typography.FONT_FAMILY};
            background: transparent;
        """)
        title_row.addWidget(title_label)
        
        badge = QLabel(badge_text)
        badge.setStyleSheet(StyleHelper.tag_badge())
        title_row.addWidget(badge)
        title_row.addStretch()
        
        text_layout.addLayout(title_row)
        
        desc_label = QLabel(desc)
        desc_label.setWordWrap(True)
        desc_label.setSizePolicy(
        QSizePolicy.Policy.Expanding,
        QSizePolicy.Policy.Preferred
         )
        desc_label.setStyleSheet(f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: 12px;
            line-height: 1.4;
            font-family: {Typography.FONT_FAMILY};
            background: transparent;
        """)
        text_layout.addWidget(desc_label)
        
        card_layout.addWidget(text_container, 1)
        
        return card
    
    def _toggle_protection(self):
        """Toggle protection on/off"""
        self.protection_enabled = not self.protection_enabled
        self._update_ui_state()
        self.protection_toggled.emit(self.protection_enabled)
    
    def _update_ui_state(self):
        """Update UI based on protection state"""
        if self.protection_enabled:
            # ON state
            self.status_label.setText("On")
            self.status_label.setStyleSheet(f"""
                color: {Colors.GREEN_500};
                font-size: 12px;
                font-weight: 700;
                letter-spacing: 1.5px;
                background: transparent;
                font-family: {Typography.FONT_FAMILY};
            """)
            self.status_badge.setStyleSheet(f"""
                QFrame {{
                    background: rgba(50, 205, 50, 0.12);
                    border: none;
                    border-radius: 16px;
                }}
            """)
            
            self.toggle_btn.setText("Nonaktifkan Perlindungan")
            self.toggle_btn.setStyleSheet(StyleHelper.pill_button_danger(Sizes.BTN_HEIGHT_LG))
            
            # Start live stats timer
            self._stats_timer.start()
        else:
            # OFF state
            self.shield_icon.setText("")
            self.shield_container.setStyleSheet("""
                QFrame {
                    background: qradialgradient(cx:0.5, cy:0.5, radius:0.5,
                        stop:0 rgba(255, 107, 53, 0.3),
                        stop:1 rgba(255, 107, 53, 0.0));
                    border-radius: 50px;
                }
            """)
            
            self.status_label.setText("TIDAK AKTIF")
            self.status_label.setStyleSheet(f"""
                color: {Colors.RED_500};
                font-size: 12px;
                font-weight: 700;
                letter-spacing: 1.5px;
                background: transparent;
                font-family: {Typography.FONT_FAMILY};
            """)
            self.status_badge.setStyleSheet(f"""
                QFrame {{
                    background: rgba(255, 107, 53, 0.15);
                    border: none;
                    border-radius: 16px;
                }}
            """)
            
            self.toggle_btn.setText("Aktifkan Perlindungan")
            self.toggle_btn.setStyleSheet(StyleHelper.pill_button_primary(Sizes.BTN_HEIGHT_LG))
            
            # Stop live stats timer
            self._stats_timer.stop()
    
    def _update_live_stats(self):
        """Pull latest stats from realtime_protection and update UI."""
        # Access parent's realtime_protection if available
        window = self.window()
        rp = getattr(window, 'realtime_protection', None)
        if rp and hasattr(rp, 'stats'):
            stats = rp.stats
            self.stat_scanned["value"].setText(str(stats.get("files_scanned", 0)))
            self.stat_threats["value"].setText(str(stats.get("malware_detected", 0)))
            self.stat_quarantine["value"].setText(str(stats.get("files_quarantined", 0)))
            self.stat_processes["value"].setText(str(stats.get("processes_suspended", 0)))
    
    def set_protection_state(self, enabled: bool):
        """Set protection state programmatically"""
        self.protection_enabled = enabled
        self._update_ui_state()
    
    def set_theme(self, is_dark: bool):
        """Update theme"""
        self.is_dark = is_dark
