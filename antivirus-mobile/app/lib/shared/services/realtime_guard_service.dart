import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:antivirus_mobile/features/scan/data/local/local_heuristic_engine.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';
import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/features/scan/data/local/running_service_inspector.dart';
import 'package:antivirus_mobile/features/scan/data/remote/cloud_scan_service.dart';

/// Service Proteksi Real-Time (Real-Time Guard)
/// Memindai berkas secara nyata menggunakan LocalHeuristicEngine & BinarySignatureDatabase
class RealtimeGuardService {
  static final RealtimeGuardService instance = RealtimeGuardService._();
  RealtimeGuardService._();

  final CloudScanService _cloudScanService = CloudScanService();

  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  /// Memeriksa seluruh layanan & proses aplikasi latar belakang yang berjalan
  Future<ServiceAuditReport> auditActiveServices({
    required BuildContext context,
  }) async {
    final report = await RunningServiceInspector.auditRunningServices();
    final now = DateTime.now();
    final timeStr = 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
    final logId = 'log_${now.millisecondsSinceEpoch}';

    final isMalicious = report.hasMaliciousServices;

    ActivityStore.addLog(
      ActivityLogItem(
        id: logId,
        title: 'Inspeksi Layanan & Aplikasi Aktif',
        subtitle: isMalicious
            ? '${report.suspiciousServices.length} Layanan Berbahaya Terdeteksi di Latar Belakang'
            : '${report.totalServicesInspected} Layanan Latar Belakang Diinspeksi • Bebas Ancaman',
        time: timeStr,
        category: isMalicious ? 'Karantina' : 'Perlindungan',
        badgeText: isMalicious ? 'Layanan Diblokir' : 'Layanan Aman',
        isQuarantined: isMalicious,
        files: report.suspiciousServices.map((s) => QuarantinedFileDetail(
          fileName: s.packageName,
          filePath: '/system/priv-app/${s.packageName}',
          quarantinedPath: null,
          threatType: s.riskReason,
          fileSize: 'Layanan Sistem',
          isSafe: false,
        )).toList(),
      ),
    );

    if (context.mounted) {
      _showFloatingNotification(
        context: context,
        appName: isMalicious
            ? report.suspiciousServices.first.packageName
            : 'Audit ${report.totalServicesInspected} Service Aktif',
        isSafe: !isMalicious,
        fileSize: isMalicious ? 'Risiko Tinggi' : 'Layanan Sistem',
      );
    }

    return report;
  }

