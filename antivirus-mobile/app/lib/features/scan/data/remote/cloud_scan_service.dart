import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:antivirus_mobile/config/api_config.dart';
import 'package:antivirus_mobile/features/scan/domain/enums.dart';
import 'package:antivirus_mobile/features/scan/domain/scan_result.dart';
import 'package:antivirus_mobile/features/scan/data/local/local_heuristic_engine.dart';

import 'package:antivirus_mobile/shared/services/offline_sync_service.dart';
import 'package:antivirus_mobile/shared/services/user_session.dart';

class GuestQuotaExceededException implements Exception {
  final String message;
  GuestQuotaExceededException(this.message);

  @override
  String toString() => message;
}

class CloudScanService {
  final String baseUrl;
  final http.Client _client;

  CloudScanService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Upload dan scan 1 file ke Machine Learning Cloud Server
  Future<ScanResult> uploadAndScanFile(
    File file, {
    ScanType scanType = ScanType.file,
    String? deviceId,
    String? sessionId,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('File tidak ditemukan', file.path);
    }

    // 1. Cek Heuristik & Database Biner MDB1 Lokal HP terlebih dahulu
    final localResult = await LocalHeuristicEngine.analyzeFile(file);
    if (localResult.verdict == ScanVerdict.malicious) {
      debugPrint('🛑 File ${file.path} terdeteksi MALWARE di Database/Heuristik Lokal. Mengisolasi (Upload Cloud ML dilewati).');
      await OfflineSyncService.enqueueOfflineScan(
        fileHash: localResult.fileHash,
        fileName: localResult.fileName,
        verdict: localResult.verdict.name.toUpperCase(),
        scanSource: 'OFFLINE_HEURISTIC',
      );
      return localResult;
    }

    // 2. Fast Cloud Hash Lookup (Cek Redis L1 / PostgreSQL L2 tanpa upload biner berat)
    // Standar Industri: Hanya lakukan hash lookup jika hash SHA-256 valid (persis 64 karakter hex)
    if (localResult.fileHash.length == 64) {
      try {
        final lookupUri = Uri.parse('$baseUrl/scans/lookup');
        final lookupRes = await _client.post(
          lookupUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'sha256': localResult.fileHash}),
        ).timeout(const Duration(milliseconds: 1500));

        if (lookupRes.statusCode == 200) {
          final jsonMap = jsonDecode(lookupRes.body) as Map<String, dynamic>;
          final bool found = jsonMap['found'] as bool? ?? false;
          final String status = (jsonMap['status'] as String? ?? 'UNKNOWN').toUpperCase();

          if (found && status != 'UNKNOWN') {
            final isMal = status == 'MALICIOUS';
            return ScanResult(
              id: 0,
              deviceId: deviceId,
              fileHash: localResult.fileHash,
              fileName: file.path.split('/').last,
              filePath: file.path,
              verdict: isMal ? ScanVerdict.malicious : ScanVerdict.benign,
              scanSource: ScanSource.fromString(jsonMap['source'] as String? ?? 'CLOUD_LOOKUP'),
              scannedAt: DateTime.now(),
            );
          }
        }
      } catch (_) {
        // Jika fast lookup timeout/error, lanjutkan ke pemindaian upload biner
      }
    }

    // 3. Jika Hash Belum Dikenali di Cloud -> Lanjutkan upload file biner ke Machine Learning API
    try {
      final uri = Uri.parse('$baseUrl/scans/analyze');
      final request = http.MultipartRequest('POST', uri);

      if (UserSession.accessToken != null) {
        request.headers['Authorization'] = 'Bearer ${UserSession.accessToken}';
      }

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      request.fields['scan_type'] = scanType.value;
      if (deviceId != null && deviceId.isNotEmpty) {
        request.fields['device_id'] = deviceId;
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        request.fields['session_id'] = sessionId;
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
        final result = ScanResult.fromJson(jsonMap);
        return ScanResult(
          id: result.id,
          deviceId: result.deviceId,
          fileHash: result.fileHash,
          fileName: result.fileName ?? file.path.split('/').last,
          filePath: file.path,
          verdict: result.verdict,
          scanSource: result.scanSource,
          scannedAt: result.scannedAt,
        );
      } else {
        throw HttpException(
          'Gagal melakukan pemindaian cloud (HTTP ${response.statusCode}): ${response.body}',
          uri: uri,
        );
      }
    } catch (e) {
      debugPrint('🌐 Cloud scan offline/gagal ($e). Menggunakan hasil Heuristik Lokal & menyimpan ke Offline Sync...');
      await OfflineSyncService.enqueueOfflineScan(
        fileHash: localResult.fileHash,
        fileName: localResult.fileName,
        verdict: localResult.verdict.name.toUpperCase(),
        scanSource: 'OFFLINE_HEURISTIC',
      );
      return localResult;
    }
  }

  /// Memindai seluruh file di dalam direktori/folder secara berurutan
  Future<List<ScanResult>> scanFolder(
    Directory directory, {
    String? deviceId,
    Function(double progress, ScanResult? lastResult)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (!await directory.exists()) {
      throw FileSystemException('Direktori tidak ditemukan', directory.path);
    }

    final entities = await directory.list(recursive: true, followLinks: false).toList();
    final files = entities.whereType<File>().toList();

    if (files.isEmpty) {
      onProgress?.call(1.0, null);
      return [];
    }

    final results = <ScanResult>[];
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    for (int i = 0; i < files.length; i++) {
      if (isCancelled?.call() == true) {
        debugPrint('🛑 Scan Folder dibatalkan oleh pengguna pada file ke-${i + 1}');
        break;
      }
      try {
        final result = await uploadAndScanFile(
          files[i],
          scanType: ScanType.folder,
          deviceId: deviceId,
          sessionId: sessionId,
        );
        results.add(result);
        final progress = (i + 1) / files.length;
        onProgress?.call(progress, result);
      } catch (e) {
        final fallbackResult = await LocalHeuristicEngine.analyzeFile(files[i]);
        results.add(fallbackResult);
        await OfflineSyncService.enqueueOfflineScan(
          fileHash: fallbackResult.sha256,
          fileName: fallbackResult.fileName,
          verdict: fallbackResult.verdict.name.toUpperCase(),
          scanSource: 'OFFLINE_HEURISTIC',
        );
        final progress = (i + 1) / files.length;
        onProgress?.call(progress, fallbackResult);
      }
    }

    return results;
  }

  /// Memindai seluruh sistem (Full System Scan)
  Future<List<ScanResult>> scanFullSystem({
    String? deviceId,
    Function(double progress, ScanResult? lastResult)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final targets = <File>[];
    final Set<String> visitedPaths = {};

    final candidateDirs = [
      if (Platform.isAndroid) ...[
        '/data/app',
        '/system/app',
        '/system/priv-app',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/WhatsApp',
        '/storage/emulated/0/Android/media',
        '/storage/emulated/0',
        '/sdcard',
      ],
      if (Platform.isLinux || Platform.isMacOS) ...[
        '${Platform.environment['HOME']}/Downloads',
        '${Platform.environment['HOME']}/Documents',
        '${Platform.environment['HOME']}/Desktop',
        Directory.current.path,
      ],
    ];

    // Deteksi SD Card Eksternal tambahan di Android (/storage/XXXX-XXXX)
    if (Platform.isAndroid) {
      try {
        final storageDir = Directory('/storage');
        if (await storageDir.exists()) {
          final entries = await storageDir.list(recursive: false).toList();
          for (final entry in entries) {
            final path = entry.path;
            if (path != '/storage/emulated' && path != '/storage/self') {
              candidateDirs.add(path);
            }
          }
        }
      } catch (_) {}
    }

    for (final dirPath in candidateDirs) {
      if (isCancelled?.call() == true) break;
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (isCancelled?.call() == true) break;
            if (entity is File && !visitedPaths.contains(entity.path)) {
              visitedPaths.add(entity.path);
              targets.add(entity);
              if (targets.length >= 250) break; // Kuota cakupan luas untuk pemindaian menyeluruh
            }
          }
        } catch (_) {}
      }
      if (targets.length >= 250) break;
    }

    if (targets.isEmpty) {
      onProgress?.call(1.0, null);
      return [];
    }

    final results = <ScanResult>[];
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    for (int i = 0; i < targets.length; i++) {
      if (isCancelled?.call() == true) {
        debugPrint('🛑 Full System Scan dibatalkan oleh pengguna pada file ke-${i + 1}');
        break;
      }
      final targetFile = targets[i];
      try {
        final result = await uploadAndScanFile(
          targetFile,
          scanType: ScanType.fullSystem,
          deviceId: deviceId,
          sessionId: sessionId,
        );
        results.add(result);
        final progress = (i + 1) / targets.length;
        onProgress?.call(progress, result);
      } catch (e) {
        // Fallback jika cloud offline/timeout: jalankan analisis LocalHeuristicEngine
        final fallbackResult = await LocalHeuristicEngine.analyzeFile(targetFile);
        results.add(fallbackResult);
        await OfflineSyncService.enqueueOfflineScan(
          fileHash: fallbackResult.fileHash,
          fileName: fallbackResult.fileName,
          verdict: fallbackResult.verdict.name.toUpperCase(),
          scanSource: 'OFFLINE_HEURISTIC',
        );
        final progress = (i + 1) / targets.length;
        onProgress?.call(progress, fallbackResult);
      }
    }

    return results;
  }

  /// Central Service Method untuk mengeksekusi pemindaian berdasarkan ScanType pilihan
  Future<List<ScanResult>> scanBySelectedType({
    required ScanType type,
    File? singleFile,
    Directory? targetFolder,
    String? deviceId,
    Function(double progress, ScanResult? lastResult)? onProgress,
    bool Function()? isCancelled,
  }) async {
    switch (type) {
      case ScanType.file:
        if (singleFile == null) {
          throw ArgumentError('File harus disediakan untuk tipe scan file.');
        }
        onProgress?.call(0.5, null);
        if (isCancelled?.call() == true) return [];
        final result = await uploadAndScanFile(
          singleFile,
          scanType: ScanType.file,
          deviceId: deviceId,
        );
        onProgress?.call(1.0, result);
        return [result];

      case ScanType.folder:
        if (targetFolder == null) {
          throw ArgumentError('Folder harus disediakan untuk tipe scan folder.');
        }
        return await scanFolder(
          targetFolder,
          deviceId: deviceId,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );

      case ScanType.fullSystem:
        return await scanFullSystem(
          deviceId: deviceId,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );

      default:
        if (singleFile != null) {
          if (isCancelled?.call() == true) return [];
          final res = await uploadAndScanFile(singleFile, scanType: type, deviceId: deviceId);
          onProgress?.call(1.0, res);
          return [res];
        }
        return [];
    }
  }
}
