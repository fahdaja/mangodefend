import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';

class LocalQuarantineService {
  static const _channel = MethodChannel('com.example.antivirus_mobile/quarantine');

  /// Jalankan Foreground Service Proteksi Real-Time Latar Belakang Native (Kotlin)
  static Future<bool> startRealtimeGuardForegroundService({bool addLog = false}) async {
    if (!Platform.isAndroid) return false;
    try {
      debugPrint('🟢 [REAL-TIME GUARD] Memulai Service Proteksi Real-Time...');
      final bool result = await _channel.invokeMethod('startRealtimeGuardService');
      if (result && addLog) {
        debugPrint('🟢 [REAL-TIME GUARD] Service berhasil dinyalakan & mengawasi folder unduhan.');
        final now = DateTime.now();
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        ActivityStore.addLog(
          ActivityLogItem(
            id: now.millisecondsSinceEpoch.toString(),
            title: 'Proteksi Real-Time Diaktifkan',
            subtitle: 'Service Proteksi Real-Time otomatis aktif dan mengawasi folder unduhan & aplikasi.',
            time: timeStr,
            category: 'Perlindungan',
            badgeText: 'Aktif',
            files: const [],
          ),
        );
      }
      return result;
    } catch (e) {
      debugPrint('❌ [REAL-TIME GUARD] Error starting RealtimeGuardForegroundService: $e');
      return false;
    }
  }

  /// Hentikan Foreground Service Proteksi Real-Time Latar Belakang Native (Kotlin)
  static Future<bool> stopRealtimeGuardForegroundService({bool addLog = false}) async {
    if (!Platform.isAndroid) return false;
    try {
      debugPrint('🛑 [REAL-TIME GUARD] Menghentikan Service Proteksi Real-Time...');
      final bool result = await _channel.invokeMethod('stopRealtimeGuardService');
      if (result && addLog) {
        debugPrint('🛑 [REAL-TIME GUARD] Service Proteksi Real-Time dimatikan sepenuhnya oleh pengguna.');
        final now = DateTime.now();
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        ActivityStore.addLog(
          ActivityLogItem(
            id: now.millisecondsSinceEpoch.toString(),
            title: 'Proteksi Real-Time Dinonaktifkan',
            subtitle: 'Service Proteksi Real-Time otomatis dan pengawasan folder dimatikan oleh pengguna.',
            time: timeStr,
            category: 'Perlindungan',
            badgeText: 'Nonaktif',
            files: const [],
          ),
        );
      }
      return result;
    } catch (e) {
      debugPrint('❌ [REAL-TIME GUARD] Error stopping RealtimeGuardForegroundService: $e');
      return false;
    }
  }

