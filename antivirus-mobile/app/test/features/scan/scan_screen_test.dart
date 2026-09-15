import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/scan/presentation/pages/scan_screen.dart';
import 'package:antivirus_mobile/shared/widgets/account_question_dialog.dart';
import 'package:antivirus_mobile/shared/services/guest_quota_service.dart';

void main() {
  testWidgets('ScanScreen renders all three scan type options correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScanScreen(),
        ),
      ),
    );

    expect(find.text('Pemindaian'), findsOneWidget);
    expect(find.text('Upload & Pindai File'), findsAtLeastNWidgets(1));
    expect(find.text('Folder Scan'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Full System Scan'), findsAtLeastNWidgets(1));
  });

  testWidgets('Tapping scan button when guest quota exceeded presents AccountQuestionDialog pop-up', (WidgetTester tester) async {
    GuestQuotaService.guestScanCountNotifier.value = 15;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScanScreen(),
        ),
      ),
    );

    final scanButton = find.byType(ElevatedButton).last;
    await tester.ensureVisible(scanButton);
    await tester.tap(scanButton);
    await tester.pumpAndSettle();

    expect(find.byType(AccountQuestionDialog), findsOneWidget);
    expect(find.text('Batas Pemindaian Gratis Tamu Tercapai!'), findsOneWidget);
    expect(find.text('Sudah, Saya Ingin Masuk'), findsOneWidget);
    expect(find.text('Belum, Buat Akun Baru'), findsOneWidget);
  });
}
