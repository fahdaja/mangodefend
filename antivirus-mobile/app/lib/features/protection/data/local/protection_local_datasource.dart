import 'package:flutter/foundation.dart';
import 'package:antivirus_mobile/features/protection/domain/models/protection_config_model.dart';

/// Data source lokal untuk menyimpan & mengelola status proteksi perangkat di disk/memori HP
class ProtectionLocalDataSource {
  static final ValueNotifier<ProtectionConfigModel> configNotifier =
      ValueNotifier<ProtectionConfigModel>(
    const ProtectionConfigModel(
      realTimeProtection: false,
      webProtection: false,
      scheduledScan: false,
      lastHealthCheckTime: '15 menit lalu',
    ),
  );

  static ProtectionConfigModel get currentConfig => configNotifier.value;

  static void updateRealTimeProtection(bool enabled) {
    configNotifier.value = ProtectionConfigModel(
      realTimeProtection: enabled,
      webProtection: currentConfig.webProtection,
      scheduledScan: currentConfig.scheduledScan,
      lastHealthCheckTime: currentConfig.lastHealthCheckTime,
    );
  }

  static void updateScheduledScan(bool enabled) {
    configNotifier.value = ProtectionConfigModel(
      realTimeProtection: currentConfig.realTimeProtection,
      webProtection: currentConfig.webProtection,
      scheduledScan: enabled,
      lastHealthCheckTime: currentConfig.lastHealthCheckTime,
    );
  }
}
