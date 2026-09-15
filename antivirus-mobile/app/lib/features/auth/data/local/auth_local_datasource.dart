import 'package:flutter/foundation.dart';
import 'package:antivirus_mobile/features/auth/domain/auth_models.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';

class AuthLocalDataSource {
  /// Mendapatkan user yang sedang aktif secara lokal
  UserModel? get currentUser => UserSession.currentUser;

  /// Memeriksa status login pengguna
  bool get isLoggedIn => UserSession.isLoggedIn;

  /// Menyimpan sesi login user secara lokal
  void saveSession(UserModel user) {
    UserSession.login(user);
    debugPrint('Sesi pengguna ${user.email} disimpan secara lokal.');
  }

  /// Menghapus sesi login user secara lokal
  void clearSession() {
    UserSession.logout();
    debugPrint('Sesi pengguna lokal dihapus.');
  }
}
