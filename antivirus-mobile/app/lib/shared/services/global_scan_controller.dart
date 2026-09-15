import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/features/scan/data/remote/cloud_scan_service.dart';
import 'package:antivirus_mobile/features/scan/data/local/scan_history_store.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';
import 'package:antivirus_mobile/features/auth/auth.dart';

import 'package:antivirus_mobile/shared/services/device_id_service.dart';
import 'package:antivirus_mobile/shared/services/storage_permission_service.dart';
import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/shared/widgets/account_question_dialog.dart';
import 'package:antivirus_mobile/shared/widgets/scan_complete_dialog.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';
import 'package:antivirus_mobile/main.dart';

class GlobalScanController {
  static final GlobalScanController instance = GlobalScanController._();
  GlobalScanController._();

  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);
  final ValueNotifier<double> scanProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<int> scannedFiles = ValueNotifier<int>(0);
  final ValueNotifier<int> threatsFound = ValueNotifier<int>(0);
  final ValueNotifier<String> currentScanType = ValueNotifier<String>('Full System Scan');
  final ValueNotifier<String> lastScanTime = ValueNotifier<String>('');
  final ValueNotifier<DateTime?> lastScanDateTime = ValueNotifier<DateTime?>(null);
  final ValueNotifier<int> activeTabIndex = ValueNotifier<int>(0);
  final ValueNotifier<String> currentScanningFilePath = ValueNotifier<String>('');

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/last_scan_store.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    await loadFromDisk();
    await syncLastScanFromCloud();
  }

  /// Memulihkan riwayat timestamp pemindaian terakhir dari Cloud DB berdasarkan Motherboard Hardware Device ID
  Future<void> syncLastScanFromCloud() async {
    try {
      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      final endpoints = [
        '${ApiConfig.baseUrl}/scans/history/$deviceId?limit=1',
      ];

      for (final url in endpoints) {
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final list = jsonDecode(res.body) as List<dynamic>;
            if (list.isNotEmpty) {
              final latestLog = list.first as Map<String, dynamic>;
              final scannedAtStr = latestLog['scanned_at'] as String?;
              if (scannedAtStr != null) {
                final cloudDate = DateTime.tryParse(scannedAtStr);
                if (cloudDate != null) {
                  if (lastScanDateTime.value == null || cloudDate.isAfter(lastScanDateTime.value!)) {
                    lastScanDateTime.value = cloudDate;
                    final now = cloudDate.toLocal();
                    lastScanTime.value = 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
                    await saveToDisk();
                    debugPrint('🕒 [LAST SCAN SYNC] Berhasil menyinkronkan waktu scan terakhir dari Cloud untuk Motherboard ID ($deviceId): $cloudDate');
                  }
                }
              }
            }
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [LAST SCAN SYNC] Gagal menyinkronkan lastScanDateTime dari cloud: $e');
    }
  }

  Future<void> loadFromDisk() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          final timeStr = jsonMap['last_scan_time'] as String?;
          final dateStr = jsonMap['last_scan_date'] as String?;
          if (timeStr != null) lastScanTime.value = timeStr;
          if (dateStr != null) lastScanDateTime.value = DateTime.tryParse(dateStr);
        }
      }
    } catch (e) {
      debugPrint('Gagal membaca lastScanDateTime dari disk: $e');
    }
  }

  Future<void> saveToDisk() async {
    try {
      final file = await _getFile();
      if (file != null) {
        await file.writeAsString(jsonEncode({
          'last_scan_time': lastScanTime.value,
          'last_scan_date': lastScanDateTime.value?.toIso8601String(),
        }));
      }
    } catch (e) {
      debugPrint('Gagal menyimpan lastScanDateTime ke disk: $e');
    }
  }

  bool _isCancelRequested = false;

  void cancelScan() {
    _isCancelRequested = true;
    isScanning.value = false;
  }

  Future<void> startScan({
    BuildContext? context,
    required ScanType scanType,
    File? singleFile,
    Directory? folder,
    VoidCallback? onNavigateToActivity,
  }) async {
    if (isScanning.value) return;

    if (GuestQuotaService.isGuestQuotaExceeded) {
      if (context != null) {
        AccountQuestionDialog.show(
          context,
          isQuotaLimit: true,
          title: 'Batas Pemindaian Gratis Tamu Tercapai!',
          description: 'Batas kuota harian pemindaian tanpa login (15 scan/hari) telah habis. Silakan Masuk atau Buat Akun Gratis untuk menikmati kuota harian 30x pemindaian Free Plan!',
          onLoginPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          onRegisterPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegisterScreen(),
              ),
            );
          },
        );
      }
      return;
    }

    if (context != null) {
      final hasPermission = await StoragePermissionService.requestStoragePermission(context);
      if (!hasPermission) return;
    }

    _isCancelRequested = false;
    isScanning.value = true;
    scanProgress.value = 0.0;
    scannedFiles.value = 0;
    threatsFound.value = 0;
    currentScanType.value = scanType.value;
    currentScanningFilePath.value = singleFile?.path ?? folder?.path ?? 'Inisialisasi Sistem...';

    final stopwatch = Stopwatch()..start();

    int actualScanned = 0;
    int actualThreats = 0;

    try {
      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      final results = await CloudScanService().scanBySelectedType(
        type: scanType,
        singleFile: singleFile,
        targetFolder: folder,
        deviceId: deviceId,
        onProgress: (progress, lastResult) {
          scanProgress.value = progress;
          if (lastResult != null) {
            scannedFiles.value++;
            if (lastResult.filePath != null && lastResult.filePath!.isNotEmpty) {
              currentScanningFilePath.value = lastResult.filePath!;
            } else if (lastResult.fileName != null && lastResult.fileName!.isNotEmpty) {
              currentScanningFilePath.value = lastResult.fileName!;
            }
            if (lastResult.verdict == ScanVerdict.malicious) {
              threatsFound.value++;
            }
          }
        },
        isCancelled: () => _isCancelRequested,
      );

      stopwatch.stop();
      final durationStr = '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';

      if (results.isNotEmpty) {
        actualScanned = results.length;
        actualThreats = results.where((r) => r.verdict == ScanVerdict.malicious).length;
      } else if (scanType == ScanType.file && !_isCancelRequested) {
        actualScanned = 1;
      } else {
        actualScanned = scannedFiles.value;
        actualThreats = threatsFound.value;
      }

      scannedFiles.value = actualScanned;
      threatsFound.value = actualThreats;
      isScanning.value = false;

      final now = DateTime.now();
      final timeStr = 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
      lastScanTime.value = timeStr;
      lastScanDateTime.value = now;
      saveToDisk();

      final isMalicious = actualThreats > 0;

      // Handling Cancellation Case
      if (_isCancelRequested) {
        // 1. Record Cancellation into ScanHistoryStore
        ScanHistoryStore.addRecord(
          ScanHistoryRecord(
            title: 'Pemindaian Dibatalkan (${scanType.value})',
            subtitle: isMalicious
                ? '$actualScanned File Dipindai • $actualThreats Terdeteksi Malware'
                : '$actualScanned File Sempat Dipindai • Dibatalkan Pengguna',
            time: timeStr,
            iconData: isMalicious ? Icons.warning_amber_outlined : Icons.cancel_outlined,
            iconColor: isMalicious ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
            isMalicious: isMalicious,
            filePath: singleFile?.path ?? folder?.path ?? 'Penyimpanan Utama',
            fileSize: 'Dibatalkan Parsial',
          ),
        );

        // 2. Prepare threat items if any found before cancellation (only malicious files)
        final quarantinedDetails = <QuarantinedFileDetail>[];
        if (results.isNotEmpty) {
          for (final res in results) {
            if (res.verdict != ScanVerdict.malicious) continue;

            final fileLoc = res.filePath != null ? File(res.filePath!) : null;
            if (fileLoc == null) continue;

            final realOriginalFile = await LocalQuarantineService.resolveRealOriginalFile(fileLoc);

            String itemSizeStr = '0.0 KB';
            try {
              if (fileLoc.existsSync()) {
                itemSizeStr = '${(fileLoc.lengthSync() / 1024).toStringAsFixed(1)} KB';
              }
            } catch (_) {}

            quarantinedDetails.add(
              QuarantinedFileDetail(
                fileName: fileLoc.path.split('/').last,
                filePath: realOriginalFile.path,
                quarantinedPath: null,
                threatType: 'Terindikasi Malware (Dibatalkan Mid-Scan)',
                fileSize: itemSizeStr,
                isSafe: false,
              ),
            );
          }
        }

        // 3. Record into ActivityStore as Cancelled
        final logId = 'log_${now.millisecondsSinceEpoch}';
        ActivityStore.addLog(
          ActivityLogItem(
            id: logId,
            title: isMalicious
                ? 'Pemindaian Dibatalkan ($actualThreats Ancaman)'
                : 'Pemindaian Dibatalkan oleh Pengguna',
            subtitle: isMalicious
                ? '$actualScanned file diperiksa, $actualThreats ancaman terdeteksi sebelum dibatalkan'
                : '$actualScanned file diperiksa sebelum pemindaian dihentikan',
            time: timeStr,
            category: isMalicious ? 'Ancaman' : 'Pemindaian',
            badgeText: isMalicious ? '$actualThreats Terdeteksi' : 'Dibatalkan',
            isQuarantined: false,
            files: quarantinedDetails,
          ),
        );

        // 4. Notify User via SnackBar
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMalicious
                    ? 'Pemindaian dibatalkan. $actualScanned file diperiksa, $actualThreats ancaman terdeteksi!'
                    : 'Pemindaian dibatalkan. $actualScanned file sempat diperiksa.',
              ),
              backgroundColor: isMalicious ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      GuestQuotaService.incrementGuestScanCount();

      // 1. Record into ScanHistoryStore
      ScanHistoryStore.addRecord(
        ScanHistoryRecord(
          title: scanType == ScanType.file
              ? 'Pemeriksaan File: ${singleFile?.path.split('/').last}'
              : (scanType == ScanType.folder
                  ? 'Pemindaian Folder: ${folder?.path.split('/').last}'
                  : 'Full System Scan Selesai'),
          subtitle: isMalicious
              ? '$actualScanned File Dipindai • $actualThreats Terindikasi Malware'
              : '$actualScanned File Dipindai • Perangkat Bebas Ancaman',
          time: timeStr,
          iconData: isMalicious ? Icons.bug_report_outlined : Icons.check_circle_outline,
          iconColor: isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          isMalicious: isMalicious,
          filePath: singleFile?.path ?? folder?.path ?? 'Penyimpanan Utama',
          fileSize: 'Memori/Sistem',
        ),
      );

      // 2. Record into ActivityStore (only include malicious files in detail list)
      final logId = 'log_${now.millisecondsSinceEpoch}';
      final quarantinedDetails = <QuarantinedFileDetail>[];

      if (results.isNotEmpty) {
        for (final res in results) {
          if (res.verdict != ScanVerdict.malicious) continue;

          final fileLoc = res.filePath != null ? File(res.filePath!) : null;
          if (fileLoc == null) continue;

          final realOriginalFile = await LocalQuarantineService.resolveRealOriginalFile(fileLoc);

          String itemSizeStr = '0.0 KB';
          try {
            if (fileLoc.existsSync()) {
              itemSizeStr = '${(fileLoc.lengthSync() / 1024).toStringAsFixed(1)} KB';
            }
          } catch (_) {}

          quarantinedDetails.add(
            QuarantinedFileDetail(
              fileName: fileLoc.path.split('/').last,
              filePath: realOriginalFile.path,
              quarantinedPath: null,
              threatType: 'Terindikasi Malware (Perlu Tinjauan)',
              fileSize: itemSizeStr,
              isSafe: false,
            ),
          );
        }
      }

      ActivityStore.addLog(
        ActivityLogItem(
          id: logId,
          title: scanType == ScanType.file
              ? 'Pemeriksaan File Selesai'
              : (scanType == ScanType.folder ? 'Pemindaian Folder Selesai' : 'Full System Scan Selesai'),
          subtitle: isMalicious ? 'Ditemukan $actualThreats ancaman malware' : 'Seluruh file terdeteksi aman',
          time: timeStr,
          category: isMalicious ? 'Ancaman' : 'Pemindaian',
          badgeText: isMalicious ? '$actualThreats Terdeteksi' : 'Sistem Aman',
          isQuarantined: false,
          files: quarantinedDetails,
        ),
      );

      // 3. Context-Aware Scan Result Presentation (Standar Industri UX Antivirus)
      final activeContext = MyApp.navigatorKey.currentContext ?? ((context != null && context.mounted) ? context : null);
      if (activeContext != null && activeContext.mounted) {
        final currentTab = activeTabIndex.value;
        final bool isHomeOrScanTab = (currentTab == 0 || currentTab == 1);

        if (isHomeOrScanTab) {
          // A. Pengguna berada di Tab Beranda / Pemindaian -> Tampilkan Full Result Modal Dialog
          ScanCompleteDialog.show(
            activeContext,
            filesScanned: actualScanned,
            threatsFound: actualThreats,
            duration: durationStr,
            scannedFileName: singleFile?.path.split('/').last,
            isSingleFileScan: scanType == ScanType.file,
            onViewActivity: onNavigateToActivity,
            onQuarantineThreats: () async {
              final threatFiles = <File>[];
              if (results.isNotEmpty) {
                for (final res in results) {
                  if (res.verdict == ScanVerdict.malicious && res.filePath != null) {
                    final f = File(res.filePath!);
                    final realFile = await LocalQuarantineService.resolveRealOriginalFile(f);
                    if (realFile.existsSync()) {
                      threatFiles.add(realFile);
                    } else if (f.existsSync()) {
                      threatFiles.add(f);
                    }
                  }
                }
              }

              if (threatFiles.isEmpty) return;

              final quarantinedThreats = <QuarantinedFileDetail>[];
              for (final tf in threatFiles) {
                final realOriginalFile = await LocalQuarantineService.resolveRealOriginalFile(tf);
                final qPath = await LocalQuarantineService.quarantineFile(tf);
                final fileName = tf.path.split('/').last;

                double sizeKb = 0;
                try {
                  sizeKb = tf.lengthSync() / 1024;
                } catch (_) {}

                quarantinedThreats.add(
                  QuarantinedFileDetail(
                    fileName: fileName,
                    filePath: realOriginalFile.path,
                    quarantinedPath: qPath,
                    threatType: 'Malware (Dikarantina Pengguna)',
                    fileSize: '${sizeKb.toStringAsFixed(1)} KB',
                    isSafe: false,
                  ),
                );
              }

              if (quarantinedThreats.isNotEmpty) {
                final count = quarantinedThreats.length;
                final qLogId = 'log_${DateTime.now().millisecondsSinceEpoch}';
                ActivityStore.addLog(
                  ActivityLogItem(
                    id: qLogId,
                    title: 'Karantina Ancaman ($count File)',
                    subtitle: '$count file terindikasi malware berhasil diisolasikan',
                    time: 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}',
                    category: 'Karantina',
                    badgeText: '$count File Dikarantina',
                    isQuarantined: true,
                    files: quarantinedThreats,
                  ),
                );

                final qContext = MyApp.navigatorKey.currentContext ?? ((context != null && context.mounted) ? context : null);
                if (qContext != null && qContext.mounted) {
                  ScaffoldMessenger.of(qContext).showSnackBar(
                    SnackBar(
                      content: Text('$count Ancaman BERHASIL DIPINDAHKAN KE VAULT KARANTINA!'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                onNavigateToActivity?.call();
              }
            },
          );
        } else {
          // B. Pengguna sedang di Tab Lain (Proteksi / Aktivitas) -> Tampilkan Non-Disruptive Top Material Banner
          final isDark = Theme.of(activeContext).brightness == Brightness.dark;
          ScaffoldMessenger.of(activeContext).hideCurrentMaterialBanner();
          ScaffoldMessenger.of(activeContext).showMaterialBanner(
            MaterialBanner(
              elevation: 4,
              backgroundColor: isMalicious
                  ? const Color(0xFFEF4444)
                  : (isDark ? const Color(0xFF065F46) : const Color(0xFF10B981)),
              leading: Icon(
                isMalicious ? Icons.bug_report_rounded : Icons.verified_user_rounded,
                color: Colors.white,
                size: 26,
              ),
              content: Text(
                isMalicious
                    ? '⚠️ Ancaman Terdeteksi! $actualThreats malware ditemukan ($actualScanned dipindai).'
                    : '✅ Pemindaian Selesai: Perangkat bebas dari ancaman ($actualScanned file dipindai).',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              actions: [
                if (isMalicious)
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(activeContext).hideCurrentMaterialBanner();
                      onNavigateToActivity?.call();
                    },
                    child: const Text(
                      'TINJAU',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(activeContext).hideCurrentMaterialBanner();
                  },
                  child: const Text(
                    'TUTUP',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );

          // Otomatis sembunyikan banner setelah 6 detik
          Future.delayed(const Duration(seconds: 6), () {
            try {
              final ctx = MyApp.navigatorKey.currentContext;
              if (ctx != null && ctx.mounted) {
                ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner();
              }
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      isScanning.value = false;
      final activeContext = MyApp.navigatorKey.currentContext ?? ((context != null && context.mounted) ? context : null);
      if (activeContext != null && activeContext.mounted) {
        if (e is GuestQuotaExceededException) {
          AccountQuestionDialog.show(
            activeContext,
            isQuotaLimit: true,
            title: 'Batas Pemindaian Gratis Tamu Tercapai!',
            description: e.message,
            onLoginPressed: () {
              Navigator.push(
                activeContext,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            onRegisterPressed: () {
              Navigator.push(
                activeContext,
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
          );
        } else {
          ScaffoldMessenger.of(activeContext).showSnackBar(
            SnackBar(
              content: Text('Gagal melakukan pemindaian: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