  /// Memindai Berkas Nyata dari Penyimpanan HP secara Real-Time dengan Hybrid Cloud ML + Engine Lokal
  Future<bool> scanRealFile({
    required BuildContext context,
    required File targetFile,
  }) async {
    if (!await targetFile.exists()) return true;

    // 1. Jalankan analisis lokal cepat (Signature Biner & Heuristik)
    final localResult = await LocalHeuristicEngine.analyzeFile(targetFile);
    bool isMalicious = localResult.verdict == ScanVerdict.malicious;
    String scanEngineSource = 'Lokal (Biner & Heuristik)';

    // 2. Jika lolos pemindaian lokal, jalankan analisis Cloud Machine Learning AI Server
    if (!isMalicious) {
      try {
        final cloudResult = await _cloudScanService.uploadAndScanFile(
          targetFile,
          scanType: ScanType.file,
        );
        if (cloudResult.verdict == ScanVerdict.malicious) {
          isMalicious = true;
          scanEngineSource = 'Cloud Machine Learning AI';
        } else {
          scanEngineSource = 'Terverifikasi Cloud ML & Engine Lokal';
        }
      } catch (e) {
        // Fallback jika cloud offline/timeout: gunakan hasil verifikasi lokal
        debugPrint('RealtimeGuard: Cloud ML offline/timeout ($e), menggunakan verifikasi lokal.');
      }
    } else {
      scanEngineSource = 'Lokal (Binary Signature Match)';
    }

    // 3. Hitung ukuran berkas asli
    String fileSizeStr = '0.0 KB';
    try {
      final len = await targetFile.length();
      fileSizeStr = '${(len / 1024).toStringAsFixed(1)} KB';
    } catch (_) {}

    final fileName = targetFile.path.split('/').last;
    final now = DateTime.now();
    final timeStr = 'Hari ini, ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
    final logId = 'log_${now.millisecondsSinceEpoch}';

    String? quarantinedPath;
    String threatTitle = 'Aman ($scanEngineSource)';

    // 4. Jika berkas terindikasi Malware, lakukan isolasi fisik ke Vault Karantina
    if (isMalicious) {
      threatTitle = 'Malware Terdeteksi ($scanEngineSource)';
      quarantinedPath = await LocalQuarantineService.quarantineFile(targetFile);
    }

    // 5. Catat riwayat asli ke ActivityStore
    ActivityStore.addLog(
      ActivityLogItem(
        id: logId,
        title: 'Proteksi Real-Time: Pemindaian Berkas',
        subtitle: isMalicious
            ? 'Berkas $fileName terdeteksi MALWARE ($scanEngineSource) & diisolasi'
            : 'Berkas $fileName dipindai & dinyatakan AMAN ($scanEngineSource)',
        time: timeStr,
        category: isMalicious ? 'Karantina' : 'Perlindungan',
        badgeText: isMalicious ? 'Ancaman Diblokir' : 'Lolos Pemindaian',
        isQuarantined: isMalicious,
        files: [
          QuarantinedFileDetail(
            fileName: fileName,
            filePath: targetFile.path,
            quarantinedPath: quarantinedPath,
            threatType: threatTitle,
            fileSize: fileSizeStr,
            isSafe: !isMalicious,
          ),
        ],
      ),
    );

    // 5. Tampilkan Notifikasi Banner Real-Time Guard
    if (context.mounted) {
      _showFloatingNotification(
        context: context,
        appName: fileName,
        isSafe: !isMalicious,
        fileSize: fileSizeStr,
      );
    }

    return !isMalicious;
  }

  /// Pemicu Pemindaian Berkas Real-Time dengan Berkas Uji Fisik Nyata di Disk
  Future<void> triggerAppInstallScan({
    required BuildContext context,
    String appName = 'Instagram_v320.0.apk',
    bool isSafe = true,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sampleFile = File('${tempDir.path}/$appName');

      if (isSafe) {
        // Tulis berkas sampel aman nyata ke disk
        await sampleFile.writeAsString('Mangodefend Clean Application Sample Data - ${DateTime.now().toIso8601String()}');
      } else {
        // Tulis berkas EICAR Anti-Malware Test String nyata ke disk
        // SHA-256 dari string EICAR ini dicocokkan langsung oleh BinarySignatureDatabase biner!
        await sampleFile.writeAsString(
          r'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*',
        );
      }

      // Panggil pemindaian biner & heuristik asli
      await scanRealFile(context: context, targetFile: sampleFile);
    } catch (e) {
      debugPrint('Gagal menjalankan simulasi berkas real-time: $e');
    }
  }

  void _showFloatingNotification({
    required BuildContext context,
    required String appName,
    required bool isSafe,
    String fileSize = '18.4 MB',
  }) {
    _dismissTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlayState = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: -100, end: 0),
              builder: (context, translateY, child) {
                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isSafe
                        ? (isDark ? const Color(0xFF059669) : const Color(0xFF10B981))
                        : (isDark ? const Color(0xFFDC2626) : const Color(0xFFEF4444)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isSafe ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: isSafe
                            ? (isDark ? const Color(0xFF065F46).withAlpha(80) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF7F1D1D).withAlpha(80) : const Color(0xFFFEF2F2)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSafe ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                        color: isSafe ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'REAL-TIME GUARD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                isSafe ? 'AMAN' : 'BAHAYA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSafe ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$appName ($fileSize)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSafe
                                ? 'Pemasangan berkas berhasil dipindai & 100% aman'
                                : 'Ancaman terdeteksi dan langsung diisolasi ke Vault Karantina',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: () {
                        _currentOverlay?.remove();
                        _currentOverlay = null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(_currentOverlay!);

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _currentOverlay?.remove();
      _currentOverlay = null;
    });
  }
}
