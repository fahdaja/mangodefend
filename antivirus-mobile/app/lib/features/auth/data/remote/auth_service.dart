import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/features/auth/domain/auth_models.dart';

class AuthService {
  final String baseUrl;
  final http.Client _client;

  AuthService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Registrasi akun baru menggunakan Nama Lengkap, Email & Password
  Future<AuthResponse> registerWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
    String? osVersion,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final payload = RegisterRequest(
      fullName: fullName,
      email: email,
      password: password,
      deviceId: deviceId,
      deviceName: deviceName,
      osVersion: osVersion,
    ).toJson();

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthResponse(
          success: true,
          message: jsonMap['message'] as String? ?? 'Registrasi berhasil',
          user: UserModel(
            id: jsonMap['id'] as int? ?? 0,
            username: jsonMap['full_name'] as String? ?? jsonMap['username'] as String? ?? fullName,
            email: email,
          ),
        );
      } else {
        final errorMsg = _extractErrorMessage(response.body);
        throw Exception(errorMsg ?? 'Gagal mendaftar (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException')) {
        rethrow;
      }
      throw Exception('Tidak dapat terhubung ke server auth ($baseUrl). Pastikan server backend sudah aktif.');
    }
  }

  /// Login menggunakan Email & Password
  Future<AuthResponse> loginWithEmailPassword({
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
    String? osVersion,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final payload = LoginRequest(
      email: email,
      password: password,
      deviceId: deviceId,
      deviceName: deviceName,
      osVersion: osVersion,
    ).toJson();

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthResponse.fromJson(jsonMap);
      } else {
        final errorMsg = _extractErrorMessage(response.body);
        throw Exception(errorMsg ?? 'Gagal login (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException')) {
        rethrow;
      }
      throw Exception('Tidak dapat terhubung ke server auth ($baseUrl). Pastikan server backend sudah aktif.');
    }
  }

  /// Login menggunakan Google OAuth
  Future<AuthResponse> loginWithGoogle({
    required String idToken,
    String? email,
    String? fullName,
    String? deviceId,
    String? deviceName,
    String? osVersion,
    bool isRegistration = false,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/google');
    final payload = GoogleOAuthRequest(
      idToken: idToken,
      email: email,
      fullName: fullName,
      deviceId: deviceId,
      deviceName: deviceName,
      osVersion: osVersion,
      isRegistration: isRegistration,
    ).toJson();

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthResponse.fromJson(jsonMap);
      } else {
        final errorMsg = _extractErrorMessage(response.body);
        throw Exception(errorMsg ?? 'Gagal login via Google (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException')) {
        rethrow;
      }
      throw Exception('Tidak dapat terhubung ke server auth ($baseUrl). Pastikan server backend sudah aktif.');
    }
  }

  String? _extractErrorMessage(String responseBody) {
    try {
      final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
      return jsonMap['detail'] as String? ?? jsonMap['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}
