// ============================================
// TimurLang - Ticket Verification Screen
// Supports QR Code Camera Scanning & Blockchain Verification
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/blockchain_service.dart';
import '../../models/simaksi_permit.dart';
import '../../widgets/custom_text_field.dart';
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

  Future<void> _verifyHash([String? inputHash]) async {
    final hash = (inputHash ?? _hashCtrl.text).replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\r\n]'), '').trim();
    if (hash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap masukkan atau pindai hash tiket')),
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
    await Future.delayed(const Duration(milliseconds: 400));

    final result = await BlockchainService.instance.verifyTicket(hash);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        _isValid = result.valid;
        _message = result.message;
        _permit = result.permit;
      });
    }
  }

  Future<void> _openQrScanner() async {
    final scannedCode = await QRScannerModal.scan(context);
    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      HapticFeedback.mediumImpact();
      _verifyHash(scannedCode);
    }
  }

  Future<void> _processCheckIn() async {
    if (_permit == null || !_isValid) return;

    final result = await BlockchainService.instance.checkInPermit(_permit!.blockHash);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.safeGreen : AppTheme.dangerRed,
        ),
      );
      if (result.success) {
        setState(() {
          _permit = null;
          _hashCtrl.clear();
          _message = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Tiket Simaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick QR Scanner Hero Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentOrange.withValues(alpha: 0.18),
                    AppTheme.primaryGreen.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.35)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner, size: 40, color: AppTheme.accentOrange),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pindai QR Tiket Pendaki',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pindai QR code tiket untuk memverifikasi integritas Block Hash SHA-256 secara langsung.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _openQrScanner,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Buka Kamera Pemindai QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ATAU MASUKKAN MANUAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
              ],
            ),
            const SizedBox(height: 16),

            // Manual Hash Input
            CustomTextField(
              controller: _hashCtrl,
              label: 'Block Hash SHA-256',
              hint: 'Tempelkan hash tiket pendaki di sini',
              prefixIcon: Icons.fingerprint,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : () => _verifyHash(),
                icon: _isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('Verifikasi Integritas Blockchain'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cardDark,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      ? AppTheme.safeGreen.withValues(alpha: 0.12)
                      : AppTheme.dangerRed.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _isValid ? AppTheme.safeGreen : AppTheme.dangerRed,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isValid ? Icons.verified_user : Icons.gpp_bad,
                      color: _isValid ? AppTheme.safeGreen : AppTheme.dangerRed,
                      size: 42,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isValid ? 'DATA BLOCKCHAIN VALID' : 'VERIFIKASI GAGAL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _isValid ? AppTheme.safeGreen : AppTheme.dangerRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _isValid ? Colors.white : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Permit Data Card
            if (_permit != null && _isValid) ...[
              const Text(
                'Data Izin Pendakian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dataRow('ID Pendaki', _permit!.userId),
                    const Divider(height: 16),
                    _dataRow('Gunung', _permit!.namaGunung ?? _permit!.gunungId),
                    const Divider(height: 16),
                    _dataRow('Rombongan', '${_permit!.jumlahAnggota} Orang'),
                    const Divider(height: 16),
                    _dataRow('Status Tiket', _permit!.statusIzin),
                    const Divider(height: 16),
                    _dataRow(
                      'Block Hash',
                      '${_permit!.blockHash.substring(0, 16)}... (Valid SHA-256)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _processCheckIn,
                  icon: const Icon(Icons.check_circle_outline),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.safeGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'Konfirmasi Pendaki Naik (Check-in)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
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
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white54)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
