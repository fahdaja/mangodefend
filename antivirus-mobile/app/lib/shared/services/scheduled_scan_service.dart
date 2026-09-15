import 'dart:async';
import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/shared/services/global_scan_controller.dart';
import 'package:antivirus_mobile/features/protection/data/local/protection_local_datasource.dart';

/// Service untuk menangani Pemindaian Otomatis Terjadwal (Scheduled Scan) setiap jam 02:00 Pagi
class ScheduledScanService {
  static final ScheduledScanService instance = ScheduledScanService._();
  ScheduledScanService._();

  Timer? _initialTimer;
  Timer? _dailyTimer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Memulai jadwal pemindaian otomatis harian pada jam 02:00 Pagi
  void startSchedule({int targetHour = 2, int targetMinute = 0}) {
    stopSchedule();
    _isRunning = true;

    final initialDelay = _durationUntilNextTargetTime(targetHour, targetMinute);
    final targetTimeFormatted = '${targetHour.toString().padLeft(2, '0')}:${targetMinute.toString().padLeft(2, '0')}';

    debugPrint(
      '⏰ [SCHEDULED SCAN] Service diaktifkan! Scan otomatis dijadwalkan setiap jam $targetTimeFormatted WIB '
      '(Scan berikutnya dalam ${initialDelay.inHours}j ${initialDelay.inMinutes % 60}m).',
    );

    // Timer 1: Menunggu hingga jam 02:00 Pagi pertama
    _initialTimer = Timer(initialDelay, () {
      _executeAndScheduleDailyRepeat(targetHour, targetMinute);
    });
  }

  void _executeAndScheduleDailyRepeat(int targetHour, int targetMinute) async {
    final isEnabled = ProtectionLocalDataSource.currentConfig.scheduledScan;
    if (!isEnabled) {
      stopSchedule();
      return;
    }

    // 1. Jalankan pemindaian otomatis jam 02:00 Pagi
    await triggerScheduledScan();

    // 2. Ulangi pemindaian otomatis setiap 24 jam sekali (setiap jam 02:00 Pagi berikutnya)
    _dailyTimer = Timer.periodic(const Duration(hours: 24), (timer) async {
      final isStillEnabled = ProtectionLocalDataSource.currentConfig.scheduledScan;
      if (!isStillEnabled) {
        stopSchedule();
        return;
      }
      await triggerScheduledScan();
    });
  }

  /// Menghitung durasi jeda waktu hingga jam 02:00 Pagi berikutnya
  Duration _durationUntilNextTargetTime(int targetHour, int targetMinute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, targetHour, targetMinute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }

  /// Menghentikan service pemindaian otomatis terjadwal
  void stopSchedule() {
    _initialTimer?.cancel();
    _initialTimer = null;
    _dailyTimer?.cancel();
    _dailyTimer = null;
    _isRunning = false;
    debugPrint('⏹️ [SCHEDULED SCAN] Service pemindaian terjadwal dihentikan.');
  }

  /// Menjalankan pemindaian penuh (Full System Scan) secara otomatis
  Future<void> triggerScheduledScan({BuildContext? context}) async {
    if (GlobalScanController.instance.isScanning.value) {
      debugPrint('⚠️ [SCHEDULED SCAN] Pemindaian dilewati karena pemindaian lain sedang berjalan.');
      return;
    }

    debugPrint('🚀 [SCHEDULED SCAN 02:00 AM] Menjalankan Pemindaian Otomatis Terjadwal (Full System Scan)...');
    try {
      await GlobalScanController.instance.startScan(
        context: context,
        scanType: ScanType.fullSystem,
      );
    } catch (e) {
      debugPrint('❌ [SCHEDULED SCAN] Error pemindaian terjadwal: $e');
    }
  }
}
