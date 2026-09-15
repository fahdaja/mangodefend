import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';

class ScanCompleteDialog extends StatelessWidget {
  final int filesScanned;
  final int threatsFound;
  final String duration;
  final String? scannedFileName;
  final bool isSingleFileScan;
  final VoidCallback? onViewActivity;
  final VoidCallback? onQuarantineThreats;
  final VoidCallback? onForceQuarantine;

  const ScanCompleteDialog({
    super.key,
    this.filesScanned = 1,
    this.threatsFound = 0,
    this.duration = '1.2s',
    this.scannedFileName,
    this.isSingleFileScan = false,
    this.onViewActivity,
    this.onQuarantineThreats,
    this.onForceQuarantine,
  });

  static void show(
    BuildContext context, {
    int filesScanned = 1,
    int threatsFound = 0,
    String duration = '1.2s',
    String? scannedFileName,
    bool isSingleFileScan = false,
    VoidCallback? onViewActivity,
    VoidCallback? onQuarantineThreats,
    VoidCallback? onForceQuarantine,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ScanCompleteDialog(
        filesScanned: filesScanned,
        threatsFound: threatsFound,
        duration: duration,
        scannedFileName: scannedFileName,
        isSingleFileScan: isSingleFileScan,
        onViewActivity: onViewActivity,
        onQuarantineThreats: onQuarantineThreats,
        onForceQuarantine: onForceQuarantine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isMalicious = threatsFound > 0;
    final themeColor = isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final fileName = scannedFileName ?? 'File Target';

    final String titleText;
    final String subtitleText;

    if (isSingleFileScan || scannedFileName != null) {
      if (isMalicious) {
        titleText = 'File Berbahaya Terdeteksi!';
        subtitleText = 'File "$fileName" terbukti terindikasi malware. Pilih tindakan untuk mengamankan perangkat.';
      } else {
        titleText = 'File Ini 100% Aman!';
        subtitleText = 'File "$fileName" telah diverifikasi bebas dari virus, malware, atau ancaman keamanan.';
      }
    } else {
      if (isMalicious) {
        titleText = '$threatsFound Ancaman Terindikasi!';
        subtitleText = 'Ditemukan $threatsFound file terindikasi malware dari $filesScanned file yang dipindai. Tinjau atau karantina ancaman sekarang.';
      } else {
        titleText = 'File & Perangkat Aman';
        subtitleText = 'Tidak ditemukan virus atau malware pada $filesScanned file yang dipindai.';
      }
    }

    final iconData = isMalicious
        ? Icons.security_update_warning_rounded
        : Icons.verified_user_rounded;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: isMalicious
                  ? const Color(0xFFEF4444).withAlpha(120)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: themeColor.withAlpha(isDark ? 40 : 20),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SINGLE CLEAN HERO ICON
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: themeColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: themeColor,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),

              // TITLE
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMalicious ? const Color(0xFFEF4444) : textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // SUBTITLE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // STATS SUMMARY (Clean numbers, no extra icons)
              if (isSingleFileScan || scannedFileName != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMalicious ? 'Status: Terindikasi Malware' : 'Status: Terverifikasi Bersih',
                        style: TextStyle(
                          color: isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$filesScanned',
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text('Dipindai', style: TextStyle(color: subTextColor, fontSize: 11)),
                        ],
                      ),
                      Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Column(
                        children: [
                          Text(
                            '$threatsFound',
                            style: TextStyle(
                              color: isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Ancaman', style: TextStyle(color: subTextColor, fontSize: 11)),
                        ],
                      ),
                      Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Column(
                        children: [
                          Text(
                            duration,
                            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text('Durasi', style: TextStyle(color: subTextColor, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ACTION BUTTONS (HANYA TINJAU LOG AKTIVITAS & ABAIKAN DULU)
              if (isMalicious) ...[
                // Primary Action: Tinjau Log Aktivitas
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewActivity?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: const Text(
                      'Tinjau Log Aktivitas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Secondary Action: Abaikan Dulu
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Abaikan Dulu',
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: Text(
                      LanguageController.tr('btn_done'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
