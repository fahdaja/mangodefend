import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:antivirus_mobile/config/api_config.dart';

/// Mesin Pembaca Database Signature Biner (Enterprise Binary Signature Engine)
/// Format Header 20 Bytes (MDB1 Enterprise Standard):
/// - Offset 0..3   (4 Bytes)  : Magic 'MDB1'
/// - Offset 4..7   (4 Bytes)  : Schema Version (uint32 Big Endian)
/// - Offset 8..11  (4 Bytes)  : Entry Count (uint32 Big Endian)
/// - Offset 12..19 (8 Bytes)  : Build Timestamp (uint64 Big Endian)
/// - Offset 20..   (Payload)  : Sorted SHA-256 Hashes (32 Bytes per record)
class BinarySignatureDatabase {
  static Uint8List? _binaryBuffer;
  static int _entryCount = 0;
  static int _schemaVersion = 1;
  static int _buildTimestamp = 0;
  static int _headerSize = 20;
  static bool _isLoaded = false;
  static bool _isUpdatedFromCloud = false;

  /// Ukuran hash SHA-256 biner (32 bytes per entry)
  static const int _hashByteSize = 32;

  /// Path file update biner lokal di penyimpanan internal HP
  static Future<File?> _getUpdatedDatabaseFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/signatures_updated.bin');
    } catch (_) {
      return null;
    }
  }

  /// Memuat database biner ke RAM (Mendukung Dynamic Cloud Update)
  static Future<void> loadBinaryDatabase({bool forceReload = false}) async {
    if (_isLoaded && !forceReload) return;

    try {
      final updatedFile = await _getUpdatedDatabaseFile();

      // Priority 1: Baca file update terbaru jika tersedia di disk lokal HP
      if (updatedFile != null && await updatedFile.exists()) {
        final bytes = await updatedFile.readAsBytes();
        if (_parseBinaryBuffer(bytes)) {
          _isUpdatedFromCloud = true;
          debugPrint('Berhasil memuat Database Signature Enterprise dari update lokal disk ($_entryCount entry, v$_schemaVersion).');
          return;
        }
      }

      // Priority 2: Fallback ke asset biner bawaan aplikasi (assets/signatures.bin)
      final ByteData data = await rootBundle.load('assets/signatures.bin');
      final bytes = data.buffer.asUint8List();
      if (_parseBinaryBuffer(bytes)) {
        debugPrint('Berhasil memuat Database Signature dari asset biner bawaan ($_entryCount entry, v$_schemaVersion).');
      }
    } catch (e) {
      debugPrint('Gagal memuat database signature biner: $e');
    }
  }

  /// Parser buffer biner (Mendukung 20-Byte Enterprise Header & Legacy 8-Byte Header)
  static bool _parseBinaryBuffer(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x4D && // M
        bytes[1] == 0x44 && // D
        bytes[2] == 0x42 && // B
        bytes[3] == 0x31) { // 1

      final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);

      // Cek apakah menggunakan Format Enterprise 20-Bytes Header
      if (bytes.length >= 20) {
        _schemaVersion = bd.getUint32(4, Endian.big);
        _entryCount = bd.getUint32(8, Endian.big);
        _buildTimestamp = bd.getUint64(12, Endian.big);
        _headerSize = 20;
      } else {
        // Fallback untuk Legacy 8-Bytes Header
        _schemaVersion = 1;
        _entryCount = bd.getUint32(4, Endian.big);
        _buildTimestamp = DateTime.now().millisecondsSinceEpoch;
        _headerSize = 8;
      }

      _binaryBuffer = bytes;
      _isLoaded = true;
      return true;
    }
    return false;
  }

  /// Memperbarui Database Biner dari Cloud Server Backend
  static Future<bool> syncSignaturesFromCloud({
    String? baseUrl,
    http.Client? client,
  }) async {
    final serverUrl = baseUrl ?? ApiConfig.baseUrl;
    final httpClient = client ?? http.Client();
    final uri = Uri.parse('$serverUrl/scans/signatures/latest');

    try {
      final response = await httpClient.get(uri);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        final countHeader = response.headers['x-signature-count'];
        final formatHeader = response.headers['x-format-version'];

        // Validasi header MDB1 (minimal 8 atau 20 byte header) sebelum disimpan ke disk
        if (bytes.length >= 8 && bytes[0] == 0x4D && bytes[1] == 0x44 && bytes[2] == 0x42 && bytes[3] == 0x31) {
          final file = await _getUpdatedDatabaseFile();
          if (file != null) {
            await file.writeAsBytes(bytes);
          }

          // Hot-reload ke memori biner tanpa perlu restart aplikasi
          _parseBinaryBuffer(bytes);
          _isUpdatedFromCloud = true;
          debugPrint('Database Signature Enterprise ($formatHeader) berhasil di-update dari Cloud! Total: $_entryCount entry (Header X-Count: $countHeader, v$_schemaVersion)');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Gagal mengunduh update database signature dari cloud: $e');
    }
    return false;
  }

  /// Melakukan Binary Search O(log N) langsung di Buffer Memori Biner
  static bool checkSha256BinaryMatch(Uint8List fileSha256Bytes) {
    if (!_isLoaded || _binaryBuffer == null || fileSha256Bytes.length != 32 || _entryCount == 0) {
      return false;
    }

    int low = 0;
    int high = _entryCount - 1;
    final int dataOffset = _headerSize; // 20 bytes (atau 8 bytes legacy)

    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      final int offset = dataOffset + (mid * _hashByteSize);

      if (offset + 32 > _binaryBuffer!.length) break;

      int cmp = 0;
      for (int i = 0; i < 32; i++) {
        final int byteA = fileSha256Bytes[i];
        final int byteB = _binaryBuffer![offset + i];
        if (byteA != byteB) {
          cmp = byteA - byteB;
          break;
        }
      }

      if (cmp == 0) {
        return true; // Match ditemukan secara instan di memori biner!
      } else if (cmp < 0) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return false;
  }

  /// Memeriksa file asli berdasarkan SHA-256 hash terhadap database biner
  static Future<bool> checkFileBinaryMatch(File file) async {
    if (!await file.exists()) return false;
    await loadBinaryDatabase();
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      final sha256Bytes = Uint8List.fromList(digest.bytes);
      return checkSha256BinaryMatch(sha256Bytes);
    } catch (_) {
      return false;
    }
  }

  /// Getter Meta Info Enterprise Signature Database
  static int get loadedBinaryEntries => _entryCount;
  static int get schemaVersion => _schemaVersion;
  static int get buildTimestamp => _buildTimestamp;
  static int get headerSize => _headerSize;
  static bool get isLoaded => _isLoaded;
  static bool get isUpdatedFromCloud => _isUpdatedFromCloud;
}
