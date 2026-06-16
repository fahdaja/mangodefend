"""
Local Queue Manager - SQLite database for offline scan results
Stores scan results locally and syncs to backend when online
"""
import sqlite3
import os
from datetime import datetime
from typing import List, Dict, Optional
from pathlib import Path


class LocalQueue:
    """Manages local SQLite queue for scan results."""
    
    def __init__(self, db_path: Optional[str] = None):
        """
        Initialize local queue database.
        
        Args:
            db_path: Path to SQLite database file. If None, uses default location.
        """
        if db_path is None:
            # Default: store in app directory
            app_dir = Path(__file__).parent.parent
            db_path = app_dir / "local_queue.db"
        
        self.db_path = str(db_path)
        self._init_database()
    
    def _init_database(self):
        """Create database and tables if they don't exist."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS scan_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT NOT NULL,
                label TEXT NOT NULL,
                file_hash TEXT NOT NULL UNIQUE,
                scan_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                synced INTEGER DEFAULT 0,
                sync_attempts INTEGER DEFAULT 0,
                last_sync_attempt TIMESTAMP
            )
        """)
        
        # Create indexes for performance
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_synced 
            ON scan_queue(synced)
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_file_hash 
            ON scan_queue(file_hash)
        """)
        
        conn.commit()
        conn.close()
    
    def add_scan_result(self, filename: str, label: str, file_hash: str) -> bool:
        """
        Add a scan result to the queue.
        
        Args:
            filename: Name of the scanned file
            label: Scan result label (Benign/Malware)
            file_hash: SHA256 hash of the file
            
        Returns:
            True if added successfully, False if duplicate
        """
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT INTO scan_queue (filename, label, file_hash, scan_date)
                VALUES (?, ?, ?, ?)
            """, (filename, label, file_hash, datetime.now()))
            
            conn.commit()
            conn.close()
            return True
            
        except sqlite3.IntegrityError:
            # Duplicate file_hash
            return False
    
    def get_pending_scans(self, limit: int = 50) -> List[Dict]:
        """
        Get pending scans that haven't been synced yet.
        
        Args:
            limit: Maximum number of records to return
            
        Returns:
            List of pending scan records
        """
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row  # Enable column access by name
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT id, filename, label, file_hash, scan_date, sync_attempts
            FROM scan_queue
            WHERE synced = 0
            ORDER BY scan_date ASC
            LIMIT ?
        """, (limit,))
        
        rows = cursor.fetchall()
        conn.close()
        
        # Convert to list of dicts
        return [dict(row) for row in rows]
    
    def mark_as_synced(self, record_id: int) -> bool:
        """
        Mark a scan record as successfully synced.
        
        Args:
            record_id: ID of the record to mark
            
        Returns:
            True if successful
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE scan_queue
            SET synced = 1, last_sync_attempt = ?
            WHERE id = ?
        """, (datetime.now(), record_id))
        
        conn.commit()
        conn.close()
        return True
    
    def increment_sync_attempts(self, record_id: int) -> bool:
        """
        Increment sync attempt counter for a record.
        
        Args:
            record_id: ID of the record
            
        Returns:
            True if successful
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE scan_queue
            SET sync_attempts = sync_attempts + 1,
                last_sync_attempt = ?
            WHERE id = ?
        """, (datetime.now(), record_id))
        
        conn.commit()
        conn.close()
        return True
    
    def get_queue_size(self) -> int:
        """
        Get the number of pending scans in the queue.
        
        Returns:
            Number of unsynced records
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM scan_queue WHERE synced = 0
        """)
        
        count = cursor.fetchone()[0]
        conn.close()
        return count
    
    def cleanup_old_records(self, days: int = 30) -> int:
        """
        Delete synced records older than specified days.
        
        Args:
            days: Number of days to keep
            
        Returns:
            Number of records deleted
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            DELETE FROM scan_queue
            WHERE synced = 1
            AND scan_date < datetime('now', '-' || ? || ' days')
        """, (days,))
        
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        return deleted
    
    def get_stats(self) -> Dict:
        """
        Get queue statistics.
        
        Returns:
            Dictionary with queue stats
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Total records
        cursor.execute("SELECT COUNT(*) FROM scan_queue")
        total = cursor.fetchone()[0]
        
        # Pending records
        cursor.execute("SELECT COUNT(*) FROM scan_queue WHERE synced = 0")
        pending = cursor.fetchone()[0]
        
        # Synced records
        cursor.execute("SELECT COUNT(*) FROM scan_queue WHERE synced = 1")
        synced = cursor.fetchone()[0]
        
        conn.close()
        
        return {
            "total": total,
            "pending": pending,
            "synced": synced
        }


# Example usage
if __name__ == "__main__":
    queue = LocalQueue()
    
    # Add a test scan result
    success = queue.add_scan_result(
        filename="test.exe",
        label="Malware",
        file_hash="abc123def456"
    )
    print(f"Added: {success}")
    
    # Get pending scans
    pending = queue.get_pending_scans()
    print(f"Pending scans: {len(pending)}")
    
    # Get stats
    stats = queue.get_stats()
    print(f"Stats: {stats}")
