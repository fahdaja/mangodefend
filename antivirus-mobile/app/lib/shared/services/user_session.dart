import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/auth/domain/auth_models.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';

class UserSession {
  static final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);
  static final ValueNotifier<bool> isProUserNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String> activePlanNameNotifier = ValueNotifier<String>('Free');
  static final ValueNotifier<int> maxDailyScansNotifier = ValueNotifier<int>(30);

  static String? accessToken;
  static String? refreshToken;

  static bool get isProUser => isProUserNotifier.value;
  static set isProUser(bool val) => isProUserNotifier.value = val;

  static String get activePlanName => activePlanNameNotifier.value;
  static set activePlanName(String val) => activePlanNameNotifier.value = val;

  static int get maxDailyScans => maxDailyScansNotifier.value;
  static set maxDailyScans(int val) => maxDailyScansNotifier.value = val;

  static bool get isLoggedIn => currentUserNotifier.value != null;
  static UserModel? get currentUser => currentUserNotifier.value;

  static void login(UserModel user, {String? token, String? refreshTokenVal}) {
    accessToken = token;
    refreshToken = refreshTokenVal;
    currentUserNotifier.value = user;
  }

  static void logout() {
    accessToken = null;
    refreshToken = null;
    isProUserNotifier.value = false;
    activePlanNameNotifier.value = 'Free';
    maxDailyScansNotifier.value = 30;
    currentUserNotifier.value = null;
    // Sinkronkan kembali penggunaan kuota guest perangkat dari Cloud Server
    GuestQuotaService.syncQuotaWithServer();
  }
}
