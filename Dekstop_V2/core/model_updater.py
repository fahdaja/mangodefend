"""
Model Updater - Automatic model version checking and updating
Downloads latest ML model from backend server
"""
import os
import json
import hashlib
import requests
import shutil
from pathlib import Path
from typing import Optional, Dict, Callable
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class ModelUpdater:
    """Manages ML model updates from backend server."""
    
    def __init__(self, backend_url: str = "http://localhost:8000", models_dir: str = "models"):
        """
        Initialize model updater.
        
        Args:
            backend_url: Backend API base URL
            models_dir: Directory to store models
        """
        self.backend_url = backend_url.rstrip('/')
        self.models_dir = Path(models_dir)
        self.models_dir.mkdir(exist_ok=True)
        
        # Backup directory
        self.backup_dir = self.models_dir / "backups"
        self.backup_dir.mkdir(exist_ok=True)
        
        # Current model info file
        self.version_file = self.models_dir / "version.json"
    
    def get_current_version(self) -> Optional[Dict]:
        """
        Get currently installed model version.
        
        Returns:
            Dict with version info or None
        """
        if self.version_file.exists():
            try:
                with open(self.version_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                logger.error(f"Failed to read version file: {e}")
        
        # Try to detect from existing model file
        model_files = list(self.models_dir.glob("Modelv*.onnx"))
        if model_files:
            # Extract version from filename
            filename = model_files[0].name
            version = filename.replace("Model", "").replace(".onnx", "")
            return {
                "version": version,
                "filename": filename,
                "installed_date": datetime.now().isoformat()
            }
        
        return None
    
    def check_for_updates(self) -> Optional[Dict]:
        """
        Check if newer model version is available.
        
        Returns:
            Dict with update info or None if no update available
        """
        try:
            # Get latest version from backend
            response = requests.get(
                f"{self.backend_url}/model/latest",
                timeout=10
            )
            response.raise_for_status()
            latest = response.json()
            
            # Get current version
            current = self.get_current_version()
            
            if current is None:
                # No model installed, update available
                return {
                    "update_available": True,
                    "current_version": None,
                    "latest_version": latest['version'],
                    "latest_info": latest
                }
            
            # Compare versions
            current_ver = current.get('version', 'v0')
            latest_ver = latest.get('version', 'v0')
            
            if latest_ver > current_ver:
                return {
                    "update_available": True,
                    "current_version": current_ver,
                    "latest_version": latest_ver,
                    "latest_info": latest
                }
            
            return {
                "update_available": False,
                "current_version": current_ver,
                "latest_version": latest_ver
            }
            
        except Exception as e:
            logger.error(f"Failed to check for updates: {e}")
            return None
    
    def download_model(
        self,
        version: str,
        progress_callback: Optional[Callable[[int, int], None]] = None
    ) -> Optional[Path]:
        """
        Download model from backend.
        
        Args:
            version: Model version to download
            progress_callback: Callback(downloaded_bytes, total_bytes)
            
        Returns:
            Path to downloaded file or None if failed
        """
        try:
            url = f"{self.backend_url}/model/download/{version}"
            
            # Stream download
            response = requests.get(url, stream=True, timeout=30)
            response.raise_for_status()
            
            # Get total size
            total_size = int(response.headers.get('content-length', 0))
            
            # Download to temp file
            temp_file = self.models_dir / f"Model{version}.onnx.tmp"
            downloaded = 0
            
            with open(temp_file, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        if progress_callback:
                            progress_callback(downloaded, total_size)
            
            logger.info(f"Downloaded model {version}: {downloaded} bytes")
            return temp_file
            
        except Exception as e:
            logger.error(f"Failed to download model: {e}")
            return None
    
    def verify_model(self, file_path: Path, expected_hash: str) -> bool:
        """
        Verify model file integrity using SHA256.
        
        Args:
            file_path: Path to model file
            expected_hash: Expected SHA256 hash
            
        Returns:
            True if hash matches
        """
        try:
            sha256_hash = hashlib.sha256()
            
            with open(file_path, "rb") as f:
                for byte_block in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(byte_block)
            
            actual_hash = sha256_hash.hexdigest()
            
            if actual_hash.lower() == expected_hash.lower():
                logger.info("Model verification successful")
                return True
            else:
                logger.error(f"Hash mismatch: {actual_hash} != {expected_hash}")
                return False
                
        except Exception as e:
            logger.error(f"Failed to verify model: {e}")
            return False
    
    def backup_current_model(self) -> bool:
        """
        Backup current model before updating.
        
        Returns:
            True if backup successful
        """
        try:
            current = self.get_current_version()
            if not current:
                return True  # No current model to backup
            
            current_file = self.models_dir / current['filename']
            if not current_file.exists():
                return True
            
            # Create backup with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            backup_file = self.backup_dir / f"{current['filename']}.{timestamp}.bak"
            
            shutil.copy2(current_file, backup_file)
            logger.info(f"Backed up model to {backup_file}")
            
            # Keep only last 2 backups
            self._cleanup_old_backups(keep=2)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to backup model: {e}")
            return False
    
    def install_model(self, temp_file: Path, version: str, metadata: Dict) -> bool:
        """
        Install downloaded model.
        
        Args:
            temp_file: Path to downloaded temp file
            version: Model version
            metadata: Model metadata from backend
            
        Returns:
            True if installation successful
        """
        try:
            # Backup current model
            if not self.backup_current_model():
                logger.warning("Backup failed, continuing anyway...")
            
            # Move temp file to final location
            final_file = self.models_dir / f"Model{version}.onnx"
            shutil.move(str(temp_file), str(final_file))
            
            # Save version info
            version_info = {
                "version": version,
                "filename": final_file.name,
                "installed_date": datetime.now().isoformat(),
                "sha256": metadata.get('sha256'),
                "size": metadata.get('size'),
                "release_notes": metadata.get('release_notes')
            }
            
            with open(self.version_file, 'w') as f:
                json.dump(version_info, f, indent=2)
            
            logger.info(f"Installed model {version} successfully")
            return True
            
        except Exception as e:
            logger.error(f"Failed to install model: {e}")
            return False
    
    def rollback(self) -> bool:
        """
        Rollback to previous model version.
        
        Returns:
            True if rollback successful
        """
        try:
            # Find latest backup
            backups = sorted(self.backup_dir.glob("*.bak"), reverse=True)
            
            if not backups:
                logger.error("No backup found for rollback")
                return False
            
            latest_backup = backups[0]
            
            # Extract original filename
            original_name = latest_backup.stem.split('.')[0] + '.onnx'
            restore_path = self.models_dir / original_name
            
            # Restore backup
            shutil.copy2(latest_backup, restore_path)
            
            logger.info(f"Rolled back to {original_name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to rollback: {e}")
            return False
    
    def _cleanup_old_backups(self, keep: int = 2):
        """Remove old backups, keeping only the most recent ones."""
        try:
            backups = sorted(self.backup_dir.glob("*.bak"), reverse=True)
            
            for backup in backups[keep:]:
                backup.unlink()
                logger.debug(f"Removed old backup: {backup}")
                
        except Exception as e:
            logger.error(f"Failed to cleanup backups: {e}")
    
    def update_model(
        self,
        progress_callback: Optional[Callable[[int, int], None]] = None
    ) -> Dict:
        """
        Complete model update process.
        
        Args:
            progress_callback: Progress callback for download
            
        Returns:
            Dict with update result
        """
        # Check for updates
        update_info = self.check_for_updates()
        
        if not update_info or not update_info.get('update_available'):
            return {
                "success": False,
                "message": "No update available"
            }
        
        latest_info = update_info['latest_info']
        version = latest_info['version']
        
        # Download model
        temp_file = self.download_model(version, progress_callback)
        
        if not temp_file:
            return {
                "success": False,
                "message": "Download failed"
            }
        
        # Verify hash if provided
        if 'sha256' in latest_info and latest_info['sha256'] != "PUT_YOUR_HASH_HERE":
            if not self.verify_model(temp_file, latest_info['sha256']):
                temp_file.unlink()  # Delete corrupted file
                return {
                    "success": False,
                    "message": "Verification failed - file corrupted"
                }
        
        # Install model
        if self.install_model(temp_file, version, latest_info):
            return {
                "success": True,
                "message": f"Successfully updated to {version}",
                "version": version
            }
        else:
            return {
                "success": False,
                "message": "Installation failed"
            }


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    updater = ModelUpdater()
    
    # Check for updates
    update_info = updater.check_for_updates()
    print(f"Update info: {update_info}")
    
    if update_info and update_info.get('update_available'):
        print(f"Update available: {update_info['latest_version']}")
        
        # Progress callback
        def progress(downloaded, total):
            percent = (downloaded / total) * 100 if total > 0 else 0
            print(f"Download progress: {percent:.1f}%", end='\r')
        
        # Update model
        result = updater.update_model(progress_callback=progress)
        print(f"\nUpdate result: {result}")
