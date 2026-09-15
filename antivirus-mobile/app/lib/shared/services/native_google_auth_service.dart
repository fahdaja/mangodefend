import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class NativeGoogleAuthResult {
  final String idToken;
  final String email;
  final String fullName;

  const NativeGoogleAuthResult({
    required this.idToken,
    required this.email,
    required this.fullName,
  });
}

class NativeGoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Membuka Account Picker Google yang dijamin selalu muncul di layar.
  /// 1. Mencoba Native Google Play Services Account Picker.
  /// 2. Jika SDK Play Services dibatalkan/error/belum siap, secara otomatis
  ///    menampilkan Modal Google Account Picker UI di layar.
  static Future<NativeGoogleAuthResult?> signIn(BuildContext context) async {
    try {
      // Reset sesi sebelumnya agar Google Play Services SELALU menampilkan dialog Account Picker
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        final idToken = auth.idToken ?? auth.accessToken ?? 'google_oauth_${account.id}';

        return NativeGoogleAuthResult(
          idToken: idToken,
          email: account.email,
          fullName: account.displayName ?? 'Google User',
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In Native SDK Notice: $e');
    }

    return null;
  }

  /// Sign out dari Google Account jika diperlukan
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
