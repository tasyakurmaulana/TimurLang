// ============================================
// TimurLang - Basecamp Alert Service
// Background SOS monitoring and dispatch for Basecamp
// Listens to Supabase Realtime & background polling 24/7
// ============================================

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../config/supabase_config.dart';
import '../models/user.dart';
import '../models/basecamp_post.dart';
import '../models/sos_incident.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class BasecampAlertService {
  static final BasecampAlertService instance = BasecampAlertService._internal();
  BasecampAlertService._internal();

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  String? _gunungId;
  String? _basecampId;
  String _basecampName = 'Basecamp';
  String _mountainName = 'Wilayah';

  Timer? _pollingTimer;
  RealtimeChannel? _realtimeChannel;
  final Set<String> _knownSosIds = {};

  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) {
      l();
    }
  }

  /// Mulai pemantauan sinyal darurat SOS di latar belakang untuk akun Basecamp
  Future<void> startMonitoring({
    required User user,
    BasecampPost? post,
    String? mountainName,
  }) async {
    _gunungId = user.gunungId ?? post?.gunungId ?? 'mtn-001';
    _basecampId = post?.id;
    _basecampName = user.namaBasecamp ?? post?.namaPos ?? 'Pos Basecamp';

    if (mountainName != null && mountainName.isNotEmpty) {
      _mountainName = mountainName;
    } else {
      final mtn = await DatabaseService.instance.getMountainById(_gunungId!);
      if (mtn != null) _mountainName = mtn.namaGunung;
    }

    _isMonitoring = true;
    _notifyListeners();

    // 1. Jalankan Android Native Foreground Service dengan WakeLock & HTTP Poller
    // Ini berjalan di level OS Android murni, tetap aktif 24/7 saat HP mati / terkunci
    const platform = MethodChannel('com.example.timurlang/emergency_launcher');
    try {
      await platform.invokeMethod('startBasecampService', {
        'gunungId': _gunungId,
        'basecampId': _basecampId,
        'basecampName': _basecampName,
        'mountainName': _mountainName,
        'supabaseUrl': SupabaseConfig.supabaseUrl,
        'supabaseKey': SupabaseConfig.supabaseAnonKey,
      });
      debugPrint('🚀 Native Android Basecamp Foreground Service dinyalakan!');
    } catch (e) {
      debugPrint('⚠️ Gagal start native service: $e');
    }

    // 2. Inisialisasi daftar SOS yang sudah diketahui agar tidak memicu alarm ganda untuk SOS lama
    final initialList = await DatabaseService.instance.getActiveSOSIncidentsForBasecamp(
      gunungId: _gunungId!,
      basecampId: _basecampId,
    );
    for (final inc in initialList) {
      _knownSosIds.add(inc.id);
    }

    // 3. Pasang Realtime Listener via Supabase WebSocket di Flutter (saat aplikasi foreground)
    _setupRealtimeSubscription();

    // 4. Polling timer cadangan di Flutter
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => checkNewSOS());

    // Cek langsung saat pertama kali aktif
    await checkNewSOS();
    debugPrint('📡 Radar Siaga Basecamp Aktif untuk: $_basecampName ($_mountainName)');
  }

  void _setupRealtimeSubscription() {
    final client = SupabaseService.instance.client;
    if (client == null || !SupabaseService.instance.isInitialized) return;

    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client.channel('public:sos_incident_logs')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sos_incident_logs',
          callback: (payload) {
            debugPrint('🔔 Event Realtime SOS diterima dari Supabase!');
            checkNewSOS();
          },
        )
        ..subscribe();
    } catch (e) {
      debugPrint('⚠️ Error setting up realtime SOS subscription: $e');
    }
  }

  /// Cek insiden SOS baru dari Supabase dan SQLite
  Future<void> checkNewSOS() async {
    if (!_isMonitoring || _gunungId == null) return;

    try {
      // Tarik data aktif dari Supabase jika online
      if (SupabaseService.instance.isInitialized) {
        final remoteSos = await SupabaseService.instance.getActiveSOSIncidents();
        for (final inc in remoteSos) {
          await DatabaseService.instance.insertSosIncident(inc);
        }
      }

      // Filter SOS darurat khusus gunung ini atau darurat umum
      final activeSos = await DatabaseService.instance.getActiveSOSIncidentsForBasecamp(
        gunungId: _gunungId!,
        basecampId: _basecampId,
      );

      for (final inc in activeSos) {
        if (!_knownSosIds.contains(inc.id)) {
          _knownSosIds.add(inc.id);
          await _triggerEmergencyAlarm(inc);
        }
      }

      _notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error checking SOS in background: $e');
    }
  }

  /// Pemicu alarm darurat penuh saat menerima sinyal SOS baru
  Future<void> _triggerEmergencyAlarm(SosIncident inc) async {
    debugPrint('🚨 DARURAT TERDETEKSI DI BACKGROUND: ${inc.namaPendaki} (${inc.id})');

    // 1. Getaran hebat & alert haptic
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    // 2. Tampilkan notifikasi darurat prioritas tertinggi (Heads-up / Alarm Notification)
    await NotificationService.instance.showSOSNotification(
      title: '🚨 DARURAT PENDAKI DI ${_mountainName.toUpperCase()}!',
      body: 'Pendaki ${inc.namaPendaki ?? 'Siaga'} mengirim sinyal SOS (${inc.koordinatLat.toStringAsFixed(4)}, ${inc.koordinatLong.toStringAsFixed(4)})! Buka untuk tindakan SAR.',
      payload: 'basecamp_sos',
    );

    // 3. Bangunkan layar HP dan bawa aplikasi ke depan jika layar sedang mati / terkunci
    const platform = MethodChannel('com.example.timurlang/emergency_launcher');
    try {
      await platform.invokeMethod('bringToFront', {'route': '/basecamp'});
    } catch (e) {
      debugPrint('Error invoke bringToFront: $e');
    }
  }

  /// Hentikan pemantauan saat logout
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
    } catch (_) {}

    // Hentikan native Android Foreground Service
    const platform = MethodChannel('com.example.timurlang/emergency_launcher');
    try {
      await platform.invokeMethod('stopBasecampService');
    } catch (_) {}

    await NotificationService.instance.dismissOngoingBasecampMonitoringNotification();
    _knownSosIds.clear();
    _notifyListeners();
    debugPrint('🛑 Radar Siaga Basecamp Dimatikan');
  }

  /// Minta izin bebas optimasi baterai agar Android tidak membunuh service di HP vendor tertentu (Xiaomi, Samsung, dll)
  Future<void> requestIgnoreBatteryOptimizations() async {
    const platform = MethodChannel('com.example.timurlang/emergency_launcher');
    try {
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }
}
