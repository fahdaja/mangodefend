import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/home/presentation/widgets/activity_item.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';

class RecentActivitySection extends StatelessWidget {
  final VoidCallback? onViewAllPressed;

  const RecentActivitySection({
    super.key,
    this.onViewAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Aktivitas Terakhir',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            InkWell(
              onTap: onViewAllPressed ?? () {},
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 20 : 6),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ValueListenableBuilder<List<ActivityLogItem>>(
            valueListenable: ActivityStore.logsNotifier,
            builder: (context, logs, child) {
              if (logs.isNotEmpty) {
                final displayLogs = logs.take(3).toList();
                return Column(
                  children: List.generate(displayLogs.length, (index) {
                    final log = displayLogs[index];
                    IconData iconData = Icons.radar_outlined;
                    Color iconColor = const Color(0xFF10B981);

                    if (log.isQuarantined) {
                      iconData = Icons.gavel_outlined;
                      iconColor = const Color(0xFFD97706);
                    } else if (log.category == 'Ancaman') {
                      iconData = Icons.bug_report_outlined;
                      iconColor = const Color(0xFFEF4444);
                    } else if (log.category == 'Perlindungan') {
                      iconData = Icons.shield_outlined;
                      iconColor = const Color(0xFF3B82F6);
                    }

                    return InkWell(
                      onTap: onViewAllPressed,
                      child: ActivityItem(
                        title: log.title,
                        subtitle: log.subtitle,
                        time: log.time,
                        iconData: iconData,
                        iconColor: iconColor,
                        isLast: index == displayLogs.length - 1,
                      ),
                    );
                  }),
                );
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 36,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum Ada Aktivitas Pemindaian',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lakukan pemindaian pertama untuk mendeteksi virus & malware di HP Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
