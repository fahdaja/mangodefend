import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';

class NavbarBottom extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const NavbarBottom({
    super.key,
    this.currentIndex = 0,
    this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final activeColor = selectedItemColor ?? const Color(0xFF10B981);
    final inactiveColor = unselectedItemColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF));

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex > 3 ? 0 : currentIndex,
        onTap: onTap,
        backgroundColor: navBg,
        elevation: 0,
        selectedItemColor: activeColor,
        unselectedItemColor: inactiveColor,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: LanguageController.tr('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.radar_outlined),
            activeIcon: const Icon(Icons.radar_rounded),
            label: LanguageController.tr('nav_scan'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shield_outlined),
            activeIcon: const Icon(Icons.shield_rounded),
            label: LanguageController.tr('nav_protection'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history_rounded),
            label: LanguageController.tr('nav_activity'),
          ),
        ],
      ),
    );
  }
}