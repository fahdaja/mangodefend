#!/usr/bin/env python3
"""
benchmark_response_time.py
Script untuk mendokumentasikan hasil response time server,
menghitung persentase keberhasilan, dan mengukur performa server (SLA).
"""

import os
import sys
import time
import csv
import json
import argparse
import statistics
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests

# ANSI Colors untuk output terminal yang menarik
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

def print_banner():
    banner = f"""
{Colors.OKCYAN}{Colors.BOLD}======================================================================
     🚀 MangoDefend - Server Response Time & SLA Benchmark Tool 🚀
======================================================================{Colors.ENDC}
"""
    print(banner)

def send_request(url, method, headers, data, files, timeout):
    """
    Mengirimkan satu request HTTP dan mengukur response time-nya.
    """
    start_time = time.perf_counter()
    status_code = None
    success = False
    error_msg = ""
    
    try:
        if method.upper() == 'POST':
            if files:
                # requests menangani multipart/form-data otomatis jika parameter files diberikan
                response = requests.post(url, headers=headers, data=data, files=files, timeout=timeout)
            else:
                response = requests.post(url, headers=headers, json=data, timeout=timeout)
        else:
            response = requests.get(url, headers=headers, params=data, timeout=timeout)
            
        status_code = response.status_code
        elapsed_time_ms = (time.perf_counter() - start_time) * 1000
        
        # Sukses jika status code adalah 2xx
        if 200 <= response.status_code < 300:
            success = True
        else:
            error_msg = f"HTTP {response.status_code}"
            
    except requests.exceptions.Timeout:
        elapsed_time_ms = (time.perf_counter() - start_time) * 1000
        error_msg = "Timeout"
    except requests.exceptions.ConnectionError:
        elapsed_time_ms = (time.perf_counter() - start_time) * 1000
        error_msg = "Connection Error"
    except Exception as e:
        elapsed_time_ms = (time.perf_counter() - start_time) * 1000
        error_msg = str(e)
        
    return {
        "timestamp": datetime.now().isoformat(),
        "status_code": status_code or "ERROR",
        "elapsed_ms": round(elapsed_time_ms, 2),
        "success": success,
        "error_message": error_msg
    }

