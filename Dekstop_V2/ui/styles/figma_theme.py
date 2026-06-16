"""
Figma Theme System
Color palette, typography, and stylesheet definitions matching Figma design
"""

# ============================================================
# COLOR PALETTE - Figma Design Colors
# ============================================================

class Colors:
    """Color constants matching Figma design"""
    
    # Primary Gradient Colors (Orange → Red)
    ORANGE_500 = "#FFA500"  # Primary Orange
    ORANGE_400 = "#FFB732"  # Light Orange
    ORANGE_300 = "#FFC04C"  # Lighter Orange
    RED_500 = "#FF6B35"     # Primary Red
    RED_400 = "#FF8C00"     # Dark Orange
    RED_600 = "#E64A19"     # Darker Red
    
    # Accent Colors
    GREEN_500 = "#32CD32"   # Success/Protected
    GREEN_400 = "#90EE90"   # Light Green
    EMERALD_500 = "#10b981" # Emerald accent
    
    # Neutral Colors - Dark Mode
    DARK_BG_PRIMARY = "#0B0B0F"      # Main background
    DARK_BG_SECONDARY = "#1A1A1A"    # Card background
    DARK_BG_TERTIARY = "#252525"     # Elevated elements
    DARK_BORDER = "rgba(255, 255, 255, 0.1)"  # Subtle borders
    DARK_TEXT_PRIMARY = "#FFFFFF"
    DARK_TEXT_SECONDARY = "#CCCCCC"
    DARK_TEXT_MUTED = "#6B7280"
    
    # Neutral Colors - Light Mode
    LIGHT_BG_PRIMARY = "#FFFFFF"
    LIGHT_BG_SECONDARY = "#F9FAFB"
    LIGHT_BG_TERTIARY = "#FFF5E6"
    LIGHT_BORDER = "#E5E7EB"
    LIGHT_TEXT_PRIMARY = "#1F2937"
    LIGHT_TEXT_SECONDARY = "#444444"
    LIGHT_TEXT_MUTED = "#6B7280"


# ============================================================
# TYPOGRAPHY
# ============================================================

class Typography:
    """Font definitions"""
    FONT_FAMILY = "'Inter', 'Segoe UI', sans-serif"
    FONT_FAMILY_MONO = "'Inter', 'Segoe UI', monospace"
    
    # Sizes
    SIZE_H1 = "32px"
    SIZE_H2 = "24px"
    SIZE_H3 = "20px"
    SIZE_BODY = "14px"
    SIZE_SMALL = "12px"
    SIZE_TINY = "11px"


# ============================================================
# SIZES & SPACING
# ============================================================

class Sizes:
    """Layout and sizing constants — single source of truth for all dimensions."""
    BTN_HEIGHT_SM = 36
    BTN_HEIGHT_MD = 48
    BTN_HEIGHT_LG = 52
    CARD_RADIUS = 24
    CARD_PADDING_H = 28
    CARD_PADDING_V = 24


# ============================================================
# STYLE HELPER — Reusable QSS factory methods
# ============================================================

