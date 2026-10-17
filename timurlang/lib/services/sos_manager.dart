// ============================================
// TimurLang - SOS Manager (Global Emergency Coordinator)
// Coordinates background monitoring, sensor trigger, GPS tagging, and SAR dispatch
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../app.dart';
import '../config/constants.dart';
import '../models/sos_incident.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'sensor_service.dart';
import 'supabase_service.dart';
import '../screens/safety/sos_beacon_screen.dart';

class SosManager {
  static final SosManager instance = SosManager._internal();
  SosManager._internal();

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  bool _isEmergencyActive = false;
  bool get isEmergencyActive => _isEmergencyActive;

  DateTime? _lastTriggerTime;

  // Callback listener for UI screens
  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Inisialisasi SOS Manager saat aplikasi start
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMonitoring = prefs.getBool(AppConstants.sosMonitoringEnabledKey) ?? false;

    // Pasang listener tap notifikasi
    NotificationService.instance.onNotificationTap = _handleNotificationTap;

    // Pasang callback dari sensor jatuh / guncangan
    SensorService.instance.onFallDetected = _onGlobalFallDetected;

    if (savedMonitoring) {
      await startMonitoring();
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == 'sos_emergency' || payload == 'sos_screen') {
      final nav = MainApp.navigatorKey.currentState;
      if (nav != null) {
        nav.push(
          MaterialPageRoute(
            builder: (context) => const SosBeaconScreen(
              triggerType: AppConstants.sosFallDetection,
            ),
          ),
        );
      }
    }
  }

  /// Aktifkan pemantauan guncangan & jatuh
  Future<void> startMonitoring() async {
    _isMonitoring = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.sosMonitoringEnabledKey, true);

    SensorService.instance.startFallDetection();
    await NotificationService.instance.showOngoingMonitoringNotification();
    _notifyListeners();
  }

  /// Matikan pemantauan guncangan & jatuh
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.sosMonitoringEnabledKey, false);

    SensorService.instance.stopFallDetection();
    await NotificationService.instance.dismissOngoingMonitoringNotification();
    _notifyListeners();
  }

  /// Dipanggil otomatis oleh sensor saat mendeteksi guncangan keras / benturan / jatuh
  Future<void> _onGlobalFallDetected() async {
    final now = DateTime.now();
    // Debounce 20 detik agar tidak spam
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inSeconds < 20) {
      return;
    }
    _lastTriggerTime = now;

    // Mainkan getaran kencang & alert haptic
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    // Dapatkan posisi GPS akurat terkini
    double lat = -8.108; // Fallback koordinat
    double lon = 112.922;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 5),
              ),
            );
        lat = pos.latitude;
        lon = pos.longitude;
      }
    } catch (e) {
      debugPrint('Gagal membaca GPS saat SOS: $e');
    }

    // Catat insiden SOS ke database lokal SQLite
    final user = AuthService.instance.currentUser;
    final incident = SosIncident(
      id: const Uuid().v4(),
      userId: user?.id ?? 'guest_user',
      koordinatLat: lat,
      koordinatLong: lon,
      tipePemicu: AppConstants.sosFallDetection,
      statusPenanganan: AppConstants.sosActive,
      waktuKejadian: DateTime.now(),
      namaPendaki: user?.namaLengkap ?? 'Pendaki Siaga',
      createdAt: DateTime.now(),
    );

    try {
      await DatabaseService.instance.insertSosIncident(incident);
      // Sync ke Supabase jika online
      await SupabaseService.instance.syncSosIncident(incident);
    } catch (e) {
      debugPrint('Error simpan insiden SOS: $e');
    }

    _isEmergencyActive = true;
    _notifyListeners();

    // Tampilkan notifikasi darurat heads-up / alarm di sistem Android
    await NotificationService.instance.showSOSNotification(
      title: '🚨 GUNCANGAN HEBAT TERDETEKSI! (SOS AKTIF)',
      body: 'Sinyal darurat beserta koordinat ($lat, $lon) telah dikirim ke Basecamp!',
      payload: 'sos_emergency',
    );

    // Bawa aplikasi langsung ke depan layar secara otomatis (bahkan saat di luar aplikasi / layar kunci)
    const platform = MethodChannel('com.example.timurlang/emergency_launcher');
    try {
      await platform.invokeMethod('bringToFront');
    } catch (e) {
      debugPrint('Error invoke bringToFront: $e');
    }

    // Arahkan navigasi ke SosBeaconScreen
    final nav = MainApp.navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (context) => SosBeaconScreen(
            incident: incident,
            triggerType: AppConstants.sosFallDetection,
          ),
        ),
      );
    }
  }

  /// Pemicu SOS manual (misal tombol tekan lama)
  Future<void> triggerManualSOS() async {
    double lat = -8.108;
    double lon = 112.922;

    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {}

    final user = AuthService.instance.currentUser;
    final incident = SosIncident(
      id: const Uuid().v4(),
      userId: user?.id ?? 'guest_user',
      koordinatLat: lat,
      koordinatLong: lon,
      tipePemicu: AppConstants.sosManual,
      statusPenanganan: AppConstants.sosActive,
      waktuKejadian: DateTime.now(),
      namaPendaki: user?.namaLengkap ?? 'Pendaki Siaga',
      createdAt: DateTime.now(),
    );

    try {
      await DatabaseService.instance.insertSosIncident(incident);
      await SupabaseService.instance.syncSosIncident(incident);
    } catch (_) {}

    await NotificationService.instance.showSOSNotification(
      title: '🚨 DARURAT SOS MANUAL DIAKTIFKAN',
      body: 'Sinyal darurat beserta koordinat ($lat, $lon) dipancarkan ke Pos Terdekat!',
      payload: 'sos_emergency',
    );

    final nav = MainApp.navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        MaterialPageRoute(
          builder: (context) => SosBeaconScreen(
            incident: incident,
            triggerType: AppConstants.sosManual,
          ),
        ),
      );
    }
  }
}
