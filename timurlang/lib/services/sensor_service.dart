// ============================================
// TimurLang - Sensor Service
// Accelerometer (fall detection) & Gyroscope (compass)
// ============================================

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../config/constants.dart';

class SensorService {
  static final SensorService instance = SensorService._internal();
  SensorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Fall detection state
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;
  DateTime? _lastFallDetection;

  // Compass state
  double _heading = 0;
  double get heading => _heading;
  double _pitch = 0;
  double get pitch => _pitch;
  double _roll = 0;
  double get roll => _roll;

  // Callbacks
  Function()? onFallDetected;
  Function(double heading, double pitch, double roll)? onCompassUpdate;

  /// Start fall detection monitoring
  void startFallDetection() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((AccelerometerEvent event) {
      _processFallDetection(event);
    });
  }

  /// Stop fall detection
  void stopFallDetection() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void _processFallDetection(AccelerometerEvent event) {
    // Hitung total percepatan vektor (X, Y, Z)
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Normal gravitasi ~9.8 m/s², konversi ke satuan G
    final gForce = magnitude / 9.8;

    // Deteksi benturan / guncangan hebat (> 2.5G) atau kondisi melayang bebas (< 0.3G)
    if (gForce > AppConstants.fallThresholdG || gForce < AppConstants.fallFreefallThreshold) {
      // Debounce: 15 detik agar tidak memicu berkali-kali dalam satu benturan
      final now = DateTime.now();
      if (_lastFallDetection != null &&
          now.difference(_lastFallDetection!).inSeconds < 15) {
        return;
      }

      _lastFallDetection = now;
      onFallDetected?.call();
    }
  }

  /// Start compass/gyroscope readings
  void startCompass() {
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((GyroscopeEvent event) {
      // Integrate gyroscope data for orientation
      _heading = (_heading + event.z * 0.05 * 180 / pi) % 360;
      if (_heading < 0) _heading += 360;
      _pitch = event.x * 180 / pi;
      _roll = event.y * 180 / pi;

      onCompassUpdate?.call(_heading, _pitch, _roll);
    });
  }

  /// Stop compass
  void stopCompass() {
    _gyroSubscription?.cancel();
    _gyroSubscription = null;
  }

  /// Get cardinal direction from heading
  static String getCardinalDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'U';
    if (heading >= 22.5 && heading < 67.5) return 'TL';
    if (heading >= 67.5 && heading < 112.5) return 'T';
    if (heading >= 112.5 && heading < 157.5) return 'TG';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'BD';
    if (heading >= 247.5 && heading < 292.5) return 'B';
    return 'BL';
  }

  static String getCardinalDirectionFull(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'Utara';
    if (heading >= 22.5 && heading < 67.5) return 'Timur Laut';
    if (heading >= 67.5 && heading < 112.5) return 'Timur';
    if (heading >= 112.5 && heading < 157.5) return 'Tenggara';
    if (heading >= 157.5 && heading < 202.5) return 'Selatan';
    if (heading >= 202.5 && heading < 247.5) return 'Barat Daya';
    if (heading >= 247.5 && heading < 292.5) return 'Barat';
    return 'Barat Laut';
  }

  /// Dispose all subscriptions
  void dispose() {
    stopFallDetection();
    stopCompass();
  }
}
