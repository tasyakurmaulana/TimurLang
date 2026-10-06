// ============================================
// TimurLang - Compass Screen
// ============================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../../config/theme.dart';
import '../../services/sensor_service.dart';

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  double _heading = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kompas Orientasi')),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          _heading = snapshot.data?.heading ?? 0;
          if (_heading < 0) _heading += 360;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_heading.toStringAsFixed(0)}°',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              Text(
                SensorService.getCardinalDirectionFull(_heading),
                style: const TextStyle(fontSize: 24, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 50),
              
              // Compass UI
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cardDark,
                    border: Border.all(color: AppTheme.primaryGreen, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Compass Dial (Rotates)
                      Transform.rotate(
                        angle: (_heading * (pi / 180) * -1),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // N S E W Markers
                            _buildMarker('U', Alignment.topCenter, AppTheme.dangerRed),
                            _buildMarker('S', Alignment.bottomCenter, Colors.white),
                            _buildMarker('T', Alignment.centerRight, Colors.white),
                            _buildMarker('B', Alignment.centerLeft, Colors.white),
                            
                            // Tick marks
                            for (int i = 0; i < 360; i += 15)
                              Transform.rotate(
                                angle: i * pi / 180,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    width: i % 90 == 0 ? 4 : 2,
                                    height: i % 90 == 0 ? 15 : 10,
                                    color: i == 0 ? AppTheme.dangerRed : Colors.white54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Center indicator (Fixed)
                      const Icon(Icons.arrow_upward, size: 40, color: AppTheme.primaryGreen),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Pastikan perangkat berada dalam posisi datar (horizontal) dan jauh dari medan magnet untuk akurasi optimal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildMarker(String label, Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          label,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
