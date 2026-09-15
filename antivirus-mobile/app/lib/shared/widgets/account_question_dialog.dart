import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/auth/auth.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/select_plan_screen.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';

class AccountQuestionDialog extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isQuotaLimit;
  final VoidCallback? onLoginPressed;
  final VoidCallback? onRegisterPressed;

  const AccountQuestionDialog({
    super.key,
    this.title,
    this.description,
    this.isQuotaLimit = false,
    this.onLoginPressed,
    this.onRegisterPressed,
  });

  static void show(
    BuildContext context, {
    String? title,
    String? description,
    bool isQuotaLimit = false,
    VoidCallback? onLoginPressed,
    VoidCallback? onRegisterPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AccountQuestionDialog(
        title: title,
        description: description,
        isQuotaLimit: isQuotaLimit,
        onLoginPressed: onLoginPressed,
        onRegisterPressed: onRegisterPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final usedScans = GuestQuotaService.guestScansUsed.clamp(0, 15);
    final maxQuota = GuestQuotaService.maxGuestScans;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(22.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 100 : 25),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close_rounded, color: subTextColor, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ),

                // Hero Icon Header: Amber Hourglass (if isQuotaLimit) or Green Lock (if normal login prompt)
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isQuotaLimit
                          ? (isDark ? [const Color(0xFF451A03), const Color(0xFF78350F)] : [const Color(0xFFFFF7ED), const Color(0xFFFEF3C7)])
                          : (isDark ? [const Color(0xFF064E3B), const Color(0xFF047857)] : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isQuotaLimit ? const Color(0xFFF59E0B).withAlpha(120) : const Color(0xFF10B981).withAlpha(120),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isQuotaLimit ? const Color(0xFFF59E0B).withAlpha(60) : const Color(0xFF10B981).withAlpha(60),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Icon(
                    isQuotaLimit ? Icons.hourglass_top_rounded : Icons.lock_person_rounded,
                    color: isQuotaLimit ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),

                // Warning Quota Badge Pill (Only if isQuotaLimit)
                if (isQuotaLimit) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: const Color(0xFFFDBA74), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'BATAS KUOTA TAMU ($usedScans/$maxQuota)',
                          style: const TextStyle(
                            color: Color(0xFFEA580C),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Question Title
                Text(
                  title ?? 'Apakah Anda Sudah Memiliki Akun?',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Description Text Body
                Text(
                  description ?? 'Silakan masuk jika Anda sudah memiliki akun Mangodefend, atau buat akun baru untuk menikmati fitur lengkap.',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Quota Progress Bar & Benefit Box (Only if isQuotaLimit)
                if (isQuotaLimit) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Penggunaan Kuota Hari Ini',
                              style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$usedScans / $maxQuota Sesi',
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (usedScans / maxQuota).clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFEA580C), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buka Kuota Scan Unlimited',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih Paket Pro/Enterprise untuk pemindaian tanpa batas!',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hero Premium Upgrade Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        final nav = Navigator.of(context);
                        nav.pop();
                        nav.push(
                          MaterialPageRoute(
                            builder: (context) => const SelectPlanScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFFEA580C).withAlpha(100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rocket_launch_rounded, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Upgrade Paket Pro (Unlimited)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'atau opsi akun:',
                          style: TextStyle(color: subTextColor, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Action Buttons (Login / Register Options)
                if (isQuotaLimit) ...[
                  // If Quota Limit: Side-by-side Row
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              if (onLoginPressed != null) {
                                onLoginPressed!();
                              } else {
                                nav.push(
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sudah, Saya Ingin Masuk',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              if (onRegisterPressed != null) {
                                onRegisterPressed!();
                              } else {
                                nav.push(
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterScreen(),
                                  ),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Belum, Buat Akun Baru',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // If Normal Sidebar Login Request: Standard Stacked Action Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            if (onLoginPressed != null) {
                              onLoginPressed!();
                            } else {
                              nav.push(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 18),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Sudah, Saya Ingin Masuk',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            if (onRegisterPressed != null) {
                              onRegisterPressed!();
                            } else {
                              nav.push(
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_rounded, size: 18),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Belum, Buat Akun Baru',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
