// ============================================
// TimurLang - Fall Detection / SOS Screen
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/sos_manager.dart';

class FallDetectionScreen extends StatefulWidget {
  const FallDetectionScreen({super.key});

  @override
  State<FallDetectionScreen> createState() => _FallDetectionScreenState();
}

class _FallDetectionScreenState extends State<FallDetectionScreen> {
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _isMonitoring = SosManager.instance.isMonitoring;
    SosManager.instance.addListener(_syncSosState);
  }

  void _syncSosState() {
    if (mounted) {
      setState(() {
        _isMonitoring = SosManager.instance.isMonitoring;
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      await SosManager.instance.stopMonitoring();
    } else {
      await SosManager.instance.startMonitoring();
    }
    if (mounted) {
      setState(() {
        _isMonitoring = SosManager.instance.isMonitoring;
      });
    }
  }

  @override
  void dispose() {
    SosManager.instance.removeListener(_syncSosState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Pemantauan Sensor Jatuh & Guncangan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isMonitoring ? AppTheme.safeGreen : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isMonitoring
                        ? '🛡️ Siaga Aktif: Sensor tetap memantau saat Anda berpindah fitur atau saat aplikasi berada di latar belakang.'
                        : 'Aktifkan pemantau akselerometer untuk mendeteksi guncangan keras/jatuh secara otomatis di mana saja.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isMonitoring ? Colors.lightGreenAccent : Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: Text(
                      _isMonitoring ? 'Siaga SOS Aktif' : 'Siaga SOS Nonaktif',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _isMonitoring ? 'Memantau di latar belakang' : 'Ketuk untuk mengaktifkan',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                    value: _isMonitoring,
                    activeThumbColor: AppTheme.safeGreen,
                    onChanged: (v) => _toggleMonitoring(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Manual SOS Button
            const Text(
              'Aktivasi SOS Manual',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan dan tahan tombol merah di bawah untuk mengirim sinyal darurat langsung beserta posisi GPS Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onLongPress: () => SosManager.instance.triggerManualSOS(),
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dangerRed,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dangerRed.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, size: 76, color: Colors.white),
                    SizedBox(height: 6),
                    Text(
                      'TEKAN LAMA\nUNTUK SOS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
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
