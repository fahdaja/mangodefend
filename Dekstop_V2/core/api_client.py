"""
Backend API Client - HTTP client for communicating with FastAPI backend
Handles scan result uploads and history retrieval
"""
import requests
from typing import Dict, List, Optional
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class BackendClient:
    """HTTP client for backend API communication."""
    
    def __init__(self, base_url: str = "http://localhost:8000", timeout: int = 10):
        """
        Initialize backend client.
        
        Args:
            base_url: Base URL of the backend API
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        
        # Create session with connection pooling
        self.session = requests.Session()
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=3,
            backoff_factor=1,  # 1s, 2s, 4s
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"]
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def is_online(self) -> bool:
        """
        Quick check if backend is online.
        
        Returns:
            True if backend is reachable
        """
        try:
            response = self.session.get(
                f"{self.base_url}/health",
                timeout=3  # Quick timeout for health check
            )
            return response.status_code == 200
        except Exception:
            return False
    
    def check_health(self) -> Optional[Dict]:
        """
        Check backend health and get service info.
        
        Returns:
            Health info dict or None if offline
        """
        try:
            response = self.session.get(
                f"{self.base_url}/health",
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Health check failed: {e}")
            return None
    
    def save_scan_result(self, filename: str, label: str, file_hash: str) -> Optional[Dict]:
        """
        Save scan result to backend.
        
        Args:
            filename: Name of the scanned file
            label: Scan result (Benign/Malware)
            file_hash: SHA256 hash of the file
            
        Returns:
            Response data or None if failed
        """
        try:
            payload = {
                "filename": filename,
                "label": label,
                "file_hash": file_hash
            }
            
            response = self.session.post(
                f"{self.base_url}/scanning-file",
                json=payload,
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"Failed to save scan result: {e}")
            return None
    
    def upload_and_scan_file(self, file_path: str, app_platform: str = "Desktop") -> Optional[Dict]:
        """
        Upload file to server for scanning.
        """
        try:
            with open(file_path, "rb") as f:
                files = {"file": f}
                data = {"app_platform": app_platform}
                
                response = self.session.post(
                    f"{self.base_url}/api/v1/scans/scan",
                    files=files,
                    data=data,
                    timeout=60
                )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Failed to upload and scan file: {e}")
            return None

    def get_scan_history(self, limit: int = 10, offset: int = 0) -> Optional[List[Dict]]:
        """
        Get scan history from backend.
        
        Args:
            limit: Number of records to fetch (1-100)
            offset: Offset for pagination
            
        Returns:
            List of scan records or None if failed
        """
        try:
            params = {
                "limit": min(limit, 100),  # Max 100
                "offset": max(offset, 0)   # Min 0
            }
            
            response = self.session.get(
                f"{self.base_url}/history-scan",
                params=params,
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            print(f"Failed to get scan history: {e}")
            return None
    
    def batch_upload(self, scan_results: List[Dict]) -> Dict[str, int]:
        """
        Upload multiple scan results in batch.
        
        Args:
            scan_results: List of scan result dicts
            
        Returns:
            Dict with success and failure counts
        """
        success_count = 0
        failure_count = 0
        
        for result in scan_results:
            response = self.save_scan_result(
                filename=result.get("filename"),
                label=result.get("label"),
                file_hash=result.get("file_hash")
            )
            
            if response:
                success_count += 1
            else:
                failure_count += 1
            
            # Small delay to avoid overwhelming server
            time.sleep(0.1)
        
        return {
            "success": success_count,
            "failed": failure_count
        }
    
    def close(self):
        """Close the session."""
        self.session.close()
    
    def __enter__(self):
        """Context manager entry."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        self.close()


# Example usage
if __name__ == "__main__":
    # Test connection
    client = BackendClient()
    
    # Check health
    health = client.check_health()
    print(f"Backend health: {health}")
    
    # Check if online
    online = client.is_online()
    print(f"Backend online: {online}")
    
    if online:
        # Save a test scan result
        result = client.save_scan_result(
            filename="test.exe",
            label="Malware",
            file_hash="test_hash_123"
        )
        print(f"Save result: {result}")
        
        # Get history
        history = client.get_scan_history(limit=5)
        print(f"History: {history}")
    
    client.close()
