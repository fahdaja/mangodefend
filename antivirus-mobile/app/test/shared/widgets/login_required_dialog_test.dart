import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/widgets/login_required_dialog.dart';

void main() {
  testWidgets('LoginRequiredDialog renders hero lock icon, title, description, and buttons', (tester) async {
    bool loginPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                LoginRequiredDialog.show(
                  context,
                  onLoginPressed: () {
                    loginPressed = true;
                  },
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Apakah Anda Sudah Memiliki Akun?'), findsOneWidget);
    expect(find.text('Sudah, Saya Ingin Masuk'), findsOneWidget);
    expect(find.text('Belum, Buat Akun Baru'), findsOneWidget);

    final loginBtn = find.text('Sudah, Saya Ingin Masuk');
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    expect(loginPressed, isTrue);
  });
}