class StyleHelper:
    """
    Centralised QSS factory to eliminate duplicate inline stylesheets.

    Usage:
        btn.setStyleSheet(StyleHelper.pill_button_primary())
        label.setStyleSheet(StyleHelper.status_badge(Colors.GREEN_500))
        header.setStyleSheet(StyleHelper.section_header())

    Rule: Every repeated stylesheet block belongs here, not inlined in view files.
    """

    # ── Buttons ──────────────────────────────────────────────

    @staticmethod
    def pill_button_primary(height: int = Sizes.BTN_HEIGHT_MD) -> str:
        """Orange-to-red gradient pill button (primary action)."""
        r = height // 2
        return f"""
            QPushButton {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 {Colors.ORANGE_500}, stop:1 {Colors.RED_500});
                color: white;
                border: none;
                border-radius: {r}px;
                font-weight: 700;
                font-size: 14px;
                font-family: {Typography.FONT_FAMILY};
            }}
            QPushButton:hover {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 {Colors.ORANGE_400}, stop:1 {Colors.RED_400});
            }}
            QPushButton:pressed {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 {Colors.RED_400}, stop:1 {Colors.RED_600});
            }}
            QPushButton:disabled {{
                background: rgba(255,255,255,0.1);
                color: rgba(255,255,255,0.3);
            }}
        """

    @staticmethod
    def pill_button_danger(height: int = Sizes.BTN_HEIGHT_MD) -> str:
        """Red gradient pill button for destructive/deactivate actions."""
        r = height // 2
        return f"""
            QPushButton {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 {Colors.RED_500}, stop:1 {Colors.RED_600});
                color: white;
                border: none;
                border-radius: {r}px;
                font-weight: 700;
                font-size: 14px;
                font-family: {Typography.FONT_FAMILY};
            }}
            QPushButton:hover {{
                background: {Colors.RED_600};
            }}
            QPushButton:pressed {{
                background: {Colors.RED_600};
                opacity: 0.9;
            }}
        """

    @staticmethod
    def pill_button_outline(height: int = Sizes.BTN_HEIGHT_MD) -> str:
        """Orange outline pill button for secondary actions."""
        r = height // 2
        return f"""
            QPushButton {{
                background: rgba(255, 165, 0, 0.1);
                color: {Colors.ORANGE_400};
                border: 2px solid {Colors.ORANGE_500};
                border-radius: {r}px;
                font-weight: 700;
                font-size: 14px;
                font-family: {Typography.FONT_FAMILY};
            }}
            QPushButton:hover {{
                background: rgba(255, 165, 0, 0.2);
                border: 2px solid {Colors.ORANGE_400};
            }}
            QPushButton:pressed {{
                background: rgba(255, 165, 0, 0.3);
            }}
        """

    # ── Labels ───────────────────────────────────────────────

    @staticmethod
    def section_header() -> str:
        """White bold 18px section heading label."""
        return f"""
            color: white;
            font-size: 18px;
            font-weight: bold;
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """

    @staticmethod
    def muted_body(size: str = "13px") -> str:
        """Muted subtitle / description text."""
        return f"""
            color: {Colors.DARK_TEXT_MUTED};
            font-size: {size};
            background: transparent;
            font-family: {Typography.FONT_FAMILY};
        """

    # ── Badges ───────────────────────────────────────────────

    @staticmethod
    def status_badge(color: str) -> str:
        """
        Solid-border pill badge.
        Pass any Colors constant, e.g. Colors.GREEN_500 or Colors.ORANGE_500.
        """
        return f"""
            color: {color};
            font-size: 13px;
            font-weight: 700;
            background: transparent;
            border: 2px solid {color};
            border-radius: 9999px;
            padding: 6px 20px;
            font-family: {Typography.FONT_FAMILY};
        """

    @staticmethod
    def tag_badge() -> str:
        """Small orange pill tag (e.g. 'Pseudo-Blocking', 'ONNX Runtime')."""
        return f"""
            color: {Colors.ORANGE_400};
            font-size: 10px;
            font-weight: 700;
            letter-spacing: 0.5px;
            background: rgba(255, 165, 0, 0.15);
            border: 1px solid rgba(255, 165, 0, 0.3);
            border-radius: 9999px;
            padding: 3px 10px;
            font-family: {Typography.FONT_FAMILY};
        """


# ============================================================
# DARK THEME STYLESHEET
# ============================================================

