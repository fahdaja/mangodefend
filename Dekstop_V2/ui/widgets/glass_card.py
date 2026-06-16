"""
Glass Card Widget - Glassmorphism Effect
Reusable card with frosted glass appearance
"""
from PySide6.QtWidgets import QFrame, QVBoxLayout
from PySide6.QtCore import Qt
from PySide6.QtGui import QPainter, QColor, QPen, QBrush, QPainterPath
from ui.styles.figma_theme import Colors


class GlassCard(QFrame):
    """
    Reusable card widget with glassmorphism effect.

    Features:
    - Semi-transparent background
    - Subtle border
    - Rounded corners
    - Optional hover glow animation
    """

    def __init__(self, parent=None, hover_effect=True):
        super().__init__(parent)
        self.hover_effect = hover_effect
        self._hovered = False
        self.setObjectName("glassCard")
        self.setProperty("class", "glassCard")

    def enterEvent(self, event):
        if self.hover_effect:
            self._hovered = True
            self.update()
        super().enterEvent(event)

    def leaveEvent(self, event):
        if self.hover_effect:
            self._hovered = False
            self.update()
        super().leaveEvent(event)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        rect = self.rect()
        radius = 24.0

        path = QPainterPath()
        path.addRoundedRect(rect.x(), rect.y(), rect.width(), rect.height(), radius, radius)

        # Background fill
        painter.setClipPath(path)
        bg_color = QColor(255, 255, 255, 13)  # rgba(255,255,255,0.05)
        painter.fillPath(path, QBrush(bg_color))

        # Border
        painter.setClipping(False)
        if self._hovered:
            border_color = QColor(255, 165, 0, 77)  # rgba(255,165,0,0.3)
            pen = QPen(border_color, 1.5)
        else:
            border_color = QColor(255, 255, 255, 26)  # rgba(255,255,255,0.1)
            pen = QPen(border_color, 1)

        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRoundedRect(
            rect.x() + 0.5, rect.y() + 0.5,
            rect.width() - 1, rect.height() - 1,
            radius, radius
        )

        painter.end()


class StatCard(QFrame):
    """
    Specialized card for displaying statistics.
    Includes gradient border matching theme colors.
    """

    def __init__(self, parent=None, is_dark=True):
        super().__init__(parent)
        self.is_dark = is_dark
        self.setObjectName("statCard")

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        rect = self.rect()
        radius = 20.0

        path = QPainterPath()
        path.addRoundedRect(rect.x(), rect.y(), rect.width(), rect.height(), radius, radius)

        # Background
        bg = QColor(255, 165, 0, 25)
        painter.fillPath(path, QBrush(bg))

        # Border
        pen = QPen(QColor(255, 165, 0, 51), 1)
        painter.setPen(pen)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRoundedRect(
            rect.x() + 0.5, rect.y() + 0.5,
            rect.width() - 1, rect.height() - 1,
            radius, radius
        )

        painter.end()
