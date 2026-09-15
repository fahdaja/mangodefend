import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:antivirus_mobile/shared/services/subscription_service.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';

class MidtransPaymentDialog extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String paymentMethod;
  final String? paymentUrl;
  final String? snapToken;
  final String planName;
  final VoidCallback onPaymentSuccess;

  const MidtransPaymentDialog({
    super.key,
    required this.transactionId,
    required this.amount,
    required this.paymentMethod,
    this.paymentUrl,
    this.snapToken,
    required this.planName,
    required this.onPaymentSuccess,
  });

  @override
  State<MidtransPaymentDialog> createState() => _MidtransPaymentDialogState();
}

class _MidtransPaymentDialogState extends State<MidtransPaymentDialog> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isChecking = false;
  String? _statusMessage;
  bool _isSuccess = false;

  Future<void> _openPaymentUrl() async {
    final urlStr = widget.paymentUrl;
    if (urlStr == null || urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL Pembayaran tidak valid.')),
      );
      return;
    }

    final uri = Uri.parse(urlStr);
    bool launched = false;

    // Mode 1: External Application (Default Browser)
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}

    // Mode 2: Platform Default
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    // Mode 3: In App Browser View
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {}
    }

    if (!launched && mounted) {
      Clipboard.setData(ClipboardData(text: urlStr));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka browser otomatis. Link Midtrans disalin ke clipboard:\n$urlStr'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    final res = await _subscriptionService.checkPaymentStatus(widget.transactionId);

    if (!mounted) return;

    setState(() {
      _isChecking = false;
    });

    if (res != null) {
      final dbStatus = (res['db_status'] as String?)?.toUpperCase();
      final midtransStatus = (res['midtrans_details']?['transaction_status'] as String?)?.toLowerCase();

      if (dbStatus == 'SUCCESS' || midtransStatus == 'settlement' || midtransStatus == 'capture') {
        UserSession.isProUser = true;
        UserSession.activePlanName = widget.planName;
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Pembayaran terverifikasi Berhasil! 🎉';
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context); // Close payment dialog
          widget.onPaymentSuccess();
        }
      } else if (dbStatus == 'FAILED' || midtransStatus == 'expire' || midtransStatus == 'cancel') {
        setState(() {
          _statusMessage = 'Pembayaran Gagal atau Kedaluwarsa.';
        });
      } else {
        setState(() {
          _statusMessage = 'Pembayaran masih PENDING. Silakan selesaikan pembayaran di Midtrans.';
        });
      }
    } else {
      setState(() {
        _statusMessage = 'Gagal menghubungi server untuk cek status.';
      });
    }
  }

  Future<void> _simulateSuccess() async {
    setState(() {
      _isChecking = true;
      _statusMessage = 'Memproses simulasi pembayaran...';
    });

    await _subscriptionService.simulatePaymentSuccess(widget.transactionId);
    await _checkStatus();
  }

  String get _formattedAmount {
    return 'Rp ${widget.amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF10B981);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161B26) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge & Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSuccess ? Icons.check_circle_rounded : Icons.payment_rounded,
                  color: _isSuccess ? const Color(0xFF059669) : const Color(0xFF2563EB),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                _isSuccess ? 'Pembayaran Berhasil!' : 'Pembayaran Midtrans Gateway',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paket: ${widget.planName}',
                style: const TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              // QRIS Code Image Container
              if (!_isSuccess && widget.paymentUrl != null && widget.paymentUrl!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2_rounded, color: Color(0xFF0F172A), size: 22),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Scan Kode QRIS Pembayaran',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${Uri.encodeComponent(widget.paymentUrl!)}',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: Icon(Icons.qr_code_scanner_rounded, size: 64, color: Color(0xFF94A3B8)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Scan QRIS menggunakan GoPay, OVO, Dana, ShopeePay, atau Mobile Banking',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Transaction Info Card
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
                    _buildDetailRow(
                      context,
                      'Order ID',
                      widget.transactionId,
                      canCopy: true,
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      context,
                      'Metode',
                      widget.paymentMethod.toUpperCase(),
                    ),
                    const Divider(height: 16),
                    _buildDetailRow(
                      context,
                      'Total Pembayaran',
                      _formattedAmount,
                      isBold: true,
                      valueColor: primaryColor,
                    ),
                    if (widget.paymentUrl != null && widget.paymentUrl!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Link Midtrans',
                        widget.paymentUrl!,
                        canCopy: true,
                      ),
                    ],
                    if (widget.snapToken != null && widget.snapToken!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildDetailRow(
                        context,
                        'Snap Token',
                        widget.snapToken!,
                        canCopy: true,
                      ),
                    ],
                  ],
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFFDCFCE7)
                        : (isDark ? const Color(0xFF332014) : const Color(0xFFFFF7ED)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess
                          ? const Color(0xFF86EFAC)
                          : (isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5)),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isSuccess
                          ? const Color(0xFF166534)
                          : (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C)),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              if (!_isSuccess) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openPaymentUrl,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: const Text(
                      'Bayar via Midtrans Snap',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _checkStatus,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(
                      _isChecking ? 'Verifikasi...' : 'Cek Status Pembayaran',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isChecking ? null : _simulateSuccess,
                    icon: const Icon(Icons.science_rounded, size: 18),
                    label: const Text(
                      'Simulasi Bayar Berhasil (Sandbox Test)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      backgroundColor: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Tutup',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    bool canCopy = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                    fontSize: 13,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label disalin ke clipboard!'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
