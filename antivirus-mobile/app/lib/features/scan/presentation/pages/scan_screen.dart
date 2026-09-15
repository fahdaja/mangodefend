import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/features/scan/presentation/widgets/scan_header_banner.dart';
import 'package:antivirus_mobile/features/scan/presentation/widgets/scan_progress_card.dart';
import 'package:antivirus_mobile/features/scan/presentation/widgets/scan_type_card.dart';
import 'package:antivirus_mobile/features/scan/presentation/widgets/recent_scan_history.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';
import 'package:antivirus_mobile/shared/services/global_scan_controller.dart';
import 'package:antivirus_mobile/shared/services/storage_permission_service.dart';

import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';

class ScanScreen extends StatelessWidget {
  final VoidCallback? onNavigateToActivity;

  const ScanScreen({
    super.key,
    this.onNavigateToActivity,
  });

  void _startScanByType(
    BuildContext context,
    ScanType scanType, {
    File? singleFile,
    Directory? folder,
  }) {
    GlobalScanController.instance.startScan(
      context: context,
      scanType: scanType,
      singleFile: singleFile,
      folder: folder,
      onNavigateToActivity: onNavigateToActivity,
    );
  }

  void _pickAndScanFile(BuildContext context) async {
    final hasPermission = await StoragePermissionService.requestStoragePermission(context);
    if (!hasPermission) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        _startScanByType(context, ScanType.file, singleFile: pickedFile);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _pickAndScanFolder(BuildContext context) async {
    final hasPermission = await StoragePermissionService.requestStoragePermission(context);
    if (!hasPermission) return;

    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final pickedFolder = Directory(selectedDirectory);
        _startScanByType(context, ScanType.folder, folder: pickedFolder);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              // Header Banner
              const ScanHeaderBanner(),
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
                      margin: const EdgeInsets.only(bottom: 20.0),
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

              // Scanning Progress Card Overlay (Listening to GlobalScanController)
              ValueListenableBuilder<bool>(
                valueListenable: GlobalScanController.instance.isScanning,
                builder: (context, isScanning, child) {
                  if (!isScanning) return const SizedBox.shrink();
                  return ValueListenableBuilder<double>(
                    valueListenable: GlobalScanController.instance.scanProgress,
                    builder: (context, scanProgress, child) {
                      return ValueListenableBuilder<int>(
                        valueListenable: GlobalScanController.instance.scannedFiles,
                        builder: (context, scannedFiles, child) {
                          return ValueListenableBuilder<String>(
                            valueListenable: GlobalScanController.instance.currentScanType,
                            builder: (context, currentScanType, child) {
                              return Column(
                                children: [
                                  ScanProgressCard(
                                    activeScanType: currentScanType,
                                    scanProgress: scanProgress,
                                    scannedFiles: scannedFiles,
                                    onCancel: () => GlobalScanController.instance.cancelScan(),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),

              // Section Title
              Text(
                LanguageController.tr('scan_type_title'),
                style: TextStyle(
                  color: sectionTitleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // 1. Upload File Scan Card
              ScanTypeCard(
                icon: Icons.upload_file_outlined,
                badgeLabel: 'File Spesifik',
                badgeBgColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                badgeTextColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                title: LanguageController.tr('file_scan_title'),
                description: LanguageController.tr('file_scan_desc'),
                buttonText: LanguageController.tr('select_file_btn'),
                buttonIcon: Icons.cloud_upload_outlined,
                buttonColor: isDark ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                onTap: () => _pickAndScanFile(context),
              ),
              const SizedBox(height: 14),

              // 2. Folder Scan Card
              ScanTypeCard(
                icon: Icons.folder_open_outlined,
                badgeLabel: 'Kustom',
                badgeBgColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                badgeTextColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                title: LanguageController.tr('folder_scan_title'),
                description: LanguageController.tr('folder_scan_desc'),
                buttonText: LanguageController.tr('select_folder_btn'),
                buttonIcon: Icons.folder_outlined,
                buttonColor: const Color(0xFF059669),
                onTap: () => _pickAndScanFolder(context),
              ),
              const SizedBox(height: 14),

              // 3. Full Scan Card
              ScanTypeCard(
                icon: Icons.shield_outlined,
                badgeLabel: 'Rekomendasi',
                badgeBgColor: const Color(0xFFECFDF5),
                badgeTextColor: const Color(0xFF059669),
                title: LanguageController.tr('full_scan_title'),
                description: LanguageController.tr('full_scan_desc'),
                buttonText: LanguageController.tr('start_scan'),
                buttonIcon: Icons.radar_rounded,
                buttonColor: const Color(0xFF10B981),
                onTap: () => _startScanByType(context, ScanType.fullSystem),
              ),
              const SizedBox(height: 28),

              // Recent Scan History Section
              RecentScanHistory(
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