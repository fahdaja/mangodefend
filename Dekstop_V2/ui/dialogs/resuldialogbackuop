"""
Result Dialog
Dialog untuk menampilkan hasil scanning
"""
import math
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QProgressBar, QFrame, QGraphicsOpacityEffect
)
from PySide6.QtCore import Qt, QPropertyAnimation, QEasingCurve


class ResultDialog(QWidget):
    """Custom result dialog dengan desain modern, smooth dan elegan"""
    def __init__(self, result_data, parent=None):
        super().__init__(parent)
        self.result_data = result_data
        self.setObjectName("resultOverlay")
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.setup_ui()
        self._animate_entry()

    def setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)

        # Check if this is a full scan result OR missing 'result' key (treat as full scan)
        is_full_scan = self.result_data.get('is_full_scan', False) or ('result' not in self.result_data)

        if is_full_scan or 'result' not in self.result_data:
            # Handle full scan result or data without 'result' key
            is_safe = not self.result_data.get('is_malware', False)
            confidence = self.result_data.get('confidence', 100) / 100.0
            result_type = "Benign" if is_safe else "Malware"
        else:
            # Determine result type for single file scan
            result_type = self.result_data['result']
            is_safe = result_type == "Benign"
            predicted_output = self.result_data['model']['predicted_output']

            # Handle different output formats (ONNX vs PyTorch)
            if isinstance(predicted_output, list):
                # Already a list (ONNX format or PyTorch format)
                if len(predicted_output) == 2:
                    # Direct probabilities [benign, malware]
                    probs = predicted_output
                else:
                    # Nested list [[benign, malware]]
                    probs = predicted_output[0] if isinstance(predicted_output[0], list) else predicted_output
            else:
                # Single value or other format
                probs = [predicted_output, 1 - predicted_output]

            # Calculate confidence using softmax-like normalization
            # Convert logits to probabilities if needed
            exp_probs = [math.exp(p) if p < 100 else math.exp(min(p, 100)) for p in probs]
            total = sum(exp_probs)

            if total > 0:
                probabilities = [p / total for p in exp_probs]
                confidence = max(probabilities)
            else:
                confidence = 0.5

            # Pastikan tidak melebihi 100%
            confidence = min(confidence, 1.0)

        # Card container
        card = QFrame()
        card.setObjectName("resultContainer")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(0, 0, 0, 0)
        card_layout.setSpacing(0)

        # === HEADER SECTION - Status Banner ===
        header = QFrame()
        header.setObjectName("resultHeader")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(35, 30, 35, 30)
        header_layout.setSpacing(12)

        # Status icon dan title
        status_row = QHBoxLayout()
        status_row.setSpacing(15)
        status_row.setAlignment(Qt.AlignmentFlag.AlignCenter)

        icon_text = "!" if not is_safe else "✓"
        status_icon = QLabel(icon_text)
        status_icon.setFixedSize(50, 50)
        status_icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        status_icon.setStyleSheet(f"""
            font-size: 32px;
            font-weight: bold;
            color: white;
            background: {'rgba(50, 205, 50, 1)' if is_safe else 'rgba(239, 68, 68, 1)'};
            border-radius: 25px;
        """)
        status_row.addWidget(status_icon)

        # Title
        title_text = "File Aman" if is_safe else "Terdeteksi Ancaman"
        title_label = QLabel(title_text)
        title_label.setStyleSheet("""
            font-size: 24px;
            font-weight: 600;
            color: white;
            font-family: 'Segoe UI', Arial, sans-serif;
        """)
        status_row.addWidget(title_label)
        status_row.addStretch()

        header_layout.addLayout(status_row)

        # Subtitle dengan confidence yang sudah diperbaiki
        subtitle = QLabel(f"Pemindaian selesai dengan tingkat keyakinan {confidence:.0%}")
        subtitle.setStyleSheet("""
            font-size: 13px;
            color: rgba(255, 255, 255, 0.95);
            font-family: 'Segoe UI', Arial, sans-serif;
            padding-left: 65px;
        """)
        header_layout.addWidget(subtitle)

        # Style header - konsisten warna mango/orange
        header.setStyleSheet(f"""
            QFrame#resultHeader {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 {'#32CD32' if is_safe else '#FF8C00'}, 
                    stop:1 {'#90EE90' if is_safe else '#FFA500'});
                border-radius: 20px 20px 0 0;
            }}
        """)
        card_layout.addWidget(header)

        # === CONTENT SECTION ===
        content = QWidget()
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(35, 30, 35, 30)
        content_layout.setSpacing(20)

        # File Info Card
        file_card = QFrame()
        file_card.setObjectName("infoCard")
        file_layout = QVBoxLayout(file_card)
        file_layout.setContentsMargins(20, 16, 20, 16)
        file_layout.setSpacing(8)

        file_header = QLabel(" INFORMASI FILE")
        file_header.setStyleSheet("""
            font-size: 11px;
            font-weight: 600;
            color: #6B7280;
            font-family: 'Segoe UI', Arial, sans-serif;
            letter-spacing: 0.5px;
        """)
        file_layout.addWidget(file_header)

        # File name - handle both formats
        if is_full_scan:
            file_name_text = self.result_data.get('file_name', 'Unknown')
        else:
            file_name_text = self.result_data['file']['file_name']

        file_name = QLabel(file_name_text)
        file_name.setWordWrap(True)
        file_name.setMaximumWidth(480)
        file_name.setStyleSheet("""
            font-size: 14px;
            font-weight: 500;
            color: #1F2937;
            font-family: 'Courier New', monospace;
            padding: 4px 0;
        """)
        file_layout.addWidget(file_name)

        file_card.setStyleSheet("""
            QFrame#infoCard {
                background: #F9FAFB;
                border: 1px solid #E5E7EB;
                border-radius: 12px;
            }
        """)
        content_layout.addWidget(file_card)

        # Detection Result Card - warna konsisten
        detect_card = QFrame()
        detect_card.setObjectName("detectCard")
        detect_layout = QVBoxLayout(detect_card)
        detect_layout.setContentsMargins(20, 16, 20, 16)
        detect_layout.setSpacing(8)

        detect_header = QLabel(" HASIL DETEKSI")
        detect_header.setStyleSheet("""
            font-size: 11px;
            font-weight: 600;
            color: #6B7280;
            font-family: 'Segoe UI', Arial, sans-serif;
            letter-spacing: 0.5px;
        """)
        detect_layout.addWidget(detect_header)

        # Detection result - handle both formats
        if is_full_scan:
            if is_safe:
                result_text = "Aman - Tidak Ada Ancaman"
            else:
                threat_count = len(self.result_data.get('threats', []))
                result_text = f"Terdeteksi {threat_count} Ancaman"
        else:
            result_text = result_type

        detect_value = QLabel(result_text)
        detect_value.setStyleSheet(f"""
            font-size: 20px;
            font-weight: 700;
            color: {'#32CD32' if is_safe else '#FF8C00'};
            font-family: 'Segoe UI', Arial, sans-serif;
        """)
        detect_layout.addWidget(detect_value)

        # Add details for full scan
        if is_full_scan:
            details_text = self.result_data.get('details', '')
            if details_text:
                details_label = QLabel(details_text)
                details_label.setWordWrap(True)
                details_label.setStyleSheet("""
                    font-size: 12px;
                    color: #6B7280;
                    font-family: 'Segoe UI', Arial, sans-serif;
                    margin-top: 8px;
                """)
                detect_layout.addWidget(details_label)

        detect_card.setStyleSheet(f"""
            QFrame#detectCard {{
                background: {'rgba(144, 238, 144, 0.2)' if is_safe else 'rgba(255, 165, 0, 0.15)'};
                border: 2px solid {'rgba(50, 205, 50, 0.4)' if is_safe else 'rgba(255, 140, 0, 0.5)'};
                border-radius: 12px;
            }}
        """)
        content_layout.addWidget(detect_card)

        # Confidence Meter - warna konsisten
        confidence_section = QVBoxLayout()
        confidence_section.setSpacing(12)

        conf_label = QLabel("TINGKAT KEYAKINAN")
        conf_label.setStyleSheet("""
            font-size: 11px;
            font-weight: 600;
            color: #6B7280;
            font-family: 'Segoe UI', Arial, sans-serif;
            letter-spacing: 0.5px;
        """)
        confidence_section.addWidget(conf_label)

        # Progress bar container
        conf_container = QHBoxLayout()
        conf_container.setSpacing(15)

        conf_bar = QProgressBar()
        conf_bar.setRange(0, 100)
        conf_bar.setValue(int(confidence * 100))
        conf_bar.setTextVisible(False)
        conf_bar.setFixedHeight(12)
        conf_bar.setStyleSheet(f"""
            QProgressBar {{
                background: #E5E7EB;
                border-radius: 6px;
                border: none;
            }}
            QProgressBar::chunk {{
                background: {'#32CD32' if is_safe else '#FFA500'};
                border-radius: 6px;
            }}
        """)
        conf_container.addWidget(conf_bar, 1)

        conf_percent = QLabel(f"{confidence:.0%}")
        conf_percent.setStyleSheet(f"""
            font-size: 24px;
            font-weight: 700;
            color: {'#32CD32' if is_safe else '#FF8C00'};
            font-family: 'Segoe UI', Arial, sans-serif;
            min-width: 60px;
        """)
        conf_container.addWidget(conf_percent)

        confidence_section.addLayout(conf_container)
        content_layout.addLayout(confidence_section)

        # Warning banner untuk malware - warna konsisten orange
        if not is_safe:
            warning = QFrame()
            warning.setObjectName("warningBanner")
            warn_layout = QHBoxLayout(warning)
            warn_layout.setContentsMargins(16, 14, 16, 14)
            warn_layout.setSpacing(12)

            warn_icon = QLabel("⚠")
            warn_icon.setStyleSheet("font-size: 24px; color: #FF8C00;")
            warn_layout.addWidget(warn_icon)

            warn_text = QLabel("Segera hapus file ini untuk melindungi perangkat Anda")
            warn_text.setWordWrap(True)
            warn_text.setStyleSheet("""
                font-size: 13px;
                font-weight: 600;
                color: #CC6600;
                font-family: 'Segoe UI', Arial, sans-serif;
            """)
            warn_layout.addWidget(warn_text, 1)

            warning.setStyleSheet("""
                QFrame#warningBanner {
                    background: rgba(255, 165, 0, 0.1);
                    border-left: 4px solid #FFA500;
                    border-radius: 10px;
                }
            """)
            content_layout.addWidget(warning)

        card_layout.addWidget(content)

        # === FOOTER SECTION ===
        footer = QWidget()
        footer_layout = QHBoxLayout(footer)
        footer_layout.setContentsMargins(35, 20, 35, 30)
        footer_layout.setSpacing(0)

        # Device info - handle both formats
        if is_full_scan:
            device_name = "MangoDefend Scanner"
        else:
            device_name = self.result_data['device']['device_name']

        device_info = QLabel(f" {device_name}")
        device_info.setStyleSheet("""
            font-size: 12px;
            color: #9CA3AF;
            font-family: 'Segoe UI', Arial, sans-serif;
        """)
        footer_layout.addWidget(device_info)
        footer_layout.addStretch()

        # Close button - warna konsisten
        self.close_btn = QPushButton("Selesai")
        self.close_btn.clicked.connect(self.close_dialog)
        self.close_btn.setFixedSize(100, 40)
        self.close_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.close_btn.setStyleSheet(f"""
            QPushButton {{
                background: {'#32CD32' if is_safe else '#FFA500'};
                color: white;
                border: none;
                border-radius: 8px;
                font-weight: 600;
                font-size: 14px;
                font-family: 'Segoe UI', Arial, sans-serif;
            }}
            QPushButton:hover {{
                background: {'#90EE90' if is_safe else '#FFB732'};
            }}
            QPushButton:pressed {{
                background: {'#228B22' if is_safe else '#FF8C00'};
            }}
        """)
        footer_layout.addWidget(self.close_btn)

        card_layout.addWidget(footer)

        layout.addWidget(card)

        # Main container style
        self.setStyleSheet("""
            QWidget#resultOverlay {
                background: rgba(17, 24, 39, 0.85);
            }
            QFrame#resultContainer {
                background: white;
                border-radius: 20px;
                min-width: 550px;
                max-width: 580px;
            }
        """)

    def _animate_entry(self):
        """Animate dialog entry"""
        self.opacity_effect = QGraphicsOpacityEffect(self)
        self.setGraphicsEffect(self.opacity_effect)
        
        self.fade_animation = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.fade_animation.setDuration(300)
        self.fade_animation.setStartValue(0.0)
        self.fade_animation.setEndValue(1.0)
        self.fade_animation.setEasingCurve(QEasingCurve.Type.OutCubic)

    def close_dialog(self):
        """Close dengan fade out"""
        self.fade_out = QPropertyAnimation(self.opacity_effect, b"opacity")
        self.fade_out.setDuration(200)
        self.fade_out.setStartValue(1.0)
        self.fade_out.setEndValue(0.0)
        self.fade_out.setEasingCurve(QEasingCurve.Type.InCubic)
        self.fade_out.finished.connect(self._final_close)
        self.fade_out.start()

    def _final_close(self):
        self.hide()
        self.deleteLater()

    def show_dialog(self):
        if self.parent():
            self.setGeometry(self.parent().rect())
        self.show()
        self.raise_()
        self.fade_animation.start()
