import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antivirus_mobile/features/activity/data/local/activity_store.dart';
import 'package:antivirus_mobile/features/activity/domain/models/quarantine_file_model.dart';
import 'package:antivirus_mobile/features/activity/presentation/pages/activity_screen.dart';

void main() {
  setUp(() {
    ActivityStore.clear();
    ActivityStore.addLog(
      const ActivityLogItem(
        id: 'q_multi_1',
        title: '4 File Terindikasi Dipindai',
        subtitle: '1 File Dalam Karantina',
        time: 'Hari ini, 09.41',
        category: 'Karantina',
        badgeText: '4 File',
        isQuarantined: true,
        files: [
          QuarantinedFileDetail(
            fileName: 'Trojan.Win32.Generic.apk',
            filePath: '/storage/emulated/0/Download/Trojan.Win32.Generic.apk',
            threatType: 'Trojan High Risk',
            fileSize: '4.8 MB',
          ),
        ],
      ),
    );
    ActivityStore.addLog(
      const ActivityLogItem(
        id: 'q_single_1',
        title: 'invoice_fake_docx.exe',
        subtitle: '1 File Dalam Karantina',
        time: 'Hari ini, 08.15',
        category: 'Karantina',
        badgeText: '1 File',
        isQuarantined: true,
        files: [
          QuarantinedFileDetail(
            fileName: 'invoice_fake_docx.exe',
            filePath: '/storage/emulated/0/Download/invoice_fake_docx.exe',
            threatType: 'Trojan.Win32.Generic',
            fileSize: '3.2 MB',
          ),
        ],
      ),
    );
  });

  testWidgets('ActivityScreen renders logs, filter pills, and quarantine items correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActivityScreen(),
        ),
      ),
    );

    expect(find.text('Log Aktivitas'), findsOneWidget);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.textContaining('Karantina'), findsAtLeastNWidgets(1));
    expect(find.text('Pemindaian'), findsOneWidget);
    expect(find.text('4 File Terindikasi Dipindai'), findsOneWidget);
    expect(find.text('invoice_fake_docx.exe'), findsOneWidget);
  });
}
