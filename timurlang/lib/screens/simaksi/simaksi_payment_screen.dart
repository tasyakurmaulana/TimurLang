// ============================================
// TimurLang - Simaksi Payment Screen
// Currency Conversion included
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../models/simaksi_permit.dart';
import '../../services/auth_service.dart';
import '../../services/blockchain_service.dart';
import '../../utils/currency_utils.dart';

class SimaksiPaymentScreen extends StatefulWidget {
  const SimaksiPaymentScreen({super.key});

  @override
  State<SimaksiPaymentScreen> createState() => _SimaksiPaymentScreenState();
}

class _SimaksiPaymentScreenState extends State<SimaksiPaymentScreen> {
  late Map<String, dynamic> _args;
  String _selectedCurrency = 'IDR';
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2)); // Mock payment processing

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final mountain = _args['mountain'] as Mountain;
      final totalBiayaIDR = _args['totalBiayaIDR'] as double;
      final convertedCost = CurrencyUtils.convertFromIDR(totalBiayaIDR, _selectedCurrency);
      final basecampId = _args['basecampId'] as String?;

      final permit = await BlockchainService.instance.createPermit(
        userId: user.id,
        gunungId: mountain.id,
        basecampId: basecampId,
        tanggalNaik: _args['tanggalNaik'] as DateTime,
        tanggalTurun: _args['tanggalTurun'] as DateTime,
        jumlahAnggota: _args['jumlahAnggota'] as int,
        namaGunung: mountain.namaGunung,
        totalBiaya: convertedCost,
        matauang: _selectedCurrency,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        _showSuccessDialog(permit);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppTheme.dangerRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_args.isEmpty) return const Scaffold();

    final mountain = _args['mountain'] as Mountain;
    final namaBasecamp = _args['namaBasecamp'] as String?;
    final totalBiayaIDR = _args['totalBiayaIDR'] as double;
    final convertedCost = CurrencyUtils.convertFromIDR(totalBiayaIDR, _selectedCurrency);
    final displayPrice = CurrencyUtils.formatCurrency(convertedCost, _selectedCurrency);

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mountain.namaGunung, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (namaBasecamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Via $namaBasecamp',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Divider(height: 24),
                  _summaryRow('Rombongan', '${_args['jumlahAnggota']} Orang'),
                  const SizedBox(height: 8),
                  _summaryRow('Durasi', '${(_args['tanggalTurun'] as DateTime).difference(_args['tanggalNaik'] as DateTime).inDays + 1} Hari'),
                  if (namaBasecamp != null) ...[
                    const SizedBox(height: 8),
                    _summaryRow('Basecamp', namaBasecamp),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Currency Converter
            const Text('Pilih Mata Uang', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedCurrency,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppTheme.cardDarkElevated,
                items: CurrencyUtils.availableCurrencies.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
            ),
            
            const Spacer(),
            
            // Total Price
            Center(
              child: Column(
                children: [
                  const Text('Total Pembayaran', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 4),
                  Text(
                    displayPrice,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Pay button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Bayar Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSuccessDialog(SimaksiPermit permit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.safeGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 44),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pembayaran Berhasil!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tiket Digital Berbasis Blockchain Diterbitkan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 16),
                // QR Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: permit.blockHash,
                    version: QrVersions.auto,
                    size: 160.0,
                    backgroundColor: Colors.white,
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
                      const Icon(Icons.lock, size: 12, color: AppTheme.accentOrange),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Hash: ${permit.blockHash.substring(0, 16)}...',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: permit.blockHash));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hash disalin')),
                          );
                        },
                        child: const Icon(Icons.copy, size: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tunjukkan QR ini ke pos Basecamp untuk verifikasi izin pendakian.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
                      Navigator.pushNamed(context, AppRoutes.simaksiTicket);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Buka Tiket Saya'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
