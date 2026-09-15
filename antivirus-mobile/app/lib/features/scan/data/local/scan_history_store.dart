import 'package:flutter/material.dart';

class ScanHistoryRecord {
  final String title;
  final String subtitle;
  final String time;
  final IconData iconData;
  final Color iconColor;
  final bool isMalicious;
  final String? filePath;
  final String? fileSize;
  final String? sha256;

  ScanHistoryRecord({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.iconData,
    required this.iconColor,
    this.isMalicious = false,
    this.filePath,
    this.fileSize,
    this.sha256,
  });
}

class ScanHistoryStore {
  static final ValueNotifier<List<ScanHistoryRecord>> historyNotifier =
      ValueNotifier<List<ScanHistoryRecord>>([]);

  static void addRecord(ScanHistoryRecord record) {
    historyNotifier.value = [record, ...historyNotifier.value];
  }

  static void clear() {
    historyNotifier.value = [];
  }
}
