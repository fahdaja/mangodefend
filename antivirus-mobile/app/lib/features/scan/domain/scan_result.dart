import 'package:antivirus_mobile/features/scan/domain/enums.dart';

class ScanResult {
  final int id;
  final String? deviceId;
  final String fileHash;
  final String? fileName;
  final String? filePath;
  final ScanVerdict verdict;
  final ScanSource scanSource;
  final DateTime scannedAt;

  const ScanResult({
    required this.id,
    this.deviceId,
    required this.fileHash,
    this.fileName,
    this.filePath,
    required this.verdict,
    required this.scanSource,
    required this.scannedAt,
  });

  String get sha256 => fileHash;

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'] as int? ?? 0,
      deviceId: json['device_id'] as String?,
      fileHash: json['file_hash'] as String? ?? json['sha256'] as String? ?? '',
      fileName: json['file_name'] as String?,
      filePath: json['file_path'] as String?,
      verdict: ScanVerdict.fromString(json['verdict'] as String?),
      scanSource: ScanSource.fromString(
        json['scan_source'] as String? ?? json['source'] as String?,
      ),
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'file_hash': fileHash,
      'file_name': fileName,
      'file_path': filePath,
      'verdict': verdict.value,
      'scan_source': scanSource.value,
      'scanned_at': scannedAt.toIso8601String(),
    };
  }
}