DARK_THEME = f"""
/* ========================================
   DARK MODE - Figma Design
   ======================================== */

QMainWindow {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 {Colors.DARK_BG_PRIMARY},
        stop:1 rgb(17, 17, 25));
}}

/* ========================================
   SIDEBAR STYLES
   ======================================== */

QWidget#sidebar {{
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
        stop:0 rgba(0, 0, 0, 0.4),
        stop:0.5 rgba(0, 0, 0, 0.3),
        stop:1 rgba(0, 0, 0, 0.4));
    border-right: 1px solid rgba(255, 255, 255, 0.05);
}}

QLabel#logoTitle {{
    color: {Colors.ORANGE_400};
    font-size: 21px;
    font-weight: bold;
    font-family: {Typography.FONT_FAMILY};
    background: transparent;
}}

QLabel#logoSubtitle {{
    color: {Colors.DARK_TEXT_MUTED};
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 2px;
    font-family: {Typography.FONT_FAMILY};
}}

/* Status Badge */
QFrame#statusBadge {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 rgba(50, 205, 50, 0.1),
        stop:1 rgba(16, 185, 129, 0.05));
    border: 1px solid rgba(50, 205, 50, 0.2);
    border-radius: 9999px;
}}

QPushButton#navButton {{
    background: transparent;
    color: {Colors.DARK_TEXT_MUTED};
    border: 2px solid transparent;
    border-radius: 9999px;
    padding: 12px 20px;
    text-align: left;
    font-size: 14px;
    font-weight: 600;
    font-family: {Typography.FONT_FAMILY};
}}

QPushButton#navButton:hover {{
    color: {Colors.DARK_TEXT_PRIMARY};
    background: rgba(255, 255, 255, 0.05);
}}

QPushButton#navButton:checked {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 rgba(255, 165, 0, 0.2),
        stop:1 rgba(255, 107, 53, 0.2));
    color: {Colors.ORANGE_400};
    border: 2px solid rgba(255, 165, 0, 0.3);
}}

/* ========================================
   CARD STYLES (Glassmorphism)
   ======================================== */

QFrame.glassCard {{
    background: rgba(255, 255, 255, 0.05);
    border-radius: 24px;
    border: 1px solid rgba(255, 165, 0, 0.3);
    padding: 24px;
}}

QFrame.glassCard:hover {{
    border: 1px solid rgba(255, 165, 0, 0.3);
}}

/* ========================================
   STAT CARDS
   ======================================== */

QFrame#statCard {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 rgba(255, 165, 0, 0.1),
        stop:1 rgba(255, 107, 53, 0.05));
    border: 1px solid rgba(255, 165, 0, 0.2);
    border-radius: 20px;
}}

QLabel.statValue {{
    color: {Colors.DARK_TEXT_PRIMARY};
    font-size: 48px;
    font-weight: bold;
    font-family: {Typography.FONT_FAMILY};
}}

QLabel.statLabel {{
    color: {Colors.DARK_TEXT_SECONDARY};
    font-size: 13px;
    font-family: {Typography.FONT_FAMILY};
}}

/* ========================================
   BUTTONS
   ======================================== */

QPushButton#primaryButton {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.ORANGE_500},
        stop:1 {Colors.RED_500});
    color: white;
    border: none;
    border-radius: 9999px;
    padding: 14px 28px;
    font-weight: 600;
    font-size: 14px;
    font-family: {Typography.FONT_FAMILY};
}}

QPushButton#primaryButton:hover {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.ORANGE_400},
        stop:1 {Colors.RED_400});
}}

QPushButton#primaryButton:pressed {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.RED_400},
        stop:1 {Colors.RED_600});
}}

QPushButton#secondaryButton {{
    background: rgba(255, 255, 255, 0.05);
    color: {Colors.ORANGE_400};
    border: 2px solid {Colors.ORANGE_500};
    border-radius: 9999px;
    padding: 12px 24px;
    font-weight: 600;
    font-size: 14px;
    font-family: {Typography.FONT_FAMILY};
}}

QPushButton#secondaryButton:hover {{
    background: rgba(255, 165, 0, 0.1);
    border: 2px solid {Colors.ORANGE_400};
}}

/* ========================================
   PROGRESS BARS
   ======================================== */

QProgressBar {{
    border: none;
    border-radius: 6px;
    background: rgba(255, 255, 255, 0.1);
    text-align: center;
    color: {Colors.DARK_TEXT_PRIMARY};
    font-weight: 600;
    font-size: 12px;
}}

QProgressBar::chunk {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.ORANGE_500},
        stop:1 {Colors.RED_500});
    border-radius: 6px;
}}

/* ========================================
   SCROLLBARS
   ======================================== */

QScrollBar:vertical {{
    border: none;
    background: rgba(255, 255, 255, 0.05);
    width: 10px;
    margin: 0;
    border-radius: 5px;
}}

QScrollBar::handle:vertical {{
    background: rgba(255, 165, 0, 0.3);
    border-radius: 5px;
    min-height: 30px;
}}

QScrollBar::handle:vertical:hover {{
    background: rgba(255, 165, 0, 0.5);
}}

/* ========================================
   LABELS
   ======================================== */

QLabel.heading {{
    color: {Colors.DARK_TEXT_PRIMARY};
    font-size: 28px;
    font-weight: bold;
    font-family: {Typography.FONT_FAMILY};
}}

QLabel.subheading {{
    color: {Colors.DARK_TEXT_SECONDARY};
    font-size: 14px;
    font-family: {Typography.FONT_FAMILY};
}}

QLabel.caption {{
    color: {Colors.DARK_TEXT_MUTED};
    font-size: 12px;
    font-family: {Typography.FONT_FAMILY};
}}
"""


