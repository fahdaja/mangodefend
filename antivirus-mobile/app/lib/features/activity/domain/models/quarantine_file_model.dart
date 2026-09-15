class QuarantinedFileDetail {
  final String fileName;
  final String filePath;
  final String? quarantinedPath;
  final String threatType;
  final String fileSize;
  final bool isSafe;
  final bool isFalsePositive;

  const QuarantinedFileDetail({
    required this.fileName,
    required this.filePath,
    this.quarantinedPath,
    required this.threatType,
    required this.fileSize,
    this.isSafe = false,
    this.isFalsePositive = false,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'filePath': filePath,
        'quarantinedPath': quarantinedPath,
        'threatType': threatType,
        'fileSize': fileSize,
        'isSafe': isSafe,
        'isFalsePositive': isFalsePositive,
      };

  factory QuarantinedFileDetail.fromJson(Map<String, dynamic> json) =>
      QuarantinedFileDetail(
        fileName: json['fileName'] as String? ?? '',
        filePath: json['filePath'] as String? ?? '',
        quarantinedPath: json['quarantinedPath'] as String?,
        threatType: json['threatType'] as String? ?? 'Umum',
        fileSize: json['fileSize'] as String? ?? '0 KB',
        isSafe: json['isSafe'] as bool? ?? false,
        isFalsePositive: json['isFalsePositive'] as bool? ?? false,
      );
}

class ActivityLogItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String category; // 'Karantina', 'Pemindaian', 'Ancaman', 'Perlindungan'
  final String badgeText;
  final bool isQuarantined;
  final List<QuarantinedFileDetail> files;

  const ActivityLogItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.category,
    required this.badgeText,
    this.isQuarantined = false,
    this.files = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'time': time,
        'category': category,
        'badgeText': badgeText,
        'isQuarantined': isQuarantined,
        'files': files.map((f) => f.toJson()).toList(),
      };

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) =>
      ActivityLogItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        time: json['time'] as String? ?? '',
        category: json['category'] as String? ?? 'Pemindaian',
        badgeText: json['badgeText'] as String? ?? '',
        isQuarantined: json['isQuarantined'] as bool? ?? false,
        files: (json['files'] as List<dynamic>?)
                ?.map((f) => QuarantinedFileDetail.fromJson(f as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  int get totalFiles => files.length;
  int get safeFilesCount => files.where((f) => f.isSafe || f.isFalsePositive).length;
  int get threatFilesCount => files.where((f) => !f.isSafe && !f.isFalsePositive).length;

  String get mainFilePath => files.isNotEmpty ? files.first.filePath : '-';
  String get mainThreatType => files.isNotEmpty ? files.first.threatType : 'Indikasi Malware';
  String get mainFileSize => files.isNotEmpty ? files.first.fileSize : '-';
}
