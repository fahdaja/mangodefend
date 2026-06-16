"""
Progress Ring Widget - Circular Progress Indicator
Used in Dashboard for protection status
"""
from PySide6.QtWidgets import QWidget
from PySide6.QtCore import Qt, QTimer, QPropertyAnimation
from PySide6.QtGui import QPainter, QPen, QColor, QLinearGradient, QConicalGradient
import math


class ProgressRing(QWidget):
    """
    Circular progress indicator with gradient stroke.
    
    Features:
    - Animated progress updates
    - Gradient colors
    - Percentage display in center
    - Smooth rendering
    """
    
    def __init__(self, diameter=120, line_width=12, parent=None):
        super().__init__(parent)
        self.diameter = diameter
        self.line_width = line_width
        self.progress = 0.0  # 0.0 to 1.0
        self.target_progress = 1.0
        
        self.setFixedSize(diameter, diameter)
        
        # Animation for smooth progress updates
        self.animation_timer = QTimer(self)
        self.animation_timer.timeout.connect(self._animate_progress)
        
    def set_progress(self, value: float, animate=True):
        """
        Set progress value
        
        Args:
            value: Progress from 0.0 to 1.0
            animate: If True, animate to new value
        """
        self.target_progress = max(0.0, min(1.0, value))
        
        if animate:
            if not self.animation_timer.isActive():
                self.animation_timer.start(16)  # ~60fps
        else:
            self.progress = self.target_progress
            self.update()
    
    def _animate_progress(self):
        """Animate progress to target"""
        if abs(self.progress - self.target_progress) < 0.01:
            self.progress = self.target_progress
            self.animation_timer.stop()
        else:
            # Smooth easing
            diff = self.target_progress - self.progress
            self.progress += diff * 0.1
        
        self.update()
    
    def paintEvent(self, event):
        """Draw the circular progress ring"""
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        rect = self.rect()
        center_x = rect.width() / 2
        center_y = rect.height() / 2
        radius = (min(rect.width(), rect.height()) - self.line_width) / 2
        
        # Background circle
        bg_pen = QPen(QColor(255, 255, 255, 20), self.line_width)
        bg_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        painter.setPen(bg_pen)
        painter.drawArc(
            int(center_x - radius), int(center_y - radius),
            int(radius * 2), int(radius * 2),
            90 * 16, -360 * 16
        )
        
        # Progress arc with gradient
        if self.progress > 0:
            # Create gradient
            gradient = QConicalGradient(center_x, center_y, 90)
            gradient.setColorAt(0.0, QColor(34, 197, 94))    # Green
            gradient.setColorAt(1.0, QColor(16, 185, 129))   # Emerald
            
            arc_pen = QPen(gradient, self.line_width)
            arc_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
            painter.setPen(arc_pen)
            
            span_angle = int(-360 * 16 * self.progress)
            painter.drawArc(
                int(center_x - radius), int(center_y - radius),
                int(radius * 2), int(radius * 2),
                90 * 16, span_angle
            )
        
        # Center percentage text
        painter.setPen(QColor(255, 255, 255))
        font = painter.font()
        font.setPointSize(24)
        font.setBold(True)
        painter.setFont(font)
        
        text = f"{int(self.progress * 100)}%"
        painter.drawText(rect, Qt.AlignmentFlag.AlignCenter, text)
