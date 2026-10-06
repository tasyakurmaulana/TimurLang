// ============================================
// TimurLang - Ticket Card Widget
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/simaksi_permit.dart';
import '../utils/date_utils.dart';

class TicketCard extends StatelessWidget {
  final SimaksiPermit permit;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.permit, this.onTap});

  Color _getStatusColor() {
    switch (permit.statusIzin) {
      case 'Terdaftar':
        return AppTheme.skyBlue;
      case 'Tervalidasi':
        return AppTheme.safeGreen;
      case 'Di Jalur':
        return AppTheme.accentOrange;
      case 'Selesai':
        return AppTheme.mistGrey;
      case 'Ditolak':
        return AppTheme.dangerRed;
      default:
        return AppTheme.warningYellow;
    }
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
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.mountainGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_num, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'SIMAKSI DIGITAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      permit.statusIzin,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permit.namaGunung ?? 'Gunung',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _info('Naik', AppDateUtils.formatDateIndonesian(permit.tanggalNaik)),
                      const SizedBox(width: 24),
                      _info('Turun', AppDateUtils.formatDateIndonesian(permit.tanggalTurun)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _info('Rombongan', '${permit.jumlahAnggota} orang'),
                  const SizedBox(height: 12),
                  // Hash display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fingerprint, size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            const Text(
                              'BLOCK HASH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: AppTheme.accentOrange,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: permit.blockHash));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Hash disalin ke clipboard')),
                                );
                              },
                              child: const Icon(Icons.copy, size: 14, color: Colors.white38),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          permit.blockHash,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, color: Colors.white70)),
      ],
    );
  }
}
