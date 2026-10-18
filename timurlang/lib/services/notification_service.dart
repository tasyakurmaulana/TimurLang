// ============================================
// TimurLang - Notification Service
// Local notifications for SOS & sunset warning
// ============================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Inisialisasi Android Notification Channels dengan prioritas tinggi
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();

      // Channel 1: SOS Darurat (Maksimum, Heads-up popover, Alarm Sound)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'sos_channel',
          'SOS Darurat',
          description: 'Notifikasi darurat SOS pendakian',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );

      // Channel 2: Radar Siaga Basecamp (Foreground Monitoring)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'basecamp_radar_channel',
          'Radar Siaga Basecamp',
          description: 'Status siaga pemantauan darurat basecamp di latar belakang',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );

      // Channel 3: Sensor Siaga Pendaki
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'sos_monitor_channel',
          'Pemantauan Siaga SOS',
          description: 'Status aktif sensor pendeteksi jatuh & guncangan',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
    }

    _initialized = true;
  }

  /// Show SOS emergency notification
  Future<void> showSOSNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sos_channel',
      'SOS Darurat',
      channelDescription: 'Notifikasi darurat SOS pendakian',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );

    await _plugin.show(1, title, body, details, payload: payload ?? 'sos_emergency');
  }

  /// Tampilkan notifikasi persisten Radar Siaga Basecamp di status bar
  Future<void> showOngoingBasecampMonitoringNotification({
    required String basecampName,
    required String mountainName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'basecamp_radar_channel',
      'Radar Siaga Basecamp',
      channelDescription: 'Status siaga pemantauan darurat basecamp di latar belakang',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      998,
      '📡 Radar Basecamp Siaga ($mountainName)',
      '$basecampName siap menerima sinyal SOS pendaki di latar belakang 24/7.',
      details,
      payload: 'basecamp_dashboard',
    );
  }

  /// Hentikan notifikasi radar siaga basecamp
  Future<void> dismissOngoingBasecampMonitoringNotification() async {
    await cancelNotification(998);
  }

  /// Show ongoing background monitoring notification for Hikers
  Future<void> showOngoingMonitoringNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'sos_monitor_channel',
      'Pemantauan Siaga SOS',
      channelDescription: 'Status aktif sensor pendeteksi jatuh & guncangan',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      999,
      '🛡️ Siaga SOS Aktif',
      'Sensor guncangan & jatuh aktif memantau di latar belakang.',
      details,
      payload: 'sos_screen',
    );
  }

  /// Dismiss ongoing monitoring notification
  Future<void> dismissOngoingMonitoringNotification() async {
    await cancelNotification(999);
  }

  /// Show sunset warning notification
  Future<void> showSunsetWarning(int minutesRemaining) async {
    const androidDetails = AndroidNotificationDetails(
      'sunset_channel',
      'Peringatan Matahari Terbenam',
      channelDescription: 'Peringatan batas jam operasional pendakian',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      2,
      '⚠️ Peringatan Matahari Terbenam',
      'Tersisa $minutesRemaining menit sebelum batas jam operasional (18:00). Segera turun ke pos terdekat!',
      details,
    );
  }

  /// Show general notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'Notifikasi Umum',
      channelDescription: 'Notifikasi umum TimurLang',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true),
    );

    await _plugin.show(id, title, body, details);
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
