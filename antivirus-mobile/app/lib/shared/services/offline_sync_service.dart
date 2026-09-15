import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:antivirus_mobile/config/api_config.dart';

import 'package:antivirus_mobile/shared/services/device_id_service.dart';

class PendingTelemetryItem {
  final String fileHash;
  final String? fileName;
  final String verdict;
  final String scanSource;
  final String? scannedAt;

  PendingTelemetryItem({
    required this.fileHash,
    this.fileName,
    required this.verdict,
    this.scanSource = 'OFFLINE_HEURISTIC',
    this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
        'file_hash': fileHash,
        'file_name': fileName,
        'verdict': verdict,
        'scan_source': scanSource,
        'scanned_at': scannedAt,
      };

  factory PendingTelemetryItem.fromJson(Map<String, dynamic> json) => PendingTelemetryItem(
        fileHash: json['file_hash'] as String? ?? '',
        fileName: json['file_name'] as String?,
        verdict: json['verdict'] as String? ?? 'clean',
        scanSource: json['scan_source'] as String? ?? 'OFFLINE_HEURISTIC',
        scannedAt: json['scanned_at'] as String?,
      );
}

class OfflineSyncService {
  static bool _isSyncing = false;
  static bool autoFlush = true;

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/pending_telemetry_store.json');
    } catch (_) {
      try {
        return File('${Directory.systemTemp.path}/pending_telemetry_store.json');
      } catch (_) {
        return null;
      }
    }
  }

  /// Membaca jumlah antrean offline yang belum tersinkronisasi
  static Future<int> getPendingCount() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) return 0;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return 0;
      final list = jsonDecode(content) as List<dynamic>;
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  /// Membaca daftar item antrean offline dari disk
  static Future<List<PendingTelemetryItem>> getPendingItems() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => PendingTelemetryItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Membersihkan antrean lokal (Utility Debug)
  static Future<void> clearQueue() async {
    try {
      final file = await _getFile();
      if (file != null) {
        await file.writeAsString(jsonEncode([]));
        debugPrint('🧹 [OFFLINE LOG] Antrean lokal berhasil dibersihkan.');
      }
    } catch (e) {
      debugPrint('🛑 [OFFLINE LOG] Gagal membersihkan antrean: $e');
    }
  }

  /// Simulasi pemindaian offline untuk pengujian (Testing Helper)
  static Future<void> simulateOfflineScans({int count = 3}) async {
    debugPrint('\n==================================================');
    debugPrint('🧪 [OFFLINE LOG TEST] Menjalankan Simulasi $count Pemindaian Offline...');
    debugPrint('==================================================');
    final dummyFiles = [
      {'name': 'sample_trojan_test.apk', 'hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 'verdict': 'MALICIOUS'},
      {'name': 'document_laporan.pdf', 'hash': '88d4266ec4e6333537722d36484e5a26620579e00040b7147b01d3080c5d326f', 'verdict': 'BENIGN'},
      {'name': 'photo_liburan.jpg', 'hash': 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb', 'verdict': 'BENIGN'},
    ];

    for (var i = 0; i < count; i++) {
      final sample = dummyFiles[i % dummyFiles.length];
      await enqueueOfflineScan(
        fileHash: sample['hash']!,
        fileName: sample['name'],
        verdict: sample['verdict']!,
        scanSource: 'OFFLINE_HEURISTIC',
      );
    }
  }

  /// Menambahkan hasil pemindaian offline ke antrean lokal
  static Future<void> enqueueOfflineScan({
    required String fileHash,
    String? fileName,
    required String verdict,
    String scanSource = 'OFFLINE_HEURISTIC',
  }) async {
    try {
      final file = await _getFile();
      if (file == null) return;

      List<dynamic> list = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(content);
            if (decoded is List<dynamic>) {
              list = decoded;
            }
          } catch (e) {
            debugPrint('⚠️ [OFFLINE QUEUE] File antrean di disk terkorupsi ($e). Memulihkan & mereset file antrean...');
            list = [];
          }
        }
      }

      final newItem = PendingTelemetryItem(
        fileHash: fileHash,
        fileName: fileName,
        verdict: verdict.toUpperCase(),
        scanSource: scanSource,
        scannedAt: DateTime.now().toIso8601String(),
      );

      list.add(newItem.toJson());
      await file.writeAsString(jsonEncode(list));
      debugPrint('📦 [OFFLINE QUEUE] Ditambahkan ke Antrean Offline: "${fileName ?? fileHash.substring(0, 8)}" (Status: $verdict) | Total Antrean: ${list.length} Item');

      // Coba flush otomatis jika koneksi sudah tersedia
      if (autoFlush) flushPendingQueue();
    } catch (e) {
      debugPrint('🛑 [OFFLINE QUEUE] Gagal menyimpan ke antrean offline: $e');
    }
  }

  /// Mengirimkan seluruh antrean log offline ke API Backend Cloud
  static Future<void> flushPendingQueue() async {
    if (_isSyncing) return;

    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      List<dynamic> rawList = [];
      try {
        final decoded = jsonDecode(content);
        if (decoded is List<dynamic>) rawList = decoded;
      } catch (e) {
        debugPrint('⚠️ [OFFLINE SYNC] File antrean terkorupsi ($e). Memulihkan file antrean...');
        await file.writeAsString(jsonEncode([]));
        return;
      }
      if (rawList.isEmpty) return;

      _isSyncing = true;
      final items = rawList
          .map((itemMap) => PendingTelemetryItem.fromJson(itemMap as Map<String, dynamic>))
          .toList();

      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      debugPrint('\n================================================================');
      debugPrint('🌐 [OFFLINE SYNC FLUSH] Mengirim ${items.length} Log Pemindaian Real ke Cloud...');
      debugPrint('   Target API: ${ApiConfig.baseUrl}/scans/sync-telemetry');
      debugPrint('   Device ID : $deviceId');
      debugPrint('   Daftar Berkas Fisik Real:');
      for (var idx = 0; idx < items.length; idx++) {
        final it = items[idx];
        final shortHash = (it.fileHash.length >= 16) ? it.fileHash.substring(0, 16) : it.fileHash;
        debugPrint('   [${idx + 1}] ${it.fileName ?? 'Unknown'} | Hash: $shortHash... | Verdict: ${it.verdict} | Time: ${it.scannedAt}');
      }
      debugPrint('----------------------------------------------------------------');

      final payloadJson = {
        'device_id': deviceId,
        'items': items.map((i) => i.toJson()).toList(),
      };

      http.Response? response;
      final endpoints = [
        '${ApiConfig.baseUrl}/scans/sync-telemetry',
      ];

      for (final endpoint in endpoints) {
        try {
          debugPrint('   Target API: $endpoint');
          final res = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payloadJson),
          ).timeout(const Duration(seconds: 15));
          response = res;
          if (res.statusCode == 200 || res.statusCode == 201) {
            break;
          }
        } catch (e) {
          debugPrint('   Gagal koneksi ke $endpoint: $e');
        }
      }

      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        await file.writeAsString(jsonEncode([]));
        debugPrint('✅ [OFFLINE SYNC SUCCESS] HTTP ${response.statusCode} OK!');
        debugPrint('   Respons Server: ${response.body}');
        debugPrint('   Status: ${items.length} Log Real Berhasil Tersimpan di Database Cloud PostgreSQL.');
        debugPrint('   Antrean Lokal: Dikosongkan (0 Pending Items).');
        debugPrint('================================================================\n');
      } else {
        debugPrint('⚠️ [OFFLINE SYNC WARNING] Cloud Server merespons HTTP Status ${response?.statusCode ?? 500}');
        debugPrint('   Body Respons: ${response?.body ?? 'No Response'}');
        debugPrint('   Status: ${items.length} item tetap ditahan di antrean lokal.');
        debugPrint('================================================================\n');
      }
    } catch (e) {
      debugPrint('🛑 [OFFLINE SYNC OFFLINE] Gagal menjangkau Cloud Server ($e).');
      debugPrint('   Semua item tetap tersimpan aman di disk lokal untuk dicoba ulang saat koneksi pulih.\n');
    } finally {
      _isSyncing = false;
    }
  }

  static Timer? _autoSyncTimer;

  /// Memulai background listener yang mendeteksi koneksi internet pulih secara otomatis setiap 5 detik
  static void startAutoSyncListener() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!autoFlush) return;
      final count = await getPendingCount();
      if (count > 0 && !_isSyncing) {
        flushPendingQueue();
      }
    });
  }
}
