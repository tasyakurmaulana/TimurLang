// ============================================
// TimurLang - Map Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peta Topografi Offline')),
      body: Stack(
        children: [
          // Mock Map Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/mock_map.png'),
                fit: BoxFit.cover,
              ),
              color: Color(0xFF2C3E50), // Fallback map color
            ),
          ),
          // Mock Path and Markers
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: AppTheme.dangerRed, size: 48),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Lokasi Anda', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // Disclaimer overlay
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map, color: AppTheme.primaryGreen),
                  SizedBox(height: 8),
                  Text(
                    'Peta Offline Ter-cache\nData topografi dari Mapbox tersedia untuk digunakan tanpa koneksi internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
