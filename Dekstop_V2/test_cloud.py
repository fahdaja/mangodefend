import time
import psutil
import threading
import requests
import os

class Profiler(threading.Thread):
    def __init__(self, pid):
        super().__init__()
        self.process = psutil.Process(pid)
        self.running = True
        self.cpu_usage = []
        self.memory_usage = []
        
    def run(self):
        while self.running:
            try:
                cpu = self.process.cpu_percent(interval=0.1)
                mem = self.process.memory_info().rss / (1024 * 1024)
                self.cpu_usage.append(cpu)
                self.memory_usage.append(mem)
            except psutil.NoSuchProcess:
                break
                
    def stop(self):
        self.running = False

def run_cloud_test(file_path, api_url):
    pid = os.getpid()
    profiler = Profiler(pid)
    
    print(f"Mulai upload dan scanning file: {file_path}")
    profiler.start()
    start_time = time.time()
    
    try:
        # Menembak ke REST API Cloud Anda
        with open(file_path, "rb") as f:
            files = {"file": f}
            # Sesuaikan Header/Bearer Token jika Backend Anda butuh autentikasi
            response = requests.post(api_url, files=files, data={"app_platform": "Desktop"})
            result = response.json()
    except Exception as e:
        result = {"error": str(e)}
        
    end_time = time.time()
    profiler.stop()
    profiler.join()
    
    total_time = end_time - start_time
    avg_cpu = sum(profiler.cpu_usage) / len(profiler.cpu_usage) if profiler.cpu_usage else 0
    peak_cpu = max(profiler.cpu_usage, default=0)
    peak_ram = max(profiler.memory_usage, default=0)
    
    print("\n" + "="*30)
    print("HASIL PENGUJIAN CLOUD ML (Klien/Aplikasi)")
    print("="*30)
    print(f"Response API   : {result}")
    print(f"Total Waktu    : {total_time:.4f} Detik")
    print(f"Rata-rata CPU  : {avg_cpu:.2f} %")
    print(f"CPU Maksimal   : {peak_cpu:.2f} %")
    print(f"RAM Maksimal   : {peak_ram:.2f} MB")
    print("="*30)

if __name__ == "__main__":
    target_file = "async getAllGigs return.txt"
    # Ganti URL menggunakan URL Endpoint Cloud Anda yang sebenarnya
    cloud_api_url = "http://localhost:8000/api/v1/scans/scan" 
    
    if os.path.exists(target_file):
        run_cloud_test(target_file, cloud_api_url)
    else:
        print(f"File {target_file} tidak ditemukan!")
