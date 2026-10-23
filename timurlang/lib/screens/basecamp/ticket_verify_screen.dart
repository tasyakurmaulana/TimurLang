// ============================================
// TimurLang - Ticket Verification Screen
// Supports QR Code Camera Scanning & Blockchain Verification
// Aura Travel Design System
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../services/blockchain_service.dart';
import '../../models/simaksi_permit.dart';
import '../../widgets/qr_scanner_modal.dart';

class TicketVerifyScreen extends StatefulWidget {
  const TicketVerifyScreen({super.key});

  @override
  State<TicketVerifyScreen> createState() => _TicketVerifyScreenState();
}

class _TicketVerifyScreenState extends State<TicketVerifyScreen> {
  final _hashCtrl = TextEditingController();
  bool _isVerifying = false;
  SimaksiPermit? _permit;
  String? _message;
  bool _isValid = false;

  @override
  void dispose() {
    _hashCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyHash([String? inputHash, bool autoCheckInOnScan = false]) async {
    final hash = (inputHash ?? _hashCtrl.text).replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\r\n]'), '').trim();
    if (hash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Harap masukkan atau pindai hash tiket', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    _hashCtrl.text = hash;

    setState(() {
      _isVerifying = true;
      _permit = null;
      _message = null;
    });

    // Short delay for verification effect
    await Future.delayed(const Duration(milliseconds: 300));

    final result = await BlockchainService.instance.verifyTicket(hash);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _isValid = result.valid;
        _message = result.message;
        _permit = result.permit;
      });

      // Jika di-scan lewat kamera scanner dan tiket valid (baru/belum pernah dipakai),
      // langsung proses check-in agar QR code sekali pakai ini langsung hangus seketika!
      if (autoCheckInOnScan &&
          result.valid &&
          result.permit != null &&
          (result.permit!.statusIzin == AppConstants.statusTerdaftar ||
              result.permit!.statusIzin == AppConstants.statusDiajukan)) {
        await _processCheckIn();
      }
    }
  }

  Future<void> _openQrScanner() async {
    final scannedCode = await QRScannerModal.scan(context);
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      HapticFeedback.mediumImpact();
      await _verifyHash(scannedCode, true);
    }
  }

  Future<void> _processCheckIn() async {
    if (_permit == null || !_isValid) return;

    final result = await BlockchainService.instance.checkInPermit(_permit!.blockHash);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message, style: GoogleFonts.plusJakartaSans()),
          backgroundColor: result.success ? AppTheme.success : AppTheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
      if (result.success) {
        setState(() {
          _permit = _permit!.copyWith(statusIzin: AppConstants.statusDiJalur);
          _isValid = true;
          _message = result.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Verifikasi Tiket Simaksi',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick QR Scanner Hero Card (Solid Surface, High Contrast)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner, size: 36, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Pindai QR Tiket Pendaki',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pindai QR code tiket untuk memverifikasi integritas Block Hash SHA-256 secara langsung.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openQrScanner,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Buka Kamera Pemindai QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Divider: Or manual
            Row(
              children: [
                const Expanded(child: Divider(color: AppTheme.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'ATAU MASUKKAN MANUAL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppTheme.border)),
              ],
            ),
            const SizedBox(height: 18),

            // Manual Hash Input Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Block Hash SHA-256',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (_hashCtrl.text.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _hashCtrl.text.trim().length == 64
                          ? AppTheme.safeGreen.withValues(alpha: 0.12)
                          : AppTheme.primarySubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_hashCtrl.text.trim().length} / 64 char',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _hashCtrl.text.trim().length == 64
                            ? AppTheme.safeGreen
                            : AppTheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Block Hash TextField
            TextField(
              controller: _hashCtrl,
              minLines: 1,
              maxLines: 2,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _verifyHash(),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                hintText: 'Tempelkan 64 karakter hash tiket di sini...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: const Icon(
                  Icons.fingerprint_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                suffixIcon: _hashCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20, color: AppTheme.textSecondary),
                        onPressed: () {
                          _hashCtrl.clear();
                          setState(() {});
                        },
                        tooltip: 'Hapus',
                      )
                    : IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 20, color: AppTheme.primary),
                        tooltip: 'Tempel dari Clipboard',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          final text = data?.text?.trim();
                          if (text != null && text.isNotEmpty) {
                            _hashCtrl.text = text;
                            if (mounted) setState(() {});
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Hash berhasil ditempel dari clipboard',
                                  style: GoogleFonts.plusJakartaSans(),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : () => _verifyHash(),
                icon: _isVerifying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search, size: 18),
                label: const Text('Verifikasi Integritas Blockchain'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status / Result Message
            if (_message != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isValid
                      ? AppTheme.success.withValues(alpha: 0.08)
                      : AppTheme.error.withValues(alpha: 0.08),
                  border: Border.all(
                    color: _isValid ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.error.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isValid ? Icons.verified_user : Icons.gpp_bad,
                      color: _isValid ? AppTheme.success : AppTheme.error,
                      size: 38,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isValid ? 'DATA BLOCKCHAIN VALID' : 'VERIFIKASI GAGAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: _isValid ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isValid ? AppTheme.textPrimary : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Permit Data Card
            if (_permit != null && _isValid) ...[
              Text(
                'Data Izin Pendakian',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dataRow('ID Pendaki', _permit!.userId),
                    const Divider(height: 16, color: AppTheme.border),
                    _dataRow('Gunung', _permit!.namaGunung ?? _permit!.gunungId),
                    const Divider(height: 16, color: AppTheme.border),
                    _dataRow('Rombongan', '${_permit!.jumlahAnggota} Orang'),
                    const Divider(height: 16, color: AppTheme.border),
                    _dataRow('Status Tiket', _permit!.statusIzin),
                    const Divider(height: 16, color: AppTheme.border),
                    _dataRow(
                      'Block Hash',
                      '${_permit!.blockHash.length > 16 ? _permit!.blockHash.substring(0, 16) : _permit!.blockHash}... (SHA-256 Valid)',
                    ),
                    if (_permit!.members.isNotEmpty) ...[
                      const Divider(height: 20, color: AppTheme.border),
                      Row(
                        children: [
                          const Icon(Icons.groups, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Identitas Anggota Rombongan:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (int i = 0; i < _permit!.members.length; i++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _permit!.members[i].isKetua
                                  ? AppTheme.primary.withValues(alpha: 0.3)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _permit!.members[i].isKetua ? Icons.verified_user : Icons.person_outline_rounded,
                                    size: 16,
                                    color: _permit!.members[i].isKetua ? AppTheme.primary : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _permit!.members[i].nama,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (_permit!.members[i].isKetua)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySubtle,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        'Ketua',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Alamat: ${_permit!.members[i].alamat}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                              Text(
                                'Kontak Darurat: ${_permit!.members[i].kontakDarurat}',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.secondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_permit!.statusIzin == AppConstants.statusTerdaftar ||
                  _permit!.statusIzin == AppConstants.statusDiajukan) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.checklist_rtl_rounded, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pemeriksaan Pos: Pastikan telah menerima hardfile fisik Surat Sehat dan memeriksa Kartu Identitas asli tiap pendaki.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppTheme.textPrimary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _processCheckIn,
                    icon: const Icon(Icons.check_circle_outline),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    label: Text(
                      'Konfirmasi Pendaki Naik (Check-in)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ] else if (_permit!.statusIzin == AppConstants.statusDiJalur) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, color: AppTheme.success, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Pendaki Sudah Check-in (Sedang Di Jalur)',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
