"""
Notification Manager - Cross-platform desktop notifications
Shows alerts when malware is detected
"""
import logging
from typing import Optional
from datetime import datetime
import platform

logger = logging.getLogger(__name__)


class NotificationManager:
    """Cross-platform notification system."""
    
    def __init__(self, app_name: str = "MangoDefend"):
        """
        Initialize notification manager.
        
        Args:
            app_name: Application name for notifications
        """
        self.app_name = app_name
        self.system = platform.system()
        self.notification_history = []
        
        # Try to import platform-specific libraries
        self._init_platform()
    
    def _init_platform(self):
        """Initialize platform-specific notification system."""
        if self.system == "Windows":
            try:
                from win10toast import ToastNotifier
                self.toaster = ToastNotifier()
                logger.info("Windows notifications initialized")
            except ImportError:
                logger.warning("win10toast not available, using fallback")
                self.toaster = None
        
        elif self.system == "Darwin":  # macOS
            # macOS uses osascript
            logger.info("macOS notifications initialized")
        
        else:  # Linux
            # Linux uses notify-send
            logger.info("Linux notifications initialized")
    
    def show_malware_alert(
        self,
        file_path: str,
        file_name: str,
        threat_level: str = "High"
    ):
        """
        Show malware detection alert.
        
        Args:
            file_path: Full path to malware file
            file_name: File name
            threat_level: Threat level (High/Medium/Low)
        """
        title = f"🚨 Malware Detected - {threat_level} Threat"
        message = f"File: {file_name}\nLocation: {file_path}\n\nAction required!"
        
        self.show_notification(title, message, icon="warning")
        
        # Add to history
        self.notification_history.append({
            "type": "malware_alert",
            "file_path": file_path,
            "file_name": file_name,
            "threat_level": threat_level,
            "timestamp": datetime.now().isoformat()
        })
    
    def show_model_update(self, version: str, size_mb: float):
        """
        Show model update notification.
        
        Args:
            version: New model version
            size_mb: Download size in MB
        """
        title = "📦 Model Update Available"
        message = f"Version {version} is available\nSize: {size_mb:.1f} MB\n\nUpdate now?"
        
        self.show_notification(title, message, icon="info")
    
    def show_protection_status(self, enabled: bool):
        """
        Show protection status change.
        
        Args:
            enabled: True if protection enabled
        """
        if enabled:
            title = "🛡️ Protection Enabled"
            message = "Real-time protection is now active"
        else:
            title = "⚠️ Protection Disabled"
            message = "Real-time protection is turned off"
        
        self.show_notification(title, message, icon="info")
    
    def show_notification(
        self,
        title: str,
        message: str,
        icon: str = "info",
        duration: int = 10
    ):
        """
        Show desktop notification (cross-platform).
        
        Args:
            title: Notification title
            message: Notification message
            icon: Icon type (info/warning/error)
            duration: Duration in seconds
        """
        try:
            if self.system == "Windows":
                self._show_windows(title, message, duration)
            elif self.system == "Darwin":
                self._show_macos(title, message)
            else:
                self._show_linux(title, message, icon)
        except Exception as e:
            logger.error(f"Failed to show notification: {e}")
            # Fallback: print to console
            print(f"\n{'='*50}")
            print(f"{title}")
            print(f"{message}")
            print(f"{'='*50}\n")
    
    def _show_windows(self, title: str, message: str, duration: int):
        """Show Windows notification."""
        if self.toaster:
            try:
                self.toaster.show_toast(
                    title,
                    message,
                    duration=duration,
                    threaded=True
                )
            except Exception as e:
                logger.error(f"Windows notification error: {e}")
                self._fallback_notification(title, message)
        else:
            self._fallback_notification(title, message)
    
    def _show_macos(self, title: str, message: str):
        """Show macOS notification."""
        import subprocess
        
        script = f'display notification "{message}" with title "{title}"'
        try:
            subprocess.run(
                ["osascript", "-e", script],
                check=True,
                capture_output=True
            )
        except Exception as e:
            logger.error(f"macOS notification error: {e}")
            self._fallback_notification(title, message)
    
    def _show_linux(self, title: str, message: str, icon: str):
        """Show Linux notification."""
        import subprocess
        
        # Map icon types
        icon_map = {
            "info": "dialog-information",
            "warning": "dialog-warning",
            "error": "dialog-error"
        }
        
        icon_name = icon_map.get(icon, "dialog-information")
        
        try:
            subprocess.run(
                ["notify-send", "-i", icon_name, title, message],
                check=True,
                capture_output=True
            )
        except FileNotFoundError:
            logger.warning("notify-send not found")
            self._fallback_notification(title, message)
        except Exception as e:
            logger.error(f"Linux notification error: {e}")
            self._fallback_notification(title, message)
    
    def _fallback_notification(self, title: str, message: str):
        """Fallback notification (console print)."""
        print(f"\n{'='*60}")
        print(f"NOTIFICATION: {title}")
        print(f"{message}")
        print(f"{'='*60}\n")
    
    def get_history(self, limit: int = 10):
        """
        Get notification history.
        
        Args:
            limit: Maximum number of notifications to return
            
        Returns:
            List of recent notifications
        """
        return self.notification_history[-limit:]
    
    def clear_history(self):
        """Clear notification history."""
        self.notification_history.clear()


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    notif = NotificationManager()
    
    # Test malware alert
    notif.show_malware_alert(
        file_path="C:\\Users\\test\\Downloads\\virus.exe",
        file_name="virus.exe",
        threat_level="High"
    )
    
    import time
    time.sleep(2)
    
    # Test model update
    notif.show_model_update(version="v4", size_mb=45.2)
    
    time.sleep(2)
    
    # Test protection status
    notif.show_protection_status(enabled=True)
    
    # Show history
    print("\nNotification History:")
    for item in notif.get_history():
        print(f"  - {item}")
