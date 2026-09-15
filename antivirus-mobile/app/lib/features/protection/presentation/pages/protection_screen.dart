import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/protection/presentation/widgets/protection_header_banner.dart';
import 'package:antivirus_mobile/features/protection/presentation/widgets/protection_toggle_card.dart';
import 'package:antivirus_mobile/features/protection/presentation/widgets/protection_health_card.dart';
import 'package:antivirus_mobile/features/more/more.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/features/protection/data/local/protection_local_datasource.dart';
import 'package:antivirus_mobile/features/scan/data/local/binary_signature_database.dart';
import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/shared/services/scheduled_scan_service.dart';
import 'package:antivirus_mobile/shared/services/subscription_service.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';

class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({super.key});

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> {
  // Essential Security Controls State (Bound to ProtectionLocalDataSource)
  bool _realTimeProtection = ProtectionLocalDataSource.currentConfig.realTimeProtection;
  bool _scheduledScan = ProtectionLocalDataSource.currentConfig.scheduledScan;
  bool _isProUser = UserSession.isProUser;
  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    if (_realTimeProtection && _isProUser) {
      LocalQuarantineService.startRealtimeGuardForegroundService();
    } else {
      LocalQuarantineService.stopRealtimeGuardForegroundService();
    }
    if (_scheduledScan && _isProUser) {
      ScheduledScanService.instance.startSchedule();
    } else {
      ScheduledScanService.instance.stopSchedule();
    }
  }

  Future<void> _checkProStatus() async {
    if (!UserSession.isLoggedIn) {
      UserSession.isProUser = false;
      UserSession.activePlanName = 'Starter Free';
      LocalQuarantineService.stopRealtimeGuardForegroundService();
      ScheduledScanService.instance.stopSchedule();
      if (mounted) setState(() => _isProUser = false);
      return;
    }

    try {
      final sub = await _subService.getMySubscription();
      if (!mounted) return;
      if (sub != null && sub.isActive) {
        final planName = sub.planName.toLowerCase();
        final isPro = planName.contains('pro') ||
            planName.contains('premium') ||
            sub.planId > 1 ||
            (sub.plan?.canRealtimeProtection ?? false);
        UserSession.isProUser = isPro;
        UserSession.activePlanName = sub.planName;
        setState(() {
          _isProUser = isPro;
        });

        if (!isPro) {
          LocalQuarantineService.stopRealtimeGuardForegroundService();
          ScheduledScanService.instance.stopSchedule();
        } else {
          if (_realTimeProtection) {
            LocalQuarantineService.startRealtimeGuardForegroundService();
          }
          if (_scheduledScan) {
            ScheduledScanService.instance.startSchedule();
          }
        }
      } else {
        UserSession.isProUser = false;
        UserSession.activePlanName = 'Starter Free';
        LocalQuarantineService.stopRealtimeGuardForegroundService();
        ScheduledScanService.instance.stopSchedule();
        setState(() {
          _isProUser = false;
        });
      }
    } catch (_) {}
  }


  void _showPremiumUpgradeDialog(String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Golden Crown Hero Icon Header
              Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withAlpha(40),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFD97706),
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),

              // Premium Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: const Color(0xFFFDBA74), width: 1.0),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Color(0xFFEA580C), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'FITUR EKSKLUSIF PRO',
                      style: TextStyle(
                        color: Color(0xFFEA580C),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                'Buka $featureName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle Description
              Text(
                'Tingkatkan keamanan perangkat kamu ke tingkat maksimal dengan proteksi real-time otomatis 24 jam.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Upgrade CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SelectPlanScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    backgroundColor: const Color(0xFFF97316),
                    elevation: 4,
                    shadowColor: const Color(0xFFF97316).withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Upgrade ke Paket Pro Sekarang',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancel / Close Text Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Nanti Saja',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              // Protection Status Top Hero
              const ProtectionHeaderBanner(),
              const SizedBox(height: 16),

              // Enterprise MDB1 Signature Database Status Card (Dynamic Up to Date / Belum Terbaru Indicator)
              Builder(
                builder: (context) {
                  final isUpdated = BinarySignatureDatabase.isUpdatedFromCloud;
                  final statusColor = isUpdated ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
                  final statusText = isUpdated ? 'Sudah Terbaru' : 'Belum Terbaru';
                  final statusIcon = isUpdated ? Icons.check_circle_rounded : Icons.sync_problem_rounded;
                  final heroIcon = isUpdated ? Icons.verified_user_rounded : Icons.warning_amber_rounded;
                  final subtitleText = isUpdated
                      ? '${BinarySignatureDatabase.loadedBinaryEntries} Signature Malicious Aktif • MDB1 20-Byte Up to Date'
                      : '${BinarySignatureDatabase.loadedBinaryEntries} Signature Malicious (Asset Bawaan) • Belum Di-update dari Cloud';

                  return Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(heroIcon, color: statusColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Database Definisi Virus (MDB1)',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Dynamic Badge Pill "Sudah Terbaru" / "Belum Terbaru"
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: statusColor.withAlpha(80),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, color: statusColor, size: 10),
                                        const SizedBox(width: 3),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final success = await BinarySignatureDatabase.syncSignaturesFromCloud();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  content: Text(
                                    success
                                        ? 'Database biner berhasil di-update dari Cloud! (${BinarySignatureDatabase.loadedBinaryEntries} Signature Malicious)'
                                        : 'Server Cloud Offline, Menggunakan Database Biner HP (${BinarySignatureDatabase.loadedBinaryEntries} Signature Malicious)',
                                  ),
                                ),
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 13, color: Colors.white),
                          label: const Text('Sync', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Section 1: Kontrol Keamanan Utama
              Text(
                LanguageController.tr('security_controls'),
                style: TextStyle(
                  color: sectionTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // 1. Proteksi Real-Time (Aplikasi & Unduhan)
              ProtectionToggleCard(
                title: 'Proteksi Real-Time',
                description: 'Deteksi otomatis virus saat menginstal aplikasi atau mengunduh berkas',
                value: _realTimeProtection && _isProUser,
                isPremium: !_isProUser,
                icon: Icons.shield_rounded,
                onChanged: (val) {
                  if (!_isProUser) {
                    _showPremiumUpgradeDialog('Proteksi Real-Time');
                  } else {
                    setState(() {
                      _realTimeProtection = val;
                    });
                    ProtectionLocalDataSource.updateRealTimeProtection(val);
                    if (val) {
                      LocalQuarantineService.startRealtimeGuardForegroundService(addLog: true);
                    } else {
                      LocalQuarantineService.stopRealtimeGuardForegroundService(addLog: true);
                    }
                  }
                },
              ),
              const SizedBox(height: 12),

              // 2. Scheduled Scan (PEMINDAIAN TERJADWAL)
              ProtectionToggleCard(
                title: LanguageController.tr('scheduled_scan'),
                description: LanguageController.tr('scheduled_scan_desc'),
                value: _scheduledScan && _isProUser,
                icon: Icons.schedule_rounded,
                isPremium: !_isProUser,
                onChanged: (val) {
                  if (!_isProUser) {
                    _showPremiumUpgradeDialog(LanguageController.tr('scheduled_scan'));
                  } else {
                    setState(() {
                      _scheduledScan = val;
                    });
                    ProtectionLocalDataSource.updateScheduledScan(val);
                    if (val) {
                      ScheduledScanService.instance.startSchedule();
                    } else {
                      ScheduledScanService.instance.stopSchedule();
                    }
                  }
                },
              ),
              const SizedBox(height: 28),

              // Section 2: Kesehatan Proteksi
              Text(
                LanguageController.tr('protection_health'),
                style: TextStyle(
                  color: sectionTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // Protection Health Status Card
              const ProtectionHealthCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
