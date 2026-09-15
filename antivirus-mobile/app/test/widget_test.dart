import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/main.dart';

void main() {
  testWidgets('HomeScreen renders protection status and scan button', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.textContaining('Perlindungan'), findsAtLeastNWidgets(1));
    expect(find.text('Mulai Full Scan'), findsOneWidget);
  });
}
