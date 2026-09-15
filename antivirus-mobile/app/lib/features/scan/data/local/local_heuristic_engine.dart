import 'dart:typed_data';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/features/scan/domain/scan_result.dart';
import 'package:antivirus_mobile/features/scan/data/local/binary_signature_database.dart';

class LocalHeuristicEngine {
  /// Ekstensi bahaya tinggi yang sering disasarkan malware
  static const Set<String> _highRiskExtensions = {
    'apk', 'dex', 'sh', 'exe', 'bat', 'vbs', 'js', 'jar', 'py', 'elf', 'so', 'php'
  };

  /// Kata kunci indikator malware umum
  static const Set<String> _suspiciousKeywords = {
    'malware', 'trojan', 'spyware', 'keylogger', 'stealer', 'ransomware',
    'backdoor', 'payload', 'exploit', 'rat', 'hacktool', 'mod_vips', 'cheat_engine'
  };

  /// Set Hash SHA-256 / File Path Terverifikasi Aman (Whitelist Lokal Pengguna)
  static final Set<String> _whitelistedHashes = {};

  /// Tambahkan Hash SHA-256 atau Path File ke Whitelist Lokal (Diizinkan Pengguna)
  static void addHashToWhitelist(String pathOrHash) {
    if (pathOrHash.isNotEmpty) {
      _whitelistedHashes.add(pathOrHash.toLowerCase().trim());
      try {
        final f = File(pathOrHash);
        if (f.existsSync() && f.lengthSync() < 20 * 1024 * 1024) {
          final bytes = f.readAsBytesSync();
          final digest = sha256.convert(bytes);
          _whitelistedHashes.add(digest.toString().toLowerCase().trim());
        }
      } catch (_) {}
    }
  }

  /// Cek apakah Hash SHA-256 atau Path File ada di Whitelist Lokal
  static bool isWhitelisted(String fileHash, [String? filePath]) {
    if (_whitelistedHashes.contains(fileHash.toLowerCase().trim())) return true;
    if (filePath != null && _whitelistedHashes.contains(filePath.toLowerCase().trim())) return true;
    return false;
  }

  /// Memanalisis file secara heuristik & biner di perangkat lokal (Offline Mode)
  static Future<ScanResult> analyzeFile(File file) async {
    final fileName = file.path.split('/').last.toLowerCase();
    final now = DateTime.now();

    // 1. Hitung Hash File SHA-256 menggunakan Streaming I/O (Standar Industri: RAM-Friendly & mendukung file ukuran berapa pun)
    String fileHash = '';
    Uint8List? rawSha256Bytes;

    try {
      if (await file.exists()) {
        final stream = file.openRead();
        final digest = await sha256.bind(stream).first;
        fileHash = digest.toString().toLowerCase().trim();
        rawSha256Bytes = Uint8List.fromList(digest.bytes);
      }
    } catch (_) {
      fileHash = '';
    }

    // 1.5. Cek jika Hash atau Path File terdaftar di Whitelist Lokal Pengguna
    if (isWhitelisted(fileHash, file.path)) {
      return ScanResult(
        id: now.millisecondsSinceEpoch,
        fileHash: fileHash,
        fileName: file.path.split('/').last,
        filePath: file.path,
        verdict: ScanVerdict.benign,
        scanSource: ScanSource.heuristicEngine,
        scannedAt: now,
      );
    }

    // 2. Cek Database Signature Biner (Kaspersky-style Binary Memory Search)
    await BinarySignatureDatabase.loadBinaryDatabase();
    if (rawSha256Bytes != null && BinarySignatureDatabase.checkSha256BinaryMatch(rawSha256Bytes)) {
      return ScanResult(
        id: now.millisecondsSinceEpoch,
        fileHash: fileHash,
        fileName: file.path.split('/').last,
        filePath: file.path,
        verdict: ScanVerdict.malicious,
        scanSource: ScanSource.heuristicEngine,
        scannedAt: now,
      );
    }

    // 3. Deteksi Pemalsuan Ekstensi Ganda (Double Extension Spoofing)
    // Contoh: "surat_tagihan.pdf.apk", "foto_mesra.jpg.exe"
    final parts = fileName.split('.');
    if (parts.length > 2) {
      final lastExt = parts.last;
      final secondLastExt = parts[parts.length - 2];
      final fakeMediaExts = {'jpg', 'jpeg', 'png', 'pdf', 'docx', 'xlsx', 'txt', 'mp4'};

      if (_highRiskExtensions.contains(lastExt) && fakeMediaExts.contains(secondLastExt)) {
        return ScanResult(
          id: now.millisecondsSinceEpoch,
          fileHash: fileHash,
          fileName: file.path.split('/').last,
          filePath: file.path,
          verdict: ScanVerdict.malicious,
          scanSource: ScanSource.heuristicEngine,
          scannedAt: now,
        );
      }
    }

    // 4. Analisis Kata Kunci Mencurigakan pada Nama File
    for (final keyword in _suspiciousKeywords) {
      if (fileName.contains(keyword)) {
        return ScanResult(
          id: now.millisecondsSinceEpoch,
          fileHash: fileHash,
          fileName: file.path.split('/').last,
          filePath: file.path,
          verdict: ScanVerdict.malicious,
          scanSource: ScanSource.heuristicEngine,
          scannedAt: now,
        );
      }
    }

    // 5. Cek Header Magic Bytes (Pemalsuan Tipe File)
    // Contoh: File dinamai .png atau .jpg tapi isinya APK/ZIP (Magic Byte PK\x03\x04)
    try {
      if (await file.exists() && (await file.length()) > 4) {
        final header = await file.openRead(0, 4).first;
        if (header.length >= 4) {
          final isZipOrApk = header[0] == 0x50 && header[1] == 0x4B && header[2] == 0x03 && header[3] == 0x04;
          final isImageExt = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png') || fileName.endsWith('.pdf');

          if (isZipOrApk && isImageExt) {
            return ScanResult(
              id: now.millisecondsSinceEpoch,
              fileHash: fileHash,
              fileName: file.path.split('/').last,
              filePath: file.path,
              verdict: ScanVerdict.malicious,
              scanSource: ScanSource.heuristicEngine,
              scannedAt: now,
            );
          }
        }
      }
    } catch (_) {}

    // File dianggap aman oleh Heuristic Engine lokal
    return ScanResult(
      id: now.millisecondsSinceEpoch,
      fileHash: fileHash,
      fileName: file.path.split('/').last,
      filePath: file.path,
      verdict: ScanVerdict.benign,
      scanSource: ScanSource.heuristicEngine,
      scannedAt: now,
    );
  }
}
