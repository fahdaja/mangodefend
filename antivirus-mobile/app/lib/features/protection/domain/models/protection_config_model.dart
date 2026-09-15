class ProtectionConfigModel {
  final bool realTimeProtection;
  final bool webProtection;
  final bool scheduledScan;
  final String lastHealthCheckTime;

  const ProtectionConfigModel({
    required this.realTimeProtection,
    required this.webProtection,
    required this.scheduledScan,
    required this.lastHealthCheckTime,
  });

  Map<String, dynamic> toJson() => {
        'realTimeProtection': realTimeProtection,
        'webProtection': webProtection,
        'scheduledScan': scheduledScan,
        'lastHealthCheckTime': lastHealthCheckTime,
      };

  factory ProtectionConfigModel.fromJson(Map<String, dynamic> json) {
    return ProtectionConfigModel(
      realTimeProtection: json['realTimeProtection'] as bool? ?? true,
      webProtection: json['webProtection'] as bool? ?? false,
      scheduledScan: json['scheduledScan'] as bool? ?? false,
      lastHealthCheckTime: json['lastHealthCheckTime'] as String? ?? '15 menit lalu',
    );
  }
}
