import time
import psutil
import threading
import os
# Import scanner dari arsitektur lokal Dekstop_V2 Anda
from core.scanner import MalwareScanner

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
                # Catat CPU (dalam %) dan RAM (diubah dari bytes ke MB) setiap interval 0.1 detik
                cpu = self.process.cpu_percent(interval=0.1)
                mem = self.process.memory_info().rss / (1024 * 1024)
                self.cpu_usage.append(cpu)
                self.memory_usage.append(mem)
            except psutil.NoSuchProcess:
                break
                
    def stop(self):
        self.running = False

def run_on_device_test(file_path):
    print("Memuat model ONNX ke dalam memory...")
    scanner = MalwareScanner()
    # Menggunakan is_full_scan (Aggressive Mode) untuk beban CPU maksimal
    scanner.load_model(aggressive=True)
    
    # Siapkan Profiling
    pid = os.getpid()
    profiler = Profiler(pid)
    
    print(f"Mulai scanning file: {file_path}")
    profiler.start()
    start_time = time.time()
    
    # Jalankan proses inferensi / prediksi
    result = scanner.scan_file(file_path, is_full_scan=True)
    
    # Berhenti
    end_time = time.time()
    profiler.stop()
    profiler.join()
    
    # Hitung Rekap Utilisation
    total_time = end_time - start_time
    avg_cpu = sum(profiler.cpu_usage) / len(profiler.cpu_usage) if profiler.cpu_usage else 0
    peak_cpu = max(profiler.cpu_usage, default=0)
    peak_ram = max(profiler.memory_usage, default=0)
    
    print("\n" + "="*30)
    print("HASIL PENGUJIAN ON-DEVICE ML")
    print("="*30)
    print(f"Hasil Deteksi  : {result['result']}")
    print(f"Waktu Deteksi  : {total_time:.4f} Detik")
    print(f"Rata-rata CPU  : {avg_cpu:.2f} %")
    print(f"CPU Maksimal   : {peak_cpu:.2f} %")
    print(f"RAM Maksimal   : {peak_ram:.2f} MB")
    print("="*30)

if __name__ == "__main__":
    # Ganti path ini ke sampel file Anda 
    target_file = "async getAllGigs return.txt" 
    
    if os.path.exists(target_file):
        run_on_device_test(target_file)
    else:
        print(f"File {target_file} tidak ditemukan!")
