import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/services/subscription_service.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';
import 'package:antivirus_mobile/features/auth/auth.dart';
import 'package:antivirus_mobile/features/more/presentation/widgets/midtrans_payment_dialog.dart';

class SelectPlanScreen extends StatefulWidget {
  const SelectPlanScreen({super.key});

  @override
  State<SelectPlanScreen> createState() => _SelectPlanScreenState();
}

class _SelectPlanScreenState extends State<SelectPlanScreen> {
  String _selectedPlanId = 'pro_monthly';
  int _billingCycleIndex = 0; // 0 = Bulanan, 1 = Tahunan
  bool _isProcessingCheckout = false;

  void _showPaymentModalSheet() {
    if (UserSession.accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFF97316),
          content: Text('Silakan masuk ke akun Anda terlebih dahulu untuk memproses pembayaran.'),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    if (_selectedPlanId == 'free') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F172A),
          content: Text('Anda sudah berada di Paket Gratis.'),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedPaymentMethod = 'qris';
    final planName = _getPlanName(_selectedPlanId);
    final planPrice = _getPlanPrice(_selectedPlanId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Title
                  Text(
                    'Ringkasan Pembayaran',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih metode pembayaran untuk menyelesaikan transaksi',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invoice Summary Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Item Paket', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                            Text(planName, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal Biaya', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                            Text(planPrice, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('PPN (11%)', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                            const Text('Termasuk', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: 20, color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Bayar', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(planPrice, style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Payment Method Options
                  Text(
                    'PILIH METODE PEMBAYARAN',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildPaymentOptionTile(
                    isDark: isDark,
                    id: 'qris',
                    title: 'QRIS / GoPay / ShopeePay / Dana',
                    subtitle: 'Instant QR Code Scan • Otomatis Terverifikasi',
                    icon: Icons.qr_code_2_rounded,
                    selectedId: selectedPaymentMethod,
                    onTap: () => setModalState(() => selectedPaymentMethod = 'qris'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOptionTile(
                    isDark: isDark,
                    id: 'bank_transfer',
                    title: 'Virtual Account (BCA, Mandiri, BRI, BNI)',
                    subtitle: 'Transfer Bank 24 Jam Nonstop',
                    icon: Icons.account_balance_rounded,
                    selectedId: selectedPaymentMethod,
                    onTap: () => setModalState(() => selectedPaymentMethod = 'bank_transfer'),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentOptionTile(
                    isDark: isDark,
                    id: 'credit_card',
                    title: 'Kartu Kredit / Debit (Visa, Mastercard)',
                    subtitle: 'Proses Aman Berstandar PCI-DSS',
                    icon: Icons.credit_card_rounded,
                    selectedId: selectedPaymentMethod,
                    onTap: () => setModalState(() => selectedPaymentMethod = 'credit_card'),
                  ),
                  const SizedBox(height: 24),

                  // Pay Now Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessingCheckout
                          ? null
                          : () {
                              Navigator.pop(modalContext);
                              _processCheckoutBackend(selectedPaymentMethod);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isProcessingCheckout
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Bayar $planPrice Sekarang',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOptionTile({
    required bool isDark,
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required String selectedId,
    required VoidCallback onTap,
  }) {
    final isSelected = id == selectedId;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFECFDF5))
              : (isDark ? const Color(0xFF0B0F17) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF10B981) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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
            Radio<String>(
              value: id,
              groupValue: selectedId,
              onChanged: (_) => onTap(),
              activeColor: const Color(0xFF10B981),
            ),
          ],
        ),
      ),
    );
  }

  void _processCheckoutBackend(String paymentMethod) async {
    setState(() {
      _isProcessingCheckout = true;
    });

    final subService = SubscriptionService();
    int planId = 1;
    if (_selectedPlanId == 'pro_monthly') planId = 2;
    if (_selectedPlanId == 'pro_annual') planId = 3;

    final checkoutRes = await subService.checkout(planId: planId, paymentMethod: paymentMethod);

    if (mounted) {
      setState(() {
        _isProcessingCheckout = false;
      });

      if (checkoutRes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Gagal membuat pesanan pembayaran. Silakan coba lagi.'),
          ),
        );
        return;
      }

      final status = checkoutRes['status'] as String? ?? 'PENDING';
      final transactionId = checkoutRes['transaction_id'] as String? ?? '';
      final amount = (checkoutRes['amount'] as num?)?.toDouble() ?? 0.0;
      final paymentUrl = checkoutRes['payment_url'] as String?;
      final snapToken = checkoutRes['snap_token'] as String?;

      if (status == 'SUCCESS') {
        _showSuccessDialog();
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => MidtransPaymentDialog(
            transactionId: transactionId,
            amount: amount,
            paymentMethod: paymentMethod,
            paymentUrl: paymentUrl,
            snapToken: snapToken,
            planName: _getPlanName(_selectedPlanId),
            onPaymentSuccess: () {
              if (mounted) {
                _showSuccessDialog();
              }
            },
          ),
        );
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    try {
      await SubscriptionService().getMySubscription();
    } catch (_) {}
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B26) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Pembayaran Berhasil! 🎉',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selamat! Paket ${_getPlanName(_selectedPlanId)} telah aktif. Akun Anda kini mendapatkan perlindungan real-time prioritas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // return to subscription screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Kembali ke Berlangganan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlanName(String planId) {
    switch (planId) {
      case 'pro_monthly':
        return 'Pro Monthly';
      case 'pro_annual':
        return 'Pro Yearly (Tahunan)';
      default:
        return 'Starter Free';
    }
  }

  String _getPlanPrice(String planId) {
    switch (planId) {
      case 'pro_monthly':
        return 'Rp 49.000';
      case 'pro_annual':
        return 'Rp 449.000';
      default:
        return 'Rp 0';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF161B26) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderTileColor = isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pilihan Paket Berlangganan',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderTileColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HERO BANNER HEADER (APPLE/iOS MINIMALIST CLEAN CARD)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20.0),
                          border: Border.all(color: borderTileColor, width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 20 : 5),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF10B981).withAlpha(25) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF10B981), size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Upgrade ke Premium',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Dapatkan proteksi otomatis 24/7 latar belakang dan scan tanpa batas.',
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SEGMENTED CYCLE TOGGLE SWITCH (BULANAN VS TAHUNAN)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _billingCycleIndex = 0;
                                    _selectedPlanId = 'pro_monthly';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _billingCycleIndex == 0
                                        ? (isDark ? const Color(0xFF0B0F17) : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _billingCycleIndex == 0
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(isDark ? 30 : 10),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Text(
                                    'Bulanan',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _billingCycleIndex == 0
                                          ? textColor
                                          : subTextColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _billingCycleIndex = 1;
                                    _selectedPlanId = 'pro_annual';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _billingCycleIndex == 1
                                        ? (isDark ? const Color(0xFF0B0F17) : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _billingCycleIndex == 1
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(isDark ? 30 : 10),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Tahunan',
                                        style: TextStyle(
                                          color: _billingCycleIndex == 1
                                              ? textColor
                                              : subTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          '-25%',
                                          style: TextStyle(
                                            color: Color(0xFFD97706),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'PILIH PAKET YANG SESUAI',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Plan 1: Starter Free
                      _buildPlanCard(
                        isDark: isDark,
                        id: 'free',
                        title: 'Starter Free (Gratis)',
                        price: 'Rp 0',
                        billingPeriod: '/ selamanya',
                        badgeText: 'GRATIS',
                        badgeBgColor: isDark ? const Color(0xFF262C3A) : const Color(0xFFF1F5F9),
                        badgeTextColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        features: const [
                          'Batas 30 Pemindaian File / Hari',
                          'Batas 1 Perangkat Terhubung',
                          'Pemindaian Manual File, Folder & Sistem',
                          'Proteksi Real-Time & Web Guard: Terkunci',
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Plan 2: Pro Monthly (POPULAR CHOICE)
                      _buildPlanCard(
                        isDark: isDark,
                        id: 'pro_monthly',
                        title: 'Pro Monthly (Bulanan)',
                        price: 'Rp 49.000',
                        billingPeriod: '/ bulan',
                        badgeText: 'PALING POPULER',
                        badgeBgColor: const Color(0xFFDCFCE7),
                        badgeTextColor: const Color(0xFF059669),
                        isPopular: true,
                        features: const [
                          'Hingga 200 Pemindaian File / Hari',
                          'Hingga 3 Perangkat Terhubung',
                          'Proteksi Real-Time Otomatis Latar Belakang',
                          'Pemindaian Otomatis Terjadwal (Scheduled Scan)',
                          'Pembaruan Definisi Malware Prioritas',
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Plan 3: Pro Annual (BEST VALUE - SAVE 25%)
                      _buildPlanCard(
                        isDark: isDark,
                        id: 'pro_annual',
                        title: 'Pro Yearly (Tahunan / Enterprise)',
                        price: 'Rp 449.000',
                        billingPeriod: '/ tahun',
                        badgeText: 'HEMAT 25%',
                        badgeBgColor: const Color(0xFFFEF3C7),
                        badgeTextColor: const Color(0xFFD97706),
                        features: const [
                          'Unlimited Pemindaian Harian (Tanpa Batas Kuota)',
                          'Hingga 10 Perangkat Terhubung',
                          'Proteksi Real-Time Otomatis Latar Belakang',
                          'Pemindaian Otomatis Terjadwal (Scheduled Scan)',
                          'Hemat 25% + Dukungan Prioritas Security 24/7',
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BOTTOM FIXED STICKY ACTION BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: cardBgColor,
              border: Border(
                top: BorderSide(
                  color: borderTileColor,
                  width: 1.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 8),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paket Dipilih:', style: TextStyle(color: subTextColor, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              _getPlanName(_selectedPlanId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isProcessingCheckout ? null : _showPaymentModalSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Lanjutkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required bool isDark,
    required String id,
    required String title,
    required String price,
    required String billingPeriod,
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required List<String> features,
    bool isPopular = false,
  }) {
    final isSelected = id == _selectedPlanId;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderTileColor = isDark ? const Color(0xFF262C3A) : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlanId = id;
          if (id == 'pro_monthly') _billingCycleIndex = 0;
          if (id == 'pro_annual') _billingCycleIndex = 1;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B26) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981)
                : borderTileColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 20 : 4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          text: price,
                          style: TextStyle(color: textColor, fontSize: 19, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(text: ' $billingPeriod', style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.normal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: id,
                  groupValue: _selectedPlanId,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPlanId = val;
                        if (val == 'pro_monthly') _billingCycleIndex = 0;
                        if (val == 'pro_annual') _billingCycleIndex = 1;
                      });
                    }
                  },
                  activeColor: const Color(0xFF10B981),
                ),
              ],
            ),
            Divider(height: 24, color: borderTileColor),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: TextStyle(color: subTextColor, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
