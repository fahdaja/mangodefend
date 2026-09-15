import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/services/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncService Queue Unit Tests', () {
    setUpAll(() async {
      OfflineSyncService.autoFlush = false;
      await OfflineSyncService.clearQueue();
    });

    setUp(() async {
      OfflineSyncService.autoFlush = false;
      await OfflineSyncService.clearQueue();
    });

    test('enqueueOfflineScan adds item to pending queue', () async {
      await OfflineSyncService.clearQueue();

      await OfflineSyncService.enqueueOfflineScan(
        fileHash: 'test_hash_1234567890abcdef',
        fileName: 'malicious_sample.apk',
        verdict: 'MALICIOUS',
      );

      final count = await OfflineSyncService.getPendingCount();
      expect(count, greaterThanOrEqualTo(1));

      final items = await OfflineSyncService.getPendingItems();
      expect(items.any((i) => i.fileName == 'malicious_sample.apk'), isTrue);
    });

    test('clearQueue resets pending items to 0', () async {
      await OfflineSyncService.simulateOfflineScans(count: 3);
      expect(await OfflineSyncService.getPendingCount(), greaterThanOrEqualTo(1));

      await OfflineSyncService.clearQueue();
      expect(await OfflineSyncService.getPendingCount(), equals(0));
    });
  });
}
