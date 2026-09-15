import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageController.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: cardBgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              LanguageController.tr('support_title'),
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LanguageController.tr('support_header_title'),
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LanguageController.tr('support_header_desc'),
                      style: TextStyle(color: subTextColor, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // QUICK HELP SECTION
                    Text(LanguageController.tr('quick_help_section'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _buildQuickHelpTile(isDark, Icons.rocket_launch_outlined, 'Panduan Awal Penggunaan', 'Cara awal melindungi perangkat Anda secara optimal'),
                    const SizedBox(height: 10),
                    _buildQuickHelpTile(isDark, Icons.radar_outlined, 'Cara Kerja Pemindaian File', 'Penjelasan Pemindaian Cepat, Pemindaian Penuh, & Folder Custom'),
                    const SizedBox(height: 10),
                    _buildQuickHelpTile(isDark, Icons.shield_outlined, 'Perlindungan Real-Time', 'Cara kerja pemindaian otomatis di latar belakang'),
                    const SizedBox(height: 10),
                    _buildQuickHelpTile(isDark, Icons.warning_amber_outlined, 'Memahami Tingkat Ancaman', 'Penjelasan deteksi file Aman, Terisolasi, dan Malware'),
                    const SizedBox(height: 24),

                    // FAQ ACCORDION SECTION
                    Text(LanguageController.tr('faq_section'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
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
                          _buildFaqItem(isDark, 'Apa fungsi utama Perlindungan Real-Time?', 'Perlindungan Real-Time memantau aktivitas perangkat secara terus-menerus di latar belakang untuk memblokir virus, spyware, dan malware secara otomatis sebelum menginfeksi sistem.'),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          _buildFaqItem(isDark, 'Apa perbedaan Pemindaian Penuh dan Pemindaian Cepat?', 'Pemindaian Penuh memeriksa seluruh direktori file, sistem OS, dan aplikasi terpasang secara mendalam, sedangkan Pemindaian Cepat hanya memindai area memori utama yang paling rawan ancaman.'),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          _buildFaqItem(isDark, 'Mengapa file aman saya terdeteksi sebagai ancaman?', 'File terdeteksi jika mengandung signature kode berisiko atau pola heuristik yang mencurigakan. Anda dapat menandai file tersebut ke daftar Whitelist jika terbukti aman.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SUPPORT ACTION BOX
                    Text(LanguageController.tr('contact_support_section'), style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(18.0),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withAlpha(15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF10B981).withAlpha(20) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Icon(Icons.headset_mic, color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669), size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(LanguageController.tr('live_chat_title'), style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(LanguageController.tr('live_chat_desc'), style: TextStyle(color: subTextColor, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: Color(0xFF059669),
                                    content: Text('Membuka sesi Live Chat dengan Tim Security Support...'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                              label: Text(
                                LanguageController.tr('start_chat_btn'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildQuickHelpTile(bool isDark, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(icon, color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 18),
        ],
      ),
    );
  }

  Widget _buildFaqItem(bool isDark, String question, String answer) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      childrenPadding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      iconColor: const Color(0xFF10B981),
      collapsedIconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      title: Text(
        question,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      children: [
        Text(
          answer,
          style: TextStyle(
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
