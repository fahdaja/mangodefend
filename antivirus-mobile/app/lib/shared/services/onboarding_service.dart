import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class OnboardingService {
  static bool _hasCompletedOnboarding = false;

  static Future<bool> hasCompletedOnboarding() async {
    try {
      if (kIsWeb) return _hasCompletedOnboarding;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/onboarding_completed.flag');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> markOnboardingCompleted() async {
    _hasCompletedOnboarding = true;
    try {
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/onboarding_completed.flag');
        await file.writeAsString('COMPLETED');
      }
    } catch (e) {
      debugPrint('Error writing onboarding flag: $e');
    }
  }
}
