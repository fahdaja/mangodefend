import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/scan/scan.dart';

void main() {
  group('Scan Domain & Model Tests', () {
    test('ScanResult.fromJson should correctly deserialize all required fields', () {
      final jsonMap = {
        'id': 101,
        'device_id': 'device-abc-123',
        'file_hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'file_name': 'test_sample.exe',
        'verdict': 'MALICIOUS',
        'scan_source': 'ML_INFERENCE',
        'scanned_at': '2026-08-22T05:00:00.000Z',
      };

      final scanResult = ScanResult.fromJson(jsonMap);

      expect(scanResult.id, equals(101));
      expect(scanResult.deviceId, equals('device-abc-123'));
      expect(scanResult.fileHash, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
      expect(scanResult.fileName, equals('test_sample.exe'));
      expect(scanResult.verdict, equals(ScanVerdict.malicious));
      expect(scanResult.scanSource, equals(ScanSource.mlInference));
      expect(scanResult.scannedAt, equals(DateTime.parse('2026-08-22T05:00:00.000Z')));
    });

    test('ScanResult.toJson should correctly serialize properties', () {
      final scanResult = ScanResult(
        id: 202,
        deviceId: 'device-xyz-789',
        fileHash: '88d4266f4714047d0781201e341c7a6c049ee77b1ca62fd12e70ceca8d7d14d4',
        fileName: 'clean_app.apk',
        verdict: ScanVerdict.benign,
        scanSource: ScanSource.redisCache,
        scannedAt: DateTime.utc(2026, 8, 22, 5, 10, 0),
      );

      final json = scanResult.toJson();

      expect(json['id'], equals(202));
      expect(json['device_id'], equals('device-xyz-789'));
      expect(json['file_hash'], equals('88d4266f4714047d0781201e341c7a6c049ee77b1ca62fd12e70ceca8d7d14d4'));
      expect(json['file_name'], equals('clean_app.apk'));
      expect(json['verdict'], equals('BENIGN'));
      expect(json['scan_source'], equals('REDIS_CACHE'));
    });

    test('ScanVerdict and ScanSource enum parsing', () {
      expect(ScanVerdict.fromString('MALICIOUS'), equals(ScanVerdict.malicious));
      expect(ScanVerdict.fromString('BENIGN'), equals(ScanVerdict.benign));
      expect(ScanVerdict.fromString('UNKNOWN'), equals(ScanVerdict.unknown));
      expect(ScanVerdict.fromString(null), equals(ScanVerdict.unknown));

      expect(ScanSource.fromString('REDIS_CACHE'), equals(ScanSource.redisCache));
      expect(ScanSource.fromString('CLOUD_DB'), equals(ScanSource.cloudDb));
      expect(ScanSource.fromString('ML_INFERENCE'), equals(ScanSource.mlInference));
      expect(ScanSource.fromString('NOT_FOUND'), equals(ScanSource.notFound));
    });
  });
}
