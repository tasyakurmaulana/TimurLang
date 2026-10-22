// ============================================
// TimurLang - Ticket Card Widget
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/simaksi_permit.dart';
import '../utils/date_utils.dart';

class TicketCard extends StatelessWidget {
  final SimaksiPermit permit;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.permit, this.onTap});

  /// QR hanya aktif saat tiket baru terdaftar / diajukan.
  /// Setelah di-scan dan divalidasi oleh Basecamp (Di Jalur, Selesai, Ditolak),
  /// QR code otomatis hangus / hilang (single-use).
  bool get _isQrActive =>
      permit.statusIzin == AppConstants.statusTerdaftar ||
      permit.statusIzin == AppConstants.statusDiajukan;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _info('Rombongan', '${permit.jumlahAnggota} orang'),
                      if (permit.members.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showMembersDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.skyBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt_outlined, size: 13, color: AppTheme.skyBlue),
                                SizedBox(width: 4),
                                Text(
                                  'Lihat Anggota',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.skyBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // QR Code Section (Single-Use: hanya muncul saat belum divalidasi)
                  if (_isQrActive) ...[
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
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 12, color: AppTheme.skyBlue),
                            SizedBox(width: 6),
                            Text(
                              'QR Sekali Pakai (Hangus setelah di-scan Basecamp)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.skyBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    _buildUsedQrSection(context),
                  ],

                  // Keterangan Wajib Bawa Berkas Hardfile
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningYellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppTheme.warningYellow),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Persyaratan Wajib di Basecamp:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.warningYellow,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Setiap pendaki (ketua & seluruh anggota) wajib membawa hardfile Surat Keterangan Sehat dan Kartu Identitas Diri asli (KTP) untuk verifikasi di pos basecamp.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildUsedQrSection(BuildContext context) {
    final isDiJalur = permit.statusIzin == AppConstants.statusDiJalur ||
        permit.statusIzin == AppConstants.statusTervalidasi;
    final isSelesai = permit.statusIzin == AppConstants.statusSelesai;
    final isDitolak = permit.statusIzin == AppConstants.statusDitolak;

    final Color primaryColor = isDiJalur
        ? AppTheme.safeGreen
        : isSelesai
            ? AppTheme.mistGrey
            : isDitolak
                ? AppTheme.dangerRed
                : AppTheme.warningYellow;

    final IconData icon = isDiJalur
        ? Icons.verified
        : isSelesai
            ? Icons.task_alt
            : isDitolak
                ? Icons.cancel_outlined
                : Icons.info_outline;

    final String title = isDiJalur
        ? 'QR SEKALI PAKAI TELAH DIGUNAKAN'
        : isSelesai
            ? 'PENDAKIAN TELAH SELESAI'
            : isDitolak
                ? 'TIKET DITOLAK'
                : 'QR CODE SUDAH TIDAK AKTIF';

    final String subtitle = isDiJalur
        ? 'Tiket telah berhasil divalidasi oleh petugas Basecamp. Pendaki resmi terdaftar & sedang berada di jalur.'
        : isSelesai
            ? 'Pendakian dan check-out telah selesai. Tiket ini sudah tidak berlaku lagi.'
            : isDitolak
                ? 'Pengajuan izin pendakian ditolak oleh pihak pengelola.'
                : 'QR Code telah dinonaktifkan.';

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryColor, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDiJalur ? Icons.hiking : Icons.check_circle_outline,
                    size: 14,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Status: ${permit.statusIzin}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
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

  void _showQrDialog(BuildContext context) {
    if (!_isQrActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR Code sekali pakai ini sudah tervalidasi dan hangus (Status: ${permit.statusIzin}).',
          ),
          backgroundColor: AppTheme.cardDark,
        ),
      );
      return;
    }

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
                'Tunjukkan ke petugas Basecamp untuk validasi Blockchain.\n(QR Code ini hanya berlaku sekali)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.45)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 16, color: AppTheme.warningYellow),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setiap pendaki (ketua & anggota) wajib membawa hardfile Surat Sehat dan KTP asli saat di pos basecamp.',
                        style: TextStyle(fontSize: 10.5, color: Colors.white, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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

  void _showMembersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups, color: AppTheme.accentOrange, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anggota Rombongan (${permit.jumlahAnggota} Orang)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 350),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: permit.members.length,
                  itemBuilder: (context, i) {
                    final m = permit.members[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: m.isKetua
                              ? AppTheme.primaryGreen.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m.isKetua ? '👑 ' : '👤 ', style: const TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  m.nama,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                ),
                              ),
                              if (m.isKetua)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Ketua', style: TextStyle(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.home_outlined, size: 14, color: Colors.white38),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.alamat,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: AppTheme.skyBlue),
                              const SizedBox(width: 6),
                              Text(
                                'Darurat: ${m.kontakDarurat}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.skyBlue, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
