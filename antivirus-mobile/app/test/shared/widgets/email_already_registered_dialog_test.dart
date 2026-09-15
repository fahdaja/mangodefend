import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/widgets/email_already_registered_dialog.dart';

void main() {
  testWidgets('EmailAlreadyRegisteredDialog renders title, description, and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmailAlreadyRegisteredDialog(
            email: 'test@example.com',
          ),
        ),
      ),
    );

    expect(find.text('Akun Sudah Terdaftar'), findsOneWidget);
    expect(find.text('Masuk ke Akun Ini'), findsOneWidget);
    expect(find.text('Gunakan Email Lain'), findsOneWidget);
  });
}
