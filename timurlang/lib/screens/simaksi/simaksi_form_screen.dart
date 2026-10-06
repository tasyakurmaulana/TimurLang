// ============================================
// TimurLang - Simaksi Form Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../utils/date_utils.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';

class SimaksiFormScreen extends StatefulWidget {
  const SimaksiFormScreen({super.key});

  @override
  State<SimaksiFormScreen> createState() => _SimaksiFormScreenState();
}

class _SimaksiFormScreenState extends State<SimaksiFormScreen> {
  Mountain? _mountain;
  final _formKey = GlobalKey<FormState>();
  final _anggotaCtrl = TextEditingController(text: '1');
  DateTime? _tanggalNaik;
  DateTime? _tanggalTurun;
  String _selectedTz = 'WIB';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mountain = ModalRoute.of(context)?.settings.arguments as Mountain?;
  }

  Future<void> _pickDate(bool isNaik) async {
    final now = DateTime.now();
    final firstDate = isNaik ? now : (_tanggalNaik ?? now);
    
    final date = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (date != null) {
      setState(() {
        if (isNaik) {
          _tanggalNaik = date;
          // Reset tanggal turun jika lebih awal dari tanggal naik
          if (_tanggalTurun != null && _tanggalTurun!.isBefore(_tanggalNaik!)) {
            _tanggalTurun = null;
          }
        } else {
          _tanggalTurun = date;
        }
      });
    }
  }

  void _proceedToPayment() {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalNaik == null || _tanggalTurun == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal naik dan turun')),
      );
      return;
    }

    final int jumlahAnggota = int.parse(_anggotaCtrl.text);
    // Base cost calculation (mock logic)
    final double baseBiayaPerOrangPerHari = 10000.0;
    final int durasiHari = _tanggalTurun!.difference(_tanggalNaik!).inDays + 1;
    final double totalBiaya = baseBiayaPerOrangPerHari * durasiHari * jumlahAnggota;

    Navigator.pushNamed(
      context,
      AppRoutes.simaksiPayment,
      arguments: {
        'mountain': _mountain,
        'tanggalNaik': _tanggalNaik,
        'tanggalTurun': _tanggalTurun,
        'jumlahAnggota': jumlahAnggota,
        'totalBiayaIDR': totalBiaya,
        'timezone': _selectedTz,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mountain == null) return const Scaffold(body: Center(child: Text('Error')));

    return Scaffold(
      appBar: AppBar(title: const Text('Formulir Simaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mountain Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terrain, color: AppTheme.primaryGreen, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_mountain!.namaGunung, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${_mountain!.elevasiMdpl} mdpl', style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Date Selection
              const Text('Jadwal Pendakian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _datePickerCard('Tanggal Naik', _tanggalNaik, () => _pickDate(true)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _datePickerCard('Tanggal Turun', _tanggalTurun, () => _pickDate(false)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Timezone conversion logic showcase
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: AppTheme.accentOrange),
                        SizedBox(width: 8),
                        Text('Rencana Summit Attack', style: TextStyle(color: AppTheme.accentOrange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Standar jam summit biasanya 02:00 pagi. Pilih zona waktu referensi Anda:', style: TextStyle(fontSize: 12)),
                    DropdownButton<String>(
                      value: _selectedTz,
                      isExpanded: true,
                      dropdownColor: AppTheme.cardDark,
                      items: ['WIB', 'WITA', 'WIT', 'UTC'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _selectedTz = v!);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Anggota
              const Text('Jumlah Anggota Rombongan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _anggotaCtrl,
                label: 'Jumlah Orang',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.people,
                validator: (v) => Validators.minValue(v, 1, 'Jumlah anggota'),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _proceedToPayment,
                  child: const Text('Lanjutkan ke Pembayaran'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerCard(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: date != null ? AppTheme.primaryGreen : Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(
              date != null ? AppDateUtils.formatDateIndonesian(date) : 'Pilih Tanggal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                color: date != null ? Colors.white : AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
