// ============================================
// TimurLang - Date & Timezone Utilities
// ============================================

import '../config/constants.dart';

class AppDateUtils {
  /// Convert a DateTime from one timezone to another
  static DateTime convertTimezone(DateTime dateTime, String fromZone, String toZone) {
    final fromOffset = AppConstants.timezoneOffsets[fromZone] ?? 7;
    final toOffset = AppConstants.timezoneOffsets[toZone] ?? 7;
    final diff = toOffset - fromOffset;
    return dateTime.add(Duration(hours: diff));
  }

  /// Format time for display with timezone label
  static String formatWithTimezone(DateTime dateTime, String timezone) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $timezone';
  }

  /// Get all timezone displays for a given WIB time
  static Map<String, String> getAllTimezoneDisplays(DateTime wibTime) {
    final result = <String, String>{};
    for (final tz in AppConstants.timezoneOffsets.keys) {
      final converted = convertTimezone(wibTime, 'WIB', tz);
      result[tz] = formatWithTimezone(converted, tz);
    }
    return result;
  }

  /// Check if current time is within operational hours (08:00 - 18:00 WIB)
  static bool isWithinOperationalHours(DateTime now) {
    return now.hour >= AppConstants.operationalStartHour &&
        now.hour < AppConstants.operationalEndHour;
  }

  /// Get minutes until operational end (sunset warning)
  static int minutesUntilOperationalEnd(DateTime now) {
    final endTime = DateTime(now.year, now.month, now.day, AppConstants.operationalEndHour);
    return endTime.difference(now).inMinutes;
  }

  /// Format date to Indonesian format
  static String formatDateIndonesian(DateTime date) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Format datetime to Indonesian format with time
  static String formatDateTimeIndonesian(DateTime date) {
    return '${formatDateIndonesian(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} WIB';
  }
}
