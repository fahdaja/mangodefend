# 🖥️ MangoDefend - Admin Dashboard

> **Frontend Dashboard Pemantauan & Portal Klien Terintegrasi Berbasis Next.js (App Router) & TypeScript**

MangoDefend Admin Dashboard adalah antarmuka web administratif untuk sistem antivirus dan deteksi malware berbasis Machine Learning (ML). Dashboard ini dibangun menggunakan teknologi web modern untuk memudahkan pemantauan, pengelolaan pengguna, transaksi, model deteksi, serta sampel malware.

---

## 🚀 Fitur Utama

Dashboard ini dilengkapi dengan berbagai modul administratif utama:

1. **Dashboard Overview**
   - Ringkasan metrik utama sistem (total pengguna, status server, performa deteksi).
   - Visualisasi tren pemindaian dan sampel malware menggunakan grafik interaktif.
2. **User Management (`/users`)**
   - Pengelolaan data pengguna terdaftar (admin, subscriber, guest).
3. **Transaction & Subscription Management (`/transactions`, `/subscriptions`)**
   - Pemantauan status transaksi pembayaran (Pending, Success, Expired, Failed).
   - Manajemen paket langganan (Plans) serta riwayat langganan pengguna.
4. **Malware Samples & Dataset Inventory (`/samples`)**
   - Inventori sampel malware yang telah diimpor ke dalam dataset latih.
5. **ML Models & Performance Monitoring (`/ml-models`, `/ml-monitoring`)**
   - Pemantauan model Machine Learning yang aktif di `mangodefend-ml-server`.
   - Analisis performa pemindaian (kecepatan inferensi, akurasi model, dan throughput load testing).
6. **System & Audit Logs (`/system-logs`)**
   - Viewer log aktivitas administratif dan performa backend secara tersentralisasi.

---

## 🛠️ Tech Stack

- **Core Framework:** [Next.js 16 (App Router)](https://nextjs.org/) & [React 19](https://react.dev/)
- **Programming Language:** [TypeScript](https://www.typescriptlang.org/)
- **Styling:** [Tailwind CSS v4](https://tailwindcss.com/) dengan `@tailwindcss/postcss`
- **State Management:** [Zustand](https://github.com/pmndrs/zustand)
- **Data Fetching & Caching:** [TanStack React Query v5](https://tanstack.com/query/latest) & [Axios](https://axios-http.com/)
- **Data Visualization:** [Recharts](https://recharts.org/)
- **Icon Pack:** [Lucide React](https://lucide.dev/)
- **Package Manager:** `pnpm` / `npm`

---

## ⚙️ Persyaratan Sistem

Pastikan perangkat Anda telah memasang:

- **Node.js** (Versi 18 ke atas disarankan)
- **pnpm** atau **npm**

---

## 📥 Panduan Instalasi & Penggunaan

### 1. Konfigurasi Environment Variables

Buat file bernama `.env.local` di root direktori `/admin` dan isi dengan URL endpoint API dari backend utama (`mangodefend-apps-server`):

```env
NEXT_PUBLIC_API_URL=http://localhost:5000
```

### 2. Install Dependensi

Gunakan `pnpm` atau `npm` untuk mengunduh semua pustaka yang dibutuhkan:

```bash
pnpm install
# atau
npm install
```

### 3. Jalankan Development Server

Jalankan aplikasi di mode lokal untuk pengembangan:

```bash
pnpm dev
# atau
npm run dev
```

Buka [http://localhost:3000](http://localhost:3000) di browser Anda untuk melihat antarmuka dashboard.

### 4. Build untuk Produksi

Untuk mengompilasi dan mengoptimalkan aplikasi sebelum dideploy ke server produksi:

```bash
pnpm build
pnpm start
# atau
npm run build
npm run start
```

---
