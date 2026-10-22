// ============================================
// TimurLang - Simaksi Form Screen
// Multi-member group registration with Leader & Members Data
// ============================================

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../models/basecamp_post.dart';
import '../../models/user.dart';
import '../../models/medical_profile.dart';
import '../../models/user_personal_data.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_text_field.dart';

class _MemberFormControllers {
  final TextEditingController namaCtrl;
  final TextEditingController alamatCtrl;
  final TextEditingController kontakDaruratCtrl;

  _MemberFormControllers({
    String nama = '',
    String alamat = '',
    String kontakDarurat = '',
  })  : namaCtrl = TextEditingController(text: nama),
        alamatCtrl = TextEditingController(text: alamat),
        kontakDaruratCtrl = TextEditingController(text: kontakDarurat);

  void dispose() {
    namaCtrl.dispose();
    alamatCtrl.dispose();
    kontakDaruratCtrl.dispose();
  }
}

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

  User? _currentUser;
  MedicalProfile? _userMedicalProfile;
  UserPersonalData? _userPersonalData;
  final List<_MemberFormControllers> _memberControllers = [];

  final _formKey = GlobalKey<FormState>();
  final _anggotaCtrl = TextEditingController(text: '1');
  DateTime? _tanggalNaik;
  DateTime? _tanggalTurun;
  String _selectedTz = 'WIB';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    _anggotaCtrl.addListener(_onAnggotaChanged);
  }

  @override
  void dispose() {
    _anggotaCtrl.removeListener(_onAnggotaChanged);
    _anggotaCtrl.dispose();
    for (final c in _memberControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      _currentUser = user;
      final med = await DatabaseService.instance.getMedicalProfile(user.id);
      final personal = await DatabaseService.instance.getPersonalData(user.id);
      if (mounted) {
        setState(() {
          _userMedicalProfile = med;
          _userPersonalData = personal;
        });

        // Cek apakah data diri belum diisi / belum lengkap
        if (personal == null || !personal.isComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showIncompletePersonalDataDialog();
            }
          });
        }
      }
    }
  }

  Future<void> _showIncompletePersonalDataDialog() async {
    final shouldFill = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentOrange, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Data Diri Belum Lengkap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Syarat Wajib SIMAKSI:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Sesuai regulasi pendaftaran SIMAKSI, ketua pendaki wajib melengkapi data identitas resmi (KTP/identitas, kontak darurat, alamat lengkap, dan data fisik) sebelum dapat melakukan reservasi tiket.',
              style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Silakan lengkapi data diri Anda terlebih dahulu agar proses verifikasi basecamp berjalan lancar.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti Saja', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.badge, size: 18),
            label: const Text('Isi Data Diri Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (shouldFill == true && mounted) {
      await Navigator.pushNamed(context, AppRoutes.personalData);
      if (mounted) {
        await _loadCurrentUserData();
      }
    }
  }

  void _onAnggotaChanged() {
    final val = int.tryParse(_anggotaCtrl.text) ?? 1;
    final needed = val > 1 ? val - 1 : 0;
    _syncMemberControllers(needed);
  }

  void _syncMemberControllers(int count) {
    if (count < 0) count = 0;
    if (_memberControllers.length == count) return;
    while (_memberControllers.length < count) {
      _memberControllers.add(_MemberFormControllers());
    }
    while (_memberControllers.length > count) {
      _memberControllers.removeLast().dispose();
    }
    setState(() {});
  }

  void _updateAnggotaCount(int delta) {
    final current = int.tryParse(_anggotaCtrl.text) ?? 1;
    final next = (current + delta).clamp(1, 50);
    _anggotaCtrl.text = next.toString();
  }

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

    // Tarik pos basecamp terbaru dari server Supabase agar pos yang baru didaftarkan akun basecamp muncul
    if (SupabaseService.instance.isInitialized) {
      try {
        final remoteBasecamps = await SupabaseService.instance.getBasecampsByMountain(gunungId);
        for (final bc in remoteBasecamps) {
          await DatabaseService.instance.insertBasecampPost(bc);
        }
      } catch (e) {
        debugPrint('⚠️ Gagal pull basecamp dari Supabase: $e');
      }
    }

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

    // Cek kelengkapan data diri wajib SIMAKSI
    if (_userPersonalData == null || !_userPersonalData!.isComplete) {
      _showIncompletePersonalDataDialog();
      return;
    }

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

    // Cek status buka/tutup basecamp
    if (!_selectedBasecamp!.isBuka) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jalur di ${_selectedBasecamp!.namaPos} sedang DITUTUP oleh pengelola basecamp.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    // Cek sisa kuota hari ini di basecamp
    if (jumlahAnggota > _selectedBasecamp!.sisaKuotaHariIni) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jumlah rombongan ($jumlahAnggota orang) melebihi sisa kuota hari ini di ${_selectedBasecamp!.namaPos} (tersisa ${_selectedBasecamp!.sisaKuotaHariIni} kuota).',
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    // Siapkan data rombongan lengkap
    final List<Map<String, dynamic>> membersList = [];

    // 1. Ketua Kelompok (Pengguna aplikasi yang login)
    final String namaKetua = _userPersonalData != null && _userPersonalData!.namaLengkap.isNotEmpty
        ? '${_userPersonalData!.namaLengkap} ${_userPersonalData!.namaBelakang}'.trim()
        : (_currentUser?.namaLengkap ?? 'Ketua Kelompok');
    final String alamatKetua = _userPersonalData != null && _userPersonalData!.alamat.isNotEmpty
        ? '${_userPersonalData!.alamat}, ${_userPersonalData!.kelurahan}, ${_userPersonalData!.kecamatan}, ${_userPersonalData!.kotaKabupaten}, ${_userPersonalData!.provinsi}'
        : 'Sesuai Profil Pengguna';
    final String kontakDaruratKetua = _userPersonalData != null && _userPersonalData!.noTeleponDarurat.isNotEmpty
        ? _userPersonalData!.noTeleponDarurat
        : (_userMedicalProfile?.kontakDaruratTelepon ?? (_currentUser?.email ?? '-'));

    membersList.add({
      'nama': namaKetua,
      'alamat': alamatKetua,
      'kontak_darurat': kontakDaruratKetua,
      'no_ktp': _userPersonalData?.nomorKtp ?? '-',
      'no_telepon': _userPersonalData?.noTelepon ?? '-',
      'is_ketua': true,
    });

    // 2. Anggota kelompok tambahan
    for (int i = 0; i < _memberControllers.length; i++) {
      final ctrl = _memberControllers[i];
      membersList.add({
        'nama': ctrl.namaCtrl.text.trim(),
        'alamat': ctrl.alamatCtrl.text.trim(),
        'kontak_darurat': ctrl.kontakDaruratCtrl.text.trim(),
        'is_ketua': false,
      });
    }

    final String dataAnggotaJson = jsonEncode(membersList);

    // Biaya SIMAKSI dihitung berdasarkan tarif resmi per basecamp (per orang)
    final double baseBiayaPerOrang = _selectedBasecamp!.hargaSimaksi;
    final double totalBiaya = baseBiayaPerOrang * jumlahAnggota;

    Navigator.pushNamed(
      context,
      AppRoutes.simaksiPayment,
      arguments: {
        'mountain': _mountain,
        'basecamp': _selectedBasecamp,
        'basecampId': _selectedBasecamp!.id,
        'namaBasecamp': _selectedBasecamp!.namaPos,
        'hargaSimaksi': baseBiayaPerOrang,
        'tanggalNaik': _tanggalNaik,
        'tanggalTurun': _tanggalTurun,
        'jumlahAnggota': jumlahAnggota,
        'totalBiayaIDR': totalBiaya,
        'timezone': _selectedTz,
        'membersList': membersList,
        'dataAnggota': dataAnggotaJson,
      },
    );
  }

  String _getOrdinalMemberTitle(int index) {
    const ordinals = [
      'Pertama',
      'Kedua',
      'Ketiga',
      'Keempat',
      'Kelima',
      'Keenam',
      'Ketujuh',
      'Kedelapan',
      'Kesembilan',
      'Kesepuluh',
    ];
    if (index < ordinals.length) {
      return 'Anggota Kelompok ${ordinals[index]}';
    }
    return 'Anggota Kelompok #${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    if (_mountain == null) return const Scaffold(body: Center(child: Text('Memuat formulir...')));

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
                        final isBuka = bc.isBuka;
                        return DropdownMenuItem<String>(
                          value: bc.id,
                          child: Row(
                            children: [
                              Icon(
                                isBuka ? Icons.holiday_village_outlined : Icons.do_not_disturb_on_outlined,
                                color: isBuka ? AppTheme.primaryGreen : AppTheme.dangerRed,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      bc.namaPos,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isBuka ? Colors.white : Colors.white60,
                                      ),
                                    ),
                                    Text(
                                      'Sisa Kuota: ${bc.sisaKuotaHariIni}/${bc.kuotaHarian} • Rp ${bc.hargaSimaksi.toInt()}/orang',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isBuka ? Colors.white54 : AppTheme.dangerRed.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isBuka ? AppTheme.safeGreen : AppTheme.dangerRed).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isBuka ? 'Buka' : 'Tutup',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isBuka ? AppTheme.safeGreen : AppTheme.dangerRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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

              // Detail Operasional Basecamp Terpilih
              if (_selectedBasecamp != null) ...[
                const SizedBox(height: 8),
                if (!_selectedBasecamp!.isBuka)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Jalur di ${_selectedBasecamp!.namaPos} sedang DITUTUP oleh pengelola basecamp. Pilih basecamp lain untuk melanjutkan pendaftaran.',
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Status Jalur', style: TextStyle(fontSize: 10, color: Colors.white54)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedBasecamp!.statusJalur,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.safeGreen),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white12),
                        Column(
                          children: [
                            const Text('Sisa Kuota Hari Ini', style: TextStyle(fontSize: 10, color: Colors.white54)),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedBasecamp!.sisaKuotaHariIni} / ${_selectedBasecamp!.kuotaHarian}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentOrange),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 24, color: Colors.white12),
                        Column(
                          children: [
                            const Text('Tarif SIMAKSI', style: TextStyle(fontSize: 10, color: Colors.white54)),
                            const SizedBox(height: 2),
                            Text(
                              'Rp ${_selectedBasecamp!.hargaSimaksi.toInt()}/hr',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
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

              // Jumlah Anggota Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jumlah Anggota Rombongan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () => _updateAnggotaCount(-1),
                          color: Colors.white70,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            _anggotaCtrl.text.isEmpty ? '1' : _anggotaCtrl.text,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryGreen),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => _updateAnggotaCount(1),
                          color: AppTheme.primaryGreen,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _anggotaCtrl,
                label: 'Jumlah Total Orang (Termasuk Ketua)',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.people,
                validator: (v) => Validators.minValue(v, 1, 'Jumlah anggota'),
              ),
              const SizedBox(height: 16),

              // Kartu Data Ketua Rombongan (Pengguna Aplikasi)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: (_userPersonalData?.isComplete == true)
                        ? [
                            AppTheme.primaryGreen.withValues(alpha: 0.15),
                            AppTheme.cardDark,
                          ]
                        : [
                            AppTheme.accentOrange.withValues(alpha: 0.15),
                            AppTheme.cardDark,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (_userPersonalData?.isComplete == true)
                        ? AppTheme.primaryGreen.withValues(alpha: 0.35)
                        : AppTheme.accentOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (_userPersonalData?.isComplete == true)
                                ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                                : AppTheme.accentOrange.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (_userPersonalData?.isComplete == true) ? Icons.verified_user : Icons.warning_amber_rounded,
                            color: (_userPersonalData?.isComplete == true) ? AppTheme.primaryGreen : AppTheme.accentOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Ketua Rombongan (Anda)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_userPersonalData?.isComplete == true)
                                ? AppTheme.primaryGreen.withValues(alpha: 0.25)
                                : AppTheme.accentOrange.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (_userPersonalData?.isComplete == true) ? 'Data Lengkap ✓' : 'Belum Lengkap',
                            style: TextStyle(
                              fontSize: 10,
                              color: (_userPersonalData?.isComplete == true) ? AppTheme.primaryGreen : AppTheme.accentOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.white12),

                    if (_userPersonalData?.isComplete == true) ...[
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_userPersonalData!.namaLengkap} ${_userPersonalData!.namaBelakang}'.trim(),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.badge, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_userPersonalData!.jenisIdentitas}: ${_userPersonalData!.nomorKtp}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No. HP: ${_userPersonalData!.noTelepon}',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.contact_phone, size: 16, color: AppTheme.skyBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kontak Darurat: ${_userPersonalData!.noTeleponDarurat}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.skyBlue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_userPersonalData!.alamat}, ${_userPersonalData!.kelurahan}, ${_userPersonalData!.kecamatan}, ${_userPersonalData!.kotaKabupaten}, ${_userPersonalData!.provinsi}',
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.pushNamed(context, AppRoutes.personalData);
                            if (mounted) await _loadCurrentUserData();
                          },
                          icon: const Icon(Icons.edit, size: 14, color: AppTheme.primaryGreen),
                          label: const Text('Ubah Data Diri', style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentUser?.namaLengkap ?? 'Pengguna',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.accentOrange, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Data identitas (KTP, alamat, data fisik) wajib diisi untuk syarat SIMAKSI.',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.pushNamed(context, AppRoutes.personalData);
                            if (mounted) await _loadCurrentUserData();
                          },
                          icon: const Icon(Icons.badge, size: 16),
                          label: const Text('Lengkapi Data Diri Sekarang'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentOrange,
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Formulir Input Anggota Kelompok Tambahan (Jika rombongan > 1)
              if (_memberControllers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.group_add, color: AppTheme.accentOrange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Data Anggota Rombongan (${_memberControllers.length} Orang)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lengkapi nama, alamat, dan kontak darurat masing-masing anggota rombongan:',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < _memberControllers.length; i++) ...[
                  _buildMemberInputCard(i),
                  const SizedBox(height: 12),
                ],
              ],

              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _proceedToPayment,
                  child: const Text('Lanjutkan ke Pembayaran'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInputCard(int index) {
    final ctrl = _memberControllers[index];
    final title = _getOrdinalMemberTitle(index);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: AppTheme.accentOrange, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: ctrl.namaCtrl,
            label: 'Nama Lengkap $title',
            prefixIcon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Masukkan nama lengkap $title' : null,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: ctrl.alamatCtrl,
            label: 'Alamat Tempat Tinggal $title',
            prefixIcon: Icons.home_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Masukkan alamat $title' : null,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: ctrl.kontakDaruratCtrl,
            label: 'Kontak Darurat / No. HP $title',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Masukkan kontak darurat $title' : null,
          ),
        ],
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
