import sys
import os
import json
import csv

# Add project root to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from app.src.core.database import SessionLocal
from app.src.modules.scans.schemas import SignatureImportItem
from app.src.modules.scans.service import CloudScanService


def clean_val(val: str) -> str:
    """Membersihkan whitespace dan tanda kutip ganda/tunggal dari nilai string."""
    if not val:
        return ""
    return val.strip().strip('"').strip("'").strip()


def seed_from_file(file_path: str):
    """
    Import massal hash SHA-256 malware dari file CSV (termasuk MalwareBazaar CSV), JSON, atau TXT
    ke tabel malware_signatures.
    """
    if not os.path.exists(file_path):
        print(f"[ERROR] File '{file_path}' tidak ditemukan.")
        return

    items = []
    ext = os.path.splitext(file_path)[1].lower()

    print(f"[Seeder] Membaca file '{file_path}'...")

    if ext == ".json":
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list):
                for d in data:
                    sha256 = clean_val(str(d.get("sha256") or d.get("sha256_hash") or ""))
                    if len(sha256) == 64:
                        items.append(SignatureImportItem(
                            sha256=sha256,
                            md5=clean_val(str(d.get("md5") or d.get("md5_hash") or "")) or None,
                            file_name=clean_val(str(d.get("file_name") or "")) or None,
                            source="MALWARE_BAZAAR"
                        ))

    elif ext == ".csv":
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = []
            for line in f:
                line_str = line.strip()
                # Abaikan HTTP Headers jika file di-download dengan `curl -i`
                if line_str.startswith("HTTP/") or line_str.startswith("server:") or line_str.startswith("date:") or \
                   line_str.startswith("content-") or line_str.startswith("accept-") or line_str.startswith("alt-svc:") or \
                   line_str.startswith("etag:") or line_str.startswith("last-modified:") or line_str.startswith("x-request-id:") or \
                   line_str.startswith("strict-transport-security:") or line_str.startswith("via:"):
                    continue

                # Abaikan baris komentar berawalan '#' KECUALI baris header kolom
                if line_str.startswith("#"):
                    if "sha256" in line_str.lower():
                        # Baris header kolom MalwareBazaar
                        cleaned_header = line_str.lstrip("#").strip()
                        lines.append(cleaned_header)
                    continue

                if line_str:
                    lines.append(line_str)

            if lines:
                reader = csv.DictReader(lines, skipinitialspace=True)
                for row in reader:
                    # Bersihkan key dan value dari kutip & spasi
                    clean_row = {clean_val(k): clean_val(v) for k, v in row.items() if k}
                    
                    sha256 = clean_row.get("sha256_hash") or clean_row.get("sha256") or clean_row.get("SHA256") or ""
                    md5 = clean_row.get("md5_hash") or clean_row.get("md5") or clean_row.get("MD5") or ""
                    file_name = clean_row.get("file_name") or clean_row.get("filename") or ""

                    if len(sha256) == 64:
                        items.append(SignatureImportItem(
                            sha256=sha256,
                            md5=md5 if len(md5) == 32 else None,
                            file_name=file_name or None,
                            source="MALWARE_BAZAAR"
                        ))

    else:
        # Direct text file (1 hash per baris)
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                h = clean_val(line)
                if not h.startswith("#") and len(h) == 64:
                    items.append(SignatureImportItem(sha256=h, source="MALWARE_BAZAAR"))

    if not items:
        print("[ERROR] Tidak ada hash SHA-256 valid yang ditemukan di file tersebut.")
        return

    print(f"[Seeder] Menemukan {len(items)} hash SHA-256 valid. Memproses import ke database...")

    db = SessionLocal()
    try:
        res = CloudScanService.bulk_import_signatures(db=db, items=items)
        print(f"\n✅ SEEDING BERHASIL!")
        print(f"   - Total diproses     : {res.total_processed}")
        print(f"   - Berhasil diimport : {res.imported_count}")
        print(f"   - Dilewati (Duplikat): {res.skipped_count}")
    finally:
        db.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Penggunaan: python -m app.src.engine.seed_signatures <path_file.csv / .txt / .json>")
    else:
        seed_from_file(sys.argv[1])
