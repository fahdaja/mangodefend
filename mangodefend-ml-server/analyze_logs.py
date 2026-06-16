#!/usr/bin/env python3
# analyze_logs.py
import os
import re
import statistics

# Set colors
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def analyze():
    # Cari file log di root atau subfolder app/
    paths_to_try = [
        "mangodefend_scan.log",
        "app/mangodefend_scan.log",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "mangodefend_scan.log"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "app", "mangodefend_scan.log")
    ]
    
    log_file_path = None
    for path in paths_to_try:
        if os.path.exists(path):
            log_file_path = path
            break
            
    if not log_file_path:
        print(f"{Colors.FAIL}[!] File log 'mangodefend_scan.log' tidak ditemukan!{Colors.ENDC}")
        print("[*] Pastikan Anda telah melakukan pengujian scan file setelah me-restart server.")
        return
        
    print(f"{Colors.OKGREEN}[*] Membaca file log dari: {Colors.BOLD}{log_file_path}{Colors.ENDC}\n")
    
    with open(log_file_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    # Pola regex untuk mengekstrak data
    read_pattern = re.compile(r"Baca File \(Read\)\s*:\s*([\d\.]+)\s*ms")
    conv_pattern = re.compile(r"Konversi Gambar\s*:\s*([\d\.]+)\s*ms")
    inf_pattern = re.compile(r"Inferensi Model ML\s*:\s*([\d\.]+)\s*ms")
    db_pattern = re.compile(r"Simpan ke Database\s*:\s*([\d\.]+)\s*ms")
    total_pattern = re.compile(r"Total Waktu Proses\s*:\s*([\d\.]+)\s*ms")
    size_pattern = re.compile(r"Ukuran:\s*(\d+)\s*bytes")
    
    read_times = [float(x) for x in read_pattern.findall(content)]
    conv_times = [float(x) for x in conv_pattern.findall(content)]
    inf_times = [float(x) for x in inf_pattern.findall(content)]
    db_times = [float(x) for x in db_pattern.findall(content)]
    total_times = [float(x) for x in total_pattern.findall(content)]
    sizes = [float(x) for x in size_pattern.findall(content)]
    
    total_scans = len(total_times)
    if total_scans == 0:
        print(f"{Colors.WARNING}[!] Belum ada log pengukuran waktu yang tercatat.{Colors.ENDC}")
        return
        
    avg_read = statistics.mean(read_times)
    avg_conv = statistics.mean(conv_times)
    avg_inf = statistics.mean(inf_times)
    avg_db = statistics.mean(db_times)
    avg_total = statistics.mean(total_times)
    
    # Hitung persentase dari rata-rata total
    pct_read = (avg_read / avg_total) * 100 if avg_total > 0 else 0
    pct_conv = (avg_conv / avg_total) * 100 if avg_total > 0 else 0
    pct_inf = (avg_inf / avg_total) * 100 if avg_total > 0 else 0
    pct_db = (avg_db / avg_total) * 100 if avg_total > 0 else 0
    
    steps = [
        {"name": "Baca File (Read)", "duration": avg_read, "percentage": pct_read},
        {"name": "Konversi Gambar", "duration": avg_conv, "percentage": pct_conv},
        {"name": "Inferensi Model ML", "duration": avg_inf, "percentage": pct_inf},
        {"name": "Simpan ke Database", "duration": avg_db, "percentage": pct_db}
    ]
    
    print("=" * 65)
    print(f"📊 {Colors.BOLD}ANALISIS RATA-RATA WAKTU PROSES INTERNAL SERVER ({total_scans} SCANS){Colors.ENDC}")
    if sizes:
        avg_size = statistics.mean(sizes)
        size_str = f"{avg_size/1024:.1f} KB" if avg_size < 1024*1024 else f"{avg_size/(1024*1024):.2f} MB"
        print(f"ℹ️  {Colors.BOLD}Rata-rata Ukuran File    : {size_str} ({int(avg_size)} bytes){Colors.ENDC}")
    print("=" * 65)
    
    for step in steps:
        pct = step["percentage"]
        bars = "█" * int(pct // 2)
        print(f"  - {step['name']:<22} : {step['duration']:>7.2f} ms ({pct:>5.1f}%) {Colors.OKBLUE}{bars}{Colors.ENDC}")
        
    print("-" * 65)
    print(f"  {Colors.BOLD}Total Waktu Proses Server : {avg_total:.2f} ms (100.0%){Colors.ENDC}")
    print("=" * 65)
    
if __name__ == "__main__":
    analyze()
