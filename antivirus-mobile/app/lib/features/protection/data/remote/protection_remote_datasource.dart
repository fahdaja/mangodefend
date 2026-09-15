import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';

/// Data source remote untuk mengambil kebijakan & aturan proteksi terbaru dari Cloud Server Backend
class ProtectionRemoteDataSource {
  final http.Client client;

  ProtectionRemoteDataSource({http.Client? httpClient}) : client = httpClient ?? http.Client();

  /// Mengambil daftar kebijakan keamanan real-time dari Cloud Backend
  Future<bool> fetchLatestSecurityPolicies({String? baseUrl}) async {
    final serverUrl = baseUrl ?? ApiConfig.baseUrl;
    final uri = Uri.parse('$serverUrl/protection/policies');

    try {
      final response = await client.get(uri);
      if (response.statusCode == 200) {
        debugPrint('Berhasil menyinkronkan kebijakan proteksi dari Cloud Server.');
        return true;
      }
    } catch (e) {
      debugPrint('Gagal menyinkronkan kebijakan proteksi dari Cloud: $e');
    }
    return false;
  }
}
