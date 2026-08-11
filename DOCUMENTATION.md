# 📄 Dokumentasi Teknis Ekosistem MangoDefend

Dokumen ini menyajikan arsitektur teknis lengkap, petunjuk konfigurasi, spesifikasi modul, skema data, serta panduan operasional untuk seluruh komponen dalam ekosistem **MangoDefend**.

---

## 📌 Daftar Isi Dokumentasi

1. [Ringkasan Ekosistem & Filosofi Desain](#1-ringkasan-ekosistem--filosofi-desain)
2. [Arsitektur Sistem & Alur Komunikasi Data](#2-arsitektur-sistem--alur-komunikasi-data)
3. [Komponen Backend Utama (mangodefend-apps-server)](#3-komponen-backend-utama-mangodefend-apps-server)
4. [Komponen Machine Learning Engine (mangodefend-ml-server)](#4-komponen-machine-learning-engine-mangodefend-ml-server)
5. [Komponen Dashboard Admin (admin)](#5-komponen-dashboard-admin-admin)
6. [Layanan Latar Belakang & Antrean Worker (Queue & Workers)](#6-layanan-latar-belakang--antrean-worker-queue--workers)
7. [Referensi Variabel Lingkungan (.env)](#7-referensi-variabel-lingkungan-env)
8. [Spesifikasi API Utama](#8-spesifikasi-api-utama)
9. [Keamanan & Praktik Terbaik Deployment](#9-keamanan--praktik-terbaik-deployment)

---

## 1. Ringkasan Ekosistem & Filosofi Desain

MangoDefend adalah platform pendeteksi malware komprehensif yang dirancang menggunakan pendekatan **microservices terisolasi**. Filosofi utama dari arsitektur ini adalah memisahkan transaksi bisnis/manajemen akun pengguna dari beban kerja pemrosesan biner berat dan inferensi Machine Learning (ML).

### Keunggulan Utama:
- **High Throughput Inference**: Proses konversi biner ke citra grayscale dan inferensi model ONNX diisolasi di layanan FastAPI Python terpisah.
- **Asynchronous Event-Driven Architecture**: Pemrosesan pembayaran, notifikasi, dan pemindaian file yang membutuhkan waktu lama ditangani secara asinkron menggunakan antrean **RabbitMQ** dan **Redis**.
- **Unified Centralized Control**: Administrator dapat memantau telemetri kedua server (kuota pembayaran dari Apps Server dan performa inferensi ML dari ML Server) dalam satu antarmuka **Next.js 15 Admin Dashboard**.

---

## 2. Arsitektur Sistem & Alur Komunikasi Data

Visualisasi detail aliran data antarkomponen:

```mermaid
sequenceDiagram
    autonumber
    actor User as Pengguna / Aplikasi Klien
    participant AppServer as Apps Server (NestJS)
    participant MLServer as ML Engine (FastAPI)
    participant Queue as RabbitMQ / Redis
    participant Payment as Midtrans Gateway
    participant DBApp as PostgreSQL DB
    participant DBML as MySQL DB

    %% Transaksi & Langganan
    rect rgb(235, 245, 255)
        User->>AppServer: POST /api/v1/auth/login (JWT / Firebase)
        AppServer-->>User: Auth Token & Role State
        User->>AppServer: POST /api/v1/subscriptions/purchase
        AppServer->>Payment: Generate Snap Charge Token
        Payment-->>AppServer: Token & Redirect URL
        AppServer-->>User: Snap Payment Token
        Payment->>AppServer: Webhook Notification (Payment Callback)
        AppServer->>Queue: Push Event: PAYMENT_VERIFIED
        Queue->>AppServer: Payment Worker Updates User Subscription
        AppServer->>DBApp: Update Status User Subscription & Balance
    end

    %% Pemindaian File ML
    rect rgb(240, 255, 240)
        User->>MLServer: POST /api/v1/scans/file (Upload Exe/DLL/Bin)
        MLServer->>MLServer: Convert Binary to 2D Grayscale Matrix
        MLServer->>MLServer: Evaluate Tensor with ONNX Model Engine
        MLServer->>DBML: Save Log Pemindaian & Latensi Evaluation
        MLServer-->>User: Hasil Klasifikasi (Malware / Benign, Confidence Score)
    end
```

---

## 3. Komponen Backend Utama (`mangodefend-apps-server`)

Backend inti menggunakan framework **NestJS** berbasis TypeScript, terhubung ke **PostgreSQL** melalui **TypeORM**.

### Struktur Modul Utama:
- **`AuthModule`**: Mengelola otentikasi JWT, integrasi **Firebase Admin SDK**, validasi role akses (`ADMIN`, `USER`, `MITRA`), dan guards (`AuthGuard`, `RolesGuard`).
- **`UserModule`**: Manajemen CRUD entitas pengguna, status akun, dan profil peranan.
- **`DeviceModule`**: Pendaftaran dan pembatasan identitas unik perangkat keras (*hardware fingerprint*) milik pengguna untuk mencegah penyalahgunaan akun.
- **`SubscriptionModule` & `TransactionModule`**: Pengelolaan katalog paket langganan antivirus dan integrasi skema callback webhook **Midtrans**.
- **`ScanModule` & `DatasetModule`**: Pencatatan metadata file sampel untuk pengujian internal serta pembaruan dataset model malware.
- **`NotificationModule`**: Layanan push notification dan email notifikasi sistem.

---

## 4. Komponen Machine Learning Engine (`mangodefend-ml-server`)

Engine pendeteksi dikembangkan menggunakan **Python FastAPI** yang dioptimalkan untuk kecepatan pemrosesan file biner dan model inferensi berkinerja tinggi.

### Tahapan Proses Pemindaian (Scan Flow):
1. **File Uploading**: Menerima multipart file binary (PE Executable, DLL, APK, Bin).
2. **Byte-to-Grayscale Conversion**:
   - Membaca mentah *byte stream* dari file.
   - Mengubah urutan byte 8-bit menjadi piksel skala abu-abu (0–255).
   - Membentuk matriks citra 2 dimensi dengan lebar tetap (*fixed width grid*) berdasarkan ukuran total file.
3. **Resizing & Normalization**: Mengubah ukuran matriks ke dimensi input yang disyaratkan oleh model Deep Learning (misal: 32x32 atau 224x224).
4. **ONNX Runtime Evaluation**: Menjalankan evaluasi tensor menggunakan model `Modelv2.onnx`.
5. **Logging & Streaming**:
   - Menyiapkan skor probabilitas klasifikasi (*Malware Probability*).
   - Menyimpan *ScanLog* ke database **MySQL**.
   - Menyiarkan log pemindaian secara realtime melalui **Server-Sent Events (SSE)** ke Dashboard Admin.

---

## 5. Komponen Dashboard Admin (`admin`)

Aplikasi antarmuka berbasis **Next.js 15 App Router** dan **Tailwind CSS**.

### Fitur Utama Dashboard:
- **Overview Metrics**: Menampilkan ringkasan total pengguna aktif, pendapatan transaksi bulanan, kuota pemindaian, dan status kesehatan server.
- **Transactions & Subscriptions Manager**: Visualisasi status pembayaran Midtrans secara realtime (Pending, Success, Expired, Failed).
- **ML Monitoring & Realtime Logs**: Menyediakan grafik visualisasi latensi inferensi ML, statistik klasifikasi file (Benign vs Malicious), dan SSE live log stream.
- **User & Device Licensing Control**: Akses langsung untuk mengaktifkan/menonaktifkan akun pengguna atau menyetujui pendaftaran perangkat baru.

---

## 6. Layanan Latar Belakang & Antrean Worker (Queue & Workers)

Untuk mencegah kemacetan pemrosesan pada thread utama NestJS, tugas-tugas berdurasi panjang dikelola melalui **RabbitMQ** dan worker internal **Redis Queue**:

| Nama Worker | Broker/Teknologi | Peran & Tanggung Jawab |
| :--- | :--- | :--- |
| **`payment.worker`** | RabbitMQ / Redis | Mengolah notifikasi verifikasi pembayaran Midtrans secara terpisah dari Webhook HTTP. |
| **`scan.worker`** | RabbitMQ | Pemrosesan kuota pemindaian dan sinkronisasi log scan skala besar. |
| **`notification.worker`** | Redis / BullMQ | Pengiriman email invoice, verifikasi akun, dan reset password via Nodemailer. |
| **`sample.worker`** | Redis Queue | Ekstraksi dan pengkategorian sampel biner baru ke dalam direktori dataset. |

---

## 7. Referensi Variabel Lingkungan (.env)

### A. Apps Server (`mangodefend-apps-server/.env`)
```ini
PORT=3001
NODE_ENV=development

# Database PostgreSQL
DATABASE_URL=postgresql://user:password@localhost:5432/mangodefend

# Security & Tokens
JWT_SECRET=super_secret_jwt_key_here
JWT_EXPIRES_IN=7d

# Redis & RabbitMQ
REDIS_HOST=localhost
REDIS_PORT=6379
RABBITMQ_URL=amqp://guest:guest@localhost:5672

# Payment Gateway (Midtrans)
MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxxx
MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxxxxxxx
MIDTRANS_IS_PRODUCTION=false

# Firebase Admin SDK
FIREBASE_PROJECT_ID=mangodefend-app
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@mangodefend.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

# SMTP Email Service
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@mangodefend.id
SMTP_PASS=app_password_here
```

### B. ML Server (`mangodefend-ml-server/.env`)
```ini
PORT=8000
ENVIRONMENT=development

# Database MySQL Scan Logs
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=rootpassword
DB_NAME=mangodefend_ml

# ML Model Configuration
MODEL_PATH=app/ml/Modelv2.onnx
SCAN_THRESHOLD=0.5
```

---

## 8. Spesifikasi API Utama

### Core Apps Server API (`:3001`)

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/login` | Otentikasi user & mengembalikan Bearer Token | No |
| `POST` | `/api/v1/auth/firebase` | Exchange token Firebase Auth dengan JWT Apps | No |
| `GET` | `/api/v1/users/profile` | Mendapatkan profil user aktif | Yes |
| `GET` | `/api/v1/subscriptions/plans` | Daftar katalog paket langganan | No |
| `POST` | `/api/v1/transactions/checkout` | Membuat transaksi pembayaran Snap Midtrans | Yes |
| `POST` | `/api/v1/transactions/notification` | Webhook receiver callback dari Midtrans | No (Validates Signature) |

### ML Engine Server API (`:8000`)

| Method | Endpoint | Description | Auth Required |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | Healthcheck endpoint status server | No |
| `POST` | `/api/v1/scans/file` | Upload & scan file biner untuk deteksi malware | Optional / API Key |
| `GET` | `/api/v1/scans/logs` | Mendapatkan riwayat log hasil pemindaian | Yes (Admin) |
| `GET` | `/api/v1/scans/sse-logs` | Stream realtime log pemindaian via Server-Sent Events | Yes (Admin) |

---

## 9. Keamanan & Praktik Terbaik Deployment

1. **Prinsip Least Privilege**:
   - DB PostgreSQL dan MySQL dipisah dengan kredensial pengguna yang unik.
   - Kunci API Midtrans production tidak boleh disimpan di dalam repositori publik.
2. **Standard Hashing & Cryptography**:
   - Password lokal di-hash menggunakan algoritma **Bcrypt** dengan salt round minimum 10.
3. **CORS & Rate Limiting**:
   - Setiap endpoint backend wajib mengonfigurasi `CORSMiddleware` dengan daftar origin tepercaya (*whitelisted domains*).
   - Penggunaan Throttler Module untuk membatasi *brute force attacks* pada endpoint login dan upload file.

---

<p align="center">
  Dokumentasi Diperbarui &mdash; <b>MangoDefend Ecosystem</b> &copy; 2026
</p>
