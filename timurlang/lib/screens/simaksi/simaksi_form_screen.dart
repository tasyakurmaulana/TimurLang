// ============================================
// TimurLang - Simaksi Form Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../models/basecamp_post.dart';
import '../../services/database_service.dart';
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
  List<Mountain> _mountains = [];
  List<BasecampPost> _basecamps = [];
  BasecampPost? _selectedBasecamp;
  bool _isLoadingBasecamps = false;

  final _formKey = GlobalKey<FormState>();
  final _anggotaCtrl = TextEditingController(text: '1');
  DateTime? _tanggalNaik;
  DateTime? _tanggalTurun;
  String _selectedTz = 'WIB';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mountain == null) {
      final argMountain = ModalRoute.of(context)?.settings.arguments as Mountain?;
      _initMountains(argMountain);
    }
  }

  Future<void> _initMountains(Mountain? initial) async {
    final list = await DatabaseService.instance.getAllMountains();
    if (!mounted) return;
    setState(() {
      _mountains = list;
      if (initial != null) {
        _mountain = list.firstWhere(
          (m) => m.id == initial.id,
          orElse: () => initial,
        );
      } else if (list.isNotEmpty) {
        _mountain = list.first;
      }
    });

    if (_mountain != null) {
      _loadBasecampsForMountain(_mountain!.id);
    }
  }

  Future<void> _loadBasecampsForMountain(String gunungId) async {
    setState(() {
      _isLoadingBasecamps = true;
      _selectedBasecamp = null;
    });

    final bcs = await DatabaseService.instance.getRegisteredBasecampsByMountain(gunungId);
    if (!mounted) return;

    setState(() {
      _basecamps = bcs;
      if (_basecamps.isNotEmpty) {
        _selectedBasecamp = _basecamps.first;
      }
      _isLoadingBasecamps = false;
    });
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
    if (_mountain == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih gunung tujuan')),
      );
      return;
    }
    if (_selectedBasecamp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih basecamp / jalur pendakian yang terdaftar terlebih dahulu'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (_tanggalNaik == null || _tanggalTurun == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal naik dan turun')),
      );
      return;
    }

    final int jumlahAnggota = int.parse(_anggotaCtrl.text);
    // Base cost calculation
    final double baseBiayaPerOrangPerHari = 10000.0;
    final int durasiHari = _tanggalTurun!.difference(_tanggalNaik!).inDays + 1;
    final double totalBiaya = baseBiayaPerOrangPerHari * durasiHari * jumlahAnggota;

    Navigator.pushNamed(
      context,
      AppRoutes.simaksiPayment,
      arguments: {
        'mountain': _mountain,
        'basecamp': _selectedBasecamp,
        'basecampId': _selectedBasecamp!.id,
        'namaBasecamp': _selectedBasecamp!.namaPos,
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
              // Mountain Info / Selection
              const Text('Gunung Tujuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: _mountains.isEmpty
                    ? Row(
                        children: [
                          const Icon(Icons.terrain, color: AppTheme.primaryGreen, size: 28),
                          const SizedBox(width: 12),
                          Text(_mountain?.namaGunung ?? 'Memuat...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _mountain?.id,
                          isExpanded: true,
                          dropdownColor: AppTheme.cardDark,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen),
                          items: _mountains.map((m) {
                            return DropdownMenuItem<String>(
                              value: m.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.terrain, color: AppTheme.primaryGreen, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(m.namaGunung, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('${m.elevasiMdpl} mdpl • Status: ${m.statusJalur}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            if (newId != null) {
                              final selected = _mountains.firstWhere((m) => m.id == newId);
                              setState(() => _mountain = selected);
                              _loadBasecampsForMountain(newId);
                            }
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Basecamp / Jalur Pendakian Selection
              const Text('Pilih Basecamp / Jalur Pendakian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Pilih basecamp resmi tempat registrasi awal & tujuan siaga darurat:',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 8),

              if (_isLoadingBasecamps)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_basecamps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada akun basecamp yang terdaftar untuk gunung ini. Pastikan pengelola pos telah meregistrasi akun basecamp.',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryGreen),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBasecamp?.id,
                      isExpanded: true,
                      dropdownColor: AppTheme.cardDark,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen),
                      items: _basecamps.map((bc) {
                        final isAccountRegistered = bc.userIdPetugas != null && bc.userIdPetugas!.isNotEmpty;
                        return DropdownMenuItem<String>(
                          value: bc.id,
                          child: Row(
                            children: [
                              const Icon(Icons.holiday_village_outlined, color: AppTheme.primaryGreen, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(bc.namaPos, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      isAccountRegistered ? 'Akun Basecamp Resmi Terverifikasi' : bc.lokasiDeskripsi,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAccountRegistered ? AppTheme.safeGreen : Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAccountRegistered)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.safeGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Terdaftar', style: TextStyle(fontSize: 10, color: AppTheme.safeGreen, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (bcId) {
                        if (bcId != null) {
                          setState(() {
                            _selectedBasecamp = _basecamps.firstWhere((b) => b.id == bcId);
                          });
                        }
                      },
                    ),
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
