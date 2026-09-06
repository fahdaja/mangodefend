from enum import Enum


class ScanVerdict(str, Enum):
    """Vonis status keamanan file & verifikasi signature."""
    MALICIOUS = "MALICIOUS"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    FALSE_POSITIVE = "FALSE_POSITIVE"
    BENIGN = "BENIGN"
    UNKNOWN = "UNKNOWN"


class ScanSource(str, Enum):
    """Sumber asal vonis hasil pemindaian."""
    REDIS_CACHE = "REDIS_CACHE"
    CLOUD_DB = "CLOUD_DB"
    ML_INFERENCE = "ML_INFERENCE"
    NOT_FOUND = "NOT_FOUND"
    OFFLINE_HEURISTIC = "OFFLINE_HEURISTIC"
    OFFLINE_SYNC = "OFFLINE_SYNC"


class DatasetSource(str, Enum):
    """Sumber pengumpulan dataset sampel ML."""
    AUTO_COLLECT = "AUTO_COLLECT"
    MANUAL_UPLOAD = "MANUAL_UPLOAD"