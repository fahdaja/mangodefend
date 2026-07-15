# 🟢 MangoDefend - Core Apps Server

> **Backend Gateway Utama Berbasis NestJS (TypeScript) dengan Integrasi PostgreSQL, Midtrans Payment Gateway, dan Sinkronisasi ML Server**

MangoDefend Apps Server adalah core backend dan API gateway untuk ekosistem antivirus dan pendeteksi malware berbasis Machine Learning (ML) MangoDefend. Dibangun menggunakan framework NestJS (TypeScript), server ini bertindak sebagai jembatan yang menghubungkan aplikasi web admin, agent desktop, engine deteksi ML, serta layanan eksternal (Database, Firebase, Supabase, dan Payment Gateway).

---

## 🚀 Fitur Utama

Backend ini mengelola modul-modul krusial sistem:

1. **Autentikasi & Otorisasi Pengguna (`/auth`, `/users`)**
   - Integrasi Firebase Authentication untuk validasi ID Token secara aman.
   - Role-Based Access Control (RBAC) untuk mengamankan endpoint berdasarkan hak akses (Super Admin, Admin Validator, Finance Admin, Subscriber, Guest).
2. **Manajemen Transaksi & Pembayaran (`/transactions`)**
   - Integrasi Webhook Payment Gateway (Midtrans) untuk memproses pembayaran langganan secara otomatis.
   - Scheduler otomatis untuk membatalkan transaksi pending yang berumur lebih dari 24 jam.
3. **Manajemen Paket & Langganan (`/subscriptions`)**
   - Skema aktivasi paket langganan (Plans) secara otomatis setelah transaksi sukses.
   - Penanganan siklus masa aktif langganan (Active, Expired, Replaced, Cancelled) beserta validasi batas limit kuota harian.
4. **API Pemindaian & Deteksi (`/scans`, `/ML`)**
   - Berinteraksi dengan `mangodefend-ml-server` untuk memicu analisis file biner.
   - Menyimpan riwayat pemindaian file, status ancaman, dan meta data file.
5. **Penyimpanan File Aman (Supabase Storage)**
   - Integrasi dengan Supabase Storage SDK untuk mengunggah file bukti sengketa (_disputes_) dan sampel malware yang dikirim oleh pengguna.
6. **Layanan Notifikasi Email (Nodemailer)**
   - Mengirimkan email verifikasi dan bukti kuitansi pembayaran (_receipt email_) otomatis menggunakan protokol SMTP.

---

## 🛠️ Tech Stack

- **Framework:** [NestJS v11](https://nestjs.com/) (Node.js)
- **Language:** [TypeScript](https://www.typescriptlang.org/)
- **ORM:** [TypeORM](https://typeorm.io/)
- **Database Driver:** `pg` (PostgreSQL)
- **Authentication:** [Firebase Admin SDK](https://firebase.google.com/docs/admin)
- **Cloud Storage:** [Supabase JS Client SDK](https://supabase.com/docs/reference/javascript/introduction)
- **Email Delivery:** [Nodemailer](https://nodemailer.com/)
- **Package Manager:** `npm`

---

## ⚙️ Konfigurasi Environment Variables

Buat file `.env` di root folder `/mangodefend-apps-server` berdasarkan template `.env.example`:

```env
PORT=5000
DATABASE_URL=postgresql://username:password@localhost:5432/mangodefend_app_db
JWT_SECRET=super_secret_jwt_key
ML_SERVER_URL=http://localhost:8000
MIDTRANS_SERVER_KEY=SB-Mid-server-...
MIDTRANS_CLIENT_KEY=SB-Mid-client-...
MIDTRANS_IS_PRODUCTION=false
```

---

## 📥 Panduan Instalasi & Penggunaan

### 1. Install Dependensi

```bash
npm install
```

### 2. Jalankan Seeder Dataset Awal

Untuk mengisi database Anda dengan contoh data ancaman/malware default:

```bash
npm run seed:dataset
npm run seed:test
```

### 3. Jalankan Server

```bash
# Mode Pengembangan (Watch Mode)
npm run start:dev

# Mode Produksi
npm run build
npm run start:prod
```

Server akan berjalan secara default di `http://localhost:5000`.

---
