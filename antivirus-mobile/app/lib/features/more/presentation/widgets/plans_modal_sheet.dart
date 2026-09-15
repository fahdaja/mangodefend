import 'package:flutter/material.dart';

class PlansModalSheet extends StatefulWidget {
  const PlansModalSheet({super.key});

  @override
  State<PlansModalSheet> createState() => _PlansModalSheetState();
}

class _PlansModalSheetState extends State<PlansModalSheet> {
  String _selectedPlanId = 'pro_monthly';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Modal Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(30),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(
                  Icons.stars,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilihan Paket Berlangganan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pilih paket keamanan yang sesuai dengan kebutuhan Anda',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Plans Options List
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Plan 1: Starter Free
                  _buildPlanCard(
                    id: 'free',
                    title: 'Starter Free',
                    price: 'Rp 0',
                    billingPeriod: '/ selamanya',
                    badgeText: 'GRATIS',
                    badgeBgColor: const Color(0xFF334155),
                    badgeTextColor: const Color(0xFF94A3B8),
                    features: [
                      'Pemindaian Manual File & Folder',
                      'Perlindungan Dasar Malware',
                      '1 Perangkat Mobile',
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Plan 2: Pro Monthly (POPULAR CHOICE)
                  _buildPlanCard(
                    id: 'pro_monthly',
                    title: 'Pro Monthly',
                    price: 'Rp 49.000',
                    billingPeriod: '/ bulan',
                    badgeText: 'PALING POPULER',
                    badgeBgColor: const Color(0xFFDCFCE7),
                    badgeTextColor: const Color(0xFF059669),
                    isPopular: true,
                    features: [
                      'Perlindungan Real-Time Latar Belakang',
                      'Engine Pemindaian Tingkat Lanjut',
                      'Pengoptimasi RAM & Baterai (+2.5 Jam)',
                      'Dukungan Tim Security',
                      'Hingga 3 Perangkat Terhubung',
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Plan 3: Pro Annual (BEST VALUE - SAVE 25%)
                  _buildPlanCard(
                    id: 'pro_annual',
                    title: 'Pro Yearly (Tahunan)',
                    price: 'Rp 449.000',
                    billingPeriod: '/ tahun',
                    badgeText: 'HEMAT 25%',
                    badgeBgColor: const Color(0xFFFEF3C7),
                    badgeTextColor: const Color(0xFFD97706),
                    features: [
                      'Semua Fitur Pro Monthly',
                      'Perlindungan Keluarga hingga 5 Perangkat',
                      'Sinkronisasi Cloud Intelligence Tercepat',
                      'Hemat Rp 139.000 dibanding bulanan',
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Select Plan Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF059669),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Paket ${_getPlanName(_selectedPlanId)} berhasil dipilih!',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
              ),
              child: Text(
                'Lanjutkan dengan ${_getPlanName(_selectedPlanId)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _getPlanName(String id) {
    switch (id) {
      case 'free':
        return 'Starter Free';
      case 'pro_annual':
        return 'Pro Yearly';
      case 'pro_monthly':
      default:
        return 'Pro Monthly';
    }
  }

  Widget _buildPlanCard({
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
    final isSelected = _selectedPlanId == id;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF10B981)
              : (isPopular ? const Color(0xFF059669) : const Color(0xFF334155)),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPlanId = id;
            });
          },
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    text: price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: ' $billingPeriod',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: features.map((feat) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feat,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
