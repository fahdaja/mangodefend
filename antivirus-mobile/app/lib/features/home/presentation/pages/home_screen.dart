import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/home/presentation/widgets/protection_status_card.dart';
import 'package:antivirus_mobile/features/home/presentation/widgets/stat_card.dart';
import 'package:antivirus_mobile/features/home/presentation/widgets/recent_activity_section.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';
import 'package:antivirus_mobile/features/protection/data/local/protection_local_datasource.dart';
import 'package:antivirus_mobile/features/protection/domain/models/protection_config_model.dart';
import 'package:antivirus_mobile/shared/services/global_scan_controller.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';
import 'package:antivirus_mobile/features/auth/domain/auth_models.dart';

class HomePage extends StatelessWidget {
  final VoidCallback? onNavigateToActivity;

  const HomePage({
    super.key,
    this.onNavigateToActivity,
  });

  void _startScan(BuildContext context) {
    GlobalScanController.instance.startScan(
      context: context,
      scanType: ScanType.fullSystem,
      onNavigateToActivity: onNavigateToActivity,
    );
  }

  void _cancelScan() {
    GlobalScanController.instance.cancelScan();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Interactive Protection Status Card (Listening to GlobalScanController & ProtectionLocalDataSource)
              ValueListenableBuilder<ProtectionConfigModel>(
                valueListenable: ProtectionLocalDataSource.configNotifier,
                builder: (context, protectionConfig, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: GlobalScanController.instance.isScanning,
                    builder: (context, isScanning, child) {
                      return ValueListenableBuilder<double>(
                        valueListenable: GlobalScanController.instance.scanProgress,
                        builder: (context, scanProgress, child) {
                          return ValueListenableBuilder<int>(
                            valueListenable: GlobalScanController.instance.scannedFiles,
                            builder: (context, scannedFiles, child) {
                              return ValueListenableBuilder<String>(
                                valueListenable: GlobalScanController.instance.currentScanningFilePath,
                                builder: (context, currentPath, child) {
                                  return ProtectionStatusCard(
                                    isScanning: isScanning,
                                    scanProgress: scanProgress,
                                    scannedFiles: scannedFiles,
                                    currentScanningFilePath: currentPath,
                                    isRealtimeProtectionEnabled: protectionConfig.realTimeProtection,
                                    onScanPressed: () => _startScan(context),
                                    onCancelScan: _cancelScan,
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Smart Dynamic Guest Quota Indicator (Only visible when remaining <= 3 or exceeded)
              if (UserSession.accessToken == null)
                ValueListenableBuilder<int>(
                  valueListenable: GuestQuotaService.guestScanCountNotifier,
                  builder: (context, guestCount, _) {
                    final remaining = 15 - guestCount;
                    // UX Best Practice: Sembunyikan banner jika kuota masih banyak (> 3) agar UI tetap bersih
                    if (remaining > 3) {
                      return const SizedBox.shrink();
                    }

                    final isExceeded = remaining <= 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                      decoration: BoxDecoration(
                        color: isExceeded
                            ? (isDark ? const Color(0xFF7C2D12).withAlpha(80) : const Color(0xFFFEE2E2))
                            : (isDark ? const Color(0xFF7C2D12).withAlpha(40) : const Color(0xFFFFF7ED)),
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(
                          color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFFFDBA74),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExceeded ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded,
                            color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFFEA580C),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isExceeded
                                  ? 'Batas Kuota Pemindaian Tamu Habis (0/15 Scan). Silakan Login untuk Membuka Kuota.'
                                  : 'Peringatan Kuota: Sisa Kuota Pemindaian Tamu Tinggal $remaining Scan Hari Ini!',
                              style: TextStyle(
                                color: isExceeded
                                    ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                    : (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C)),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Gentle Scan Reminder Card (Hidden if scanned today, reappears if not scanned for >= 3 days or never scanned)
              ValueListenableBuilder<DateTime?>(
                valueListenable: GlobalScanController.instance.lastScanDateTime,
                builder: (context, lastScanDate, _) {
                  final bool shouldShowReminder;
                  if (lastScanDate == null) {
                    shouldShowReminder = true;
                  } else {
                    final now = DateTime.now();
                    final isToday = lastScanDate.year == now.year &&
                        lastScanDate.month == now.month &&
                        lastScanDate.day == now.day;
                    final differenceInDays = now.difference(lastScanDate).inDays;

                    if (isToday) {
                      shouldShowReminder = false;
                    } else if (differenceInDays >= 3) {
                      shouldShowReminder = true;
                    } else {
                      shouldShowReminder = false;
                    }
                  }

                  if (!shouldShowReminder) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFFD97706).withAlpha(80) : const Color(0xFFFDE68A),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF7C2D12).withAlpha(80) : const Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_moon_outlined, color: Color(0xFFD97706), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LanguageController.tr('scan_reminder_title'),
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                LanguageController.tr('scan_reminder_desc'),
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _startScan(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          ),
                          child: Text(
                            LanguageController.tr('scan_now_btn'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Ringkasan Keamanan Section Title
              Text(
                LanguageController.tr('security_summary'),
                style: TextStyle(
                  color: sectionTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // Statistics Section Grid with Interactive Navigation (Computed Live from ActivityStore)
              ValueListenableBuilder<List<ActivityLogItem>>(
                valueListenable: ActivityStore.logsNotifier,
                builder: (context, logs, child) {
                  String lastScanText = GlobalScanController.instance.lastScanTime.value;
                  int totalThreats = GlobalScanController.instance.threatsFound.value;
                  int totalScanned = GlobalScanController.instance.scannedFiles.value;

                  int quarantinedCount = 0;
                  if (logs.isNotEmpty) {
                    lastScanText = logs.first.time;
                    int logScanned = 0;
                    int logThreats = 0;
                    for (final item in logs) {
                      logScanned += item.files.isNotEmpty ? item.files.length : 1;
                      logThreats += item.files.where((f) => !f.isSafe).length;
                      if (item.isQuarantined) {
                        quarantinedCount += item.files.length;
                      }
                    }
                    if (totalScanned == 0) totalScanned = logScanned;
                    if (totalThreats == 0) totalThreats = logThreats;
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.access_time_outlined,
                              title: LanguageController.tr('last_scan'),
                              value: lastScanText.isNotEmpty ? lastScanText : 'Belum Pernah',
                              valueColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              iconColor: const Color(0xFF3B82F6),
                              iconBgColor: isDark ? const Color(0xFF1E3A8A).withAlpha(80) : const Color(0xFFEFF6FF),
                              onTap: onNavigateToActivity,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              icon: Icons.bug_report_outlined,
                              title: LanguageController.tr('threats_found'),
                              value: totalThreats > 0 ? '$totalThreats Ditemukan' : '0 Dimusnahkan',
                              valueColor: totalThreats > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              iconColor: totalThreats > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              iconBgColor: totalThreats > 0
                                  ? (isDark ? const Color(0xFF7F1D1D).withAlpha(80) : const Color(0xFFFEF2F2))
                                  : (isDark ? const Color(0xFF065F46).withAlpha(80) : const Color(0xFFECFDF5)),
                              onTap: onNavigateToActivity,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.insert_drive_file_outlined,
                              title: LanguageController.tr('scanned_files_title'),
                              value: totalScanned > 0 ? '$totalScanned File' : '0 File',
                              valueColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              iconColor: const Color(0xFF6366F1),
                              iconBgColor: isDark ? const Color(0xFF312E81).withAlpha(80) : const Color(0xFFEEF2FF),
                              onTap: onNavigateToActivity,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              icon: Icons.phonelink_lock_outlined,
                              title: LanguageController.tr('quarantine_title'),
                              value: '$quarantinedCount ${LanguageController.tr('quarantined_isolated')}',
                              valueColor: quarantinedCount > 0
                                  ? const Color(0xFFF97316)
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              iconColor: quarantinedCount > 0
                                  ? const Color(0xFFF97316)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              iconBgColor: quarantinedCount > 0
                                  ? (isDark ? const Color(0xFF7C2D12).withAlpha(80) : const Color(0xFFFFF7ED))
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              onTap: onNavigateToActivity,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // Recent Activity Section
              RecentActivitySection(
                onViewAllPressed: onNavigateToActivity,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
