import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/services/device_id_service.dart';

void main() {
  test('DeviceIdService.getMotherboardDeviceId should return a non-empty unique string', () async {
    final deviceId1 = await DeviceIdService.getMotherboardDeviceId();
    final deviceId2 = await DeviceIdService.getMotherboardDeviceId();

    expect(deviceId1, isNotEmpty);
    expect(deviceId2, equals(deviceId1)); // Cached consistency check
  });
}
