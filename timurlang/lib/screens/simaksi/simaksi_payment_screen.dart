// ============================================
// TimurLang - Simaksi Payment Screen
// Currency Conversion included
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
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

      await BlockchainService.instance.createPermit(
        userId: user.id,
        gunungId: mountain.id,
        tanggalNaik: _args['tanggalNaik'] as DateTime,
        tanggalTurun: _args['tanggalTurun'] as DateTime,
        jumlahAnggota: _args['jumlahAnggota'] as int,
        namaGunung: mountain.namaGunung,
        totalBiaya: convertedCost,
        matauang: _selectedCurrency,
      );

      if (mounted) {
        // Pop until home, then go to tickets
        Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
        Navigator.pushNamed(context, AppRoutes.simaksiTicket);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil! Tiket digital telah dibuat.'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );
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
                  const Divider(height: 24),
                  _summaryRow('Rombongan', '${_args['jumlahAnggota']} Orang'),
                  const SizedBox(height: 8),
                  _summaryRow('Durasi', '${(_args['tanggalTurun'] as DateTime).difference(_args['tanggalNaik'] as DateTime).inDays + 1} Hari'),
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
}
