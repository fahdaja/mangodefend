import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/shared/widgets/navbar_bottom.dart';

void main() {
  testWidgets('NavbarBottom renders all 4 menu items correctly', (WidgetTester tester) async {
    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: NavbarBottom(
            currentIndex: 0,
            onTap: (index) {
              tappedIndex = index;
            },
          ),
        ),
      ),
    );

    // Verify all 4 labels are visible in Indonesian
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Pemindaian'), findsOneWidget);
    expect(find.text('Perlindungan'), findsOneWidget);
    expect(find.text('Aktivitas'), findsOneWidget);

    // Tap on 'Pemindaian' (index 1)
    await tester.tap(find.text('Pemindaian'));
    await tester.pump();

    expect(tappedIndex, 1);
  });
}
