"""
Scan View - File, Folder, and Device Scanner Interface
Interface for scanning files, folders, or entire device for malware
"""
import os
import re
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QFrame, QPushButton, QFileDialog, QListWidget,
    QListWidgetItem, QScrollArea, QGridLayout, QApplication
)
from PySide6.QtCore import Qt, Signal, QEvent
from ui.widgets.glass_card import GlassCard
from ui.styles.figma_theme import Colors, Typography, StyleHelper


class _DropScrollArea(QScrollArea):
    """
    QScrollArea subclass with built-in drag-and-drop support.
    Forwards dropped URLs to the parent ScanView regardless which
    child widget the cursor is over — reliable in PyInstaller frozen builds.
    """

    def __init__(self, scan_view, parent=None):
        super().__init__(parent)
        self._scan_view = scan_view
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragMoveEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragLeaveEvent(self, event):
        event.accept()

    def dropEvent(self, event):
        if event.mimeData().hasUrls():
            urls = event.mimeData().urls()
            if urls:
                path = urls[0].toLocalFile()
                if os.path.isdir(path):
                    self._scan_view.folder_scan_requested.emit(path)
                else:
                    self._scan_view.scan_requested.emit(path)
                event.acceptProposedAction()
        else:
            event.ignore()


class ScanView(QWidget):
    """
    File scanner view with support for file, folder, and full device scanning.
    
    Signals:
        scan_requested(str): Scan a single file
        folder_scan_requested(str): Scan all files in a folder
        device_scan_requested: Scan entire device
    """
    
    scan_requested = Signal(str)
    folder_scan_requested = Signal(str)
    device_scan_requested = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.is_dark = True
        self.setAcceptDrops(True)
        self._scroll_ref = None

        # Label registries — populated in setup_ui(), updated by _apply_theme()
        self._primary_labels: list[QLabel] = []
        self._muted_labels:   list[QLabel] = []
        self._drop_area_ref:  QFrame | None = None

        self.setup_ui()
    
    # ------------------------------------------------------------------
    # THEME HELPERS
    # ------------------------------------------------------------------

    def _tp(self) -> str:
        return Colors.DARK_TEXT_PRIMARY if self.is_dark else Colors.LIGHT_TEXT_PRIMARY

    def _tm(self) -> str:
        return Colors.DARK_TEXT_MUTED if self.is_dark else Colors.LIGHT_TEXT_MUTED

    def _card_bg(self) -> str:
        return "rgba(255,255,255,0.04)" if self.is_dark else "rgba(0,0,0,0.04)"

    def _card_border(self) -> str:
        return "rgba(255,255,255,0.08)" if self.is_dark else "rgba(0,0,0,0.08)"

    def _drop_bg(self) -> str:
        return "rgba(255,255,255,0.02)" if self.is_dark else "rgba(0,0,0,0.02)"

    def _drop_border(self) -> str:
        return "rgba(255,255,255,0.10)" if self.is_dark else "rgba(0,0,0,0.15)"

    def _reg_p(self, lbl: QLabel) -> QLabel:
        self._primary_labels.append(lbl)
        return lbl

    def _reg_m(self, lbl: QLabel) -> QLabel:
        self._muted_labels.append(lbl)
        return lbl

    # ------------------------------------------------------------------
    # BUILD UI
    # ------------------------------------------------------------------

    def setup_ui(self):
        """Build scan view UI"""
        scroll = _DropScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("QScrollArea{background:transparent;border:none;}")
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self._scroll_ref = scroll
        
        content = QWidget()
        content.setStyleSheet("background:transparent;")
        
        layout = QVBoxLayout(content)
        layout.setContentsMargins(32, 24, 32, 32)
        layout.setSpacing(24)
        
        # ===== HEADER CARD =====
        header_card = GlassCard()
        header_layout = QVBoxLayout(header_card)
        header_layout.setContentsMargins(40, 36, 40, 36)
        header_layout.setSpacing(16)
        header_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        title = self._reg_p(QLabel("Smart Malware Scanner"))
        title.setStyleSheet(f"""
            color:{self._tp()};font-size:26px;font-weight:bold;
            background:transparent;font-family:{Typography.FONT_FAMILY};
        """)
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        header_layout.addWidget(title)

        desc = self._reg_m(QLabel("Pilih file, folder, atau scan seluruh perangkat\nuntuk mendeteksi malware menggunakan AI"))
        desc.setWordWrap(True)
        desc.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc.setStyleSheet(f"""
            color:{self._tm()};font-size:13px;
            background:transparent;font-family:{Typography.FONT_FAMILY};
        """)
        header_layout.addWidget(desc)

        layout.addWidget(header_card)
        
        # ===== SCAN OPTIONS (3 cards) =====
        options_grid = QGridLayout()
        options_grid.setSpacing(16)
        
        # File scan card
        file_card = self._create_scan_option(
            icon="",
            title="Scan File",
            desc="Pilih satu file untuk\ndipindai secara mendalam",
            btn_text="Pilih File",
            accent="rgba(255,165,0,1)",
            callback=self._browse_file
        )
        options_grid.addWidget(file_card, 0, 0)
        
        # Folder scan card
        folder_card = self._create_scan_option(
            icon="",
            title="Folder Scanner",
            desc="Pindai semua file dalam\nfolder yang dipilih",
            btn_text="Pilih Folder",
            accent="rgba(139,92,246,1)",
            callback=self._browse_folder
        )
        options_grid.addWidget(folder_card, 0, 1)
        
        # Device scan card
        device_card = self._create_scan_option(
            icon="",
            title="Scan Perangkat",
            desc="Scan seluruh file berbahaya\ndi seluruh perangkat Anda",
            btn_text="Mulai Full Scan",
            accent="rgba(255,107,53,1)",
            callback=self._start_device_scan
        )
        options_grid.addWidget(device_card, 0, 2)
        
        layout.addLayout(options_grid)
        
        # ===== DRAG & DROP AREA =====
        drop_area = QFrame()
        self._drop_area_ref = drop_area
        drop_area.setMinimumHeight(80)
        drop_area.setStyleSheet(f"""
            QFrame{{
                background:{self._drop_bg()};
                border:2px dashed {self._drop_border()};
                border-radius:16px;
            }}
        """)
        drop_layout = QVBoxLayout(drop_area)
        drop_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        drop_text = self._reg_m(QLabel("Atau drag & drop file di sini"))
        drop_text.setStyleSheet(f"""
            color:{self._tm()};font-size:13px;
            background:transparent;font-family:{Typography.FONT_FAMILY};
        """)
        drop_text.setAlignment(Qt.AlignmentFlag.AlignCenter)
        drop_layout.addWidget(drop_text)

        layout.addWidget(drop_area)
        
        # ===== SCAN HISTORY =====
        history_card = self._create_history_section()
        layout.addWidget(history_card)
        
        layout.addStretch()
        
        scroll.setWidget(content)

        # Propagate acceptDrops=False on every child widget so that drag
        # events are not silently consumed — they will bubble up to
        # _DropScrollArea which handles them.
        self._disable_child_drops(content)

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.addWidget(scroll)

    @staticmethod
    def _disable_child_drops(widget: QWidget):
        """Recursively set acceptDrops=False on all descendants so drag
        events propagate up to the _DropScrollArea instead of being silently
        rejected by intermediate child widgets."""
        for child in widget.findChildren(QWidget):
            child.setAcceptDrops(False)
    
    def _create_scan_option(self, icon: str, title: str, desc: str,
                            btn_text: str, accent: str, callback) -> GlassCard:
        """Create a scan option card."""
        card = GlassCard()
        card.setMinimumHeight(220)

        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(24, 24, 24, 24)
        card_layout.setSpacing(12)
        card_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # Icon
        icon_lbl = QLabel(icon)
        icon_lbl.setStyleSheet("font-size:36px;background:transparent;")
        icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.addWidget(icon_lbl)

        # Title
        title_lbl = self._reg_p(QLabel(title))
        title_lbl.setStyleSheet(f"""
            color:{self._tp()};font-size:16px;font-weight:bold;
            background:transparent;font-family:{Typography.FONT_FAMILY};
        """)
        title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_layout.addWidget(title_lbl)

        # Description
        desc_lbl = self._reg_m(QLabel(desc))
        desc_lbl.setWordWrap(True)
        desc_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        desc_lbl.setStyleSheet(f"""
            color:{self._tm()};font-size:11px;
            background:transparent;font-family:{Typography.FONT_FAMILY};
        """)
        card_layout.addWidget(desc_lbl)

        card_layout.addSpacing(4)

        # Button
        btn = QPushButton(btn_text)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setMinimumWidth(160)
        btn.setFixedHeight(42)
        btn.setStyleSheet(StyleHelper.pill_button_outline(42))
        btn.clicked.connect(callback)

        btn_row = QHBoxLayout()
        btn_row.setAlignment(Qt.AlignmentFlag.AlignCenter)
        btn_row.addWidget(btn)
        card_layout.addLayout(btn_row)

        return card
    
    def _create_history_section(self) -> GlassCard:
        """Create scan history list."""
        card = GlassCard()
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(28, 22, 28, 22)
        layout.setSpacing(14)
        
        header = QHBoxLayout()
        header.setSpacing(8)
        ht = self._reg_p(QLabel("Riwayat Pemindaian"))
        ht.setStyleSheet(f"""
            color:{self._tp()};font-size:16px;font-weight:bold;
            background:transparent;font-family:{Typography.FONT_FAMILY};
        """)
        header.addWidget(ht)
        header.addStretch()
        layout.addLayout(header)
        
        self.history_list = QListWidget()
        self._history_list_ref = self.history_list
        self.history_list.setMinimumHeight(120)
        self.history_list.addItem("Belum ada riwayat pemindaian")
        layout.addWidget(self.history_list)
        self._apply_history_list_theme()

        return card
    
    # ── Actions ──
    
    def _browse_file(self):
        """Open file browser dialog"""
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Pilih File untuk Dipindai", "", "All Files (*.*)"
        )
        if file_path:
            self.scan_requested.emit(file_path)
    
    def _browse_folder(self):
        """Open folder browser dialog"""
        folder_path = QFileDialog.getExistingDirectory(
            self, "Pilih Folder untuk Dipindai", ""
        )
        if folder_path:
            self.folder_scan_requested.emit(folder_path)
    
    def _start_device_scan(self):
        """Start full device scan"""
        self.device_scan_requested.emit()
    
    # ── Drag & Drop (on ScanView itself, backup for when scroll area is not hit) ──

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dragMoveEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
        else:
            event.ignore()

    def dropEvent(self, event):
        if event.mimeData().hasUrls():
            urls = event.mimeData().urls()
            if urls:
                path = urls[0].toLocalFile()
                if os.path.isdir(path):
                    self.folder_scan_requested.emit(path)
                else:
                    self.scan_requested.emit(path)
                event.acceptProposedAction()
    
    # ── History ──
    
    def add_to_history(self, filename: str, result: str, timestamp: str, file_path: str = None):
        """Add scan result to history"""
        if self.history_list.count() == 1:
            first = self.history_list.item(0)
            if first and first.text() == "Belum ada riwayat pemindaian":
                self.history_list.clear()
        
        icon = "" if result == "Benign" else ""
        item_text = f"{icon} {filename}\n{result} • {timestamp}"
        item = QListWidgetItem(item_text)
        self.history_list.insertItem(0, item)
        
        while self.history_list.count() > 20:
            self.history_list.takeItem(self.history_list.count() - 1)
    
    def set_theme(self, is_dark: bool):
        self.is_dark = is_dark
        self._apply_theme()

    def _apply_theme(self):
        """Apply current theme colors to all registered widgets."""
        tp = self._tp()
        tm = self._tm()

        for lbl in self._primary_labels:
            lbl.setStyleSheet(re.sub(r'color:[^;]+;', f'color:{tp};', lbl.styleSheet(), count=1))

        for lbl in self._muted_labels:
            lbl.setStyleSheet(re.sub(r'color:[^;]+;', f'color:{tm};', lbl.styleSheet(), count=1))

        if self._drop_area_ref:
            self._drop_area_ref.setStyleSheet(f"""
                QFrame{{
                    background:{self._drop_bg()};
                    border:2px dashed {self._drop_border()};
                    border-radius:16px;
                }}
            """)

        self._apply_history_list_theme()

    def _apply_history_list_theme(self):
        """Apply theme to the history QListWidget."""
        tp = self._tp()
        card_bg = self._card_bg()
        card_border = self._card_border()
        hover_bg = "rgba(255,255,255,0.07)" if self.is_dark else "rgba(0,0,0,0.06)"
        if hasattr(self, 'history_list'):
            self.history_list.setStyleSheet(f"""
                QListWidget{{
                    background:transparent;border:none;
                    color:{tp};font-size:13px;
                }}
                QListWidget::item{{
                    background:{card_bg};
                    border:1px solid {card_border};
                    border-radius:10px;
                    padding:12px;margin-bottom:6px;
                }}
                QListWidget::item:hover{{
                    background:{hover_bg};
                    border:1px solid rgba(255,165,0,0.3);
                }}
            """)
