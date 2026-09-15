import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/protection/presentation/pages/protection_screen.dart';

void main() {
  testWidgets('ProtectionScreen renders security controls and protection health card', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProtectionScreen(),
        ),
      ),
    );

    expect(find.text('Pusat Perlindungan'), findsOneWidget);
    expect(find.text('Kontrol Keamanan'), findsOneWidget);
    expect(find.text('Proteksi Real-Time'), findsOneWidget);
    expect(find.text('Kesehatan Proteksi'), findsOneWidget);
  });
}
