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

      final dataAnggota = _args['dataAnggota'] as String?;

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
        dataAnggota: dataAnggota,
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
    final double hargaSimaksi = (_args['hargaSimaksi'] as num?)?.toDouble() ?? 15000.0;
    final totalBiayaIDR = _args['totalBiayaIDR'] as double;
    final convertedCost = CurrencyUtils.convertFromIDR(totalBiayaIDR, _selectedCurrency);
    final displayPrice = CurrencyUtils.formatCurrency(convertedCost, _selectedCurrency);
    final membersList = _args['membersList'] as List<dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: SingleChildScrollView(
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
                  _summaryRow('Tarif SIMAKSI', 'Rp ${hargaSimaksi.toInt()} / orang'),
                  const SizedBox(height: 8),
                  _summaryRow('Durasi', '${(_args['tanggalTurun'] as DateTime).difference(_args['tanggalNaik'] as DateTime).inDays + 1} Hari'),
                  if (namaBasecamp != null) ...[
                    const SizedBox(height: 8),
                    _summaryRow('Basecamp', namaBasecamp),
                  ],

                  // Rincian Anggota
                  if (membersList != null && membersList.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.groups, size: 16, color: AppTheme.accentOrange),
                        SizedBox(width: 6),
                        Text(
                          'Daftar Pendaki:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < membersList.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              membersList[i]['is_ketua'] == true ? '👑 ' : '👤 ',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Expanded(
                              child: Text(
                                '${membersList[i]['nama'] ?? '-'}${membersList[i]['is_ketua'] == true ? ' (Ketua)' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: membersList[i]['is_ketua'] == true ? FontWeight.bold : FontWeight.normal,
                                  color: Colors.white70,
                                ),
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
            const SizedBox(height: 24),
            
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
            
            const SizedBox(height: 36),
            
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
                  const SizedBox(height: 4),
                  Text(
                    '(${_args['jumlahAnggota']} Orang x Rp ${hargaSimaksi.toInt()})',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
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
                  'Tunjukkan QR ini ke pos Basecamp untuk verifikasi check-in.\n(QR Code ini bersifat sekali pakai dan otomatis hangus setelah di-scan)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 14),

                // Persyaratan Hardfile di Basecamp
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningYellow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.assignment_late_outlined, color: AppTheme.warningYellow, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PERSYARATAN DI BASECAMP:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.warningYellow,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tiap pendaki (ketua & seluruh anggota) WAJIB membawa hardfile Surat Keterangan Sehat dan Kartu Identitas Asli (KTP/identitas diri) untuk verifikasi di pos basecamp.',
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
