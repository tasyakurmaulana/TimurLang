// ============================================
// TimurLang - Compass Screen
// Oriented with Aura Travel Design System
// ============================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Kompas',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<CompassEvent>(
        stream: FlutterCompass.events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Sensor tidak tersedia: ${snapshot.error}',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.error),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          _heading = snapshot.data?.heading ?? 0;
          if (_heading < 0) _heading += 360;

          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Heading Degrees & Cardinal Label
                Column(
                  children: [
                    Text(
                      '${_heading.toStringAsFixed(0)}°',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: const Color(0xFFD4E0D2)),
                      ),
                      child: Text(
                        SensorService.getCardinalDirectionFull(_heading),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. High-Contrast Tactical Compass Dial
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.primary, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inner decorative ring
                        Container(
                          width: 236,
                          height: 236,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.border, width: 1),
                          ),
                        ),

                        // Compass Dial Face (Rotates with heading)
                        Transform.rotate(
                          angle: (_heading * (pi / 180) * -1),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // N S E W Cardinal Markers (Dark high-contrast text, U in red)
                              _buildMarker('U', Alignment.topCenter, const Color(0xFFDC2626)),
                              _buildMarker('S', Alignment.bottomCenter, AppTheme.textPrimary),
                              _buildMarker('T', Alignment.centerRight, AppTheme.textPrimary),
                              _buildMarker('B', Alignment.centerLeft, AppTheme.textPrimary),

                              // Intercardinal Markers
                              _buildSubMarker('TL', 45),
                              _buildSubMarker('TG', 135),
                              _buildSubMarker('BD', 225),
                              _buildSubMarker('BL', 315),

                              // Tick marks around perimeter (High Contrast)
                              for (int i = 0; i < 360; i += 15)
                                Transform.rotate(
                                  angle: i * pi / 180,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      width: i % 90 == 0 ? 3.5 : (i % 45 == 0 ? 2.5 : 1.5),
                                      height: i % 90 == 0 ? 14 : (i % 45 == 0 ? 10 : 6),
                                      decoration: BoxDecoration(
                                        color: i == 0
                                            ? const Color(0xFFDC2626)
                                            : (i % 90 == 0
                                                ? AppTheme.textPrimary
                                                : (i % 45 == 0 ? AppTheme.primary : AppTheme.border)),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Center Reference Pointer (Fixed Heading Line)
                        const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 28,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),

                        // Center Indicator Hub
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.navigation_rounded,
                              size: 24,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. User Guidance Notice Card (Clear dark text on white surface)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textPrimary.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.screen_rotation_alt_rounded,
                          size: 20,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Posisikan perangkat mendatar (horizontal) dan jauhkan dari interferensi logam untuk akurasi optimal.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarker(String label, Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSubMarker(String label, double angleDegree) {
    return Transform.rotate(
      angle: angleDegree * pi / 180,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 25),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
