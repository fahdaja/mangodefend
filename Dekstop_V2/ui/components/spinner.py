"""
Animated Spinner Component
Custom animated loading spinner untuk UI
"""
from PySide6.QtWidgets import QWidget
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QPainter, QPen, QColor


class AnimatedSpinner(QWidget):
    """Custom animated spinner widget"""
    def __init__(self, diameter=80, line_width=6, parent=None):
        super().__init__(parent)
        self.diameter = diameter
        self.line_width = line_width
        self.angle = 0
        self.setFixedSize(diameter, diameter)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self._rotate)
        self.timer.start(16)  # ~60fps

    def _rotate(self):
        self.angle = (self.angle + 6) % 360
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        rect = self.rect()
        margin = self.line_width

        # Background circle
        back_pen = QPen(QColor(255, 255, 255, 80), self.line_width)
        back_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        painter.setPen(back_pen)
        painter.drawArc(
            rect.adjusted(margin, margin, -margin, -margin),
            0, 360 * 16
        )

        # Animated arc
        arc_pen = QPen(QColor(255, 140, 0), self.line_width)
        arc_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        painter.setPen(arc_pen)
        span_angle = 120 * 16
        painter.drawArc(
            rect.adjusted(margin, margin, -margin, -margin),
            int(self.angle * 16), span_angle
        )
