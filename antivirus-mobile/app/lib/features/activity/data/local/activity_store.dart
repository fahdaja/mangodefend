import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';

class ActivityStore {
  static final ValueNotifier<List<ActivityLogItem>> logsNotifier =
      ValueNotifier<List<ActivityLogItem>>([]);

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await loadFromDisk();
  }

  static Future<File?> _getLogFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/activity_logs_store.json');
    } catch (_) {
      return null;
    }
  }

  static Future<void> loadFromDisk() async {
    try {
      final file = await _getLogFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = jsonDecode(content);
          final loadedLogs = jsonList
              .map((j) => ActivityLogItem.fromJson(j as Map<String, dynamic>))
              .toList();
          logsNotifier.value = loadedLogs;
        }
      }
    } catch (e) {
      debugPrint('Gagal membaca ActivityStore dari disk: $e');
    }
  }

  static Future<void> saveToDisk() async {
    try {
      final file = await _getLogFile();
      if (file != null) {
        final jsonList = logsNotifier.value.map((item) => item.toJson()).toList();
        await file.writeAsString(jsonEncode(jsonList));
      }
    } catch (e) {
      debugPrint('Gagal menyimpan ActivityStore ke disk: $e');
    }
  }

  static void addLog(ActivityLogItem item) {
    final currentLogs = List<ActivityLogItem>.from(logsNotifier.value);

    // Deduplikasi Cerdas: Cek apakah sudah ada log sebelumnya untuk daftar file yang sama persis
    if (item.files.isNotEmpty) {
      final itemPaths = item.files.map((f) => f.filePath).where((p) => p.isNotEmpty).toSet();

      if (itemPaths.isNotEmpty) {
        final existingIndex = currentLogs.indexWhere((existing) {
          if (existing.files.length != item.files.length) return false;
          final existingPaths = existing.files.map((f) => f.filePath).where((p) => p.isNotEmpty).toSet();
          return existingPaths.isNotEmpty &&
              existingPaths.length == itemPaths.length &&
              existingPaths.containsAll(itemPaths);
        });

        if (existingIndex != -1) {
          // Hapus entri log lama agar diperbarui ke posisi paling atas dengan timestamp terbaru
          currentLogs.removeAt(existingIndex);
        }
      }
    }

    logsNotifier.value = [item, ...currentLogs];
    saveToDisk();
  }

  static void removeFileFromLog(String logId, String fileName) {
    removeMultipleFilesFromLog(logId, [fileName]);
  }

  static void removeMultipleFilesFromLog(String logId, List<String> fileNames) {
    final currentLogs = List<ActivityLogItem>.from(logsNotifier.value);
    final index = currentLogs.indexWhere((item) => item.id == logId);
    if (index != -1) {
      final oldItem = currentLogs[index];
      final targetSet = Set<String>.from(fileNames);
      final updatedFiles = oldItem.files.where((f) => !targetSet.contains(f.fileName)).toList();

      if (updatedFiles.isEmpty) {
        currentLogs.removeAt(index);
      } else {
        final remainingThreats = updatedFiles.where((f) => !f.isSafe && !f.isFalsePositive).length;
        final subtitleText = remainingThreats > 0
            ? '${updatedFiles.length} file dipindai • $remainingThreats ancaman terdeteksi'
            : '${updatedFiles.length} file dipindai • Bebas ancaman';

        currentLogs[index] = ActivityLogItem(
          id: oldItem.id,
          title: oldItem.title,
          subtitle: subtitleText,
          time: oldItem.time,
          category: remainingThreats > 0 ? oldItem.category : 'Pemindaian',
          badgeText: remainingThreats > 0 ? '$remainingThreats Ancaman' : '${updatedFiles.length} File',
          isQuarantined: oldItem.isQuarantined,
          files: updatedFiles,
        );
      }
      logsNotifier.value = currentLogs;
      saveToDisk();
    }
  }

  static void removeLogCompletely(String logId) {
    final currentLogs = List<ActivityLogItem>.from(logsNotifier.value);
    currentLogs.removeWhere((item) => item.id == logId);
    logsNotifier.value = currentLogs;
    saveToDisk();
  }

  static void clear() {
    logsNotifier.value = [];
    saveToDisk();
  }
}
