import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/widgets/account_question_dialog.dart';
import 'package:antivirus_mobile/features/auth/auth.dart';

void main() {
  testWidgets('AccountQuestionDialog renders question title, description, and both action buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AccountQuestionDialog.show(context),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountQuestionDialog), findsOneWidget);
    expect(find.text('Apakah Anda Sudah Memiliki Akun?'), findsOneWidget);
    expect(find.text('Sudah, Saya Ingin Masuk'), findsOneWidget);
    expect(find.text('Belum, Buat Akun Baru'), findsOneWidget);
  });

  testWidgets('Tapping "Sudah, Saya Ingin Masuk" opens LoginScreen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AccountQuestionDialog.show(context),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    final loginBtn = find.text('Sudah, Saya Ingin Masuk');
    await tester.ensureVisible(loginBtn);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Masuk ke akun keamanan Anda'), findsOneWidget);
  });

  testWidgets('Tapping "Belum, Buat Akun Baru" opens RegisterScreen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AccountQuestionDialog.show(context),
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    final registerBtn = find.text('Belum, Buat Akun Baru');
    await tester.ensureVisible(registerBtn);
    await tester.tap(registerBtn);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Buat Akun Baru'), findsOneWidget);
  });
}
