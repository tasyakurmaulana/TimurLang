// ============================================
// TimurLang - Notification Service
// Local notifications for SOS & sunset warning
// ============================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

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

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Show SOS emergency notification
  Future<void> showSOSNotification({
    required String title,
    required String body,
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

    await _plugin.show(1, title, body, details);
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