def run_benchmark(url, total_requests, concurrency, method, headers, data, files_payload, timeout, threshold_ms):
    results = []
    print(f"[*] Menjalankan pengujian ke: {Colors.BOLD}{url}{Colors.ENDC}")
    print(f"[*] Parameter: Method={method}, Total Request={total_requests}, Concurrency={concurrency}, Timeout={timeout}s")
    print(f"[*] Response Time Threshold SLA: {Colors.BOLD}{threshold_ms} ms{Colors.ENDC}")
    print("-" * 70)
    
    # Jika payload berupa file, kita harus membuka filenya berkali-kali untuk thread-safety
    # atau memuat isinya ke memori agar aman diakses oleh banyak thread.
    loaded_files = None
    if files_payload:
        loaded_files = {}
        for key, file_info in files_payload.items():
            file_name, file_path = file_info
            if os.path.exists(file_path):
                with open(file_path, 'rb') as f:
                    # Load file content to memory
                    loaded_files[key] = (file_name, f.read())
            else:
                print(f"{Colors.FAIL}[!] File tidak ditemukan: {file_path}{Colors.ENDC}")
                return None

    # Mulai thread pool executor
    start_bench = time.perf_counter()
    completed = 0
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = []
        for _ in range(total_requests):
            # Siapkan file pointer untuk setiap request jika ada payload file
            current_files = None
            if loaded_files:
                current_files = {}
                for key, (file_name, file_bytes) in loaded_files.items():
                    current_files[key] = (file_name, file_bytes)
            
            futures.append(
                executor.submit(send_request, url, method, headers, data, current_files, timeout)
            )
            
        for future in as_completed(futures):
            res = future.result()
            results.append(res)
            completed += 1
            if completed % max(1, total_requests // 10) == 0 or completed == total_requests:
                print(f"[~] Progress: {completed}/{total_requests} request selesai...")
                
    total_duration = time.perf_counter() - start_bench
    print("-" * 70)
    print(f"{Colors.OKGREEN}[+] Pengujian selesai dalam {total_duration:.2f} detik!{Colors.ENDC}\n")
    return results

def calculate_metrics(results, threshold_ms):
    if not results:
        return {}
        
    latencies = [r["elapsed_ms"] for r in results]
    success_latencies = [r["elapsed_ms"] for r in results if r["success"]]
    
    total = len(results)
    success_count = sum(1 for r in results if r["success"])
    failed_count = total - success_count
    
    success_rate = (success_count / total) * 100 if total > 0 else 0
    
    # Hitung statistik response time
    min_latency = min(latencies)
    max_latency = max(latencies)
    avg_latency = statistics.mean(latencies)
    median_latency = statistics.median(latencies)
    
    # Percentiles
    sorted_latencies = sorted(latencies)
    p90 = sorted_latencies[int(total * 0.90)] if total > 0 else 0
    p95 = sorted_latencies[int(total * 0.95)] if total > 0 else 0
    p99 = sorted_latencies[int(total * 0.99)] if total > 0 else 0
    
    # Hitung persentase keberhasilan response time berdasarkan threshold
    # 1. Persentase dari TOTAL request yang <= threshold
    total_under_threshold = sum(1 for r in results if r["elapsed_ms"] <= threshold_ms)
    pct_total_under_threshold = (total_under_threshold / total) * 100
    
    # 2. Persentase dari request SUKSES yang <= threshold
    success_under_threshold = sum(1 for r in results if r["success"] and r["elapsed_ms"] <= threshold_ms)
    pct_success_under_threshold = (success_under_threshold / success_count) * 100 if success_count > 0 else 0
    
    # Distribusi Response Time
    distributions = {
        "<= 50ms": sum(1 for r in results if r["elapsed_ms"] <= 50),
        "51ms - 100ms": sum(1 for r in results if 50 < r["elapsed_ms"] <= 100),
        "101ms - 200ms": sum(1 for r in results if 100 < r["elapsed_ms"] <= 200),
        "201ms - 500ms": sum(1 for r in results if 200 < r["elapsed_ms"] <= 500),
        "501ms - 1000ms": sum(1 for r in results if 500 < r["elapsed_ms"] <= 1000),
        "> 1000ms": sum(1 for r in results if r["elapsed_ms"] > 1000)
    }
    
    return {
        "total": total,
        "success_count": success_count,
        "failed_count": failed_count,
        "success_rate": round(success_rate, 2),
        "min": round(min_latency, 2),
        "max": round(max_latency, 2),
        "avg": round(avg_latency, 2),
        "median": round(median_latency, 2),
        "p90": round(p90, 2),
        "p95": round(p95, 2),
        "p99": round(p99, 2),
        "threshold_ms": threshold_ms,
        "total_under_threshold": total_under_threshold,
        "pct_total_under_threshold": round(pct_total_under_threshold, 2),
        "success_under_threshold": success_under_threshold,
        "pct_success_under_threshold": round(pct_success_under_threshold, 2),
        "distributions": distributions
    }

def print_summary(metrics):
    if not metrics:
        return
        
    print(f"{Colors.HEADER}{Colors.BOLD}📊 RINGKASAN BENCHMARK HILIR & HULU PERFORMA SERVER{Colors.ENDC}")
    print("=" * 60)
    print(f"Total Request          : {metrics['total']}")
    
    success_color = Colors.OKGREEN if metrics['success_rate'] >= 95 else Colors.WARNING
    print(f"Request Sukses (2xx)   : {success_color}{metrics['success_count']} ({metrics['success_rate']}%){Colors.ENDC}")
    print(f"Request Gagal          : {Colors.FAIL if metrics['failed_count'] > 0 else Colors.ENDC}{metrics['failed_count']}")
    
    print("-" * 60)
    print(f"{Colors.BOLD}⏱️ Statistik Response Time:{Colors.ENDC}")
    print(f"Minimal                : {metrics['min']} ms")
    print(f"Maksimal               : {metrics['max']} ms")
    print(f"Rata-rata (Average)    : {metrics['avg']} ms")
    print(f"Median                 : {metrics['median']} ms")
    print(f"90th Percentile (P90)  : {metrics['p90']} ms")
    print(f"95th Percentile (P95)  : {metrics['p95']} ms")
    print(f"99th Percentile (P99)  : {metrics['p99']} ms")
    
    print("-" * 60)
    print(f"{Colors.OKCYAN}{Colors.BOLD}🎯 Metrik Kepatuhan Response Time (SLA Threshold: {metrics['threshold_ms']} ms):{Colors.ENDC}")
    
    # Warna persentase kepatuhan
    pct = metrics['pct_total_under_threshold']
    pct_color = Colors.OKGREEN if pct >= 90 else (Colors.WARNING if pct >= 75 else Colors.FAIL)
    
    print(f"Request Selesai <= {metrics['threshold_ms']} ms  : {pct_color}{metrics['total_under_threshold']} dari {metrics['total']} ({pct}%){Colors.ENDC}")
    
    pct_success = metrics['pct_success_under_threshold']
    pct_success_color = Colors.OKGREEN if pct_success >= 90 else (Colors.WARNING if pct_success >= 75 else Colors.FAIL)
    print(f"Persentase Keberhasilan Response Time : {pct_success_color}{pct_success}%{Colors.ENDC} dari total request sukses")
    
    print("-" * 60)
    print(f"{Colors.BOLD}📊 Distribusi Response Time:{Colors.ENDC}")
    for dist, count in metrics['distributions'].items():
        percentage = (count / metrics['total']) * 100
        bars = "█" * int(percentage // 5)
        print(f"  {dist:<15} : {count:<5} ({percentage:>5.1f}%) {bars}")
    print("=" * 60)

def save_to_csv(results, file_path):
    """Menyimpan setiap data request ke file CSV untuk dokumentasi audit."""
    try:
        keys = results[0].keys()
        with open(file_path, 'w', newline='', encoding='utf-8') as f:
            dict_writer = csv.DictWriter(f, fieldnames=keys)
            dict_writer.writeheader()
            dict_writer.writerows(results)
        print(f"[+] Detail data response time sukses disimpan ke: {Colors.BOLD}{file_path}{Colors.ENDC}")
    except Exception as e:
        print(f"{Colors.FAIL}[!] Gagal menyimpan CSV: {e}{Colors.ENDC}")

def save_markdown_report(metrics, file_path, target_url, method):
    """Menyimpan kesimpulan benchmark dalam format Markdown yang rapi."""
    try:
        dist_rows = ""
        for dist, count in metrics['distributions'].items():
            pct = (count / metrics['total']) * 100
            bars = "█" * int(pct // 5)
            dist_rows += f"| {dist} | {count} | {pct:.1f}% | {bars} |\n"

        report_content = f"""# 📊 Laporan Dokumentasi Response Time & Performa Server

*Dibuat otomatis pada: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}*

## 🔌 Detail Endpoint Pengujian
- **Target URL**: `{target_url}`
- **Method**: `{method}`
- **Target SLA Threshold**: `{metrics['threshold_ms']} ms`

## 📈 Parameter & Ringkasan Performa
| Parameter | Nilai |
| :--- | :--- |
| **Total Request** | {metrics['total']} |
| **Sukses (HTTP 2xx)** | {metrics['success_count']} ({metrics['success_rate']}%) |
| **Gagal** | {metrics['failed_count']} |

## ⏱️ Statistik Latensi (Response Time)
| Metrik | Durasi (ms) |
| :--- | :--- |
| **Minimal** | {metrics['min']} ms |
| **Maksimal** | {metrics['max']} ms |
| **Rata-rata (Average)** | {metrics['avg']} ms |
| **Median** | {metrics['median']} ms |
| **90th Percentile (P90)** | {metrics['p90']} ms |
| **95th Percentile (P95)** | {metrics['p95']} ms |
| **99th Percentile (P99)** | {metrics['p99']} ms |

## 🎯 Evaluasi Persentase Keberhasilan Response Time (SLA)
> [!IMPORTANT]
> Target Keberhasilan Response Time (SLA) diatur pada: **`{metrics['threshold_ms']} ms`**

- **Total Request di bawah SLA**: **{metrics['pct_total_under_threshold']}%** ({metrics['total_under_threshold']} dari {metrics['total']} request)
- **Persentase Keberhasilan Response Time**: **{metrics['pct_success_under_threshold']}%** (dari total request sukses, {metrics['success_under_threshold']} request sukses memiliki response time <= {metrics['threshold_ms']} ms)

## 📊 Distribusi Latensi
| Rentang Waktu | Jumlah Request | Persentase | Grafik |
| :--- | :--- | :--- | :--- |
{dist_rows}

---
*Laporan ini digunakan sebagai dokumentasi resmi hasil pengujian load dan response time server.*
"""
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(report_content)
        print(f"[+] Laporan ringkasan performa sukses disimpan ke: {Colors.BOLD}{file_path}{Colors.ENDC}")
    except Exception as e:
        print(f"{Colors.FAIL}[!] Gagal menyimpan laporan Markdown: {e}{Colors.ENDC}")

def main():
    print_banner()
    
    # Parsing argumen CLI
    parser = argparse.ArgumentParser(description="MangoDefend Response Time Benchmarking Script")
    parser.add_argument("--url", default="http://localhost:8000/health", help="Target URL server yang akan diuji (default: http://localhost:8000/health)")
    parser.add_argument("-n", "--requests", type=int, default=100, help="Jumlah total request yang akan dikirim (default: 100)")
    parser.add_argument("-c", "--concurrency", type=int, default=5, help="Jumlah request concurrent (koneksi paralel) (default: 5)")
    parser.add_argument("-t", "--threshold", type=int, default=200, help="SLA Response time threshold dalam milidetik untuk persentase keberhasilan (default: 200)")
    parser.add_argument("-m", "--method", default="GET", choices=["GET", "POST"], help="HTTP Method (GET atau POST) (default: GET)")
    parser.add_argument("--timeout", type=int, default=10, help="Timeout koneksi HTTP dalam detik (default: 10)")
    parser.add_argument("--data", help="JSON data untuk request body (jika POST) atau parameter (jika GET)")
    parser.add_argument("--headers", help="JSON string untuk custom HTTP Headers")
    
    # Opsi khusus upload file
    parser.add_argument("--upload-file", help="Path file jika ingin melakukan simulasi upload scan file")
    parser.add_argument("--upload-key", default="file", help="Form field name untuk file upload (default: file)")
    parser.add_argument("--app-platform", default="Mobile", help="Nilai form parameter app_platform (default: Mobile)")
    
    # Opsi penyimpanan output
    parser.add_argument("--output-csv", default="response_times.csv", help="Nama file output detail CSV (default: response_times.csv)")
    parser.add_argument("--output-report", default="benchmark_report.md", help="Nama file output laporan Markdown (default: benchmark_report.md)")
    
    # Shortcut preset untuk scan endpoint MangoDefend
    parser.add_argument("--scan-preset", action="store_true", help="Gunakan konfigurasi preset otomatis untuk menguji endpoint scan malware (/api/v1/scans/scan)")
    
    args = parser.parse_args()
    
    url = args.url
    method = args.method
    headers = {}
    data = None
    files_payload = None
    
    # Parse custom headers
    if args.headers:
        try:
            headers = json.loads(args.headers)
        except Exception as e:
            print(f"{Colors.WARNING}[!] Gagal parse custom headers JSON: {e}. Mengabaikan headers.{Colors.ENDC}")

    # Parse custom data
    if args.data:
        try:
            data = json.loads(args.data)
        except Exception as e:
            # Jika bukan JSON valid, biarkan sebagai plain string / form data
            data = args.data
            
    # Jika menggunakan preset scan MangoDefend
    if args.scan_preset:
        url = "http://localhost:8000/api/v1/scans/scan"
        method = "POST"
        
        # Cari file gambar default di direktori project jika tidak ada argumen upload-file
        file_path = args.upload_file
        if not file_path:
            # Cari file PNG/JPG di direktori parent
            parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            possible_files = [
                os.path.join(parent_dir, "Screenshot From 2026-05-31 15-08-43.png"),
                os.path.join(os.path.dirname(os.path.abspath(__file__)), "Screenshot From 2026-05-31 15-08-43.png")
            ]
            for f in possible_files:
                if os.path.exists(f):
                    file_path = f
                    break
            
        if not file_path or not os.path.exists(file_path):
            print(f"{Colors.WARNING}[!] Preset scan diaktifkan tetapi file sampel scan tidak ditemukan.{Colors.ENDC}")
            print(f"[*] Silakan gunakan opsi --upload-file untuk menentukan file scan.")
            sys.exit(1)
            
        print(f"[*] {Colors.OKBLUE}Mengaktifkan Preset Pengujian Scan Malware MangoDefend{Colors.ENDC}")
        print(f"[*] Menggunakan file scan: {Colors.BOLD}{file_path}{Colors.ENDC}")
        
        files_payload = {args.upload_key: (os.path.basename(file_path), file_path)}
        data = {"app_platform": args.app_platform}
    
    # Jika file upload diberikan secara manual tanpa preset
    elif args.upload_file:
        if not os.path.exists(args.upload_file):
            print(f"{Colors.FAIL}[!] File upload tidak ditemukan: {args.upload_file}{Colors.ENDC}")
            sys.exit(1)
        files_payload = {args.upload_key: (os.path.basename(args.upload_file), args.upload_file)}
        if not data:
            data = {}
            
    # Jalankan benchmark
    results = run_benchmark(
        url=url,
        total_requests=args.requests,
        concurrency=args.concurrency,
        method=method,
        headers=headers,
        data=data,
        files_payload=files_payload,
        timeout=args.timeout,
        threshold_ms=args.threshold
    )
    
    if not results:
        print(f"{Colors.FAIL}[!] Tidak ada data hasil pengujian. Pastikan server aktif dan URL benar.{Colors.ENDC}")
        sys.exit(1)
        
    # Kalkulasi metrik
    metrics = calculate_metrics(results, args.threshold)
    
    # Print ke CLI
    print_summary(metrics)
    
    # Simpan hasil dokumentasi
    save_to_csv(results, args.output_csv)
    save_markdown_report(metrics, args.output_report, url, method)
    
    print(f"\n{Colors.OKGREEN}{Colors.BOLD}🎉 Selesai! Gunakan laporan di atas untuk dokumentasi analisis Anda.{Colors.ENDC}\n")

if __name__ == "__main__":
    main()
