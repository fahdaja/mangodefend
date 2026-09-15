import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/more/presentation/widgets/menu_tile.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/account_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/settings_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/support_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/about_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/subscription_screen.dart';
import 'package:antivirus_mobile/features/auth/domain/auth_models.dart';
import 'package:antivirus_mobile/shared/widgets/account_question_dialog.dart';
import 'package:antivirus_mobile/shared/theme/theme_controller.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';

import 'package:antivirus_mobile/shared/services/subscription_service.dart';

class AppSidebar extends StatefulWidget {
  final VoidCallback? onNavigateToQuarantine;

  const AppSidebar({
    super.key,
    this.onNavigateToQuarantine,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _syncUserSubscription();
  }

  Future<void> _syncUserSubscription() async {
    if (UserSession.isLoggedIn) {
      try {
        await _subService.getMySubscription();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final categoryTextColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageController.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        return ValueListenableBuilder<UserModel?>(
          valueListenable: UserSession.currentUserNotifier,
          builder: (context, currentUser, _) {
            final isLoggedIn = currentUser != null;
            final displayName = currentUser?.username.isNotEmpty == true
                ? currentUser!.username
                : 'Pengguna Mangodefend';
            final displayEmail = currentUser?.email.isNotEmpty == true
                ? currentUser!.email
                : 'user@mangodefend.com';
            final initials = displayName.trim().isNotEmpty
                ? displayName.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
                : 'MD';

            return Drawer(
              backgroundColor: drawerBg,
              width: 310,
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Drawer Close Button & Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(10.0),
                                      ),
                                      child: const Image(
                                        image: AssetImage('assets/images/logo-mangodefend.png'),
                                        width: 22,
                                        height: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      LanguageController.tr('app_title'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: secondaryTextColor, size: 22),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // User Profile Header Card (Only visible when logged in)
                            if (isLoggedIn) ...[
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20.0),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: isDark ? const Color(0xFF10B981).withAlpha(25) : const Color(0xFFDCFCE7),
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Color(0xFF059669),
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayName,
                                                      style: TextStyle(
                                                        color: primaryTextColor,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ValueListenableBuilder<bool>(
                                                    valueListenable: UserSession.isProUserNotifier,
                                                    builder: (context, isPro, _) {
                                                      return ValueListenableBuilder<String>(
                                                        valueListenable: UserSession.activePlanNameNotifier,
                                                        builder: (context, activePlan, _) {
                                                          final planLabel = isPro
                                                              ? (activePlan.isNotEmpty && activePlan != 'Free'
                                                                  ? activePlan
                                                                  : 'PRO Plan')
                                                              : 'Free Plan';
                                                          return Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: isPro
                                                                  ? const Color(0xFFD97706).withAlpha(30)
                                                                  : const Color(0xFF10B981).withAlpha(30),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: isPro
                                                                    ? const Color(0xFFF59E0B).withAlpha(80)
                                                                    : const Color(0xFF10B981).withAlpha(80),
                                                                width: 1.0,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              planLabel,
                                                              style: TextStyle(
                                                                color: isPro ? const Color(0xFFD97706) : const Color(0xFF059669),
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                displayEmail,
                                                style: TextStyle(
                                                  color: secondaryTextColor,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    // Ringkasan Kuota Scan Akun Terdaftar (Dinamis & Real-Time)
                                    ValueListenableBuilder<bool>(
                                      valueListenable: UserSession.isProUserNotifier,
                                      builder: (context, isPro, _) {
                                        return ValueListenableBuilder<String>(
                                          valueListenable: UserSession.activePlanNameNotifier,
                                          builder: (context, activePlanName, _) {
                                            return ValueListenableBuilder<int>(
                                              valueListenable: UserSession.maxDailyScansNotifier,
                                              builder: (context, sessionMaxScans, _) {
                                                return ValueListenableBuilder<int>(
                                                  valueListenable: GuestQuotaService.userScanCountNotifier,
                                                  builder: (context, userUsedScans, _) {
                                                    final isAnnual = activePlanName.toLowerCase().contains('annual') ||
                                                        activePlanName.toLowerCase().contains('yearly') ||
                                                        activePlanName.toLowerCase().contains('tahunan') ||
                                                        sessionMaxScans == -1;

                                                    final maxScans = isPro ? (isAnnual ? -1 : (sessionMaxScans > 0 ? sessionMaxScans : 200)) : 30;
                                                    final remainingUserScans = maxScans == -1
                                                        ? 99999
                                                        : (maxScans - userUsedScans).clamp(0, maxScans);

                                                    final progressValue = maxScans == -1
                                                        ? 0.15
                                                        : (userUsedScans / maxScans).clamp(0.0, 1.0);

                                                    final progressColor = isPro ? const Color(0xFFD97706) : const Color(0xFF10B981);

                                                    return Container(
                                                      padding: const EdgeInsets.all(14.0),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: isPro
                                                            ? Border.all(color: const Color(0xFFF59E0B).withAlpha(50), width: 1.0)
                                                            : Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.0),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Row(
                                                                  children: [
                                                                    Icon(
                                                                      isPro ? Icons.star_rounded : Icons.bolt_rounded,
                                                                      size: 16,
                                                                      color: progressColor,
                                                                    ),
                                                                    const SizedBox(width: 8),
                                                                    Flexible(
                                                                      child: Text(
                                                                        'Kuota Pemindaian Harian',
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: TextStyle(
                                                                          color: primaryTextColor,
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              Text(
                                                                maxScans == -1
                                                                    ? 'Unlimited'
                                                                    : '$userUsedScans / $maxScans',
                                                                style: TextStyle(
                                                                  color: progressColor,
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (maxScans != -1) ...[
                                                            const SizedBox(height: 12),
                                                            ClipRRect(
                                                              borderRadius: BorderRadius.circular(6),
                                                              child: LinearProgressIndicator(
                                                                value: progressValue,
                                                                minHeight: 7,
                                                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                                                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 10),
                                                          ] else ...[
                                                            const SizedBox(height: 8),
                                                          ],
                                                          Text(
                                                            maxScans == -1
                                                                ? 'Paket Pro Annual: Pemindaian Tanpa Batas'
                                                                : 'Sisa Kuota Hari Ini: $remainingUserScans Pemindaian',
                                                            style: TextStyle(
                                                              color: secondaryTextColor,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: UserSession.isProUserNotifier,
                                      builder: (context, isPro, _) {
                                        return SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                                              );
                                            },
                                            icon: Icon(
                                              isPro ? Icons.verified_user_rounded : Icons.star_rounded,
                                              size: 16,
                                              color: const Color(0xFFD97706),
                                            ),
                                            label: Text(
                                              isPro ? 'Kelola Langganan Pro' : 'Upgrade Paket Pro',
                                              style: const TextStyle(
                                                color: Color(0xFFD97706),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Color(0xFFFBBF24), width: 1.2),
                                              backgroundColor: isDark ? const Color(0xFFD97706).withAlpha(20) : const Color(0xFFFFF7ED),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Section Title: MENU NAVIGASI
                            Padding(
                              padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
                              child: Text(
                                LanguageController.tr('sidebar_nav_menu'),
                                style: TextStyle(
                                  color: categoryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),

                            // If Logged Out: Masuk / Daftar Akun
                            if (!isLoggedIn) ...[
                              MenuTile(
                                icon: Icons.login_rounded,
                                iconBgColor: const Color(0xFFEFF6FF),
                                iconColor: const Color(0xFF2563EB),
                                title: 'Masuk / Daftar',
                                subtitle: 'Masuk ke akun Mangodefend Anda',
                                onTap: () {
                                  Navigator.pop(context);
                                  AccountQuestionDialog.show(context);
                                },
                              ),
                            ],

                            // If Logged In: Karantina, Akun Saya, Subskripsi, Pengaturan
                            if (isLoggedIn) ...[
                              // 1. Karantina (Real-time dynamic counter)
                              ValueListenableBuilder(
                                valueListenable: ActivityStore.logsNotifier,
                                builder: (context, logs, _) {
                                  final qCount = logs.where((item) => item.isQuarantined).length;
                                  return MenuTile(
                                    icon: Icons.gavel_outlined,
                                    iconBgColor: const Color(0xFFFEF3C7),
                                    iconColor: const Color(0xFFD97706),
                                    title: 'Karantina (Quarantine)',
                                    subtitle: 'Kelola file terisolasi & ancaman',
                                    badgeText: qCount > 0 ? qCount.toString() : null,
                                    badgeBgColor: const Color(0xFFEF4444),
                                    badgeTextColor: Colors.white,
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (widget.onNavigateToQuarantine != null) {
                                        widget.onNavigateToQuarantine!();
                                      }
                                    },
                                  );
                                },
                              ),
                              Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                              // 2. Akun Saya
                              MenuTile(
                                icon: Icons.person_outline,
                                iconBgColor: const Color(0xFFECFDF5),
                                iconColor: const Color(0xFF059669),
                                title: 'Akun Saya (Account)',
                                subtitle: 'Profil pengguna & perangkat terhubung',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AccountScreen(),
                                    ),
                                  );
                                },
                              ),
                              Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                              // 3. Paket & Langganan
                              MenuTile(
                                icon: Icons.star_outline_rounded,
                                iconBgColor: const Color(0xFFFFF7ED),
                                iconColor: const Color(0xFFD97706),
                                title: 'Paket & Langganan',
                                subtitle: 'Kelola langganan & upgrade fitur',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SubscriptionScreen(),
                                    ),
                                  );
                                },
                              ),
                              Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                              // 4. Pengaturan
                              MenuTile(
                                icon: Icons.settings_outlined,
                                iconBgColor: const Color(0xFFF1F5F9),
                                iconColor: const Color(0xFF475569),
                                title: 'Pengaturan (Settings)',
                                subtitle: 'Preferensi notifikasi, scan & tema',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],

                            Padding(
                              padding: const EdgeInsets.only(left: 12.0, top: 18.0, bottom: 8.0),
                              child: Text(
                                LanguageController.tr('sidebar_help_info'),
                                style: TextStyle(
                                  color: categoryTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),

                            // 4. Bantuan & Support
                            MenuTile(
                              icon: Icons.help_outline,
                              iconBgColor: const Color(0xFFEFF6FF),
                              iconColor: const Color(0xFF2563EB),
                              title: LanguageController.tr('menu_support'),
                              subtitle: LanguageController.tr('menu_support_desc'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SupportScreen()),
                                );
                              },
                            ),

                            // 5. About
                            MenuTile(
                              icon: Icons.info_outline,
                              iconBgColor: const Color(0xFFF8FAFC),
                              iconColor: const Color(0xFF64748B),
                              title: LanguageController.tr('menu_about'),
                              subtitle: LanguageController.tr('menu_about_desc'),
                              badgeText: 'v2.4.0',
                              badgeBgColor: const Color(0xFFF1F5F9),
                              badgeTextColor: const Color(0xFF475569),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                                );
                              },
                            ),

                            // If Logged In: Logout Button
                            if (isLoggedIn) ...[
                              const SizedBox(height: 16),
                              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              const SizedBox(height: 8),
                              MenuTile(
                                icon: Icons.logout_rounded,
                                iconBgColor: const Color(0xFFFEF2F2),
                                iconColor: const Color(0xFFEF4444),
                                title: 'Keluar (Logout)',
                                subtitle: 'Keluar dari akun saat ini',
                                onTap: () {
                                  Navigator.pop(context);
                                  _showLogoutConfirmationDialog(context);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // FIXED FOOTER CONTAINER (THEME SWITCH)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                                color: secondaryTextColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isDark ? LanguageController.tr('mode_dark') : LanguageController.tr('mode_light'),
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: isDark,
                            onChanged: (val) {
                              ThemeController.toggleTheme(val);
                            },
                            activeTrackColor: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Konfirmasi Keluar',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun Mangodefend Anda?',
          style: TextStyle(
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              UserSession.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              elevation: 0,
            ),
            child: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