# ============================================================
# LIGHT THEME STYLESHEET
# ============================================================

LIGHT_THEME = f"""
/* ========================================
   LIGHT MODE - Figma Design
   ======================================== */

QMainWindow {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 rgb(255, 250, 245),
        stop:0.5 white,
        stop:1 rgb(255, 240, 230));
}}

/* ========================================
   SIDEBAR STYLES
   ======================================== */

QWidget#sidebar {{
    background: rgba(255, 255, 255, 0.6);
    border-right: 1px solid rgba(255, 165, 0, 0.2);
}}

QLabel#logoTitle {{
    color: {Colors.ORANGE_500};
    font-size: 21px;
    font-weight: bold;
    font-family: {Typography.FONT_FAMILY};
    background: transparent;
}}

QLabel#logoSubtitle {{
    color: {Colors.LIGHT_TEXT_MUTED};
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 2px;
    font-family: {Typography.FONT_FAMILY};
}}

/* Status Badge */
QFrame#statusBadge {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 rgb(240, 253, 244),
        stop:1 rgb(220, 252, 231));
    border: 1px solid rgb(167, 243, 208);
    border-radius: 9999px;
}}

QPushButton#navButton {{
    background: transparent;
    color: {Colors.LIGHT_TEXT_SECONDARY};
    border: 2px solid transparent;
    border-radius: 9999px;
    padding: 12px 20px;
    text-align: left;
    font-size: 14px;
    font-weight: 600;
    font-family: {Typography.FONT_FAMILY};
}}

QPushButton#navButton:hover {{
    color: {Colors.ORANGE_500};
    background: rgba(255, 165, 0, 0.05);
}}

QPushButton#navButton:checked {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 rgb(255, 237, 213),
        stop:1 rgb(254, 215, 170));
    color: {Colors.ORANGE_500};
    border: 2px solid {Colors.ORANGE_400};
}}

/* ========================================
   CARD STYLES
   ======================================== */

QFrame.glassCard {{
    background: rgba(255, 255, 255, 0.6);
    border: 1px solid {Colors.LIGHT_BORDER};
    border-radius: 24px;
    padding: 24px;
}}

QFrame.glassCard:hover {{
    border: 1px solid rgba(255, 165, 0, 0.4);
}}

/* ========================================
   STAT CARDS
   ======================================== */

QFrame#statCard {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:1,
        stop:0 rgb(255, 247, 237),
        stop:1 rgb(254, 226, 226));
    border: 1px solid rgb(253, 186, 116);
    border-radius: 20px;
}}

QLabel.statValue {{
    color: {Colors.LIGHT_TEXT_PRIMARY};
    font-size: 48px;
    font-weight: bold;
    font-family: {Typography.FONT_FAMILY};
}}

QLabel.statLabel {{
    color: {Colors.LIGHT_TEXT_SECONDARY};
    font-size: 13px;
    font-family: {Typography.FONT_FAMILY};
}}

/* ========================================
   BUTTONS
   ======================================== */

QPushButton#primaryButton {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.ORANGE_500},
        stop:1 {Colors.RED_500});
    color: white;
    border: none;
    border-radius: 9999px;
    padding: 14px 28px;
    font-weight: 600;
    font-size: 14px;
    font-family: {Typography.FONT_FAMILY};
}}

QPushButton#primaryButton:hover {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.ORANGE_400},
        stop:1 {Colors.RED_400});
}}

QPushButton#primaryButton:pressed {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.RED_400},
        stop:1 {Colors.RED_600});
}}

QPushButton#secondaryButton {{
    background: white;
    color: {Colors.ORANGE_500};
    border: 2px solid {Colors.ORANGE_500};
    border-radius: 9999px;
    padding: 12px 24px;
    font-weight: 600;
    font-size: 14px;
    font-family: {Typography.FONT_FAMILY};
}}

QPushButton#secondaryButton:hover {{
    background: rgb(255, 247, 237);
    border: 2px solid {Colors.ORANGE_400};
}}

/* ========================================
   PROGRESS BARS
   ======================================== */

QProgressBar {{
    border: none;
    border-radius: 6px;
    background: {Colors.LIGHT_BG_SECONDARY};
    text-align: center;
    color: {Colors.LIGHT_TEXT_PRIMARY};
    font-weight: 600;
    font-size: 12px;
}}

QProgressBar::chunk {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {Colors.ORANGE_500},
        stop:1 {Colors.RED_500});
    border-radius: 6px;
}}

/* ========================================
   SCROLLBARS
   ======================================== */

QScrollBar:vertical {{
    border: none;
    background: {Colors.LIGHT_BG_SECONDARY};
    width: 10px;
    margin: 0;
    border-radius: 5px;
}}

QScrollBar::handle:vertical {{
    background: rgba(255, 165, 0, 0.4);
    border-radius: 5px;
    min-height: 30px;
}}

QScrollBar::handle:vertical:hover {{
    background: rgba(255, 165, 0, 0.6);
}}

/* ========================================
   LABELS
   ======================================== */

QLabel.heading {{
    color: {Colors.LIGHT_TEXT_PRIMARY};
    font-size: 28px;
    font-weight: bold;
    font-family: {Typography.FONT_FAMILY};
}}

QLabel.subheading {{
    color: {Colors.LIGHT_TEXT_SECONDARY};
    font-size: 14px;
    font-family: {Typography.FONT_FAMILY};
}}

QLabel.caption {{
    color: {Colors.LIGHT_TEXT_MUTED};
    font-size: 12px;
    font-family: {Typography.FONT_FAMILY};
}}
"""


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def get_theme_stylesheet(is_dark: bool = True) -> str:
    """Get complete stylesheet for the specified theme
    
    Args:
        is_dark: If True, return dark theme. If False, return light theme.
        
    Returns:
        Complete CSS stylesheet string
    """
    return DARK_THEME if is_dark else LIGHT_THEME


def get_gradient_style(color1: str, color2: str, direction: str = "x") -> str:
    """Generate QSS gradient string
    
    Args:
        color1: Start color
        color2: End color
        direction: 'x' for horizontal, 'y' for vertical, 'diagonal' for diagonal
        
    Returns:
        QSS gradient string
    """
    if direction == "x":
        return f"qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 {color1}, stop:1 {color2})"
    elif direction == "y":
        return f"qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 {color1}, stop:1 {color2})"
    else:  # diagonal
        return f"qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {color1}, stop:1 {color2})"
