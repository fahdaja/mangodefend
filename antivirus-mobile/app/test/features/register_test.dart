import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/auth/auth.dart';

void main() {
  group('Register Domain Models & Serialization Tests', () {
    test('RegisterRequest.toJson should produce correct json map', () {
      const req = RegisterRequest(
        fullName: 'Budi Santoso',
        email: 'budi@example.com',
        password: 'securePassword123',
        deviceId: 'device-003',
      );

      final json = req.toJson();
      expect(json['full_name'], equals('Budi Santoso'));
      expect(json['email'], equals('budi@example.com'));
      expect(json['password'], equals('securePassword123'));
      expect(json['device_id'], equals('device-003'));
    });
  });

  group('RegisterScreen UI Widget Tests', () {
    testWidgets('RegisterScreen renders full name, email, password fields and Google OAuth button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );

      expect(find.text('Buat Akun Baru'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);
      expect(find.byType(GoogleOAuthButton), findsOneWidget);
    });

    testWidgets('RegisterScreen shows validation errors on empty submission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: RegisterScreen(),
        ),
      );

      final registerBtn = find.text('Daftar');
      await tester.tap(registerBtn);
      await tester.pump();

      expect(find.text('Nama lengkap tidak boleh kosong'), findsOneWidget);
      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
      expect(find.text('Password tidak boleh kosong'), findsOneWidget);
    });
  });
}
