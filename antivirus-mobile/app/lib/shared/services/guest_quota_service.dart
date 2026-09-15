import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/shared/services/device_id_service.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';

class GuestQuotaService {
  static const int maxGuestScans = 15;
  static final ValueNotifier<int> guestScanCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> userScanCountNotifier = ValueNotifier<int>(0);
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await loadFromDisk();
    await syncQuotaWithServer();
  }

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/guest_quota_store.json');
    } catch (_) {
      return null;
    }
  }

  /// Sinkronisasi kuota pemindaian guest dengan database cloud berdasarkan Motherboard Hardware Device ID
  static Future<void> syncQuotaWithServer() async {
    try {
      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      final endpoints = [
        '${ApiConfig.baseUrl}/scans/guest-quota/$deviceId',
      ];

      for (final url in endpoints) {
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
            final cloudUsedCount = jsonMap['used_scans'] as int? ?? 0;
            final cloudSessionCount = jsonMap['session_count'] as int? ?? jsonMap['used_sessions'] as int?;

            // 1 Sesi Pemindaian (misal Full Scan) mencatat banyak file (21 file) di DB.
            // Gunakan cloudSessionCount jika server menyediakan, atau pertahankan local session count
            final localCount = guestScanCountNotifier.value;
            int effectiveCount = localCount;
            if (cloudSessionCount != null) {
              effectiveCount = cloudSessionCount;
            } else if (localCount == 0 && cloudUsedCount > 0) {
              // Jika data lokal kosong tapi ada record di cloud, gunakan perkiraan sesi scan (1)
              effectiveCount = 1;
            }

            guestScanCountNotifier.value = effectiveCount.clamp(0, maxGuestScans);
            await saveToDisk();
            debugPrint('🔒 [GUEST QUOTA] Berhasil menyinkronkan kuota dari Cloud Server untuk Motherboard ID ($deviceId): ${guestScanCountNotifier.value}/$maxGuestScans scan terpakai (Total file di DB: $cloudUsedCount).');
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [GUEST QUOTA] Gagal menyinkronkan kuota dari cloud: $e');
    }
  }

  static Future<void> loadFromDisk() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          guestScanCountNotifier.value = jsonMap['count'] as int? ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Gagal membaca GuestQuotaService dari disk: $e');
    }
  }

  static Future<void> saveToDisk() async {
    try {
      final file = await _getFile();
      if (file != null) {
        await file.writeAsString(jsonEncode({'count': guestScanCountNotifier.value}));
      }
    } catch (e) {
      debugPrint('Gagal menyimpan GuestQuotaService ke disk: $e');
    }
  }

  static int get guestScansUsed => guestScanCountNotifier.value;
  static int get remainingGuestScans => (maxGuestScans - guestScansUsed).clamp(0, maxGuestScans);
  static bool get isGuestQuotaExceeded => !UserSession.isLoggedIn && guestScansUsed >= maxGuestScans;

  static void incrementGuestScanCount() {
    if (!UserSession.isLoggedIn) {
      guestScanCountNotifier.value = guestScanCountNotifier.value + 1;
      saveToDisk();
    } else {
      userScanCountNotifier.value = userScanCountNotifier.value + 1;
    }
  }

  static Future<void> reset() async {
    guestScanCountNotifier.value = 0;
    await saveToDisk();
    await resetQuotaOnServerAndLocal();
  }

  /// Mereset kuota guest di Cloud Server PostgreSQL & lokal disk
  static Future<bool> resetQuotaOnServerAndLocal() async {
    try {
      guestScanCountNotifier.value = 0;
      await saveToDisk();

      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      final endpoints = [
        '${ApiConfig.baseUrl}/scans/guest-quota/reset/$deviceId',
      ];

      for (final url in endpoints) {
        try {
          final res = await http.post(Uri.parse(url)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            debugPrint('🔄 [GUEST QUOTA] Berhasil mereset kuota di Cloud Server & Lokal untuk $deviceId');
            return true;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [GUEST QUOTA] Gagal mereset kuota dari cloud: $e');
    }
    return false;
  }
}
