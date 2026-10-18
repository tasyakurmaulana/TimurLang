// ============================================
// TimurLang - Ticket Card Widget
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
                  const SizedBox(height: 16),
                  // QR Code Section
                  Center(
                    child: GestureDetector(
                      onTap: () => _showQrDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: permit.blockHash,
                              version: QrVersions.auto,
                              size: 150.0,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen, size: 14, color: Color(0xFF475569)),
                                SizedBox(width: 4),
                                Text(
                                  'Ketuk untuk memperbesar QR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                            const Icon(Icons.security, size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            const Text(
                              'BLOCKCHAIN HASH (SHA-256)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
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

  void _showQrDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: AppTheme.accentOrange, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'QR Tiket Simaksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: permit.blockHash,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                permit.namaGunung ?? 'Gunung',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tunjukkan ke petugas Basecamp untuk validasi Blockchain',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 12, color: AppTheme.safeGreen),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Hash: ${permit.blockHash.substring(0, 16)}...',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
