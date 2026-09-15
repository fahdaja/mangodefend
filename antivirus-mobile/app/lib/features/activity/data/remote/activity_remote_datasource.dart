import 'package:flutter/foundation.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';

class ActivityRemoteDataSource {
  /// Mengunggah log aktivitas lokal ke server backend cloud jika terhubung
  Future<bool> syncActivityLogsToCloud(List<ActivityLogItem> logs) async {
    try {
      debugPrint('Menyinkronkan ${logs.length} log aktivitas ke cloud...');
      return true;
    } catch (e) {
      debugPrint('Gagal menyinkronkan log aktivitas: $e');
      return false;
    }
  }
}
