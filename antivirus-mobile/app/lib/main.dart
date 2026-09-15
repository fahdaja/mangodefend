import 'package:flutter/material.dart';
import 'package:antivirus_mobile/shared/widgets/navbar_bottom.dart';
import 'package:antivirus_mobile/shared/widgets/header.dart';
import 'package:antivirus_mobile/shared/theme/theme_controller.dart';
import 'package:antivirus_mobile/shared/language/language_controller.dart';
import 'package:antivirus_mobile/features/home/home.dart';
import 'package:antivirus_mobile/features/scan/scan.dart';
import 'package:antivirus_mobile/features/scan/data/local/binary_signature_database.dart';
import 'package:antivirus_mobile/features/protection/protection.dart';
import 'package:antivirus_mobile/features/activity/activity.dart';
import 'package:antivirus_mobile/features/more/more.dart';

import 'package:antivirus_mobile/features/splash/presentation/pages/splash_screen.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:antivirus_mobile/shared/services/local_quarantine_service.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';

import 'package:antivirus_mobile/shared/services/offline_sync_service.dart';
import 'package:antivirus_mobile/shared/services/global_scan_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ActivityStore.init();
  await GuestQuotaService.init();
  await GlobalScanController.instance.init();
  OfflineSyncService.flushPendingQueue();
  OfflineSyncService.startAutoSyncListener();
  try {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  } catch (_) {}
  BinarySignatureDatabase.loadBinaryDatabase().then((_) {
    BinarySignatureDatabase.syncSignaturesFromCloud();
  });

  if (ProtectionLocalDataSource.currentConfig.realTimeProtection) {
    LocalQuarantineService.startRealtimeGuardForegroundService();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeModeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<String>(
          valueListenable: LanguageController.currentLanguageNotifier,
          builder: (context, currentLang, child) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Mangodefend',
              themeMode: currentMode,
              theme: ThemeData.light().copyWith(
                scaffoldBackgroundColor: const Color(0xFFF4F5F7),
                primaryColor: const Color(0xFF10B981),
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF10B981),
                  secondary: Color(0xFF3B82F6),
                  surface: Colors.white,
                ),
              ),
              darkTheme: ThemeData.dark().copyWith(
                scaffoldBackgroundColor: const Color(0xFF0F172A),
                primaryColor: const Color(0xFF10B981),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF10B981),
                  secondary: Color(0xFF3B82F6),
                  surface: Color(0xFF1E293B),
                ),
              ),
              home: const SplashScreen(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    GlobalScanController.instance.activeTabIndex.value = _currentIndex;
    _pages = [
      HomePage(onNavigateToActivity: _navigateToActivity),
      ScanPage(onNavigateToActivity: _navigateToActivity),
      const ProtectionScreen(),
      const ActivityScreen(),
    ];
  }

  void _navigateToActivity() {
    setState(() {
      _currentIndex = 3;
      GlobalScanController.instance.activeTabIndex.value = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F5F7),
      appBar: const HeaderApp(
        title: 'Mangodefend',
      ),
      endDrawer: AppSidebar(
        onNavigateToQuarantine: () {
          setState(() {
            _currentIndex = 3;
            GlobalScanController.instance.activeTabIndex.value = 3;
          });
        },
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavbarBottom(
        currentIndex: _currentIndex,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: const Color(0xFF10B981),
        unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            GlobalScanController.instance.activeTabIndex.value = index;
          });
        },
      ),
    );
  }
}
