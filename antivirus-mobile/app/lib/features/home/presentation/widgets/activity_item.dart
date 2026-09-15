import 'package:flutter/material.dart';

class ActivityItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String time;
  final String? iconPath;
  final IconData? iconData;
  final Color iconColor;
  final bool isLast;

  const ActivityItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.time,
    this.iconPath,
    this.iconData,
    required this.iconColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9.0),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(isDark ? 40 : 24),
                  shape: BoxShape.circle,
                ),
                child: iconData != null
                    ? Icon(iconData, color: isDark ? Color.lerp(iconColor, Colors.white, 0.2) : iconColor, size: 20)
                    : Image.asset(
                        iconPath ?? '',
                        width: 20,
                        height: 20,
                        color: iconColor,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.check_circle_outline,
                          color: iconColor,
                          size: 20,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: TextStyle(
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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