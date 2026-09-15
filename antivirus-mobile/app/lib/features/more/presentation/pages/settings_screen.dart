import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/theme/theme_controller.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/features/protection/data/local/protection_local_datasource.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Protection Preferences State
  bool _realTimeProtection = ProtectionLocalDataSource.currentConfig.realTimeProtection;
  bool _autoScanDownload = true;
  bool _cloudScanEngine = true;

  @override
  void initState() {
    super.initState();
    if (_realTimeProtection) {
      LocalQuarantineService.startRealtimeGuardForegroundService();
    }
  }

  // Notification Preferences State
  bool _pushNotifications = true;
  bool _threatAlerts = true;

  void _showThemeSelectorDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(
          LanguageController.tr('theme_app'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(LanguageController.tr('mode_light'), ThemeMode.light, isDark),
            _buildThemeOption(LanguageController.tr('mode_dark'), ThemeMode.dark, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, bool isDark) {
    final isSelected = ThemeController.themeModeNotifier.value == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ThemeController.setThemeMode(mode);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectorDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: LanguageController.currentLanguageNotifier,
        builder: (context, currentLang, child) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
            title: Text(
              LanguageController.tr('select_language'),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLanguageOption('id', 'Bahasa Indonesia', '🇮🇩', isDark),
                _buildLanguageOption('en', 'English (US)', '🇺🇸', isDark),
                _buildLanguageOption('ja', '日本語 (Japanese)', '🇯🇵', isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageOption(String langCode, String label, String flagEmoji, bool isDark) {
    final isSelected = LanguageController.currentLanguage == langCode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          LanguageController.setLanguage(langCode);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LanguageController.tr('language_changed')),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          child: Row(
            children: [
              Text(flagEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageController.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F5F7),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              LanguageController.tr('settings_title'),
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: false,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PROTECTION PREFERENCES
                    Text(LanguageController.tr('section_security'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildSectionBox(isDark, [
                      _buildSwitchTile(
                        isDark,
                        Icons.shield_outlined,
                        LanguageController.tr('realtime_setting'),
                        LanguageController.tr('realtime_setting_desc'),
                        _realTimeProtection,
                        (val) {
                          setState(() => _realTimeProtection = val);
                          if (val) {
                            LocalQuarantineService.startRealtimeGuardForegroundService(addLog: true);
                          } else {
                            LocalQuarantineService.stopRealtimeGuardForegroundService(addLog: true);
                          }
                        },
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      _buildSwitchTile(
                        isDark,
                        Icons.download_done_outlined,
                        LanguageController.tr('auto_scan_download'),
                        LanguageController.tr('auto_scan_download_desc'),
                        _autoScanDownload,
                        (val) => setState(() => _autoScanDownload = val),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      _buildSwitchTile(
                        isDark,
                        Icons.cloud_sync_outlined,
                        LanguageController.tr('cloud_engine'),
                        LanguageController.tr('cloud_engine_desc'),
                        _cloudScanEngine,
                        (val) => setState(() => _cloudScanEngine = val),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // NOTIFICATION PREFERENCES
                    Text(LanguageController.tr('section_notifications'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildSectionBox(isDark, [
                      _buildSwitchTile(
                        isDark,
                        Icons.notifications_active_outlined,
                        LanguageController.tr('push_notif'),
                        LanguageController.tr('push_notif_desc'),
                        _pushNotifications,
                        (val) => setState(() => _pushNotifications = val),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      _buildSwitchTile(
                        isDark,
                        Icons.warning_amber_outlined,
                        LanguageController.tr('threat_alert'),
                        LanguageController.tr('threat_alert_desc'),
                        _threatAlerts,
                        (val) => setState(() => _threatAlerts = val),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // PRIVACY & DATA
                    Text(LanguageController.tr('section_privacy'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildSectionBox(isDark, [
                      _buildNavigationTile(isDark, Icons.privacy_tip_outlined, LanguageController.tr('privacy_policy'), null, null),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      _buildNavigationTile(isDark, Icons.policy_outlined, LanguageController.tr('sample_policy'), null, null),
                    ]),
                    const SizedBox(height: 24),

                    // APPEARANCE SECTION (DYNAMIC THEME & LANGUAGE TOGGLE)
                    Text(LanguageController.tr('appearance_theme'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildSectionBox(isDark, [
                      _buildNavigationTile(
                        isDark,
                        Icons.palette_outlined,
                        LanguageController.tr('theme_app'),
                        isDark ? LanguageController.tr('mode_dark') : LanguageController.tr('mode_light'),
                        _showThemeSelectorDialog,
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                      _buildNavigationTile(
                        isDark,
                        Icons.language_outlined,
                        LanguageController.tr('language'),
                        LanguageController.currentLanguageName,
                        _showLanguageSelectorDialog,
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionBox(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
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
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(icon, color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(
    bool isDark,
    IconData icon,
    String title,
    String? trailingText,
    VoidCallback? onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(icon, color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
