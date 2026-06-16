"""
Embedded Backend Server - Runs FastAPI inside desktop application
No external hosting needed, backend runs locally
"""
import os
import sys
import threading
import time
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class EmbeddedBackend:
    """Embedded FastAPI backend that runs in background thread."""
    
    def __init__(self, host: str = "127.0.0.1", port: int = 8000):
        """
        Initialize embedded backend.
        
        Args:
            host: Host to bind to (127.0.0.1 for localhost only)
            port: Port to run on
        """
        self.host = host
        self.port = port
        self.server_thread = None
        self.running = False
        
        # Setup database path
        self.db_path = Path.home() / ".mangodefend" / "database.db"
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
    
    def _setup_database(self):
        """Setup SQLite database for embedded backend."""
        import sqlite3
        
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        # Create scan_results table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS scan_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT NOT NULL,
                label TEXT NOT NULL,
                file_hash TEXT UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        conn.close()
        
        logger.info(f"Database initialized at {self.db_path}")
    
    def _create_app(self):
        """Create FastAPI application."""
        from fastapi import FastAPI, HTTPException
        from fastapi.middleware.cors import CORSMiddleware
        from pydantic import BaseModel
        import sqlite3
        from datetime import datetime
        
        app = FastAPI(
            title="MangoDefend Embedded Backend",
            description="Local backend for MangoDefend desktop app",
            version="1.0.0"
        )
        
        # CORS for localhost
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        
        # Models
        class ScanResult(BaseModel):
            filename: str
            label: str
            file_hash: str = None
        
        # Database helper
        def get_db():
            conn = sqlite3.connect(str(self.db_path))
            conn.row_factory = sqlite3.Row
            return conn
        
        # Routes
        @app.get("/health")
        def health_check():
            return {
                "status": "healthy",
                "service": "MangoDefend Embedded Backend",
                "version": "1.0.0",
                "mode": "embedded"
            }
        
        @app.post("/scanning-file")
        def save_scan_result(scan: ScanResult):
            try:
                conn = get_db()
                cursor = conn.cursor()
                
                # Check for duplicate
                if scan.file_hash:
                    cursor.execute(
                        "SELECT id FROM scan_results WHERE file_hash = ?",
                        (scan.file_hash,)
                    )
                    if cursor.fetchone():
                        return {
                            "message": "File has already been scanned",
                            "duplicate": True
                        }
                
                # Insert new scan
                cursor.execute(
                    """INSERT INTO scan_results (filename, label, file_hash) 
                       VALUES (?, ?, ?)""",
                    (scan.filename, scan.label, scan.file_hash)
                )
                conn.commit()
                scan_id = cursor.lastrowid
                conn.close()
                
                return {
                    "message": "File scanned successfully",
                    "id": scan_id
                }
            
            except Exception as e:
                logger.error(f"Error saving scan result: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @app.get("/history-scan")
        def get_scan_history(limit: int = 10):
            try:
                conn = get_db()
                cursor = conn.cursor()
                
                cursor.execute(
                    """SELECT id, filename, label, file_hash, created_at 
                       FROM scan_results 
                       ORDER BY created_at DESC 
                       LIMIT ?""",
                    (limit,)
                )
                
                results = []
                for row in cursor.fetchall():
                    results.append({
                        "id": row["id"],
                        "filename": row["filename"],
                        "label": row["label"],
                        "file_hash": row["file_hash"],
                        "created_at": row["created_at"]
                    })
                
                conn.close()
                return results
            
            except Exception as e:
                logger.error(f"Error getting history: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        @app.get("/stats")
        def get_stats():
            """Get statistics."""
            try:
                conn = get_db()
                cursor = conn.cursor()
                
                # Total scans
                cursor.execute("SELECT COUNT(*) as total FROM scan_results")
                total = cursor.fetchone()["total"]
                
                # By label
                cursor.execute(
                    """SELECT label, COUNT(*) as count 
                       FROM scan_results 
                       GROUP BY label"""
                )
                by_label = {row["label"]: row["count"] for row in cursor.fetchall()}
                
                conn.close()
                
                return {
                    "total_scans": total,
                    "by_label": by_label
                }
            
            except Exception as e:
                logger.error(f"Error getting stats: {e}")
                raise HTTPException(status_code=500, detail=str(e))
        
        return app
    
    def _run_server(self):
        """Run uvicorn server in thread."""
        import uvicorn
        
        try:
            # Setup database
            self._setup_database()
            
            # Create app
            app = self._create_app()
            
            # Run server
            logger.info(f"Starting embedded backend on {self.host}:{self.port}")
            
            config = uvicorn.Config(
                app,
                host=self.host,
                port=self.port,
                log_level="error",  # Suppress uvicorn logs
                access_log=False
            )
            
            server = uvicorn.Server(config)
            server.run()
            
        except Exception as e:
            logger.error(f"Embedded backend error: {e}")
            self.running = False
    
    def start(self):
        """Start embedded backend in background thread."""
        if self.running:
            logger.warning("Backend already running")
            return
        
        self.running = True
        self.server_thread = threading.Thread(
            target=self._run_server,
            daemon=True,
            name="EmbeddedBackend"
        )
        self.server_thread.start()
        
        # Wait for server to start
        time.sleep(2)
        
        # Verify server is running
        try:
            import requests
            response = requests.get(f"http://{self.host}:{self.port}/health", timeout=2)
            if response.status_code == 200:
                logger.info("✅ Embedded backend started successfully")
                return True
        except Exception as e:
            logger.error(f"Failed to start embedded backend: {e}")
            self.running = False
            return False
    
    def stop(self):
        """Stop embedded backend."""
        self.running = False
        logger.info("Embedded backend stopped")
    
    def is_running(self) -> bool:
        """Check if backend is running."""
        return self.running and self.server_thread and self.server_thread.is_alive()


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    backend = EmbeddedBackend()
    backend.start()
    
    print("Embedded backend running at http://127.0.0.1:8000")
    print("Try: http://127.0.0.1:8000/health")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        backend.stop()
        print("\nStopped")
