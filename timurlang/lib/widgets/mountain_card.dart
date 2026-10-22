// ============================================
// TimurLang - Mountain Card Widget
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1),
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
                      color: AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4E0D2), width: 1),
                    ),
                    child: const Icon(Icons.terrain_rounded, color: AppTheme.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mountain.namaGunung,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${mountain.elevasiMdpl} MDPL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      mountain.statusJalur,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(altIcon ?? icon, size: 13, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
