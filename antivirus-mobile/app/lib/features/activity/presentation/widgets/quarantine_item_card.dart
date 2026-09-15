import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';

class QuarantineItemCard extends StatelessWidget {
  final ActivityLogItem item;
  final VoidCallback onTap;
  final VoidCallback? onQuarantinePressed;

  const QuarantineItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onQuarantinePressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnresolvedThreats = item.category == 'Ancaman' && item.files.any((f) => !f.isSafe);

    // Determine colors based on category/status
    Color iconBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    Color iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    IconData iconData = Icons.shield_outlined;
    Color badgeBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    Color badgeTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    String displayBadge = item.badgeText;

    if (item.isQuarantined) {
      iconBgColor = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFD97706);
      iconData = Icons.gavel_outlined;
      badgeBgColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFD97706);
    } else if (hasUnresolvedThreats) {
      iconBgColor = const Color(0xFFFEE2E2);
      iconColor = const Color(0xFFEF4444);
      iconData = Icons.bug_report_outlined;
      badgeBgColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFDC2626);
      displayBadge = 'Perlu Tindakan';
    } else if (item.category == 'Ancaman') {
      iconBgColor = isDark ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFECFDF5);
      iconColor = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
      iconData = Icons.verified_user_outlined;
      badgeBgColor = isDark ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFDCFCE7);
      badgeTextColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      displayBadge = 'Teratasi';
    } else if (item.category == 'Pemindaian') {
      iconBgColor = isDark ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFECFDF5);
      iconColor = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
      iconData = Icons.radar_outlined;
      badgeBgColor = isDark ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFDCFCE7);
      badgeTextColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    } else if (item.category == 'Perlindungan') {
      iconBgColor = isDark ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFECFDF5);
      iconColor = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
      iconData = Icons.shield_outlined;
      badgeBgColor = isDark ? const Color(0xFF10B981).withAlpha(30) : const Color(0xFFDCFCE7);
      badgeTextColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 3.0,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Text(
                              displayBadge,
                              style: TextStyle(
                                color: badgeTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasUnresolvedThreats && onQuarantinePressed != null) ...[
                                InkWell(
                                  onTap: onQuarantinePressed,
                                  borderRadius: BorderRadius.circular(6.0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706),
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.gavel_outlined, size: 11, color: Colors.white),
                                        SizedBox(width: 3),
                                        Text(
                                          'Karantina',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (item.files.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      hasUnresolvedThreats ? 'Detail' : 'Lihat Detail File',
                                      style: TextStyle(
                                        color: badgeTextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Icon(
                                      Icons.chevron_right,
                                      color: badgeTextColor,
                                      size: 14,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
