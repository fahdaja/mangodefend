# 📊 Laporan Dokumentasi Response Time & Performa Server

*Dibuat otomatis pada: 2026-06-10 17:12:46*

## 🔌 Detail Endpoint Pengujian
- **Target URL**: `http://localhost:8000/api/v1/scans/scan`
- **Method**: `POST`
- **Target SLA Threshold**: `500 ms`

## 📈 Parameter & Ringkasan Performa
| Parameter | Nilai |
| :--- | :--- |
| **Total Request** | 100 |
| **Sukses (HTTP 2xx)** | 100 (100.0%) |
| **Gagal** | 0 |

## ⏱️ Statistik Latensi (Response Time)
| Metrik | Durasi (ms) |
| :--- | :--- |
| **Minimal** | 176.03 ms |
| **Maksimal** | 485.84 ms |
| **Rata-rata (Average)** | 336.44 ms |
| **Median** | 319.71 ms |
| **90th Percentile (P90)** | 426.85 ms |
| **95th Percentile (P95)** | 436.27 ms |
| **99th Percentile (P99)** | 485.84 ms |

## 🎯 Evaluasi Persentase Keberhasilan Response Time (SLA)
> [!IMPORTANT]
> Target Keberhasilan Response Time (SLA) diatur pada: **`500 ms`**

- **Total Request di bawah SLA**: **100.0%** (100 dari 100 request)
- **Persentase Keberhasilan Response Time**: **100.0%** (dari total request sukses, 100 request sukses memiliki response time <= 500 ms)

## 📊 Distribusi Latensi
| Rentang Waktu | Jumlah Request | Persentase | Grafik |
| :--- | :--- | :--- | :--- |
| <= 50ms | 0 | 0.0% |  |
| 51ms - 100ms | 0 | 0.0% |  |
| 101ms - 200ms | 3 | 3.0% |  |
| 201ms - 500ms | 97 | 97.0% | ███████████████████ |
| 501ms - 1000ms | 0 | 0.0% |  |
| > 1000ms | 0 | 0.0% |  |


---
*Laporan ini digunakan sebagai dokumentasi resmi hasil pengujian load dan response time server.*
