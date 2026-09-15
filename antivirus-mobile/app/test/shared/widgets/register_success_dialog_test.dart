import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/widgets/register_success_dialog.dart';

void main() {
  testWidgets('RegisterSuccessDialog renders title, description, and action button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RegisterSuccessDialog(),
        ),
      ),
    );

    expect(find.text('Pendaftaran Berhasil!'), findsOneWidget);
    expect(find.text('Masuk Sekarang'), findsOneWidget);
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
  });
}
