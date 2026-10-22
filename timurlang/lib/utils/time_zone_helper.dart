// ============================================
// TimurLang - Indonesian Time Zone Helper (WIB, WITA, WIT)
// Handles dynamic time zone conversion and mountain zone detection
// ============================================

class TimeZoneHelper {
  static const String wib = 'WIB';
  static const String wita = 'WITA';
  static const String wit = 'WIT';
  static const String london = 'London';

  static const List<String> supportedTimeZones = [wib, wita, wit, london];

  /// Mendapatkan offset jam dari UTC
  static int getOffsetHours(String timeZone) {
    switch (timeZone.toUpperCase()) {
      case 'WITA':
        return 8;
      case 'WIT':
        return 9;
      case 'LONDON':
      case 'GMT':
      case 'UTC':
        return 0;
      case 'WIB':
      default:
        return 7;
    }
  }

  /// Label lengkap zona waktu
  static String getTimeZoneFullName(String timeZone) {
    switch (timeZone.toUpperCase()) {
      case 'WITA':
        return 'Waktu Indonesia Tengah (UTC+8)';
      case 'WIT':
        return 'Waktu Indonesia Timur (UTC+9)';
      case 'LONDON':
      case 'GMT':
      case 'UTC':
        return 'Waktu London / GMT (UTC+0)';
      case 'WIB':
      default:
        return 'Waktu Indonesia Barat (UTC+7)';
    }
  }

  /// Menentukan zona waktu native gunung berdasarkan nama dan/atau longitude
  static String getMountainTimeZone({String? mountainName, double? longitude}) {
    if (mountainName != null && mountainName.isNotEmpty) {
      final name = mountainName.toLowerCase();
      // WITA: Bali, NTB, NTT, Sulawesi, Kalimantan Timur & Selatan
      if (name.contains('rinjani') ||
          name.contains('agung') ||
          name.contains('batur') ||
          name.contains('tambora') ||
          name.contains('latimojong') ||
          name.contains('bawakaraeng') ||
          name.contains('inerie') ||
          name.contains('klabat') ||
          name.contains('mahawu') ||
          name.contains('lokon') ||
          name.contains('soputan') ||
          name.contains('lompobattang') ||
          name.contains('bukit raya')) {
        return wita;
      }
      // WIT: Maluku dan Papua
      if (name.contains('carstensz') ||
          name.contains('jaya') ||
          name.contains('binaiya') ||
          name.contains('gamalama') ||
          name.contains('dukono') ||
          name.contains('ibu')) {
        return wit;
      }
      // WIB: Jawa, Sumatera
      if (name.contains('merbabu') ||
          name.contains('semeru') ||
          name.contains('prau') ||
          name.contains('gede') ||
          name.contains('pangrango') ||
          name.contains('slamet') ||
          name.contains('lawu') ||
          name.contains('sindoro') ||
          name.contains('sumbing') ||
          name.contains('kerinci') ||
          name.contains('marapi') ||
          name.contains('dempo') ||
          name.contains('ciremai') ||
          name.contains('papandayan') ||
          name.contains('salak') ||
          name.contains('bromo') ||
          name.contains('ijen') ||
          name.contains('raung') ||
          name.contains('arjuno') ||
          name.contains('welirang')) {
        return wib;
      }
    }

    if (longitude != null && longitude > 0) {
      if (longitude >= 125.0) return wit;
      if (longitude >= 114.5) return wita;
      return wib;
    }

    return wib;
  }

  /// Konversi jam "HH:mm" dari zona asal ke zona target
  static String convertTime(String baseTime, String fromZone, String toZone) {
    try {
      final parts = baseTime.trim().split(':');
      if (parts.length < 2) return baseTime;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      int diff = getOffsetHours(toZone) - getOffsetHours(fromZone);
      hour = (hour + diff) % 24;
      if (hour < 0) hour += 24;

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return baseTime;
    }
  }

  /// Konversi rentang waktu misalnya "07:00 - 16:00"
  static String convertTimeRange(String timeRange, String fromZone, String toZone) {
    try {
      final parts = timeRange.split('-');
      if (parts.length == 2) {
        final start = convertTime(parts[0].trim(), fromZone, toZone);
        final end = convertTime(parts[1].trim(), fromZone, toZone);
        return '$start - $end';
      }
    } catch (_) {}
    return timeRange;
  }
}
