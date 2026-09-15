import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/scan/data/remote/cloud_scan_service.dart';
import 'package:antivirus_mobile/shared/services/global_scan_controller.dart';

import 'package:antivirus_mobile/shared/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    OfflineSyncService.autoFlush = false;
    await OfflineSyncService.clearQueue();
  });

  group('Scan Cancellation Unit Tests', () {
    test('CloudScanService stops processing files immediately when isCancelled returns true', () async {
      final cloudService = CloudScanService();
      final tempDir = await Directory.systemTemp.createTemp('scan_cancel_test');

      // Create 5 dummy files
      for (int i = 0; i < 5; i++) {
        final file = File('${tempDir.path}/test_file_$i.txt');
        await file.writeAsString('Dummy content $i');
      }

      int filesScanned = 0;
      bool cancelRequested = false;

      final results = await cloudService.scanFolder(
        tempDir,
        onProgress: (progress, result) {
          filesScanned++;
          if (filesScanned == 2) {
            cancelRequested = true;
          }
        },
        isCancelled: () => cancelRequested,
      );

      // Should stop after scanning 2 files instead of 5
      expect(results.length, equals(2));
      expect(cancelRequested, isTrue);

      await tempDir.delete(recursive: true);
    });

    test('GlobalScanController cancelScan updates cancellation state', () {
      final controller = GlobalScanController.instance;
      controller.isScanning.value = true;

      controller.cancelScan();

      expect(controller.isScanning.value, isFalse);
    });

    test('CloudScanService scanFullSystem stops immediately when cancelled', () async {
      final cloudService = CloudScanService();
      int filesScanned = 0;
      bool cancelRequested = false;

      final results = await cloudService.scanFullSystem(
        onProgress: (progress, result) {
          filesScanned++;
          if (filesScanned >= 3) {
            cancelRequested = true;
          }
        },
        isCancelled: () => cancelRequested,
      );

      // Even if candidate dirs have 250 files, scan stops at 3 files!
      if (filesScanned >= 3) {
        expect(results.length, equals(3));
      }
    });
  });
}
