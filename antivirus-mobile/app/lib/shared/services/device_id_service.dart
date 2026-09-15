import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceIdService {
  static String? _cachedDeviceId;

  /// Mengambil ID Unik Motherboard / Perangkat Keras secara otomatis
  static Future<String> getMotherboardDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    if (kIsWeb) {
      _cachedDeviceId = 'device-web-client-01';
      return _cachedDeviceId!;
    }

    try {
      if (!kIsWeb && Platform.isAndroid) {
        const platform = MethodChannel('com.example.antivirus_mobile/quarantine');
        final String? androidHardwareId = await platform.invokeMethod<String>('getHardwareDeviceId');
        if (androidHardwareId != null && androidHardwareId.isNotEmpty) {
          _cachedDeviceId = androidHardwareId;
          debugPrint('🔑 [DEVICE ID] Unique Motherboard Hardware ID: $androidHardwareId');
          return androidHardwareId;
        }
      }

      if (!kIsWeb && Platform.isLinux) {
        final linuxDeviceId = await _getLinuxMotherboardId();
        if (linuxDeviceId != null && linuxDeviceId.isNotEmpty) {
          _cachedDeviceId = linuxDeviceId;
          return linuxDeviceId;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DEVICE ID] Native MethodChannel Error: $e');
    }

    try {
      final os = Platform.operatingSystem;
      final host = Platform.localHostname.hashCode.abs();
      _cachedDeviceId = 'device-hw-$os-$host';
    } catch (_) {
      _cachedDeviceId = 'device-hw-fallback-01';
    }

    return _cachedDeviceId!;
  }

  /// Ekstraksi motherboard serial / UUID pada sistem Linux
  static Future<String?> _getLinuxMotherboardId() async {
    final paths = [
      '/sys/class/dmi/id/product_uuid',
      '/sys/class/dmi/id/board_serial',
      '/etc/machine-id',
      '/var/lib/dbus/machine-id',
    ];

    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = (await file.readAsString()).trim();
          if (content.isNotEmpty && content != 'None' && content != 'Default string') {
            final cleanStr = content.replaceAll('-', '').toLowerCase();
            final shortHash = (cleanStr.length >= 32) ? cleanStr.substring(0, 32) : cleanStr;
            return 'device-hw-linux-$shortHash';
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Mengambil Nama Model / Hostname Perangkat Fisik (Contoh: "Infinix X6833", "Samsung Galaxy S24", "mr-pacman")
  static Future<String> getDeviceModelName() async {
    if (kIsWeb) {
      return 'Web Browser Client';
    }

    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.example.antivirus_mobile/quarantine');
        final String? modelName = await platform.invokeMethod<String>('getDeviceModelName');
        if (modelName != null && modelName.trim().isNotEmpty) {
          return modelName.trim();
        }
      }
    } on MissingPluginException {
      debugPrint('ℹ️ [DEVICE ID] Native Kotlin getDeviceModelName method not reloaded yet. Perform full app restart to load new Kotlin binary code.');
    } catch (e) {
      debugPrint('⚠️ [DEVICE ID] Error fetching device model name: $e');
    }

    try {
      final name = Platform.localHostname;
      if (name.isNotEmpty && name != 'localhost' && name != 'android') {
        return name;
      }
    } catch (_) {}

    return Platform.isAndroid ? 'Android Smartphone' : 'Local Workstation';
  }

  /// Mengambil Versi OS Perangkat Fisik (Contoh: "Android 14 (API 34)", "Linux 6.8.0")
  static Future<String> getDeviceOsVersion() async {
    if (kIsWeb) {
      return 'Web Browser';
    }

    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.example.antivirus_mobile/quarantine');
        final String? osVersion = await platform.invokeMethod<String>('getDeviceOsVersion');
        if (osVersion != null && osVersion.trim().isNotEmpty) {
          return osVersion.trim();
        }
      }
    } catch (_) {}

    try {
      final osName = Platform.operatingSystem;
      if (osName.isNotEmpty) {
        return '${osName[0].toUpperCase()}${osName.substring(1)}';
      }
    } catch (_) {}

    return Platform.isAndroid ? 'Android' : 'Linux/Desktop';
  }
}
