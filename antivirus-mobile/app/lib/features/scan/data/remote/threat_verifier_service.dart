import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';

/// Enum Status Verifikasi Ancaman Malware (PostgreSQL Backend Database Engine)
enum ThreatVerificationStatus {
  verified,            // Terverifikasi 100% Malware di DB PostgreSQL Backend
  pendingVerification, // Hasil ML Baru (Perlu verifikasi lebih lanjut di DB)
  falsePositive,       // Ditolak / Dinyatakan berkas aman di DB
}

/// Model Laporan Verifikasi Ancaman DB Backend
class ThreatVerificationResult {
  final String sha256;
  final ThreatVerificationStatus status;
  final String verificationReason;

  const ThreatVerificationResult({
    required this.sha256,
    required this.status,
    required this.verificationReason,
  });

  bool get isSafeToExport => status == ThreatVerificationStatus.verified;
}

/// Layanan Verifikasi Ancaman yang Mengambil Data Langsung dari Database Backend PostgreSQL
class ThreatVerifierService {
  final http.Client client;
  final String baseUrl;

  ThreatVerifierService({
    http.Client? httpClient,
    String? baseUrl,
  })  : client = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Memverifikasi hash SHA-256 langsung ke Database PostgreSQL Backend Anda
  Future<ThreatVerificationResult> verifyAgainstBackendDb({
    required String sha256,
  }) async {
    final cleanHash = sha256.trim().toLowerCase();
    if (cleanHash.length != 64) {
      return ThreatVerificationResult(
        sha256: cleanHash,
        status: ThreatVerificationStatus.pendingVerification,
        verificationReason: 'Format SHA-256 tidak valid (wajib 64 karakter hex)',
      );
    }
    final uri = Uri.parse('$baseUrl/scans/lookup');

    try {
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sha256': cleanHash}),
      );
      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final found = jsonMap['found'] as bool? ?? false;
        final statusStr = (jsonMap['status'] as String? ?? jsonMap['verdict'] as String? ?? '').toUpperCase();

        if (found && (statusStr == 'MALICIOUS' || statusStr == 'VERIFIED')) {
          return ThreatVerificationResult(
            sha256: cleanHash,
            status: ThreatVerificationStatus.verified,
            verificationReason: 'Terverifikasi 100% Malware di Database Backend PostgreSQL (Status: $statusStr)',
          );
        } else if (found && (statusStr == 'FALSE_POSITIVE' || statusStr == 'WHITELIST')) {
          return ThreatVerificationResult(
            sha256: cleanHash,
            status: ThreatVerificationStatus.falsePositive,
            verificationReason: 'Ditolak / Ditandai False Positive di Database Backend PostgreSQL',
          );
        }
      }
    } catch (e) {
      debugPrint('ThreatVerifierService: Backend DB lookup error ($e).');
    }

    return ThreatVerificationResult(
      sha256: cleanHash,
      status: ThreatVerificationStatus.pendingVerification,
      verificationReason: 'Belum Terverifikasi di DB Backend PostgreSQL',
    );
  }

  /// Memicu Endpoint Backend POST /scans/signatures/verify-pending
  /// untuk memverifikasi seluruh signature yang berstatus PENDING_VERIFICATION
  Future<Map<String, dynamic>?> triggerVerifyPendingSignatures() async {
    final uri = Uri.parse('$baseUrl/scans/signatures/verify-pending');
    try {
      final response = await client.post(uri);
      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('Berhasil memicu verifikasi signature pending di Backend: $jsonMap');
        return jsonMap;
      }
    } catch (e) {
      debugPrint('ThreatVerifierService: Error trigger verify-pending endpoint ($e)');
    }
    return null;
  }

  /// Melaporkan ke Backend FastAPI bahwa file ini di-whitelist (FALSE_POSITIVE) oleh pengguna
  Future<bool> reportWhitelistToBackend(String sha256) async {
    final cleanHash = sha256.trim().toLowerCase();
    if (cleanHash.isEmpty) return false;
    final uri = Uri.parse('$baseUrl/scans/signatures/whitelist/$cleanHash');

    try {
      final response = await client.post(uri);
      if (response.statusCode == 200) {
        debugPrint('Berhasil mendaftarkan Whitelist/FALSE_POSITIVE $cleanHash ke DB PostgreSQL Backend!');
        return true;
      }
    } catch (e) {
      debugPrint('ThreatVerifierService: Error reporting Whitelist to Backend ($e)');
    }
    return false;
  }
}
