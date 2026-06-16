"""
Dashboard View - System Overview
Main dashboard showing protection status, stats, and activity
"""
import os
import re
import sys
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QFrame, QGridLayout, QScrollArea
)
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QPixmap
from ui.widgets.glass_card import GlassCard
from ui.styles.figma_theme import Colors, Typography
from datetime import datetime
import psutil


def _asset(relative: str) -> str:
    """Resolve asset path for both dev and PyInstaller frozen mode."""
    if getattr(sys, 'frozen', False):
        base = sys._MEIPASS
    else:
        # dashboard_view.py lives in ui/components/ — go up 2 levels to app root
        base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return os.path.join(base, relative)


_LOGO_PATH = _asset(os.path.join('assets', 'mango_icon.png'))


class DashboardView(QWidget):
    """
    Dashboard tab view with modern design.

    Displays:
    - Protection status with progress ring
    - Live stats (threats, scanned, last scan)
    - Resource usage (CPU, RAM)
    - Recent activity feed
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self.is_dark = True
        self.realtime_enabled = True
        self.last_scan = datetime.now()
        self.threats_detected = 0

        # Label registries — populated during setup_ui, updated by _apply_theme()
        self._primary_labels: list[QLabel] = []    # headings / big values
        self._secondary_labels: list[QLabel] = []  # sub-headings / card titles
        self._muted_labels: list[QLabel] = []      # timestamps / helper text
        self._resource_cards: list[QFrame] = []    # mini resource cards
        self._activity_items: list[QFrame] = []    # activity grid items
        self._progress_bar_bgs: list[QFrame] = []  # progress-bar track frames

        # Live resource update timer
        self._resource_timer = QTimer(self)
        self._resource_timer.timeout.connect(self._update_resources)
        self._resource_timer.setInterval(3000)
        self._resource_timer.start()

        self.setup_ui()

    # ------------------------------------------------------------------
    # THEME HELPERS
    # ------------------------------------------------------------------

    def _tp(self) -> str:
        """Primary text color."""
        return Colors.DARK_TEXT_PRIMARY if self.is_dark else Colors.LIGHT_TEXT_PRIMARY

    def _ts(self) -> str:
        """Secondary text color."""
        return Colors.DARK_TEXT_SECONDARY if self.is_dark else Colors.LIGHT_TEXT_SECONDARY

    def _tm(self) -> str:
        """Muted text color."""
        return Colors.DARK_TEXT_MUTED if self.is_dark else Colors.LIGHT_TEXT_MUTED

    def _card_bg(self) -> str:
        return "rgba(255, 255, 255, 0.05)" if self.is_dark else "rgba(0, 0, 0, 0.04)"

    def _card_border(self) -> str:
        return "rgba(255, 255, 255, 0.12)" if self.is_dark else "rgba(0, 0, 0, 0.10)"

    def _bar_track(self) -> str:
        return "rgba(0, 0, 0, 0.25)" if self.is_dark else "rgba(0, 0, 0, 0.10)"

    # Register helpers — store reference and return it so call sites stay one-liners
    def _reg_p(self, lbl: QLabel) -> QLabel:
        self._primary_labels.append(lbl)
        return lbl

    def _reg_s(self, lbl: QLabel) -> QLabel:
        self._secondary_labels.append(lbl)
        return lbl

    def _reg_m(self, lbl: QLabel) -> QLabel:
        self._muted_labels.append(lbl)
        return lbl
    
    def setup_ui(self):
        """Build dashboard UI."""
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        content = QWidget()
        content.setStyleSheet("background: transparent;")
        scroll.setWidget(content)

        layout = QVBoxLayout(content)
        layout.setContentsMargins(32, 24, 32, 32)
        layout.setSpacing(24)

        # Bento grid
        grid = QGridLayout()
        grid.setSpacing(24)
        grid.addWidget(self._create_about_card(), 0, 0, 2, 2)
        grid.addWidget(self._create_threats_card(),    0, 2, 1, 1)
        grid.addWidget(self._create_last_scan_card(),  1, 2, 1, 1)
        layout.addLayout(grid)

        # Resource cards row
        resource_row = QHBoxLayout()
        resource_row.setSpacing(12)
        self._resource_labels = {}

        for label_text, default_value in [
            ("CPU Usage", "2.3%"),
            ("Memory",    "128MB"),
            ("Database",  "342MB"),
        ]:
            res_card = QFrame()
            self._resource_cards.append(res_card)

            res_layout = QVBoxLayout(res_card)
            res_layout.setSpacing(4)

            name = self._reg_m(QLabel(label_text))
            name.setStyleSheet(f"color: {self._tm()}; font-size: 11px; background: transparent;")
            res_layout.addWidget(name)

            val = self._reg_p(QLabel(default_value))
            val.setStyleSheet(f"color: {self._tp()}; font-size: 16px; font-weight: bold; background: transparent;")
            res_layout.addWidget(val)

            self._resource_labels[label_text] = val
            resource_row.addWidget(res_card)

        layout.addLayout(resource_row)
        layout.addWidget(self._create_activity_section())
        layout.addStretch()

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)

        self._apply_theme()
        self._update_resources()
    
    def _create_about_card(self) -> GlassCard:
        """About MangoDefend card with app logo and info."""
        card = GlassCard()
        card.setMinimumHeight(420)

        layout = QVBoxLayout(card)
        # Top margin 32 (not 40) so the logo doesn’t get nipped by the 24px
        # corner-radius clip of GlassCard’s paintEvent.
        layout.setContentsMargins(40, 32, 40, 40)
        layout.setSpacing(0)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # ── Logo — give it a fixed container so it never touches the card edge ──
        logo_lbl = QLabel()
        logo_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        logo_lbl.setStyleSheet("background: transparent; padding-top: 8px;")
        pix = QPixmap(_LOGO_PATH)
        if not pix.isNull():
            logo_lbl.setPixmap(pix.scaled(100, 100, Qt.AspectRatioMode.KeepAspectRatio,
                                          Qt.TransformationMode.SmoothTransformation))
        else:
            logo_lbl.setText("🥭")
            logo_lbl.setStyleSheet("font-size: 72px; background: transparent;")
        layout.addWidget(logo_lbl)
        layout.addSpacing(18)

        # ── App name ──
        app_name = self._reg_p(QLabel("MangoDefend"))
        app_name.setAlignment(Qt.AlignmentFlag.AlignCenter)
        app_name.setStyleSheet(f"""
            color: {self._tp()};
            font-size: 28px;
            font-weight: bold;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        layout.addWidget(app_name)
        layout.addSpacing(6)

        # ── Tagline ──
        tagline = self._reg_m(QLabel("AI-Powered Malware Protection"))
        tagline.setAlignment(Qt.AlignmentFlag.AlignCenter)
        tagline.setStyleSheet(f"""
            color: {Colors.ORANGE_500};
            font-size: 13px;
            font-weight: 600;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """)
        layout.addWidget(tagline)
        layout.addSpacing(24)

        # ── Divider ──
        divider = QFrame()
        divider.setFixedHeight(1)
        divider.setStyleSheet("background: rgba(255,255,255,0.10); border: none;")
        layout.addWidget(divider)
        layout.addSpacing(20)

        # ── Info rows ──
        info_data = [
            ("Versi",      "1.0.0"),
            ("Model",      "MangoDefend CNN v3 (ONNX)"),
            ("Developer",  "MangoDefend Team"),
            ("Platform",   "Desktop · Windows"),
        ]
        for key, val in info_data:
            row = QHBoxLayout()
            row.setSpacing(0)

            key_lbl = self._reg_s(QLabel(key))
            key_lbl.setStyleSheet(f"""
                color: {self._ts()};
                font-size: 12px;
                background: transparent;
                font-family: {Typography.FONT_FAMILY};
            """)
            row.addWidget(key_lbl)
            row.addStretch()

            val_lbl = self._reg_p(QLabel(val))
            val_lbl.setStyleSheet(f"""
                color: {self._tp()};
                font-size: 12px;
                font-weight: 600;
                background: transparent;
                font-family: {Typography.FONT_FAMILY};
            """)
            val_lbl.setAlignment(Qt.AlignmentFlag.AlignRight)
            row.addWidget(val_lbl)
            layout.addLayout(row)
            layout.addSpacing(10)

        layout.addStretch()
        return card
    
    def _create_threats_card(self) -> GlassCard:
        """Threats blocked statistic card."""
        card = GlassCard()
        card.setMinimumHeight(200)

        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(12)

        lbl = self._reg_s(QLabel("Threats Blocked"))
        lbl.setStyleSheet(f"color: {self._ts()}; font-size: 13px; background: transparent;")
        layout.addWidget(lbl)

        self.threats_value = QLabel("0")
        self.threats_value.setStyleSheet(f"""
            color: {Colors.ORANGE_500};
            font-size: 42px;
            font-weight: bold;
            background: transparent;
        """)
        layout.addWidget(self.threats_value)

        rate = QLabel("100% success rate")
        rate.setStyleSheet(f"color: {Colors.GREEN_500}; font-size: 12px; background: transparent;")
        layout.addWidget(rate)

        layout.addStretch()
        return card
    
    def _create_last_scan_card(self) -> GlassCard:
        """Last scan timestamp card."""
        card = GlassCard()
        card.setMinimumHeight(190)

        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(12)

        lbl = self._reg_s(QLabel("Last Scan"))
        lbl.setStyleSheet(f"color: {self._ts()}; font-size: 13px; background: transparent;")
        layout.addWidget(lbl)

        self.last_scan_time = self._reg_p(QLabel(self.last_scan.strftime("%H:%M")))
        self.last_scan_time.setStyleSheet(f"color: {self._tp()}; font-size: 28px; font-weight: bold; background: transparent;")
        layout.addWidget(self.last_scan_time)

        status_badge = QFrame()
        status_badge.setStyleSheet("QFrame { background: rgba(50, 205, 50, 0.1); border: none; border-radius: 8px; }")
        status_row = QHBoxLayout(status_badge)
        status_row.setContentsMargins(8, 6, 8, 6)
        no_threat = QLabel("No threats found")
        no_threat.setStyleSheet(f"color: {Colors.GREEN_500}; font-size: 11px; font-weight: 600; background: transparent;")
        status_row.addWidget(no_threat)

        layout.addWidget(status_badge)
        layout.addStretch()
        return card
    
    def _create_activity_section(self) -> GlassCard:
        """Recent activity feed card."""
        card = GlassCard()

        layout = QVBoxLayout(card)
        layout.setContentsMargins(32, 24, 32, 24)
        layout.setSpacing(20)

        # Header
        header = QHBoxLayout()

        activity_title = self._reg_p(QLabel("Recent Activity"))
        activity_title.setStyleSheet(f"color: {self._tp()}; font-size: 20px; font-weight: bold; background: transparent;")
        header.addWidget(activity_title)
        header.addStretch()

        live_badge = QFrame()
        live_badge.setStyleSheet("QFrame { background: rgba(50, 205, 50, 0.1); border: none; border-radius: 12px; }")
        live_row = QHBoxLayout(live_badge)
        live_row.setContentsMargins(10, 4, 10, 4)
        live_text = QLabel("Live")
        live_text.setStyleSheet(f"color: {Colors.GREEN_500}; font-size: 11px; font-weight: bold; background: transparent;")
        live_row.addWidget(live_text)
        header.addWidget(live_badge)
        layout.addLayout(header)

        activities = [
            ("2 min ago",   "Real-time scan completed", Colors.GREEN_500),
            ("15 min ago",  "System scan finished",     Colors.GREEN_500),
            ("1 hour ago",  "Database updated",         Colors.ORANGE_500),
            ("3 hours ago", "Threat quarantined",       Colors.RED_500),
        ]

        activity_grid = QGridLayout()
        activity_grid.setSpacing(16)
        activity_grid.setColumnStretch(0, 1)
        activity_grid.setColumnStretch(1, 1)

        for idx, (time_text, action, _color) in enumerate(activities):
            item = QFrame()
            self._activity_items.append(item)

            item_layout = QHBoxLayout(item)
            item_layout.setSpacing(12)

            text_container = QWidget()
            text_container.setStyleSheet("background: transparent;")
            text_layout = QVBoxLayout(text_container)
            text_layout.setContentsMargins(0, 0, 0, 0)
            text_layout.setSpacing(4)

            action_label = self._reg_p(QLabel(action))
            action_label.setStyleSheet(f"color: {self._tp()}; font-size: 13px; font-weight: 600; background: transparent;")
            text_layout.addWidget(action_label)

            time_label = self._reg_m(QLabel(time_text))
            time_label.setStyleSheet(f"color: {self._tm()}; font-size: 11px; background: transparent;")
            text_layout.addWidget(time_label)

            item_layout.addWidget(text_container, 1)
            activity_grid.addWidget(item, idx // 2, idx % 2)

        layout.addLayout(activity_grid)
        return card

    # ------------------------------------------------------------------
    # THEME APPLICATION
    # ------------------------------------------------------------------

    def _apply_theme(self):
        """Apply current theme colors to all registered widgets."""
        tp = self._tp()
        ts = self._ts()
        tm = self._tm()
        card_bg     = self._card_bg()
        card_border = self._card_border()
        bar_track   = self._bar_track()

        for lbl in self._primary_labels:
            lbl.setStyleSheet(re.sub(r'color:\s*[^;]+;', f'color: {tp};', lbl.styleSheet(), count=1))

        for lbl in self._secondary_labels:
            lbl.setStyleSheet(re.sub(r'color:\s*[^;]+;', f'color: {ts};', lbl.styleSheet(), count=1))

        for lbl in self._muted_labels:
            lbl.setStyleSheet(re.sub(r'color:\s*[^;]+;', f'color: {tm};', lbl.styleSheet(), count=1))

        for frame in self._resource_cards:
            frame.setStyleSheet(f"""
                QFrame {{
                    background: {card_bg};
                    border: 1px solid {card_border};
                    border-radius: 12px;
                    padding: 12px;
                }}
            """)

        for frame in self._activity_items:
            frame.setStyleSheet(f"""
                QFrame {{
                    background: {card_bg};
                    border: 1px solid {card_border};
                    border-radius: 12px;
                    padding: 16px;
                }}
                QFrame:hover {{
                    border: 1px solid rgba(255, 165, 0, 0.3);
                }}
            """)

        for frame in self._progress_bar_bgs:
            frame.setStyleSheet(f"background: {bar_track}; border-radius: 4px;")
    
    def _update_resources(self):
        """Update live resource usage."""
        try:
            cpu = psutil.cpu_percent(interval=0)
            if "CPU Usage" in self._resource_labels:
                self._resource_labels["CPU Usage"].setText(f"{cpu:.1f}%")
            
            proc = psutil.Process()
            mem_mb = proc.memory_info().rss / (1024 * 1024)
            if "Memory" in self._resource_labels:
                self._resource_labels["Memory"].setText(f"{mem_mb:.0f}MB")
        except Exception:
            pass
    
    def update_threats(self, count: int):
        """Update threats detected counter"""
        self.threats_detected = count
        if hasattr(self, 'threats_value'):
            self.threats_value.setText(str(count))
    
    def update_threats_count(self, count: int):
        """Alias for update_threats"""
        self.update_threats(count)
    
    def update_last_scan(self, scan_time: datetime):
        """Update last scan timestamp"""
        self.last_scan = scan_time
        if hasattr(self, 'last_scan_time'):
            self.last_scan_time.setText(scan_time.strftime("%H:%M"))
    
    def set_theme(self, is_dark: bool):
        """Switch between dark and light mode."""
        self.is_dark = is_dark
        self._apply_theme()
