import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/widgets/manage_storage_permission_dialog.dart';

void main() {
  testWidgets('ManageStoragePermissionDialog renders title, step instructions and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ManageStoragePermissionDialog(),
        ),
      ),
    );

    expect(find.text('Akses Semua File Diperlukan'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Buka Pengaturan'), findsOneWidget);
    expect(find.text('Nanti Saja'), findsOneWidget);
    expect(find.textContaining('Izinkan Akses untuk Mengelola Semua File'), findsOneWidget);
  });
}
