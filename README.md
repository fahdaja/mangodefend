# 🛡️ MangoDefend - Cybersecurity & Malware Detection Ecosystem

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Next.js](https://img.shields.io/badge/Next.js_15-000000?style=flat&logo=nextdotjs&logoColor=white)](https://nextjs.org/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![ONNX Runtime](https://img.shields.io/badge/ONNX_Runtime-005FE6?style=flat&logo=onnx&logoColor=white)](https://onnxruntime.ai/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org/)

Platform keamanan siber terpadu untuk deteksi malware berbasis **Machine Learning (ONNX)**, konversi biner ke skala abu-abu (2D matrix), manajemen langganan & transaksi (**Midtrans Payment Gateway**), serta **Dashboard Monitoring Terpadu**.

---

## 📌 Daftar Isi

- [Arsitektur Ekosistem](#-arsitektur-ekosistem)
- [Komponen Utama](#-komponen-utama)
- [Persyaratan Sistem](#-persyaratan-sistem)
- [Panduan Instalasi & Quickstart](#-panduan-instalasi--quickstart)
- [Konfigurasi Lingkungan (.env)](#-konfigurasi-lingkungan-env)
- [Struktur Monorepo](#-struktur-monorepo)
- [Dokumentasi API & Fitur](#-dokumentasi-api--fitur)
- [Lisensi](#-lisensi)

---

## 🏗️ Arsitektur Ekosistem

MangoDefend menggunakan **Unified Core FastAPI Engine** yang menangani seluruh API transaksi bisnis, manajemen akun, lisensi perangkat, serta inferensi model Machine Learning yang asinkron dan terisolasi.

```mermaid
graph TD
    subgraph Klien [Klien Utama]
        MobileApp[Aplikasi Mobile Client / Flutter]
        AdminUser[Administrator Sistem]
    end

    subgraph Frontend_Dashboard [Dashboard Admin]
        AdminApp["Next.js 15 Admin App (:3000)"]
    end

    subgraph Core_Backend [MangoDefend ML & API Server]
        FastAPIServer["FastAPI Core & ML Server (:8000)"]
        Postgres[(PostgreSQL Database)]
        Redis[(Redis L1 Cache & Session)]
        RabbitMQ[(RabbitMQ Task Queue)]
        Worker["Python ML & Telemetry Worker"]
        Midtrans[Midtrans Payment Gateway]
        SupabaseS3[Supabase / S3 Object Storage]

        FastAPIServer --> Postgres
        FastAPIServer --> Redis
        FastAPIServer --> RabbitMQ
        FastAPIServer --> Midtrans
        FastAPIServer --> SupabaseS3
        Worker --> RabbitMQ
        Worker --> Postgres
        Worker --> Redis
    end

    %% Client Interactions
    MobileApp -->|REST API /api/v1 - Auth, Scan, Subscriptions| FastAPIServer
    AdminUser -->|Manajemen & Monitoring| AdminApp

    %% Internal Monitoring Connections
    AdminApp -->|REST API /api/v1 - Users, Payments, Devices, Scans| FastAPIServer
```

---

## 🧩 Komponen Utama

### 1. 🐍 `mangodefend-ml-server` (Core Backend API & ML Engine)
Server utama berbasis **Python FastAPI**, **SQLAlchemy**, **PostgreSQL**, **Redis**, **RabbitMQ**, dan **ONNX Runtime**.
- **Fungsi Utama**:
  - **Otentikasi & Akun**: Login JWT & Google OAuth 2.0.
  - **Manajemen Perangkat (Devices)**: Identifikasi unik hardware fingerprint client.
  - **Langganan & Transaksi**: Integrasi gateway pembayaran **Midtrans Snap API** & verifikasi webhook otomatis.
  - **Pemindaian & ML Engine**: Konversi biner file (PE/APK/DLL) ke matriks skala abu-abu 2D dan inferensi model `Modelv2.onnx`.
  - **Signature Binary Export**: Konversi database signature ke format biner `MDB1`.
  - **Storage**: Sinkronisasi dataset sampel malware ke Supabase S3 Object Storage.
- **Port Default**: `8000`

### 2. 🖥️ `admin` (Unified Admin Dashboard)
Dashboard web interaktif yang dikembangkan dengan **Next.js 15 App Router**, **Tailwind CSS**, dan **Zustand**.
- **Fungsi Utama**: Antarmuka kontrol terpadu untuk mengelola pengguna, memantau histori transaksi pembayaran, kuota pemindaian perangkat, metrik performa ML, serta audit log sistem secara real-time.
- **Port Default**: `3000`

---

## ⚙️ Persyaratan Sistem

Pastikan environment lokal atau VPS Anda memiliki:
- **Docker & Docker Compose** (Rekomendasi Utama)
- **Node.js**: `v18.x` atau `v20.x` (Untuk Admin Dashboard)
- **pnpm**: `v9.x` atau `npm`
- **Python**: `v3.11+` (Jika dijalankan tanpa Docker)
- **PostgreSQL**: `v16+`
- **Redis**: `v7+`
- **RabbitMQ**: `v3+`

---

## 🚀 Panduan Instalasi & Quickstart

### 1. Clone Repositori
```bash
git clone https://github.com/fahdaja/mangodefend.git
cd mangodefend
```

### 2. Jalankan Backend Services (`mangodefend-ml-server`) dengan Docker
```bash
cd mangodefend-ml-server
cp .env.example .env

# Jalankan seluruh stack (API, Worker, Postgres, Redis, RabbitMQ)
docker compose up -d --build
```
> API Server akan aktif di `http://localhost:8000`  
> Dokumentasi Swagger UI: `http://localhost:8000/docs`

### 3. Jalankan `admin` Dashboard
```bash
cd ../admin
cp .env.example .env.local
pnpm install
pnpm dev
```
> Dashboard Admin akan aktif di `http://localhost:3000`

---

## 🔐 Konfigurasi Lingkungan (.env)

Variabel utama yang perlu dikonfigurasi di `mangodefend-ml-server/.env`:

```ini
APP_NAME="MangoDefend ML Server"
DEBUG=True

# Database PostgreSQL
DATABASE_URL=postgresql://postgres:secretpassword@postgres:5432/mangodefend_database

# Redis & RabbitMQ
REDIS_URL=redis://redis:6379/0
RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/

# Object Storage (Supabase S3)
S3_ENDPOINT_URL=https://your-supabase-id.supabase.co/storage/v1/s3
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key

# Payment Gateway (Midtrans)
MIDTRANS_SERVER_KEY=SB-Mid-server-xxxxxxxxx
MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxxxxxxx
MIDTRANS_IS_PRODUCTION=False
```

---

## 📁 Struktur Monorepo

```text
mangodefend/
├── DOCUMENTATION.md           # Dokumentasi teknis & arsitektur terperinci
├── LICENSE                    # Lisensi terbuka MIT
├── README.md                  # Dokumentasi ringkas repositori
├── admin/                     # Dashboard Frontend (Next.js 15)
│   ├── app/                   # App Router Pages & Components
│   ├── lib/                   # API Client & State Store (Zustand)
│   └── public/                # Asset gambar & ikon UI
└── mangodefend-ml-server/     # Core Backend API & ML Engine (FastAPI + Docker)
    ├── app/
    │   ├── model_weights/     # Weights Model ONNX (Modelv2.onnx)
    │   ├── src/               # Core Modules (auth, devices, users, scans, datasets, subscriptions)
    │   └── tests/             # Pytest Unit Test Suite
    ├── Dockerfile             # Multi-stage Dockerfile
    ├── docker-compose.yml     # Orchestration (Postgres, Redis, RabbitMQ, API, Worker)
    └── requirements.txt       # Dependensi Python
```

---

## 📖 Dokumentasi API & Fitur Lengkap

Dokumentasi teknis lengkap mengenai spesifikasi endpoint REST API, skema database, alur kerja pembayaran Midtrans, dan detail inferensi ML dapat dilihat pada:

📄 **[Lihat DOCUMENTATION.md](file:///home/mr-pacman/Documents/Project%20Deteksi%20Malware%20Magang/mangodefend/DOCUMENTATION.md)**

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah **MIT License**. Lihat file [LICENSE](file:///home/mr-pacman/Documents/Project%20Deteksi%20Malware%20Magang/mangodefend/LICENSE) untuk rincian selengkapnya.

---

<p align="center">
  Dikembangkan oleh <b>MangoDefend Team (fahdaja)</b> &copy; 2026.
</p>
