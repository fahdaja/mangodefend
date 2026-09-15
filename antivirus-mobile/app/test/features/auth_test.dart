import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/auth/auth.dart';

void main() {
  group('Auth Domain Models & Serialization Tests', () {
    test('LoginRequest.toJson should produce correct json map', () {
      const req = LoginRequest(
        email: 'user@example.com',
        password: 'secretPassword123',
        deviceId: 'device-001',
      );

      final json = req.toJson();
      expect(json['email'], equals('user@example.com'));
      expect(json['password'], equals('secretPassword123'));
      expect(json['device_id'], equals('device-001'));
    });

    test('GoogleOAuthRequest.toJson should produce correct json map', () {
      const req = GoogleOAuthRequest(
        idToken: 'google_oauth_token_xyz',
        deviceId: 'device-002',
      );

      final json = req.toJson();
      expect(json['id_token'], equals('google_oauth_token_xyz'));
      expect(json['device_id'], equals('device-002'));
    });

    test('AuthResponse.fromJson should deserialize successfully', () {
      final jsonMap = {
        'success': true,
        'message': 'Login successful',
        'data': {
          'id': 12,
          'username': 'mango_user',
          'email': 'mango@defend.com',
          'token': {
            'access_token': 'jwt_access_token_123',
            'refresh_token': 'jwt_refresh_token_456',
            'token_type': 'bearer',
          }
        }
      };

      final response = AuthResponse.fromJson(jsonMap);
      expect(response.success, isTrue);
      expect(response.message, equals('Login successful'));
      expect(response.accessToken, equals('jwt_access_token_123'));
      expect(response.user?.id, equals(12));
      expect(response.user?.username, equals('mango_user'));
      expect(response.user?.email, equals('mango@defend.com'));
    });
  });

  group('LoginScreen UI Widget Tests', () {
    testWidgets('LoginScreen renders email, password fields and Google OAuth button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Mangodefend'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);
      expect(find.byType(GoogleOAuthButton), findsOneWidget);
    });

    testWidgets('LoginScreen shows validation errors on empty submission', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final loginBtn = find.text('Masuk');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
      expect(find.text('Password tidak boleh kosong'), findsOneWidget);
    });

    testWidgets('Tapping "Daftar Sekarang" link navigates to RegisterScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final registerLink = find.text('Daftar Sekarang');
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Buat Akun Baru'), findsOneWidget);
    });
  });
}
