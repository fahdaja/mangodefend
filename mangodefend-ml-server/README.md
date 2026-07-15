# 🐍 MangoDefend - ML Server Engine

> **API Deteksi Malware Menggunakan Machine Learning dengan Konversi Grayscale File Biner dan Inferensi ONNX Runtime**

---

## 🚀 Fitur Utama

1. **Konverter File Ke Gambar**: Mengonversi byte biner file yang diunggah (`.exe`, `.dll`, dll.) menjadi representasi gambar skala abu-abu (grayscale image) secara in-memory.
2. **Inference Engine**: Menjalankan prediksi klasifikasi ancaman (malware vs benign) menggunakan model Neural Network berformat **ONNX**.
3. **Database Logs**: Mencatat detail log pemindaian (ID, nama file, ukuran, label hasil klasifikasi, platform klien) ke database **MySQL**.
4. **Real-time Server-Sent Events (SSE)**: Menyiarkan event log scan baru ke klien yang mendengarkan endpoint `/api/v1/scans/stream` secara instan.
5. **Telemetry Logs**: Menyimpan detail pencatatan waktu proses internal (membaca file, mengonversi gambar, inferensi model, query database) ke `mangodefend_scan.log`.

---

## 🛠️ Tech Stack

- **Web Framework**: [FastAPI](https://fastapi.tiangolo.com/) (Python)
- **ASGI Server**: [Uvicorn](https://www.uvicorn.org/)
- **ML Inference**: [ONNX Runtime](https://onnxruntime.ai/)
- **Data Manipulation**: [NumPy](https://numpy.org/) & [Pillow](https://python-pillow.org/)
- **Database Driver**: [SQLAlchemy](https://www.sqlalchemy.org/) dengan MySQL Connector
- **Load Testing**: [Locust](https://locust.io/)

---

## ⚙️ Persyaratan Sistem & Konfigurasi

1. Pastikan python 3.10+ sudah terinstal.
2. Konfigurasi file `.env` di dalam folder ini:
   ```ini
   DATABASE_URL=mysql+pymysql://username:password@localhost:3306/mangodefend_db
   PORT=8000
   HOST=0.0.0.0
   ```

---

## 📥 Langkah Penggunaan

1. **Instal dependencies**:
   ```bash
   pip install -r requirements.txt
   ```
2. **Jalankan FastAPI Server**:
   ```bash
   uvicorn main:app --reload --port 8000
   ```
3. **Akses Dokumentasi API**:
   Buka browser ke `http://localhost:8000/docs` untuk mengakses Swagger UI yang interaktif.

---
