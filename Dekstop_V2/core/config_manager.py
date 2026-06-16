"""
Configuration Manager - Read and write app configuration
Manages settings from config.ini file
"""
import configparser
import os
from pathlib import Path
from typing import Any, Optional


class ConfigManager:
    """Manages application configuration from config.ini."""
    
    def __init__(self, config_path: Optional[str] = None):
        """
        Initialize config manager.
        
        Args:
            config_path: Path to config.ini. If None, uses default location.
        """
        if config_path is None:
            # Default: config.ini in app root directory
            app_dir = Path(__file__).parent.parent
            config_path = app_dir / "config.ini"
        
        self.config_path = str(config_path)
        self.config = configparser.ConfigParser()
        self._load()
    
    def _load(self):
        """Load configuration from file."""
        if os.path.exists(self.config_path):
            self.config.read(self.config_path)
        else:
            # Create default config if not exists
            self._create_default()
    
    def _create_default(self):
        """Create default configuration file."""
        self.config['Backend'] = {
            'url': 'http://localhost:8000',
            'timeout': '10',
            'retry_attempts': '3',
            'retry_backoff': '2.0'
        }
        
        self.config['Sync'] = {
            'enabled': 'true',
            'interval': '30',
            'batch_size': '50',
            'max_queue_size': '1000'
        }
        
        self.config['App'] = {
            'auto_sync': 'true',
            'show_notifications': 'true',
            'log_level': 'INFO'
        }
        
        self.save()
    
    def save(self):
        """Save configuration to file."""
        with open(self.config_path, 'w') as f:
            self.config.write(f)
    
    def get(self, section: str, key: str, fallback: Any = None) -> Any:
        """
        Get configuration value.
        
        Args:
            section: Config section name
            key: Config key name
            fallback: Default value if not found
            
        Returns:
            Configuration value
        """
        try:
            return self.config.get(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError):
            return fallback
    
    def get_int(self, section: str, key: str, fallback: int = 0) -> int:
        """Get integer configuration value."""
        try:
            return self.config.getint(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError, ValueError):
            return fallback
    
    def get_float(self, section: str, key: str, fallback: float = 0.0) -> float:
        """Get float configuration value."""
        try:
            return self.config.getfloat(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError, ValueError):
            return fallback
    
    def get_bool(self, section: str, key: str, fallback: bool = False) -> bool:
        """Get boolean configuration value."""
        try:
            return self.config.getboolean(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError, ValueError):
            return fallback
    
    def set(self, section: str, key: str, value: Any):
        """
        Set configuration value.
        
        Args:
            section: Config section name
            key: Config key name
            value: Value to set
        """
        if not self.config.has_section(section):
            self.config.add_section(section)
        
        self.config.set(section, key, str(value))
    
    # Convenience methods for common settings
    
    def get_backend_url(self) -> str:
        """Get backend URL."""
        return self.get('Backend', 'url', 'http://localhost:8000')
    
    def get_backend_timeout(self) -> int:
        """Get backend request timeout."""
        return self.get_int('Backend', 'timeout', 10)
    
    def get_sync_interval(self) -> int:
        """Get sync interval in seconds."""
        return self.get_int('Sync', 'interval', 30)
    
    def get_sync_batch_size(self) -> int:
        """Get sync batch size."""
        return self.get_int('Sync', 'batch_size', 50)
    
    def is_sync_enabled(self) -> bool:
        """Check if auto-sync is enabled."""
        return self.get_bool('Sync', 'enabled', True)
    
    def is_auto_sync(self) -> bool:
        """Check if auto-sync on startup is enabled."""
        return self.get_bool('App', 'auto_sync', True)
    
    def get_log_level(self) -> str:
        """Get logging level."""
        return self.get('App', 'log_level', 'INFO')


# Global config instance
_config_instance: Optional[ConfigManager] = None


def get_config() -> ConfigManager:
    """
    Get global config instance (singleton).
    
    Returns:
        ConfigManager instance
    """
    global _config_instance
    if _config_instance is None:
        _config_instance = ConfigManager()
    return _config_instance


# Example usage
if __name__ == "__main__":
    config = ConfigManager()
    
    print(f"Backend URL: {config.get_backend_url()}")
    print(f"Sync interval: {config.get_sync_interval()}s")
    print(f"Sync enabled: {config.is_sync_enabled()}")
    print(f"Log level: {config.get_log_level()}")
