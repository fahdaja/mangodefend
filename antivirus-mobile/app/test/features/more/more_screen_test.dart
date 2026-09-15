import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/more/presentation/pages/more_screen.dart';

void main() {
  testWidgets('MoreScreen renders user profile card and all menu items correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MoreScreen(),
        ),
      ),
    );

    expect(find.text('Status Premium Aktif'), findsOneWidget);
    expect(find.text('Kelola Berlangganan'), findsOneWidget);
    expect(find.text('Karantina (Quarantine)'), findsOneWidget);
    expect(find.text('Akun Saya (Account)'), findsOneWidget);
    expect(find.text('Pengaturan (Settings)'), findsOneWidget);
    expect(find.text('Bantuan & Support'), findsOneWidget);
    expect(find.text('Tentang Aplikasi (About)'), findsOneWidget);
  });
}
