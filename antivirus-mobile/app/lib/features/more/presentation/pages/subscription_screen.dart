import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/select_plan_screen.dart';
import 'package:antivirus_mobile/shared/services/subscription_service.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  UserSubscriptionStatus? _userSub;
  int _usedDevicesCount = 1;
  int _usedDailyScansCount = 0;

  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    // 1. Sync & fetch daily scan usage count
    await GuestQuotaService.syncQuotaWithServer();

    final quotaScans = UserSession.isLoggedIn
        ? GuestQuotaService.userScanCountNotifier.value
        : GuestQuotaService.guestScanCountNotifier.value;

    int realDailyScans = quotaScans;

    // 2. Fetch real devices count if logged in
    int realDevices = 1;
    if (UserSession.isLoggedIn && UserSession.accessToken != null) {
      try {
        const baseUrl = ApiConfig.baseUrl;
        final response = await http.get(
          Uri.parse('$baseUrl/devices'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${UserSession.accessToken}',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final List<dynamic> listJson = jsonDecode(response.body);
          if (listJson.isNotEmpty) {
            realDevices = listJson.length;
          }
        }
      } catch (e) {
        debugPrint('⚠️ [SUBSCRIPTION SCREEN] Failed to fetch device count: $e');
      }
    }

    if (!UserSession.isLoggedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userSub = null;
          _usedDevicesCount = realDevices;
          _usedDailyScansCount = realDailyScans;
        });
      }
      return;
    }

    try {
      final sub = await _subService.getMySubscription();
      if (mounted) {
        setState(() {
          _userSub = sub;
          _isLoading = false;
          _usedDevicesCount = realDevices;
          _usedDailyScansCount = realDailyScans;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _usedDevicesCount = realDevices;
          _usedDailyScansCount = realDailyScans;
        });
      }
    }
  }

  void _navigateToSelectPlan(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SelectPlanScreen()),
    );
    _fetchSubscriptionStatus();
  }

  String _formatDate(String? isoDateStr, bool isPro) {
    if (!isPro || isoDateStr == null || isoDateStr.isEmpty) return 'Aktif Selamanya';
    try {
      final dt = DateTime.parse(isoDateStr).toLocal();
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDateStr;
    }
  }

  void _showCancelSubscriptionDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isPro = _userSub != null &&
        _userSub!.isActive &&
        _userSub!.planName.toLowerCase() != 'free' &&
        _userSub!.planName.toLowerCase() != 'starter free';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Batalkan Langganan Pro?',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Manfaat paket Pro Anda tetap aktif hingga tanggal kedaluwarsa (${_formatDate(_userSub?.endDate, isPro)}). Setelah itu, akun akan kembali ke Paket Starter Gratis.',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tetap Berlangganan',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final success = await _subService.cancelSubscription();
              if (mounted) {
                if (success) {
                  _fetchSubscriptionStatus();
                  messenger.showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF0F172A),
                      content: Text('Langganan berhasil dibatalkan. Akun Anda kembali ke Paket Starter Free.'),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFFEF4444),
                      content: Text('Gagal membatalkan langganan. Silakan coba lagi.'),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Batalkan Langganan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF161B26) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderTileColor = isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0);

    final bool isPro = _userSub != null &&
        _userSub!.isActive &&
        _userSub!.planName.toLowerCase() != 'free' &&
        _userSub!.planName.toLowerCase() != 'starter free';

    final String planName = _userSub?.planName ?? (isPro ? 'Pro' : 'Starter Free');
    final bool isAnnual = planName.toLowerCase().contains('annual') ||
        planName.toLowerCase().contains('yearly') ||
        planName.toLowerCase().contains('tahunan') ||
        _userSub?.plan?.maxDailyScans == -1 ||
        UserSession.activePlanName.toLowerCase().contains('annual');

    final String priceText = _userSub?.plan?.formattedPrice ??
        (isPro
            ? (isAnnual ? 'Rp 449.000 / tahun' : 'Rp 49.000 / bulan')
            : 'Rp 0 (Gratis Selamanya)');

    final String expireText = _formatDate(_userSub?.endDate, isPro);

    final int maxDevices = _userSub?.plan?.maxDevices ?? (isPro ? (isAnnual ? 10 : 3) : 1);
    final int maxScans = _userSub?.plan?.maxDailyScans ?? (isPro ? (isAnnual ? -1 : 200) : 30);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Kelola Berlangganan',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
            onPressed: _fetchSubscriptionStatus,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderTileColor),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HERO STATUS CARD (APPLE/iOS MINIMALIST STYLE)
                      Container(
                        padding: const EdgeInsets.all(22.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: isPro
                                ? (isDark ? const Color(0xFF10B981).withAlpha(80) : const Color(0xFFA7F3D0))
                                : borderTileColor,
                            width: isPro ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 25 : 6),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Avatar + Title + Badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                    color: isPro
                                        ? (isDark ? const Color(0xFF10B981).withAlpha(25) : const Color(0xFFECFDF5))
                                        : (isDark ? const Color(0xFF262C3A) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                  child: Icon(
                                    isPro ? Icons.workspace_premium_rounded : Icons.shield_outlined,
                                    color: isPro ? const Color(0xFF10B981) : subTextColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        planName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isPro ? (isAnnual ? 'Paket Pro Annual (Aktif)' : 'Paket Pro Monthly (Aktif)') : 'Paket Dasar Gratis Selamanya',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: subTextColor, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPro
                                        ? const Color(0xFFDCFCE7)
                                        : (isDark ? const Color(0xFF262C3A) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isPro ? (isAnnual ? 'PRO ANNUAL' : 'PRO MONTHLY') : 'FREE',
                                    style: TextStyle(
                                      color: isPro ? const Color(0xFF059669) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Inset Progress Bars Box (iOS Minimalist Style) - REAL LIVE METRICS TRACKING
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: borderTileColor, width: 1.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Metric 1: Devices Allowed Progress Bar
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.devices_rounded, color: isPro ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Devices Allowed',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '$_usedDevicesCount/$maxDevices Used',
                                        style: TextStyle(color: isPro ? const Color(0xFF10B981) : subTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: maxDevices <= 0 ? 0.0 : (_usedDevicesCount / maxDevices).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(isPro ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Metric 2: Daily Scan Quota Progress Bar
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.flash_on_rounded, color: isPro ? const Color(0xFF10B981) : const Color(0xFF3B82F6), size: 16),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Kuota Pemindaian Harian',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          maxScans == -1 ? 'Unlimited Scans' : '$_usedDailyScansCount / $maxScans Used',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: isPro ? const Color(0xFF10B981) : subTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (maxScans != -1) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: (_usedDailyScansCount / maxScans).clamp(0.0, 1.0),
                                        minHeight: 6,
                                        backgroundColor: isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0),
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Divider(height: 1, color: borderTileColor),
                            const SizedBox(height: 14),

                            // Grid Info (Harga & Masa Berlaku)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Harga Penagihan', style: TextStyle(color: subTextColor, fontSize: 11)),
                                      const SizedBox(height: 3),
                                      Text(priceText, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 28,
                                  width: 1,
                                  color: borderTileColor,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(isPro ? 'Berlaku Hingga' : 'Masa Berlaku', style: TextStyle(color: subTextColor, fontSize: 11)),
                                      const SizedBox(height: 3),
                                      Text(expireText, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Saved Payment Method (if Pro)
                            if (isPro) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.payment_rounded, color: Color(0xFF10B981), size: 15),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Metode Pembayaran: Midtrans Gateway (QRIS / E-Wallet)',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. PRIVILEGES / INCLUDED FEATURES
                      Text(
                        isPro ? 'FASILITAS PAKET PRO AKTIF' : 'FITUR PAKET ANDA SAAT INI',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: borderTileColor, width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 20 : 4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildCleanFeatureRow(
                              isDark,
                              icon: Icons.flash_on_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              title: 'Batas Pemindaian File / Hari',
                              subtitle: maxScans == -1
                                  ? 'Pemindaian Tanpa Batas (Unlimited Scans)'
                                  : (isPro ? 'Hingga $maxScans Scan Harian' : 'Batas 30 Scan Harian (Free Tier)'),
                              isIncluded: true,
                            ),
                            Divider(height: 1, color: borderTileColor),
                            _buildCleanFeatureRow(
                              isDark,
                              icon: Icons.devices_outlined,
                              iconColor: const Color(0xFFF59E0B),
                              title: 'Batas Perangkat Terhubung',
                              subtitle: isPro ? 'Dukungan hingga $maxDevices Perangkat Terhubung' : '1 Perangkat Terhubung',
                              isIncluded: true,
                            ),
                            Divider(height: 1, color: borderTileColor),
                            _buildCleanFeatureRow(
                              isDark,
                              icon: Icons.shield_outlined,
                              iconColor: const Color(0xFF10B981),
                              title: 'Proteksi Real-Time (Otomatis)',
                              subtitle: 'Pemantauan malware otomatis 24/7 di latar belakang',
                              isIncluded: isPro || (_userSub?.plan?.canRealtimeProtection ?? false),
                            ),

                            Divider(height: 1, color: borderTileColor),
                            _buildCleanFeatureRow(
                              isDark,
                              icon: Icons.schedule_outlined,
                              iconColor: const Color(0xFF8B5CF6),
                              title: 'Pemindaian Terjadwal',
                              subtitle: 'Scan otomatis harian/mingguan saat HP dicas',
                              isIncluded: isPro || (_userSub?.plan?.canScheduledScan ?? false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3. MAIN ACTION BUTTON (UPGRADE / UPDATE PLAN)
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withAlpha(40),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToSelectPlan(context),
                          icon: Icon(
                            isPro ? Icons.stars_rounded : Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isPro ? 'Ganti atau Perbarui Paket' : 'Upgrade ke Paket Pro Sekarang',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 4. SECONDARY ACTIONS (RESTORE & CANCEL)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF0F172A),
                                  content: Text('Pembelian Mangodefend PRO berhasil dipulihkan.'),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.refresh_rounded, color: subTextColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pulihkan Pembelian',
                                    style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isPro) ...[
                            Text(' • ', style: TextStyle(color: subTextColor, fontSize: 12)),
                            InkWell(
                              onTap: () => _showCancelSubscriptionDialog(context),
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Batalkan Langganan',
                                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCleanFeatureRow(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isIncluded,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: isIncluded
                  ? iconColor.withAlpha(20)
                  : (isDark ? const Color(0xFF262C3A) : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isIncluded
                  ? iconColor
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isIncluded
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    fontSize: 13,
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
          const SizedBox(width: 10),
          Icon(
            isIncluded ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: isIncluded ? const Color(0xFF10B981) : (isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
            size: 20,
          ),
        ],
      ),
    );
  }
}
