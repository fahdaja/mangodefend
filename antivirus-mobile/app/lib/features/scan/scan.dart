import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/scan/presentation/pages/scan_screen.dart';

export 'domain/enums.dart';
export 'domain/scan_result.dart';
export 'data/remote/cloud_scan_service.dart';
export 'data/local/scan_history_store.dart';
export 'data/local/local_heuristic_engine.dart';
export 'presentation/pages/scan_screen.dart';

class ScanPage extends StatelessWidget {
  final VoidCallback? onNavigateToActivity;

  const ScanPage({
    super.key,
    this.onNavigateToActivity,
  });

  @override
  Widget build(BuildContext context) {
    return ScanScreen(onNavigateToActivity: onNavigateToActivity);
  }
}