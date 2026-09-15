import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/account_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/settings_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/support_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/about_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/subscription_screen.dart';
import 'package:antivirus_mobile/features/more/presentation/widgets/menu_tile.dart';

class MoreScreen extends StatelessWidget {
  final VoidCallback? onNavigateToQuarantine;

  const MoreScreen({
    super.key,
    this.onNavigateToQuarantine,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Text(
                'Menu & Fitur Keamanan',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kelola akun Anda & akses fitur keamanan tambahan',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // Hero Card: Premium Active
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(30),
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Color(0xFF10B981),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Pro Aktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Perangkat Anda terlindungi keamanan tingkat tinggi',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SubscriptionScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: const Text(
                                'Kelola Berlangganan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Grouped Menu List Box
              Container(
                decoration: BoxDecoration(
                  color: cardBgColor,
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
                child: Column(
                  children: [
                    // 1. Karantina
                    MenuTile(
                      icon: Icons.gavel_outlined,
                      iconBgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: 'Karantina (Quarantine)',
                      subtitle: 'Kelola file terisolasi & ancaman',
                      badgeText: '4',
                      badgeBgColor: const Color(0xFFEF4444),
                      badgeTextColor: Colors.white,
                      onTap: () {
                        if (onNavigateToQuarantine != null) {
                          onNavigateToQuarantine!();
                        }
                      },
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 2. Akun
                    MenuTile(
                      icon: Icons.person_outline,
                      iconBgColor: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      title: 'Akun Saya (Account)',
                      subtitle: 'Profil pengguna & perangkat terhubung',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AccountScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 3. Pengaturan
                    MenuTile(
                      icon: Icons.settings_outlined,
                      iconBgColor: const Color(0xFFF1F5F9),
                      iconColor: const Color(0xFF475569),
                      title: 'Pengaturan (Settings)',
                      subtitle: 'Preferensi notifikasi, scan & tema',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 4. Bantuan & Support
                    MenuTile(
                      icon: Icons.help_outline,
                      iconBgColor: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: 'Bantuan & Support',
                      subtitle: 'Pusat FAQ & layanan live chat',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SupportScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 60, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                    // 5. About
                    MenuTile(
                      icon: Icons.info_outline,
                      iconBgColor: const Color(0xFFF8FAFC),
                      iconColor: const Color(0xFF64748B),
                      title: 'Tentang Aplikasi (About)',
                      subtitle: 'Informasi versi v2.4.0 & lisensi',
                      badgeText: 'v2.4.0',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AboutScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
