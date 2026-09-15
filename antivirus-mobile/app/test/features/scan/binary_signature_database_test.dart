import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/scan/data/local/binary_signature_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BinarySignatureDatabase should load signatures.bin and detect known signatures', () async {
    await BinarySignatureDatabase.loadBinaryDatabase();

    expect(BinarySignatureDatabase.isLoaded, isTrue);
    expect(BinarySignatureDatabase.loadedBinaryEntries, equals(7));

    // Hash EICAR Standard Test File (SHA-256)
    // 275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f
    final eicarBytes = Uint8List.fromList([
      0x27, 0x5a, 0x02, 0x1b, 0xbf, 0xb6, 0x48, 0x9e,
      0x54, 0xd4, 0x71, 0x89, 0x9f, 0x7d, 0xb9, 0xd1,
      0x66, 0x3f, 0xc6, 0x95, 0xec, 0x2f, 0xe2, 0xa2,
      0xc4, 0x53, 0x8a, 0xab, 0xf6, 0x51, 0xfd, 0x0f,
    ]);

    final matchEicar = BinarySignatureDatabase.checkSha256BinaryMatch(eicarBytes);
    expect(matchEicar, isTrue);

    // Random safe hash that shouldn't match
    final safeBytes = Uint8List(32); // All zeros
    final matchSafe = BinarySignatureDatabase.checkSha256BinaryMatch(safeBytes);
    expect(matchSafe, isFalse);
  });
}
