# 📄 Dokumentasi Teknis Ekosistem MangoDefend

Dokumen ini menyajikan arsitektur teknis lengkap, petunjuk konfigurasi, spesifikasi modul, skema data, serta panduan operasional untuk seluruh komponen dalam ekosistem **MangoDefend**.

---

## 📌 Daftar Isi Dokumentasi

1. [Ringkasan Ekosistem & Filosofi Desain](#1-ringkasan-ekosistem--filosofi-desain)
2. [Arsitektur Sistem & Alur Komunikasi Data](#2-arsitektur-sistem--alur-komunikasi-data)
3. [Komponen Backend Utama (mangodefend-ml-server)](#3-komponen-backend-utama-mangodefend-ml-server)
4. [Komponen Dashboard Admin (admin)](#4-komponen-dashboard-admin-admin)
5. [Layanan Latar Belakang & Antrean Worker (Queue & Workers)](#5-layanan-latar-belakang--antrean-worker-queue--workers)
6. [Referensi Variabel Lingkungan (.env)](#6-referensi-variabel-lingkungan-env)
7. [Spesifikasi API Utama](#7-spesifikasi-api-utama)
8. [Keamanan & Praktik Terbaik Deployment](#8-keamanan--praktik-terbaik-deployment)

---

## 1. Ringkasan Ekosistem & Filosofi Desain

MangoDefend adalah platform pendeteksi malware komprehensif berbasis **Machine Learning (ONNX Engine)**, analitik biner skala abu-abu 2D, manajemen langganan dengan gateway pembayaran **Midtrans**, dan sistem lisensi perangkat keras (*hardware fingerprinting*).

seluruh fungsi bisnis dan engine ML dikonsolidasikan ke dalam **Unified FastAPI Core Engine** (`mangodefend-ml-server`) yang berkinerja tinggi, ringan, dan di-containerize menggunakan Docker.

### Keunggulan Utama:
- **High Throughput ML Inference**: Konversi biner file (PE/APK/DLL) ke matriks gambar skala abu-abu 2D dan evaluasi model `Modelv2.onnx` dilakukan secara asinkron.
- **Fast L1 Hash Lookup**: Pengecekan cepat reputasi file berbasis Redis L1 Cache & PostgreSQL L2 Database untuk efisiensi beban kerja.
- **Integrated Payment & Subscription**: Pengolahan transaksi otomatis melalui **Midtrans Snap API** dan pembuktian webhook real-time.
- **MDB1 Binary Signature Exporter**: Kemampuan mengonversi master malware signatures dari PostgreSQL ke format biner padat `MDB1` untuk konsumsi klien offline.
- **Unified Centralized Control**: Administrator dapat memantau telemetri sistem, akun pengguna, transaksi langganan, dan performa inferensi ML melalui **Next.js 15 Admin Dashboard**.

---

## 2. Arsitektur Sistem & Alur Komunikasi Data

Visualisasi alur transaksi dan pemindaian file dalam ekosistem MangoDefend:

```mermaid
sequenceDiagram
    autonumber
    actor User as Pengguna / Aplikasi Klien (Mobile/Web)
    participant CoreAPI as MangoDefend Core API (FastAPI :8000)
    participant RedisDB as Redis (L1 Cache & Session)
    participant PostgresDB as PostgreSQL Database
    participant Worker as Python Worker (RabbitMQ Queue)
    participant Midtrans as Midtrans Payment Gateway
    participant Storage as Supabase S3 Storage

    %% Transaksi & Langganan
    rect rgb(235, 245, 255)
        note over User, Midtrans: Alur Otentikasi & Pembayaran Langganan
        User->>CoreAPI: POST /api/v1/auth/login (JWT / Google OAuth)
        CoreAPI-->>User: Bearer Access Token & User Profile
        User->>CoreAPI: POST /api/v1/subscriptions/checkout (Pilih Paket)
        CoreAPI->>Midtrans: Request Snap Token & Payment Redirect URL
        Midtrans-->>CoreAPI: Return Snap Token & Redirect URL
        CoreAPI-->>User: Snap Token & Redirect URL
        Midtrans->>CoreAPI: Webhook Notification (Payment Callback)
        CoreAPI->>PostgresDB: Verifikasi & Aktifkan Paket Langganan User
    end

    %% Pemindaian File ML
    rect rgb(240, 255, 240)
        note over User, Worker: Alur Pemindaian File & Cek Hash
        User->>CoreAPI: POST /api/v1/scans/lookup (Check SHA-256 Hash)
        CoreAPI->>RedisDB: Cek Hash di Redis L1 Cache
        alt Cache Hit
            RedisDB-->>CoreAPI: Status Reputasi File (Clean / Malicious)
        else Cache Miss
            CoreAPI->>PostgresDB: Query Malware Signatures DB
            PostgresDB-->>CoreAPI: Result & Update Redis L1 Cache
        end
        CoreAPI-->>User: Result Reputasi Hash

        User->>CoreAPI: POST /api/v1/scans/analyze (Upload Binary File)
        CoreAPI->>Worker: Enqueue Scan Job to RabbitMQ
        Worker->>Worker: Convert Binary Bytes to 2D Grayscale Matrix
        Worker->>Worker: Evaluate ONNX Model Tensor (Modelv2.onnx)
        Worker->>PostgresDB: Simpan Log Pemindaian & Latensi Scan
        CoreAPI-->>User: Hasil Klasifikasi (Malware / Benign & Confidence Score)
    end
```

---

## 3. Komponen Backend Utama (`mangodefend-ml-server`)

Backend inti dikembangkan menggunakan **Python FastAPI** dan **SQLAlchemy** terhubung ke **PostgreSQL**, **Redis**, **RabbitMQ**, dan **ONNX Runtime Engine**.

### Modul-Modul Utama:
- **`auth`**: Mengelola registrasi, otentikasi JWT Bearer, integrasi **Google OAuth 2.0**, reset password, serta dependency guard role (`get_current_user`, `get_optional_current_user`).
- **`devices`**: Pendaftaran dan pembatasan identitas unik perangkat keras (*hardware fingerprint*) milik pengguna untuk mengontrol kuota pemindaian per perangkat.
- **`users`**: Manajemen profil pengguna, pembaruan kata sandi, dan status hak akses.
- **`subscriptions`**: Katalisasi paket langganan (Starter, Pro Monthly, Pro Annual), integrasi **Midtrans Snap API**, verifikasi webhook pembayaran otomatis, serta manajemen pembatalan langganan.
- **`scans`**:
  - Pengecekan cepat reputasi hash SHA-256 via L1 Redis / L2 PostgreSQL.
  - Upload dan analisis biner dengan model ONNX (`Modelv2.onnx`).
  - Ekspor database signature malware ke format biner padat `MDB1` (`signatures_latest.mdb1`).
  - Sinkronisasi antrean telemetri offline dari perangkat klien.
- **`datasets`**: Manajemen sampel dataset malware dan integrasi upload ke **Supabase S3 Object Storage**.
- **`engine`**: Pemrosesan inferensi ML, penanganan worker latar belakang berbasis RabbitMQ, dan manipulasi matriks skala abu-abu biner.

---

## 4. Komponen Dashboard Admin (`admin`)

Aplikasi antarmuka administrator berbasis **Next.js 15 App Router**, **Tailwind CSS**, dan **Zustand**.

### Fitur Utama Dashboard:
- **Overview Metrics**: Menampilkan ringkasan total pengguna aktif, pendapatan transaksi bulanan, kuota pemindaian, dan status kesehatan server API.
- **Transactions & Subscriptions Manager**: Visualisasi status pembayaran Midtrans secara real-time (Pending, Settlement, Expired, Cancelled).
- **ML Monitoring & Realtime Logs**: Menyediakan grafik visualisasi latensi inferensi ML, statistik klasifikasi file (Benign vs Malicious), serta telemetri pemindaian.
- **User & Device Licensing Control**: Akses langsung untuk mengaktifkan/menonaktifkan akun pengguna atau mengelola perangkat terdaftar.

---

## 5. Layanan Latar Belakang & Antrean Worker (Queue & Workers)

Tugas-tugas berdurasi panjang dan inferensi ML dikelola secara asinkron menggunakan **RabbitMQ** dan worker Python (`app.src.engine.worker`):

| Nama Worker / Component | Broker/Teknologi | Peran & Tanggung Jawab |
| :--- | :--- | :--- |
| **`mangodefend_api`** | FastAPI / Uvicorn | Menangani HTTP REST API endpoint, otentikasi, checkout Midtrans, dan response langsung. |
| **`mangodefend_worker`** | Python / RabbitMQ | Pemrosesan inferensi biner ML skala besar dan penulisan log pemindaian ke PostgreSQL. |
| **`Redis L1 Cache`** | Redis 7 | Caching hash SHA-256 malware dan sesi otentikasi cepat. |
| **`PostgreSQL`** | PostgreSQL 16 | Penyimpanan master data pengguna, perangkat, transaksi, paket, dan signature malware. |

---

## 6. Referensi Variabel Lingkungan (.env)

Variabel lingkungan untuk `mangodefend-ml-server/.env`:

```ini
# Application Configuration
APP_NAME="MangoDefend ML Server"
DEBUG=True

# Database PostgreSQL
DATABASE_URL=postgresql://postgres:secretpassword@postgres:5432/mangodefend_database

# Redis & RabbitMQ Broker
REDIS_URL=redis://redis:6379/0
RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/

# Security & JWT Tokens
SECRET_KEY=super_secret_jwt_key_please_change_in_production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

# Object Storage (Supabase / S3)
S3_ENDPOINT_URL=https://your-supabase-id.supabase.co/storage/v1/s3
S3_ACCESS_KEY_ID=your_s3_access_key
S3_SECRET_ACCESS_KEY=your_s3_secret_key
S3_BUCKET_RAW=raw-uploads
S3_BUCKET_QUARANTINE=quarantine-files
S3_REGION=us-east-1

# Payment Gateway (Midtrans Snap & Core API)
MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxxx
MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxxxxxxx
MIDTRANS_IS_PRODUCTION=False
MIDTRANS_MERCHANT_ID=Gxxxxxxxxx
```

---

## 7. Spesifikasi API Utama

Seluruh endpoint API berada di bawah prefix **`/api/v1`** (Server Port `8000`):

### A. Otentikasi & Akun (`/api/v1/auth` & `/api/v1/users`)

| Method | Endpoint | Deskripsi | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/register` | Mendaftarkan akun pengguna baru | No |
| `POST` | `/api/v1/auth/login` | Otentikasi login & mengembalikan Bearer JWT Token | No |
| `POST` | `/api/v1/auth/google` | Login / Registrasi via Google OAuth 2.0 ID Token | No |
| `GET` | `/api/v1/users/me` | Mendapatkan informasi profil pengguna aktif | Yes (Bearer) |
| `PUT` | `/api/v1/users/password` | Memperbarui kata sandi pengguna | Yes (Bearer) |

### B. Perangkat & Hardware (`/api/v1/devices`)

| Method | Endpoint | Deskripsi | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/devices/register` | Mendaftarkan fingerprint hardware perangkat baru | Yes (Bearer) |
| `GET` | `/api/v1/devices/my-devices` | Mendapatkan daftar perangkat terhubung milik pengguna | Yes (Bearer) |
| `DELETE`| `/api/v1/devices/{device_id}`| Menghapus pendaftaran perangkat | Yes (Bearer) |

### C. Langganan & Pembayaran Midtrans (`/api/v1/subscriptions`)

| Method | Endpoint | Deskripsi | Auth Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/subscriptions/plans` | Mendapatkan daftar katalog paket langganan aktif | No |
| `POST` | `/api/v1/subscriptions/checkout` | Membuat transaksi pembayaran Snap Token Midtrans | Yes (Bearer) |
| `POST` | `/api/v1/subscriptions/webhook` | Webhook callback penerima status pembayaran Midtrans | No (Signature Validated) |
| `GET` | `/api/v1/subscriptions/my-status` | Cek status paket langganan aktif pengguna | Yes (Bearer) |
| `POST` | `/api/v1/subscriptions/cancel` | Membatalkan langganan aktif (Kembali ke Free) | Yes (Bearer) |

### D. Pemindaian & ML Engine (`/api/v1/scans`)

| Method | Endpoint | Deskripsi | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/scans/lookup` | Pengecekan cepat reputasi hash SHA-256 | No |
| `POST` | `/api/v1/scans/analyze` | Upload file biner untuk analisis inferensi ML | Optional |
| `GET` | `/api/v1/scans/signatures/latest` | Download database signature malware biner (`MDB1` format) | No |
| `GET` | `/api/v1/scans/history/{device_id}` | Mendapatkan histori pemindaian perangkat | No / Optional |
| `POST` | `/api/v1/scans/sync-telemetry` | Sinkronisasi antrean log pemindaian offline dari klien | Optional |
| `GET` | `/api/v1/scans/guest-quota/{device_id}` | Cek sisa kuota scan harian gratis perangkat guest | No |

---

## 8. Keamanan & Praktik Terbaik Deployment

1. **Deployment Berbasis Docker Compose**:
   - Gunakan perintah `docker compose up -d --build` untuk menjalankan seluruh ekosistem (API, Worker, Postgres, Redis, RabbitMQ) di VPS.
2. **Keamanan Kredensial**:
   - Pastikan `SECRET_KEY` dan `MIDTRANS_SERVER_KEY` diganti menggunakan nilai acak yang aman pada environment produksi.
3. **Nginx Reverse Proxy**:
   - Pasang Nginx di depan container Docker untuk menangani SSL (HTTPS/TLS via Let's Encrypt) dan meneruskan traffic ke port `8000`.
4. **CORS & Data Protection**:
   - `CORSMiddleware` sudah terkonfigurasi di `main.py` untuk mengizinkan permintaan dari domain terpercaya.

---

<p align="center">
  Dokumentasi Diperbarui &mdash; <b>MangoDefend Ecosystem</b> &copy; 2026
</p>
