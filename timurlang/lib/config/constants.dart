// ============================================
// TimurLang - Constants Configuration
// ============================================

class AppConstants {
  // App Info
  static const String appName = 'TimurLang';
  static const String appTagline = 'Perizinan & Keselamatan Pendakian Terpadu';
  static const String appVersion = '0.1.0';

  // Database
  static const String dbName = 'timurlang.db';
  static const int dbVersion = 3;

  // Session
  static const String sessionTokenKey = 'session_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const int sessionExpiryHours = 72;
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String lastBiometricUserIdKey = 'last_biometric_user_id';
  static const String registeredBiometricUserIdsKey = 'registered_biometric_user_ids';

  // Fall Detection
  static const double fallThresholdG = 2.5; // G-force threshold
  static const int fallCountdownSeconds = 15;
  static const double fallFreefallThreshold = 0.3;

  // Operational Hours
  static const int operationalStartHour = 8;
  static const int operationalEndHour = 18;
  static const int sunsetWarningMinutes = 120; // 2 jam sebelum

  // Currency Rates (mock offline)
  static const Map<String, double> defaultCurrencyRates = {
    'IDR': 1.0,
    'USD': 0.0000625,  // 1 IDR = ~0.0000625 USD
    'EUR': 0.0000575,
    'GBP': 0.0000494,
  };

  // Timezone offsets
  static const Map<String, int> timezoneOffsets = {
    'WIB': 7,
    'WITA': 8,
    'WIT': 9,
    'UTC': 0,
  };

  // Mountain Grades
  static const List<String> mountainGrades = [
    'Grade 1 - Mudah',
    'Grade 2 - Sedang',
    'Grade 3 - Sulit',
    'Grade 4 - Sangat Sulit',
    'Grade 5 - Ekstrem',
  ];

  // User Roles
  static const String rolePendaki = 'pendaki';
  static const String roleBasecamp = 'basecamp';

  // Sync Status
  static const String syncPending = 'menunggu_sinkronisasi';
  static const String syncCompleted = 'tersinkronisasi';
  static const String syncFailed = 'gagal';

  // Simaksi Status
  static const String statusDiajukan = 'Diajukan';
  static const String statusTerdaftar = 'Terdaftar';
  static const String statusTervalidasi = 'Tervalidasi';
  static const String statusDiJalur = 'Di Jalur';
  static const String statusSelesai = 'Selesai';
  static const String statusDitolak = 'Ditolak';

  // Trail Status
  static const String trailOpen = 'Buka';
  static const String trailClosed = 'Tutup';
  static const String trailWarning = 'Waspada Cuaca Ekstrem';

  // SOS Types
  static const String sosFallDetection = 'fall_detection';
  static const String sosManual = 'manual';
  
  // SOS Handling Status
  static const String sosActive = 'darurat_aktif';
  static const String sosHandled = 'ditangani';
  static const String sosCancelled = 'dibatalkan';
}
