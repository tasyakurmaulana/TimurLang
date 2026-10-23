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
import '../../services/midtrans_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/time_zone_helper.dart';
import 'midtrans_payment_screen.dart';

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
    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final mountain = _args['mountain'] as Mountain;
    final totalBiayaIDR = _args['totalBiayaIDR'] as double;
    final hargaSimaksi = (_args['hargaSimaksi'] as num?)?.toDouble() ?? 15000.0;
    final jumlahAnggota = _args['jumlahAnggota'] as int;

    // Cek apakah Server Key Midtrans sudah diatur
    if (!MidtransService.instance.isConfigured) {
      _showKeyNotConfiguredDialog();
      return;
    }

    setState(() => _isProcessing = true);

    final orderId = 'SIMAKSI-${DateTime.now().millisecondsSinceEpoch}';

    final snapResult = await MidtransService.instance.createSnapTransaction(
      orderId: orderId,
      grossAmount: totalBiayaIDR.toInt(),
      customerName: user.namaLengkap,
      customerEmail: user.email,
      itemName: 'SIMAKSI ${mountain.namaGunung}',
      itemPrice: hargaSimaksi.toInt(),
      quantity: jumlahAnggota,
    );

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (!snapResult.success || snapResult.redirectUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghubungkan ke Midtrans: ${snapResult.message}'),
          backgroundColor: AppTheme.dangerRed,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Buka WebView Midtrans Snap untuk pembayaran
    final isPaid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MidtransPaymentScreen(
          orderId: orderId,
          redirectUrl: snapResult.redirectUrl!,
          mountainName: mountain.namaGunung,
          totalAmount: totalBiayaIDR.toInt(),
        ),
      ),
    );

    if (isPaid == true) {
      await _issuePermitAfterPayment();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran belum diselesaikan atau dibatalkan.'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    }
  }

  void _showKeyNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_outlined, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text('Kunci Midtrans Belum Diatur', style: TextStyle(fontSize: 16, color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Key Midtrans belum dimasukkan pada file:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              'lib/config/constants.dart -> midtransServerKey',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Apakah Anda ingin melakukan Simulasi Pembayaran Berhasil untuk pengujian sekarang?',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _issuePermitAfterPayment();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simulasi Bayar'),
          ),
        ],
      ),
    );
  }

  Future<void> _issuePermitAfterPayment() async {
    setState(() => _isProcessing = true);
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final mountain = _args['mountain'] as Mountain;
      final totalBiayaIDR = _args['totalBiayaIDR'] as double;
      final convertedCost = CurrencyUtils.convertFromIDR(totalBiayaIDR, _selectedCurrency);
      final basecampId = _args['basecampId'] as String?;
      final namaBasecamp = _args['namaBasecamp'] as String?;
      final dataAnggota = _args['dataAnggota'] as String?;

      final permit = await BlockchainService.instance.createPermit(
        userId: user.id,
        gunungId: mountain.id,
        basecampId: basecampId,
        namaBasecamp: namaBasecamp,
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
      if (mounted) {
        setState(() => _isProcessing = false);
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
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mountain.namaGunung, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  if (namaBasecamp != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Via $namaBasecamp',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Divider(height: 24, color: AppTheme.border),
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
                    const Divider(height: 24, color: AppTheme.border),
                    const Row(
                      children: [
                        Icon(Icons.groups, size: 16, color: AppTheme.secondary),
                        SizedBox(width: 6),
                        Text(
                          'Daftar Pendaki:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
                            Icon(
                              membersList[i]['is_ketua'] == true ? Icons.star_rounded : Icons.person_outline_rounded,
                              size: 15,
                              color: membersList[i]['is_ketua'] == true ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${membersList[i]['nama'] ?? '-'}${membersList[i]['is_ketua'] == true ? ' (Ketua)' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: membersList[i]['is_ketua'] == true ? FontWeight.bold : FontWeight.normal,
                                  color: AppTheme.textSecondary,
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
            const Text('Pilih Mata Uang', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButton<String>(
                value: _selectedCurrency,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: AppTheme.surface,
                items: CurrencyUtils.availableCurrencies.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: AppTheme.textPrimary)));
                }).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v!),
              ),
            ),
            
            const SizedBox(height: 36),
            
            // Total Price
            Center(
              child: Column(
                children: [
                  const Text('Total Pembayaran', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    displayPrice,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(${_args['jumlahAnggota']} Orang x Rp ${hargaSimaksi.toInt()})',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
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
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 44),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pembayaran Berhasil!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tiket Digital Berbasis Blockchain Diterbitkan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                // QR Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                    color: AppTheme.primarySubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 12, color: AppTheme.secondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Hash: ${permit.blockHash.substring(0, 16)}...',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textPrimary),
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
                        child: const Icon(Icons.copy, size: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tunjukkan QR ini ke pos Basecamp untuk verifikasi check-in.\n(QR Code ini bersifat sekali pakai dan otomatis hangus setelah di-scan)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),

                // Jadwal Check-in Basecamp
                Builder(
                  builder: (context) {
                    final zone = TimeZoneHelper.getMountainTimeZone(mountainName: permit.namaGunung);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Jadwal Check-in Basecamp Resmi',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  '07:00 - 16:00 $zone (${TimeZoneHelper.getTimeZoneFullName(zone)})',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Persyaratan Hardfile di Basecamp
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.assignment_late_outlined, color: Color(0xFF92400E), size: 20),
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
                                color: Color(0xFF92400E),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tiap pendaki (ketua & seluruh anggota) WAJIB membawa hardfile Surat Keterangan Sehat dan Kartu Identitas Asli (KTP/identitas diri) untuk verifikasi di pos basecamp.',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF78350F),
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
                      backgroundColor: AppTheme.primary,
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
