enum ScanVerdict {
  malicious('MALICIOUS'),
  benign('BENIGN'),
  unknown('UNKNOWN');

  final String value;
  const ScanVerdict(this.value);

  factory ScanVerdict.fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'MALICIOUS':
        return ScanVerdict.malicious;
      case 'BENIGN':
        return ScanVerdict.benign;
      default:
        return ScanVerdict.unknown;
    }
  }
}

enum ScanSource {
  redisCache('REDIS_CACHE'),
  cloudDb('CLOUD_DB'),
  mlInference('ML_INFERENCE'),
  localDb('LOCAL_DB'),
  heuristicEngine('HEURISTIC_ENGINE'),
  offlineHeuristic('OFFLINE_HEURISTIC'),
  offlineSync('OFFLINE_SYNC'),
  notFound('NOT_FOUND');

  final String value;
  const ScanSource(this.value);

  factory ScanSource.fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'REDIS_CACHE':
        return ScanSource.redisCache;
      case 'CLOUD_DB':
        return ScanSource.cloudDb;
      case 'ML_INFERENCE':
        return ScanSource.mlInference;
      case 'LOCAL_DB':
        return ScanSource.localDb;
      case 'HEURISTIC_ENGINE':
        return ScanSource.heuristicEngine;
      case 'OFFLINE_HEURISTIC':
        return ScanSource.offlineHeuristic;
      case 'OFFLINE_SYNC':
        return ScanSource.offlineSync;
      default:
        return ScanSource.notFound;
    }
  }
}

enum ScanType {
  file('upload'),
  folder('folder'),
  fullSystem('full_system'),
  apkDownload('apk_download'),
  fileDownload('file_download'),
  realtimeMonitoring('realtime_monitoring');

  final String value;
  const ScanType(this.value);
}
