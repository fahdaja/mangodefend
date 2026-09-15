import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/scan/data/local/scan_history_store.dart';

class ScanHistoryItem extends StatelessWidget {
  final ScanHistoryRecord record;
  final bool isLast;
  final VoidCallback? onViewActivity;

  const ScanHistoryItem({
    super.key,
    required this.record,
    this.isLast = false,
    this.onViewActivity,
  });

  void _showDetailBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row with Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: record.iconColor.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(record.iconData, color: record.iconColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Rincian Pemindaian',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Verdict Status Badge Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: record.isMalicious
                      ? const Color(0xFFEF4444).withAlpha(20)
                      : const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: record.isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      record.isMalicious ? Icons.warning_rounded : Icons.verified_user_rounded,
                      color: record.isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        record.isMalicious
                            ? 'BERBAHAYA: Terdeteksi Ancaman / Malware'
                            : 'AMAN: File & Perangkat Terverifikasi Bersih',
                        style: TextStyle(
                          color: record.isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detail List Items Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Aktivitas', record.title, textColor, subTextColor),
                    const Divider(height: 20),
                    _buildDetailRow('Status & Hasil', record.subtitle, textColor, subTextColor),
                    const Divider(height: 20),
                    _buildDetailRow('Waktu Pemindaian', record.time, textColor, subTextColor),
                    if (record.filePath != null) ...[
                      const Divider(height: 20),
                      _buildDetailRow('Lokasi Path Target', record.filePath!, textColor, subTextColor),
                    ],
                    if (record.fileSize != null) ...[
                      const Divider(height: 20),
                      _buildDetailRow('Ukuran File', record.fileSize!, textColor, subTextColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Action: Go to Activity Log Screen
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onViewActivity?.call();
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('Buka Halaman Log Aktivitas', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: record.isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color textColor, Color subTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        InkWell(
          onTap: () => _showDetailBottomSheet(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Left Icon Badge
                Container(
                  padding: const EdgeInsets.all(9.0),
                  decoration: BoxDecoration(
                    color: record.iconColor.withAlpha(isDark ? 40 : 24),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    record.iconData,
                    color: isDark ? Color.lerp(record.iconColor, Colors.white, 0.2) : record.iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),

                // Middle Text & Status Pill Tag
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Status Pill Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: record.isMalicious
                                  ? const Color(0xFFEF4444).withAlpha(30)
                                  : const Color(0xFF10B981).withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              record.isMalicious ? 'ANCAMAN' : 'AMAN',
                              style: TextStyle(
                                color: record.isMalicious ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Right Time & Chevron Icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.time,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 58,
            endIndent: 16,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
      ],
    );
  }
}