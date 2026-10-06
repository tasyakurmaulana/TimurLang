// ============================================
// TimurLang - Fall Detection / SOS Screen
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/sos_incident.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sensor_service.dart';
import '../../services/notification_service.dart';

class FallDetectionScreen extends StatefulWidget {
  const FallDetectionScreen({super.key});

  @override
  State<FallDetectionScreen> createState() => _FallDetectionScreenState();
}

class _FallDetectionScreenState extends State<FallDetectionScreen> {
  bool _isMonitoring = false;
  bool _isCountdown = false;
  int _countdown = AppConstants.fallCountdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _isMonitoring = SensorService.instance.isMonitoring;
    SensorService.instance.onFallDetected = _handleFall;
  }

  void _handleFall() {
    if (!mounted) return;
    setState(() {
      _isCountdown = true;
      _countdown = AppConstants.fallCountdownSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _timer?.cancel();
          _triggerSOS(AppConstants.sosFallDetection);
        }
      });
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() => _isCountdown = false);
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
    });

    if (_isMonitoring) {
      SensorService.instance.startFallDetection();
    } else {
      SensorService.instance.stopFallDetection();
    }
  }

  Future<void> _triggerSOS(String type) async {
    setState(() => _isCountdown = false);
    
    // Show notification
    await NotificationService.instance.showSOSNotification(
      title: '🚨 DARURAT SOS AKTIF',
      body: 'Sinyal darurat telah dikirim ke Basecamp!',
    );

    // Save to DB
    final user = AuthService.instance.currentUser;
    if (user != null) {
      final incident = SosIncident(
        id: const Uuid().v4(),
        userId: user.id,
        koordinatLat: -8.108, // Mock GPS
        koordinatLong: 112.922, // Mock GPS
        tipePemicu: type,
        statusPenanganan: AppConstants.sosActive,
        waktuKejadian: DateTime.now(),
        namaPendaki: user.namaLengkap,
        createdAt: DateTime.now(),
      );
      await DatabaseService.instance.insertSosIncident(incident);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinyal SOS telah dikirim!'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountdown) {
      return Scaffold(
        backgroundColor: AppTheme.dangerRed,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 100, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'INDIKASI JATUH TERDETEKSI!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'SOS akan dikirim dalam:',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              Text(
                '$_countdown',
                style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _cancelCountdown,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.dangerRed,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
                child: const Text('SAYA BAIK-BAIK SAJA (BATALKAN)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Keselamatan & SOS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Fall Detection Toggle
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isMonitoring ? AppTheme.safeGreen : Colors.white12,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isMonitoring ? Icons.sensors : Icons.sensors_off,
                    size: 48,
                    color: _isMonitoring ? AppTheme.safeGreen : Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pemantauan Sensor Jatuh',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isMonitoring ? AppTheme.safeGreen : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Menggunakan akselerometer untuk mendeteksi guncangan keras dan otomatis mengirim SOS jika Anda tidak merespons.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: Text(_isMonitoring ? 'Aktif' : 'Nonaktif', style: const TextStyle(fontWeight: FontWeight.bold)),
                    value: _isMonitoring,
                    activeThumbColor: AppTheme.safeGreen,
                    onChanged: (v) => _toggleMonitoring(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Manual SOS Button
            const Text('Aktivasi Manual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GestureDetector(
              onLongPress: () => _triggerSOS(AppConstants.sosManual),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dangerRed,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dangerRed.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, size: 80, color: Colors.white),
                    SizedBox(height: 8),
                    Text('TEHAN LAMA\nUNTUK SOS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
