import 'package:flutter/material.dart';

class ProtectionToggleCard extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isPremium;
  final IconData? icon;

  const ProtectionToggleCard({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.isPremium = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.0),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sleek Hybrid Left Icon Anchor
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPremium
                        ? (isDark ? const Color(0xFFD97706).withAlpha(20) : const Color(0xFFFEF3C7))
                        : (value
                            ? (isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F5F7))),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isPremium ? Icons.lock_rounded : (icon ?? Icons.shield_outlined),
                      color: isPremium
                          ? const Color(0xFFD97706)
                          : (value ? const Color(0xFF10B981) : subTextColor),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title, Subtitle, & Premium Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7.0,
                                vertical: 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFD97706).withAlpha(30)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withAlpha(80),
                                  width: 1.0,
                                ),
                              ),
                              child: const Text(
                                'PREMIUM',
                                style: TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Switch Toggle
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
