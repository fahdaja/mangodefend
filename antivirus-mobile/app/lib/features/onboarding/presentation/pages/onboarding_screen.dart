import 'package:flutter/material.dart';
import 'package:antivirus_mobile/main.dart';
import 'package:antivirus_mobile/shared/services/onboarding_service.dart';

class OnboardingItem {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData mainIcon;
  final IconData accentIcon;
  final Color primaryColor;
  final Color secondaryColor;

  const OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.mainIcon,
    required this.accentIcon,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _slides = const [
    OnboardingItem(
      title: 'Proteksi Real-Time 24/7',
      subtitle:
          'Mangodefend memindai file, aplikasi baru, dan unduhan secara otomatis di latar belakang untuk mengamankan perangkat dari virus & malware.',
      badgeText: 'PROTECTION ACTIVE',
      mainIcon: Icons.security_rounded,
      accentIcon: Icons.verified_user_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF06B6D4),
    ),
    OnboardingItem(
      title: 'Pemindaian Cepat & Akurat',
      subtitle:
          'Didukung oleh Database Signature Biner Enterprise (MDB1) dan AI Heuristic Engine untuk deteksi ancaman presisi tinggi.',
      badgeText: '918+ SIGNATURE RULES',
      mainIcon: Icons.radar_rounded,
      accentIcon: Icons.bolt_rounded,
      primaryColor: Color(0xFF3B82F6),
      secondaryColor: Color(0xFF10B981),
    ),
    OnboardingItem(
      title: 'Karantina & Manajemen Aman',
      subtitle:
          'Isolasi ancaman berbahaya secara instan dalam Karantina Lokal terenkripsi dan kelola kuota pemindaian perangkat secara otomatis.',
      badgeText: 'ENCRYPTED LOCAL VAULT',
      mainIcon: Icons.lock_outline_rounded,
      accentIcon: Icons.gavel_rounded,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFFEC4899),
    ),
  ];

  void _onFinishOnboarding() async {
    await OnboardingService.markOnboardingCompleted();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _onNextPressed() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _onFinishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _slides[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.3),
                  radius: 1.2,
                  colors: [
                    currentItem.primaryColor.withValues(alpha: 0.15),
                    const Color(0xFF0B0F19),
                    const Color(0xFF070A10),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Cyber Ambient Glow Circles
          Positioned(
            top: -60,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: currentItem.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App Logo & Brand Header
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo-mangodefend.png',
                            width: 28,
                            height: 28,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Mangodefend',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      // Skip Button
                      if (_currentPage < _slides.length - 1)
                        TextButton(
                          onPressed: _onFinishOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(
                                color: Color(0xFF334155),
                                width: 0.8,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Lewati',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // PageView Carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _slides[index];
                      return _buildSlidePage(item);
                    },
                  ),
                ),

                // Bottom Control Section
                Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      // Slide Page Indicator Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _slides.length,
                          (index) => _buildIndicatorDot(index),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Main Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _onNextPressed,
                          style: ElevatedButton.styleFrom(
                            elevation: 8,
                            shadowColor: currentItem.primaryColor
                                .withValues(alpha: 0.4),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ).copyWith(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>(
                              (states) => currentItem.primaryColor,
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  currentItem.primaryColor,
                                  currentItem.secondaryColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == _slides.length - 1
                                        ? 'Mulai Sekarang'
                                        : 'Lanjut',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  Widget _buildSlidePage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic Hero Illustration Component (First Version)
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A),
              border: Border.all(
                color: item.primaryColor.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: item.primaryColor.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Subtle Accent Circle
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.secondaryColor.withValues(alpha: 0.08),
                  ),
                ),

                // Main Center Icon
                Icon(
                  item.mainIcon,
                  size: 68,
                  color: item.primaryColor,
                ),

                // Floating Accent Icon Badge
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.secondaryColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.secondaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      item.accentIcon,
                      size: 18,
                      color: item.secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Status Badge Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: item.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: item.primaryColor.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              item.badgeText,
              style: TextStyle(
                color: item.primaryColor,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Slide Title
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 12),

          // Slide Subtitle
          Text(
            item.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(int index) {
    final isActive = _currentPage == index;
    final item = _slides[_currentPage];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 26 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? item.primaryColor
            : const Color(0xFF334155).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: item.primaryColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                )
              ]
            : [],
      ),
    );
  }
}
