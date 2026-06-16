# locustfile.py
import os
import random
from locust import HttpUser, task, between

# File configuration
DEFAULT_FILE_PATH = "/home/mr-pacman/Documents/Project Deteksi Malware Magang/mangodefend/Screenshot From 2026-05-31 15-08-43.png"
FALLBACK_FILE_SIZE = 236742  # 231.2 KB (matching the user's test image size)

class MangoDefendLoadTest(HttpUser):
    """
    Locust load test class for the MangoDefend ML Server API.
    Simulates multiple users performing scan requests, viewing logs,
    checking dashboard stats, and verifying health check endpoints.
    """
    # Think time between 0.5 to 1.5 seconds to simulate fast but realistic user traffic
    wait_time = between(0.5, 1.5)

    def on_start(self):
        """
        Runs once when a virtual user starts.
        Preloads the file content in memory to avoid high disk I/O overhead on the client machine.
        """
        self.file_name = "test_sample.png"
        self.file_bytes = b""
        
        # Try finding the file in several potential locations
        paths_to_try = [
            DEFAULT_FILE_PATH,
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Screenshot From 2026-05-31 15-08-43.png"),
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "Screenshot From 2026-05-31 15-08-43.png"),
        ]
        
        found = False
        for path in paths_to_try:
            if os.path.exists(path):
                try:
                    with open(path, "rb") as f:
                        self.file_bytes = f.read()
                    self.file_name = os.path.basename(path)
                    print(f"[{self.__class__.__name__}] Loaded sample file: {path} ({len(self.file_bytes)} bytes)")
                    found = True
                    break
                except Exception as e:
                    print(f"[{self.__class__.__name__}] Error reading {path}: {e}")
        
        if not found:
            # Generate random bytes as fallback to guarantee the test can run without a physical file
            print(f"[{self.__class__.__name__}] ⚠️ Sample file not found. Generating {FALLBACK_FILE_SIZE} bytes of mock data in-memory...")
            self.file_bytes = os.urandom(FALLBACK_FILE_SIZE)
            self.file_name = "mock_scans_fallback.png"

    @task
    def task_scan_file(self):
        """
        Simulates scanning a file. This is the primary high-load endpoint.
        """
        files = {
            'file': (self.file_name, self.file_bytes, 'application/octet-stream')
        }
        data = {
            'app_platform': random.choice(['Desktop', 'Mobile', 'WebClient'])
        }
        
        with self.client.post("/api/v1/scans/scan", files=files, data=data, name="/scan", catch_response=True) as response:
            if response.status_code == 500:
                body_text = response.text.lower()
                if "pool" in body_text or "queuepool" in body_text or "timeout" in body_text:
                    response.failure(f"DB Pool Exhausted: {response.text}")
                else:
                    response.failure(f"Server Error (500): {response.text}")
            elif response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"HTTP {response.status_code}: {response.text}")


