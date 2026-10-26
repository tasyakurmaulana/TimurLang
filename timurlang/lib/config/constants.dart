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
  static const int dbVersion = 7;

  // Session
  static const String sessionTokenKey = 'session_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
  static const String rememberMeKey = 'remember_me';
  // ⏱️ SESSION TIMEOUT: Ubah angka di bawah untuk mengatur durasi sesi (dalam menit)
  // Contoh: 1 = 1 menit, 60 = 1 jam, 1440 = 1 hari, 4320 = 3 hari
  static const int sessionExpiryMinutes = 600;
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String lastBiometricUserIdKey = 'last_biometric_user_id';
  static const String registeredBiometricUserIdsKey =
      'registered_biometric_user_ids';

  // Midtrans Payment Gateway
  // Otomatis terdeteksi Production jika Server Key bukan Sandbox (tidak berawalan SB-)
  static bool get midtransIsProduction =>
      midtransServerKey.startsWith('Mid-') &&
      !midtransServerKey.startsWith('SB-');
  // Masukkan Server Key Midtrans Anda (Contoh: SB-Mid-server-XXXXX)
  static const String midtransServerKey = 'SB-Mid-server-ggpA~I8KRa3j6U9d4~Urilpf';
  // Masukkan Client Key Midtrans Anda (Contoh: SB-Mid-client-XXXXX)
  static const String midtransClientKey = 'SB-Mid-client-DSuywWCiN0pxVMZKepEY2_UW';
  static String get midtransSnapUrl => midtransIsProduction
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';
  static String get midtransApiBaseUrl => midtransIsProduction
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2';
  // Fall Detection
  static const double fallThresholdG = 2.5; // G-force threshold
  static const int fallCountdownSeconds = 15;
  static const double fallFreefallThreshold = 0.3;
  static const String sosMonitoringEnabledKey = 'sos_monitoring_enabled';

  // Operational Hours
  static const int operationalStartHour = 8;
  static const int operationalEndHour = 18;
  static const int sunsetWarningMinutes = 120; // 2 jam sebelum

  // Currency Rates (mock offline)
  static const Map<String, double> defaultCurrencyRates = {
    'IDR': 1.0,
    'USD': 0.0000625, // 1 IDR = ~0.0000625 USD
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
  static const String statusDibatalkan = 'Dibatalkan';
  static const String statusDibatalkanPendaki = 'Dibatalkan (Non-Refund)';
  static const String statusDibatalkanBasecamp = 'Dibatalkan Pengelola';
  static const String statusRescheduled = 'Jadwal Diubah';
  static const String statusRefundDiajukan = 'Refund Diajukan';
  static const String statusRefundSelesai = 'Refund Selesai';

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
