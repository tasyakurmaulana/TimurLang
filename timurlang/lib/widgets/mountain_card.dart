// ============================================
// TimurLang - Mountain Card Widget
// ============================================

import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/mountain.dart';

class MountainCard extends StatelessWidget {
  final Mountain mountain;
  final VoidCallback onTap;

  const MountainCard({
    super.key,
    required this.mountain,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (mountain.statusJalur) {
      case 'Buka':
        return AppTheme.safeGreen;
      case 'Tutup':
        return AppTheme.dangerRed;
      default:
        return AppTheme.warningYellow;
    }
  }

  IconData _getGradeIcon() {
    if (mountain.tingkatBahaya.contains('1')) return Icons.sentiment_satisfied;
    if (mountain.tingkatBahaya.contains('2')) return Icons.sentiment_neutral;
    if (mountain.tingkatBahaya.contains('3')) return Icons.warning_amber;
    if (mountain.tingkatBahaya.contains('4')) return Icons.dangerous;
    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.darkCardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.mountainGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.terrain, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mountain.namaGunung,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mountain.elevasiMdpl} mdpl',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      mountain.statusJalur,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(Icons.speed, mountain.tingkatBahaya.split(' - ').first, _getGradeIcon()),
                  const SizedBox(width: 8),
                  _infoChip(
                    mountain.sumberAirTersedia ? Icons.water_drop : Icons.water_drop_outlined,
                    mountain.sumberAirTersedia ? 'Air ✓' : 'Air ✗',
                    null,
                  ),
                  const SizedBox(width: 8),
                  if (mountain.kuotaHarian != null)
                    _infoChip(Icons.people, '${mountain.kuotaHarian}/hari', null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, IconData? altIcon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(altIcon ?? icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
