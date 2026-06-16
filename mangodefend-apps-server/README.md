# MangoDefend - Core Apps Server

MangoDefend Apps Server adalah core backend dan API gateway untuk ekosistem antivirus dan pendeteksi malware berbasis Machine Learning (ML) MangoDefend. Dibangun menggunakan framework NestJS (TypeScript), server ini bertindak sebagai jembatan yang menghubungkan aplikasi web admin, agent desktop, engine deteksi ML, serta layanan eksternal (Database, Firebase, Supabase, dan Payment Gateway).

---

## 🚀 Fitur Utama

Backend ini mengelola modul-modul krusial sistem:

1. **Autentikasi & Otorisasi Pengguna (`/auth`, `/users`)**
   - Integrasi Firebase Authentication untuk validasi ID Token secara aman.
   - Mendukung registrasi dan login melalui metode standar maupun OAuth2.
   - Role-Based Access Control (RBAC) untuk mengamankan endpoint berdasarkan hak akses (Super Admin, Admin Validator, Finance Admin, Subscriber, Guest).
2. **Manajemen Transaksi & Pembayaran (`/transactions`)**
   - Integrasi Webhook Payment Gateway (Midtrans/Xendit) untuk memproses pembayaran langganan secara otomatis.
   - Scheduler otomatis (`autoExpirePendingTransactions`) untuk membatalkan transaksi pending yang berumur lebih dari 24 jam.
   - Lifecycle status transaksi yang aman (Pending, Success, Expired, Failed).
3. **Manajemen Paket & Langganan (`/subscriptions`)**
   - Skema aktivasi paket langganan (Plans) secara otomatis setelah transaksi sukses.
   - Penanganan siklus masa aktif langganan (Active, Expired, Replaced, Cancelled).
4. **API Pemindaian & Deteksi (`/scans`, `/ML`)**
   - Berinteraksi dengan `mangodefend-ml-server` untuk memicu analisis file biner.
   - Menyimpan riwayat pemindaian file, status ancaman, dan meta data file.
   - Pencatatan log deteksi real-time untuk audit.
5. **Penyimpanan File Aman (Supabase Storage)**
   - Integrasi dengan Supabase Storage SDK untuk mengunggah file bukti sengketa (*disputes*) dan sampel malware yang dikirim oleh pengguna.
6. **Layanan Notifikasi Email (Nodemailer)**
   - Mengirimkan email verifikasi dan bukti kuitansi pembayaran (*receipt email*) otomatis menggunakan protokol SMTP Gmail/kustom.
7. **Pengelolaan Dataset Ancaman (`/dataset`)**
   - Endpoint untuk mendaftarkan dan memvalidasi sampel malware baru.
   - Seeder otomatis (`seed:dataset`) untuk mengisi data awal ancaman ke database.

---

## 🛠️ Tech Stack

- **Framework:** [NestJS v11](https://nestjs.com/) (Node.js)
- **Language:** [TypeScript](https://www.typescriptlang.org/)
- **ORM:** [TypeORM](https://typeorm.io/) (berkomunikasi dengan PostgreSQL)
- **Database Driver:** `pg` (PostgreSQL)
- **Authentication:** [Firebase Admin SDK](https://firebase.google.com/docs/admin)
- **Cloud Storage:** [Supabase JS Client SDK](https://supabase.com/docs/reference/javascript/introduction)
- **Email Delivery:** [Nodemailer](https://nodemailer.com/)
- **Package Manager:** `pnpm`

---

## ⚙️ Konfigurasi Environment Variables

Buat file `.env` di root folder `/mangodefend-apps-server` berdasarkan template `.env.example`:

```env
# SERVER CONFIG
PORT=4000

# DATABASE CONFIG (PostgreSQL)
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=your_database_password
DB_NAME=mangodefend_db

# SUPABASE STORAGE CONFIG
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_supabase_api_key
SUPABASE_BUCKET_NAME=your_storage_bucket_name

# FIREBASE CONFIG
FIREBASE_PROJECT_ID=your-firebase-project-id

# SMTP EMAIL CONFIG
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_gmail_app_password
SMTP_FROM=noreply@mangodefend.com
```

---

## 📥 Panduan Instalasi & Penggunaan

### 1. Jalankan Migrasi/Setup Database
Pastikan layanan PostgreSQL Anda telah aktif dan database yang dideklarasikan di `.env` sudah dibuat.

### 2. Install Dependensi
```bash
pnpm install
```

### 3. Jalankan Seeder Dataset Awal
Untuk mengisi database Anda dengan contoh data ancaman/malware default:
```bash
pnpm run seed:dataset
```

### 4. Jalankan Server
```bash
# Mode Pengembangan (Watch Mode)
pnpm run start:dev

# Mode Produksi
pnpm run build
pnpm run start:prod
```
Server akan berjalan secara default di `http://localhost:4000`.

---

## 📁 Struktur Folder Utama

```text
mangodefend-apps-server/
├── src/
│   ├── api/                # Modul Fitur API
│   │   ├── ML/             # Integrasi dengan Engine Deteksi ML
│   │   ├── auth/           # Manajemen login & Firebase token
│   │   ├── dataset/        # Inventori data malware/benign
│   │   ├── scans/          # Proses scanning & history log scan
│   │   ├── subscriptions/  # Skema paket & masa aktif langganan
│   │   ├── transactions/   # Transaksi billing & webhook payment
│   │   └── users/          # Profil pengguna & manajemen akses
│   ├── common/             # Modul & Helper Global
│   │   ├── decorator/      # Custom decorators (@Roles)
│   │   ├── filters/        # Exception filters global
│   │   ├── firebase/       # Inisialisasi Firebase Admin
│   │   ├── hash/           # Helper enkripsi bcrypt
│   │   ├── logger/         # Custom file logger untuk logging performa
│   │   ├── mail/           # Layanan kirim kuitansi via Nodemailer
│   │   └── supabase/       # Klien Supabase Storage SDK
│   ├── app.module.ts       # Root module aplikasi
│   ├── main.ts             # Entrypoint bootstrap aplikasi
│   └── seed-dataset.ts     # Script seeder database
```
