import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';

class SubscriptionPlan {
  final int id;
  final String name;
  final double price;
  final int maxDevices;
  final int maxDailyScans;
  final bool canUploadScans;
  final bool canUploadFolder;
  final bool canFullSystemScan;
  final bool canRealtimeProtection;
  final bool canWebProtection;
  final bool canScheduledScan;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.maxDevices,
    required this.maxDailyScans,
    required this.canUploadScans,
    required this.canUploadFolder,
    required this.canFullSystemScan,
    required this.canRealtimeProtection,
    required this.canWebProtection,
    required this.canScheduledScan,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int? ?? 0,
      name: json['plan_name'] as String? ?? json['name'] as String? ?? 'Free',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      maxDevices: json['max_devices'] as int? ?? 1,
      maxDailyScans: json['max_daily_scans'] as int? ?? json['daily_scan_limit'] as int? ?? 30,
      canUploadScans: json['can_upload_scans'] as bool? ?? true,
      canUploadFolder: json['can_upload_folder'] as bool? ?? true,
      canFullSystemScan: json['can_full_system_scan'] as bool? ?? true,
      canRealtimeProtection: json['can_realtime_protection'] as bool? ?? json['realtime_guard_enabled'] as bool? ?? false,
      canWebProtection: json['can_web_protection'] as bool? ?? false,
      canScheduledScan: json['can_scheduled_scan'] as bool? ?? false,
    );
  }

  String get formattedPrice {
    if (price == 0.0) return 'Rp 0 (Gratis)';
    return 'Rp ${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String get scanLimitLabel {
    if (maxDailyScans == -1) return 'Unlimited Scans / hari';
    return '$maxDailyScans Scan / hari';
  }
}

class UserSubscriptionStatus {
  final int id;
  final int userId;
  final int planId;
  final String status;
  final String? startDate;
  final String? endDate;
  final SubscriptionPlan? plan;

  const UserSubscriptionStatus({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    this.startDate,
    this.endDate,
    this.plan,
  });

  factory UserSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map<String, dynamic>?;
    return UserSubscriptionStatus(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      planId: json['plan_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'ACTIVE',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      plan: planJson != null ? SubscriptionPlan.fromJson(planJson) : null,
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  String get planName => plan?.name ?? 'Free';
  int get maxDailyScans => plan?.maxDailyScans ?? 30;
}

class SubscriptionService {
  final String baseUrl;
  final http.Client _client;

  SubscriptionService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Mengambil daftar paket langganan dari Backend
  Future<List<SubscriptionPlan>> getPlans() async {
    final uri = Uri.parse('$baseUrl/subscriptions/plans');
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((j) => SubscriptionPlan.fromJson(j as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error getPlans: $e');
    }
    return [];
  }

  /// Mengambil status langganan pengguna saat ini
  Future<UserSubscriptionStatus?> getMySubscription() async {
    final token = UserSession.accessToken;
    if (token == null) return null;

    final uri = Uri.parse('$baseUrl/subscriptions/my-subscription');
    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final sub = UserSubscriptionStatus.fromJson(jsonMap);
        if (sub.isActive) {
          final planName = sub.planName.toLowerCase();
          final isPro = planName.contains('pro') ||
              planName.contains('premium') ||
              sub.planId > 1 ||
              (sub.plan?.canRealtimeProtection ?? false);
          UserSession.isProUser = isPro;
          UserSession.activePlanName = sub.planName;
          UserSession.maxDailyScans = sub.maxDailyScans;
        } else {
          UserSession.isProUser = false;
          UserSession.activePlanName = 'Free';
          UserSession.maxDailyScans = 30;
        }
        return sub;
      }
    } catch (e) {
      debugPrint('Error getMySubscription: $e');
    }
    return null;
  }

  /// Melakukan checkout paket langganan
  Future<Map<String, dynamic>?> checkout({
    required int planId,
    String paymentMethod = 'qris',
  }) async {
    final token = UserSession.accessToken;
    final uri = Uri.parse('$baseUrl/subscriptions/checkout');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'plan_id': planId,
          'payment_method': paymentMethod,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error checkout: $e');
    }
    return null;
  }

  /// Mengecek status transaksi pembayaran ke Backend Midtrans Integration
  Future<Map<String, dynamic>?> checkPaymentStatus(String transactionId) async {
    final token = UserSession.accessToken;
    final uri = Uri.parse('$baseUrl/subscriptions/payments/$transactionId/status');
    try {
      final response = await _client.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error checkPaymentStatus: $e');
    }
    return null;
  }

  /// Mensimulasikan pembayaran berhasil (khusus mode Sandbox / Dev Testing)
  Future<bool> simulatePaymentSuccess(String transactionId) async {
    final uri = Uri.parse('$baseUrl/subscriptions/payments/webhook');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'order_id': transactionId,
          'transaction_status': 'settlement',
          'status_code': '200',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error simulatePaymentSuccess: $e');
    }
    return false;
  }

  /// Membatalkan langganan aktif pengguna di Backend
  Future<bool> cancelSubscription() async {
    final token = UserSession.accessToken;
    final uri = Uri.parse('$baseUrl/subscriptions/cancel');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        UserSession.isProUser = false;
        UserSession.activePlanName = 'Starter Free';
        return true;
      }
    } catch (e) {
      debugPrint('Error cancelSubscription: $e');
    }
    return false;
  }
}
