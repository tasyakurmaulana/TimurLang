// ============================================
// TimurLang - Ticket Verification Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/blockchain_service.dart';
import '../../models/simaksi_permit.dart';
import '../../widgets/custom_text_field.dart';

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

  Future<void> _verifyHash() async {
    final hash = _hashCtrl.text.trim();
    if (hash.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _permit = null;
      _message = null;
    });

    // Simulate short delay for UI effect
    await Future.delayed(const Duration(milliseconds: 500));

    final result = await BlockchainService.instance.verifyTicket(hash);

    setState(() {
      _isVerifying = false;
      _isValid = result.valid;
      _message = result.message;
      _permit = result.permit;
    });
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
      appBar: AppBar(title: const Text('Verifikasi Tiket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan Block Hash Tiket',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _hashCtrl,
              label: 'Hash SHA-256',
              hint: 'Tempelkan hash tiket pendaki di sini',
              prefixIcon: Icons.fingerprint,
              maxLines: 2,
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : _verifyHash,
                icon: _isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search),
                label: const Text('Verifikasi Integritas Data'),
              ),
            ),
            const SizedBox(height: 32),

            if (_message != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isValid ? AppTheme.safeGreen.withValues(alpha: 0.1) : AppTheme.dangerRed.withValues(alpha: 0.1),
                  border: Border.all(color: _isValid ? AppTheme.safeGreen : AppTheme.dangerRed),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle : Icons.error,
                      color: _isValid ? AppTheme.safeGreen : AppTheme.dangerRed,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isValid ? AppTheme.safeGreen : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (_permit != null && _isValid) ...[
              const Text('Data Perizinan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dataRow('ID Pendaki', _permit!.userId),
                    const Divider(),
                    _dataRow('Gunung', _permit!.namaGunung ?? _permit!.gunungId),
                    const Divider(),
                    _dataRow('Anggota', '${_permit!.jumlahAnggota} Orang'),
                    const Divider(),
                    _dataRow('Status Saat Ini', _permit!.statusIzin),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _processCheckIn,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentOrange),
                  child: const Text('Konfirmasi Pendaki Naik (Check-in)'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.white54))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
