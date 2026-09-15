import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';

class ProtectionStatusCard extends StatefulWidget {
  final bool isScanning;
  final double scanProgress;
  final int scannedFiles;
  final String currentScanningFilePath;
  final VoidCallback? onScanPressed;
  final VoidCallback? onCancelScan;

  final bool isRealtimeProtectionEnabled;

  const ProtectionStatusCard({
    super.key,
    this.isScanning = false,
    this.scanProgress = 0.0,
    this.scannedFiles = 0,
    this.currentScanningFilePath = '',
    this.isRealtimeProtectionEnabled = true,
    this.onScanPressed,
    this.onCancelScan,
  });

  @override
  State<ProtectionStatusCard> createState() => _ProtectionStatusCardState();
}

class _ProtectionStatusCardState extends State<ProtectionStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutQuad,
    );

    if (widget.isScanning) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ProtectionStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!widget.isScanning && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final progressPercent = (widget.scanProgress * 100).toInt();

    final themeColor = const Color(0xFF10B981);

    final String statusTitle = widget.isScanning
        ? LanguageController.tr('scanning')
        : (widget.isRealtimeProtectionEnabled ? LanguageController.tr('system_protected') : 'Sistem Siap Dipindai');

    final String statusSubtitle = widget.isScanning
        ? 'Inspeksi mendalam ${widget.scannedFiles} file dalam penyimpanan sistem...'
        : (widget.isRealtimeProtectionEnabled
            ? LanguageController.tr('full_protection')
            : 'Perangkat bebas ancaman. Pemindaian manual gratis siap digunakan kapan saja.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 24.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withAlpha(isDark ? 20 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // VirtualShield Animated Radar Pulse Hero Container
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated Radar Wave 1 (Expanded pulse)
                if (widget.isScanning)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final waveScale = 1.0 + (_pulseAnimation.value * 0.35);
                      final waveOpacity = (1.0 - _pulseAnimation.value).clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: waveScale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: themeColor.withOpacity(waveOpacity * 0.25),
                            border: Border.all(
                              color: themeColor.withOpacity(waveOpacity * 0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Animated Radar Wave 2 (Secondary phase wave)
                if (widget.isScanning)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final phaseValue = (_pulseAnimation.value + 0.5) % 1.0;
                      final waveScale = 1.0 + (phaseValue * 0.35);
                      final waveOpacity = (1.0 - phaseValue).clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: waveScale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: themeColor.withOpacity(waveOpacity * 0.15),
                          ),
                        ),
                      );
                    },
                  ),

                // Circular Progress Ring Overlay
                if (widget.isScanning)
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      value: widget.scanProgress > 0 ? widget.scanProgress : null,
                      strokeWidth: 6.0,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                      color: themeColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),

                // Central Shield Logo Container
                Container(
                  width: widget.isScanning ? 116 : 130,
                  height: widget.isScanning ? 116 : 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? themeColor.withAlpha(15)
                        : (widget.isRealtimeProtectionEnabled ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED)),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withAlpha(isDark ? 25 : 35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: Border.all(
                              color: isDark ? themeColor.withAlpha(60) : const Color(0xFFDCFCE7),
                              width: 2.0,
                            ),
                          ),
                          child: widget.isScanning
                              ? Text(
                                  '$progressPercent%',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/logo-mangodefend.png',
                                  width: 42,
                                  height: 42,
                                ),
                        ),

                        // Shield Status Badge (Only when not scanning)
                        if (!widget.isScanning)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Title
          Text(
            statusTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.isScanning
                  ? textColor
                  : (widget.isRealtimeProtectionEnabled ? textColor : const Color(0xFFD97706)),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            statusSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subTextColor,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          // Live Active File Marquee Ticker (Visible during scanning)
          if (widget.isScanning && widget.currentScanningFilePath.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Memeriksa: ${widget.currentScanningFilePath}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          if (widget.isScanning) ...[
            OutlinedButton.icon(
              onPressed: widget.onCancelScan,
              icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
              label: Text(
                LanguageController.tr('cancel_scan'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ] else ...[
            Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onScanPressed ?? () {},
                    borderRadius: BorderRadius.circular(14.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26.0,
                        vertical: 13.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(14.0),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            LanguageController.tr('start_scan'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Full System Scan • Memori & Penyimpanan Utama',
                  style: TextStyle(
                    color: subTextColor.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
