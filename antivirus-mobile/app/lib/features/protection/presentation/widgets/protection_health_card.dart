import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/protection/data/local/protection_local_datasource.dart';
import 'package:antivirus_mobile/shared/services/global_scan_controller.dart';
import 'package:antivirus_mobile/features/scan/data/local/binary_signature_database.dart';

class ProtectionHealthCard extends StatelessWidget {
  const ProtectionHealthCard({super.key});

  String _formatRelativeTime(DateTime? scanDate) {
    if (scanDate == null) return 'Belum Pernah';

    final now = DateTime.now();
    final difference = now.difference(scanDate);

    if (difference.inSeconds < 60) {
      return '< 1 menit lalu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin, ${scanDate.hour.toString().padLeft(2, '0')}.${scanDate.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${scanDate.day}/${scanDate.month}/${scanDate.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    final isRealTimeActive = ProtectionLocalDataSource.currentConfig.realTimeProtection;
    final isCloudActive = BinarySignatureDatabase.isUpdatedFromCloud;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ValueListenableBuilder<DateTime?>(
        valueListenable: GlobalScanController.instance.lastScanDateTime,
        builder: (context, lastDate, child) {
          final relativeTimeStr = _formatRelativeTime(lastDate);
          final isRecentScan = lastDate != null && DateTime.now().difference(lastDate).inHours < 24;

          return Column(
            children: [
              _buildHealthItem(
                isDark: isDark,
                icon: Icons.shield_outlined,
                iconColor: isRealTimeActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                title: 'Real-Time Protection',
                status: isRealTimeActive ? 'Aktif' : 'Nonaktif',
                statusColor: isRealTimeActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                isLast: false,
              ),
              _buildHealthItem(
                isDark: isDark,
                icon: Icons.history_toggle_off_outlined,
                iconColor: isRecentScan ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                title: 'Pemeriksaan Keamanan Terakhir',
                status: relativeTimeStr,
                statusColor: isRecentScan
                    ? const Color(0xFF10B981)
                    : (lastDate == null ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280))),
                isLast: false,
              ),
              _buildHealthItem(
                isDark: isDark,
                icon: Icons.cloud_done_outlined,
                iconColor: const Color(0xFF3B82F6),
                title: 'Perlindungan Cloud AI',
                status: isCloudActive ? 'Aktif (Terhubung)' : 'Aktif (Lokal)',
                statusColor: const Color(0xFF10B981),
                isLast: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHealthItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String status,
    required Color statusColor,
    required bool isLast,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 52,
            endIndent: 18,
            color: dividerColor,
          ),
      ],
    );
  }
}
