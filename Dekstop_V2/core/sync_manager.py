"""
Sync Manager - Background service for syncing local queue to backend
Automatically uploads pending scan results when backend is available
"""
import threading
import time
import logging
from typing import Optional
from .local_queue import LocalQueue
from .api_client import BackendClient


logger = logging.getLogger(__name__)


class SyncManager:
    """Manages background synchronization of scan results to backend."""
    
    def __init__(
        self,
        backend_url: str = "http://localhost:8000",
        sync_interval: int = 30,
        batch_size: int = 50
    ):
        """
        Initialize sync manager.
        
        Args:
            backend_url: URL of the backend API
            sync_interval: Sync interval in seconds
            batch_size: Maximum records to sync per batch
        """
        self.backend_url = backend_url
        self.sync_interval = sync_interval
        self.batch_size = batch_size
        self.running = False
        self._thread: Optional[threading.Thread] = None
        
        # Initialize components
        self.queue = LocalQueue()
        self.client = BackendClient(base_url=backend_url)
        
        logger.info(f"SyncManager initialized (backend: {backend_url})")
    
    def _sync_once(self) -> dict:
        """
        Perform one sync cycle.
        
        Returns:
            Dict with sync results
        """
        # Check if backend is online
        if not self.client.is_online():
            logger.debug("Backend offline, skipping sync")
            return {"status": "offline", "synced": 0}
        
        # Get pending scans
        pending = self.queue.get_pending_scans(limit=self.batch_size)
        
        if not pending:
            logger.debug("No pending scans to sync")
            return {"status": "idle", "synced": 0}
        
        logger.info(f"Syncing {len(pending)} pending scans...")
        
        synced_count = 0
        failed_count = 0
        
        for record in pending:
            try:
                # Upload to backend
                response = self.client.save_scan_result(
                    filename=record["filename"],
                    label=record["label"],
                    file_hash=record["file_hash"]
                )
                
                if response:
                    # Mark as synced
                    self.queue.mark_as_synced(record["id"])
                    synced_count += 1
                    logger.debug(f"Synced: {record['filename']}")
                else:
                    # Increment attempt counter
                    self.queue.increment_sync_attempts(record["id"])
                    failed_count += 1
                    logger.warning(f"Failed to sync: {record['filename']}")
                
                # Small delay between uploads
                time.sleep(0.1)
                
            except Exception as e:
                logger.error(f"Error syncing record {record['id']}: {e}")
                self.queue.increment_sync_attempts(record["id"])
                failed_count += 1
        
        logger.info(f"Sync complete: {synced_count} synced, {failed_count} failed")
        
        return {
            "status": "synced",
            "synced": synced_count,
            "failed": failed_count
        }
    
    def _run_loop(self):
        """Background sync loop."""
        logger.info("Sync loop started")
        
        while self.running:
            try:
                self._sync_once()
            except Exception as e:
                logger.error(f"Sync error: {e}")
            
            # Wait for next cycle
            time.sleep(self.sync_interval)
        
        logger.info("Sync loop stopped")
    
    def start(self):
        """Start background sync service."""
        if self.running:
            logger.warning("Sync manager already running")
            return
        
        self.running = True
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()
        logger.info("Sync manager started")
    
    def stop(self):
        """Stop background sync service."""
        if not self.running:
            return
        
        logger.info("Stopping sync manager...")
        self.running = False
        
        if self._thread:
            self._thread.join(timeout=5)
        
        self.client.close()
        logger.info("Sync manager stopped")
    
    def sync_now(self) -> dict:
        """
        Trigger immediate sync (manual).
        
        Returns:
            Sync results
        """
        logger.info("Manual sync triggered")
        return self._sync_once()
    
    def get_status(self) -> dict:
        """
        Get current sync status.
        
        Returns:
            Status dict with queue info and connection status
        """
        stats = self.queue.get_stats()
        online = self.client.is_online()
        
        return {
            "running": self.running,
            "online": online,
            "queue_stats": stats,
            "backend_url": self.backend_url
        }


# Example usage
if __name__ == "__main__":
    sync_manager = SyncManager()
    sync_manager.start()
    
    # Let it run for a while
    try:
        while True:
            status = sync_manager.get_status()
            print(f"Status: {status}")
            time.sleep(10)
    except KeyboardInterrupt:
        print("\nStopping...")
        sync_manager.stop()