  /// Hapus file fisik via Native Kotlin (ContentResolver & MediaStore)
  static Future<bool> deleteNativeFilePhysically(String filePath, String fileName) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool result = await _channel.invokeMethod('deleteFilePhysically', {
        'filePath': filePath,
        'fileName': fileName,
      });
      return result;
    } catch (e) {
      debugPrint('Native MethodChannel delete error: $e');
      return false;
    }
  }

  /// Pulihkan file fisik via Native Kotlin (MediaStore Insert & Direct File Copy)
  static Future<bool> restoreNativeFilePhysically(String quarantinedPath, String fileName, {String? originalPath}) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool result = await _channel.invokeMethod('restoreFilePhysically', {
        'quarantinedPath': quarantinedPath,
        'fileName': fileName,
        'originalPath': originalPath,
      });
      return result;
    } catch (e) {
      debugPrint('Native MethodChannel restore error: $e');
      return false;
    }
  }

  /// Picu scanner MediaStore Android agar Galeri langsung menampilkan file yang baru dipulihkan
  static Future<void> scanMediaFile(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanMediaFile', {'filePath': filePath});
    } catch (e) {
      debugPrint('Error triggering media scanner: $e');
    }
  }

  /// Check jika MANAGE_EXTERNAL_STORAGE aktif secara native
  static Future<bool> checkNativeManageStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool isGranted = await _channel.invokeMethod('checkManageStoragePermission');
      return isGranted;
    } catch (_) {
      return true;
    }
  }

  /// Request MANAGE_EXTERNAL_STORAGE secara native
  static Future<bool> requestNativeManageStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool result = await _channel.invokeMethod('requestManageStoragePermission');
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Mendapatkan lokasi folder Vault Karantina Terisolasi
  static Future<Directory> getQuarantineVaultDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }

    final vaultDir = Directory('${baseDir.path}/quarantine_vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Lacak file terisolasi di Vault berdasarkan nama filenya
  static Future<String?> findQuarantinedVaultPath(String fileName) async {
    try {
      final vaultDir = await getQuarantineVaultDirectory();
      if (await vaultDir.exists()) {
        final entities = vaultDir.listSync();
        for (final entity in entities) {
          if (entity is File && (entity.path.endsWith('$fileName.vir') || entity.path.endsWith(fileName))) {
            return entity.path;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Mencari lokasi file asli publik jika file yang diterima berasal dari cache temporary FilePicker
  /// Mencari file di dalam direktori beserta sub-foldernya secara rekursif
  static File? _findFileInDirectory(Directory dir, String targetFileName) {
    try {
      if (!dir.existsSync()) return null;
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('/$targetFileName')) {
          return entity;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Mendapatkan lokasi file asli publik via Native Android ContentResolver / MediaStore (MANAGE_EXTERNAL_STORAGE)
  static Future<File> resolveRealOriginalFile(File sourceFile) async {
    if (!sourceFile.path.contains('/cache/') && !sourceFile.path.contains('/data/user/')) {
      return sourceFile;
    }

    if (Platform.isAndroid) {
      try {
        final String? nativePath = await _channel.invokeMethod('resolveRealPath', {
          'filePath': sourceFile.path,
        });
        if (nativePath != null && nativePath != sourceFile.path && await File(nativePath).exists()) {
          debugPrint('Ditemukan file asli fisik publik via Native MediaStore ContentResolver: $nativePath');
          return File(nativePath);
        }
      } catch (e) {
        debugPrint('Error invoking native resolveRealPath: $e');
      }
    }

    final fileName = sourceFile.path.split('/').last;
    final candidatePaths = [
      '/storage/emulated/0/Pictures/Screenshot/$fileName',
      '/storage/emulated/0/Pictures/Screenshots/$fileName',
      '/storage/emulated/0/DCIM/Screenshot/$fileName',
      '/storage/emulated/0/DCIM/Screenshots/$fileName',
      '/storage/emulated/0/Download/$fileName',
      '/storage/emulated/0/Pictures/$fileName',
      '/storage/emulated/0/DCIM/Camera/$fileName',
      '/storage/emulated/0/DCIM/$fileName',
      '/storage/emulated/0/Documents/$fileName',
    ];

    for (final path in candidatePaths) {
      final realFile = File(path);
      if (await realFile.exists()) {
        debugPrint('Ditemukan file asli fisik publik di kandidat langsung: $path');
        return realFile;
      }
    }

    return sourceFile;
  }

  /// Menentukan path publik asli file jika path yang tercatat berasal dari cache temporary FilePicker
  static String resolvePublicOriginalPath(String path) {
    if (!path.contains('/cache/') && !path.contains('/data/user/')) return path;
    final fileName = path.split('/').last;

    final rootDirs = [
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Documents'),
      Directory('/storage/emulated/0/Pictures'),
      Directory('/storage/emulated/0/DCIM'),
    ];

    for (final dir in rootDirs) {
      final found = _findFileInDirectory(dir, fileName);
      if (found != null) {
        return found.path;
      }
    }

    if (fileName.toLowerCase().contains('screenshot')) {
      if (Directory('/storage/emulated/0/Pictures/Screenshot').existsSync()) {
        return '/storage/emulated/0/Pictures/Screenshot/$fileName';
      }
      if (Directory('/storage/emulated/0/Pictures/Screenshots').existsSync()) {
        return '/storage/emulated/0/Pictures/Screenshots/$fileName';
      }
      return '/storage/emulated/0/Pictures/Screenshot/$fileName';
    }

    if (fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.gif') ||
        fileName.toLowerCase().endsWith('.webp')) {
      return '/storage/emulated/0/Pictures/$fileName';
    }
    return '/storage/emulated/0/Download/$fileName';
  }

  /// Pindahkan file fisik ke Karantina via Native Kotlin (Mengatasi errno = 18 Cross-device link & errno = 13 Permission denied)
  static Future<bool> quarantineNativeFilePhysically(String sourcePath, String targetPath, {String? originalPath}) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool result = await _channel.invokeMethod('quarantineFilePhysically', {
        'sourcePath': sourcePath,
        'targetPath': targetPath,
        'originalPath': originalPath,
      });
      return result;
    } catch (e) {
      debugPrint('Native MethodChannel quarantine error: $e');
      return false;
    }
  }

  /// Pindahkan & netralkan file fisik secara otomatis ke folder Vault Karantina terisolasi
  static Future<String?> quarantineFile(File inputSourceFile) async {
    try {
      final sourceFile = await resolveRealOriginalFile(inputSourceFile);
      if (!await sourceFile.exists() && !await inputSourceFile.exists()) return null;

      // Jika file asal berukuran 0 byte, hapus file 0-byte dari disk tanpa memasukkannya ke karantina
      if ((await sourceFile.exists() && await sourceFile.length() == 0) || (await inputSourceFile.exists() && await inputSourceFile.length() == 0)) {
        try { if (await sourceFile.exists()) await sourceFile.delete(); } catch (_) {}
        try { if (await inputSourceFile.exists()) await inputSourceFile.delete(); } catch (_) {}
        await deleteNativeFilePhysically(sourceFile.path, sourceFile.path.split('/').last);
        await deleteNativeFilePhysically(inputSourceFile.path, inputSourceFile.path.split('/').last);
        await scanMediaFile(sourceFile.path);
        await scanMediaFile(inputSourceFile.path);
        return null;
      }

      final vaultDir = await getQuarantineVaultDirectory();
      final fileName = sourceFile.path.split('/').last;
      final targetPath = '${vaultDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName.vir';

      // Utamakan file yang dapat dibaca tanpa EACCES (Gunakan inputSourceFile cache jika sourceFile publik dibatasi Scoped Storage OS)
      File readableFile = inputSourceFile;
      if (await sourceFile.exists()) {
        try {
          final testStream = sourceFile.openRead(0, 1);
          await testStream.drain();
          readableFile = sourceFile;
        } catch (_) {
          debugPrint('Berkas publik ${sourceFile.path} dibatasi EACCES OS, menggunakan cache privat ${inputSourceFile.path} untuk karantina.');
        }
      }

      // 1. Coba Pindahkan Fisik secara ATOMIC MOVE (rename) terlebih dahulu
      try {
        final renamedFile = await readableFile.rename(targetPath);
        debugPrint('File fisik $fileName berhasil di-RENAME secara atomic ke Karantina: ${renamedFile.path}');

        await deleteNativeFilePhysically(sourceFile.path, fileName);
        await deleteNativeFilePhysically(inputSourceFile.path, fileName);
        await scanMediaFile(sourceFile.path);
        await scanMediaFile(inputSourceFile.path);

        if (inputSourceFile.path != sourceFile.path && await inputSourceFile.exists()) {
          try {
            await inputSourceFile.delete();
            await scanMediaFile(inputSourceFile.path);
          } catch (_) {}
        }
        return renamedFile.path;
      } catch (renameErr) {
        debugPrint('Atomic rename tidak dapat dilakukan lintas mount, melangkah ke Native Kotlin quarantine: $renameErr');
      }

      // 2. Coba Pindahkan via Native Kotlin File Copy & Scoped Storage Resolver
      final nativeSuccess = await quarantineNativeFilePhysically(
        readableFile.path,
        targetPath,
        originalPath: sourceFile.path,
      );
      if (nativeSuccess && await File(targetPath).exists() && await File(targetPath).length() > 0) {
        if (await sourceFile.exists()) {
          try { await sourceFile.delete(); } catch (_) {}
        }
        await deleteNativeFilePhysically(sourceFile.path, fileName);
        await deleteNativeFilePhysically(inputSourceFile.path, fileName);
        await scanMediaFile(sourceFile.path);
        await scanMediaFile(inputSourceFile.path);

        if (inputSourceFile.path != sourceFile.path && await inputSourceFile.exists()) {
          try {
            await inputSourceFile.delete();
            await scanMediaFile(inputSourceFile.path);
          } catch (_) {}
        }
        debugPrint('File fisik $fileName berhasil dipindahkan ke Karantina via Native Kotlin: $targetPath');
        return targetPath;
      }

      // 3. Fallback: Copy via Byte Stream jika direct Dart file copy dibatasi OS
      File quarantinedFile;
      try {
        quarantinedFile = await readableFile.copy(targetPath);
      } catch (copyErr) {
        debugPrint('Direct Dart copy failed ($copyErr), falling back to Byte Stream write...');
        final bytes = await readableFile.readAsBytes();
        final qFile = File(targetPath);
        await qFile.writeAsBytes(bytes);
        quarantinedFile = qFile;
      }

      // 4. Hapus file fisik asal secara langsung tanpa menyisakan file 0-byte
      try {
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        }
      } catch (deleteErr) {
        debugPrint('Hapus file asal dibatasi OS: $deleteErr');
      }

      await deleteNativeFilePhysically(sourceFile.path, fileName);
      await deleteNativeFilePhysically(inputSourceFile.path, fileName);
      await scanMediaFile(sourceFile.path);
      await scanMediaFile(inputSourceFile.path);

      // 5. Bersihkan file cache temporary FilePicker jika berbeda
      if (inputSourceFile.path != sourceFile.path && await inputSourceFile.exists()) {
        try {
          await inputSourceFile.delete();
          await scanMediaFile(inputSourceFile.path);
        } catch (_) {}
      }

      debugPrint('File fisik $fileName berhasil dipindahkan ke Karantina: ${quarantinedFile.path}');
      return quarantinedFile.path;
    } catch (e) {
      debugPrint('Gagal memindahkan file ke karantina: $e');
      return null;
    }
  }

  /// Pulihkan file dari Vault Karantina kembali ke lokasi aslinya (Publik SDCard & MediaStore)
  static Future<bool> restoreFile(String quarantinedPath, String originalPath) async {
    try {
      final qFile = File(quarantinedPath);
      if (!await qFile.exists()) return false;

      // Cegah pemulihan file 0-byte / kosong ke folder publik
      if (await qFile.length() == 0) {
        debugPrint('File karantina $quarantinedPath berukuran 0-byte, menghapus file karantina tanpa membuat file publik baru.');
        try { await qFile.delete(); } catch (_) {}
        return false;
      }

      final fileName = originalPath.split('/').last;
      final publicPath = resolvePublicOriginalPath(originalPath);

      // 1. Coba pulihkan via Native Kotlin MediaStore ContentResolver & File System ke publicPath
      final nativeSuccess = await restoreNativeFilePhysically(quarantinedPath, fileName, originalPath: publicPath);
      if (nativeSuccess) {
        debugPrint('File $fileName berhasil dipulihkan via Native Kotlin MediaStore!');
        return true;
      }

      // 2. Fallback Pemulihan Dart File System
      final targetFile = File(publicPath);

      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      try {
        await qFile.copy(publicPath);
        await qFile.delete();
      } catch (_) {
        await qFile.rename(publicPath);
      }

      await scanMediaFile(publicPath);
      return true;
    } catch (e) {
      debugPrint('Gagal memulihkan file dari karantina: $e');
      return false;
    }
  }

  /// Hapus permanen file dari Vault Karantina
  static Future<bool> deletePermanently(String quarantinedPath) async {
    try {
      final qFile = File(quarantinedPath);
      if (await qFile.exists()) {
        await qFile.delete();
      }
      return true;
    } catch (e) {
      debugPrint('Gagal menghapus file karantina: $e');
      return false;
    }
  }
}
