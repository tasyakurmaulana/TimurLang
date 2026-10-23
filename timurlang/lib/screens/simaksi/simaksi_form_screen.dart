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
import '../../utils/time_zone_helper.dart';
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Data Diri Belum Lengkap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              'Sesuai regulasi pendaftaran SIMAKSI, ketua pendaki wajib melengkapi data identitas resmi (KTP/identitas, kontak darurat, alamat lengkap, dan data fisik) sebelum dapat melakukan reservasi tiket.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Silakan lengkapi data diri Anda terlebih dahulu agar proses verifikasi basecamp berjalan lancar.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti Saja', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.badge, size: 18),
            label: const Text('Isi Data Diri Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
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
      final args = ModalRoute.of(context)?.settings.arguments;
      Mountain? argMountain;
      String? mountainId;
      String? targetBasecampId;
      String? targetBasecampName;

      if (args is Mountain) {
        argMountain = args;
      } else if (args is String) {
        mountainId = args;
      } else if (args is Map) {
        if (args['mountain'] is Mountain) {
          argMountain = args['mountain'] as Mountain;
        } else if (args['mountain'] is String) {
          mountainId = args['mountain'] as String;
        }
        if (args['mountainId'] is String) {
          mountainId = args['mountainId'] as String;
        }
        if (args['basecampId'] is String) {
          targetBasecampId = args['basecampId'] as String;
        }
        if (args['basecamp'] is BasecampPost) {
          targetBasecampId = (args['basecamp'] as BasecampPost).id;
          targetBasecampName = (args['basecamp'] as BasecampPost).namaPos;
        }
        if (args['basecampName'] is String) {
          targetBasecampName = args['basecampName'] as String;
        }
      }

      _initMountains(
        argMountain,
        initialId: mountainId,
        targetBasecampId: targetBasecampId,
        targetBasecampName: targetBasecampName,
      );
    }
  }

  Future<void> _initMountains(
    Mountain? initial, {
    String? initialId,
    String? targetBasecampId,
    String? targetBasecampName,
  }) async {
    final list = await DatabaseService.instance.getAllMountains();
    if (!mounted) return;
    setState(() {
      _mountains = list;
      if (initial != null) {
        _mountain = list.firstWhere(
          (m) => m.id == initial.id,
          orElse: () => initial,
        );
      } else if (initialId != null) {
        final found = list.where((m) => m.id == initialId);
        if (found.isNotEmpty) {
          _mountain = found.first;
        } else if (list.isNotEmpty) {
          _mountain = list.first;
        }
      } else if (list.isNotEmpty) {
        _mountain = list.first;
      }
    });

    if (_mountain != null) {
      _loadBasecampsForMountain(
        _mountain!.id,
        targetBasecampId: targetBasecampId,
        targetBasecampName: targetBasecampName,
      );
    }
  }

  Future<void> _loadBasecampsForMountain(
    String gunungId, {
    String? targetBasecampId,
    String? targetBasecampName,
  }) async {
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
        BasecampPost? matched;
        if (targetBasecampId != null || targetBasecampName != null) {
          for (final b in _basecamps) {
            if (targetBasecampId != null && b.id == targetBasecampId) {
              matched = b;
              break;
            }
            if (targetBasecampName != null &&
                (b.namaPos.toLowerCase().trim() == targetBasecampName.toLowerCase().trim() ||
                 b.namaPos.toLowerCase().contains(targetBasecampName.toLowerCase().trim()) ||
                 targetBasecampName.toLowerCase().contains(b.namaPos.toLowerCase().trim()))) {
              matched = b;
              break;
            }
          }
        }
        _selectedBasecamp = matched ?? _basecamps.first;
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
        'timezone': _mountain != null ? TimeZoneHelper.getMountainTimeZone(mountainName: _mountain!.namaGunung) : 'WIB',
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
                                        Text(m.namaGunung, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                                        Text('${m.elevasiMdpl} mdpl • Status: ${m.statusJalur}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
              const Text('Pilih Basecamp / Jalur Pendakian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Pilih basecamp resmi tempat registrasi awal & tujuan siaga darurat:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),

              if (_isLoadingBasecamps)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                )
              else if (_basecamps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Belum ada akun basecamp yang terdaftar untuk gunung ini. Pastikan pengelola pos telah meregistrasi akun basecamp.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBasecamp?.id,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                      items: _basecamps.map((bc) {
                        final isBuka = bc.isBuka;
                        return DropdownMenuItem<String>(
                          value: bc.id,
                          child: Row(
                            children: [
                              Icon(
                                isBuka ? Icons.holiday_village_outlined : Icons.do_not_disturb_on_outlined,
                                color: isBuka ? AppTheme.primary : AppTheme.error,
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
                                        color: isBuka ? AppTheme.textPrimary : AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'Sisa Kuota: ${bc.sisaKuotaHariIni}/${bc.kuotaHarian} • Rp ${bc.hargaSimaksi.toInt()}/orang',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isBuka ? AppTheme.textSecondary : AppTheme.error.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isBuka ? AppTheme.success : AppTheme.error).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isBuka ? 'Buka' : 'Tutup',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isBuka ? AppTheme.success : AppTheme.error,
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
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Jalur di ${_selectedBasecamp!.namaPos} sedang DITUTUP oleh pengelola basecamp. Pilih basecamp lain untuk melanjutkan pendaftaran.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Status Jalur', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              _selectedBasecamp!.statusJalur,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 24, color: AppTheme.border),
                        Column(
                          children: [
                            const Text('Sisa Kuota Hari Ini', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedBasecamp!.sisaKuotaHariIni} / ${_selectedBasecamp!.kuotaHarian}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 24, color: AppTheme.border),
                        Column(
                          children: [
                            const Text('Tarif SIMAKSI', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              'Rp ${_selectedBasecamp!.hargaSimaksi.toInt()}/hr',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
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

              // Jumlah Anggota Section
              const Text(
                'Jumlah Anggota Rombongan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Termasuk ketua rombongan (Anda)',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _anggotaCtrl,
                      label: 'Total Anggota',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.people_outline,
                      validator: (v) => Validators.minValue(v, 1, 'Jumlah anggota'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: () => _updateAnggotaCount(-1),
                          color: AppTheme.textPrimary,
                          tooltip: 'Kurangi Anggota',
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: AppTheme.border,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () => _updateAnggotaCount(1),
                          color: AppTheme.primary,
                          tooltip: 'Tambah Anggota',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kartu Data Ketua Rombongan (Solid Surface, High Contrast)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_userPersonalData?.isComplete == true)
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : AppTheme.warning.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (_userPersonalData?.isComplete == true)
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.warning.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (_userPersonalData?.isComplete == true) ? Icons.verified_user : Icons.warning_amber_rounded,
                            color: (_userPersonalData?.isComplete == true) ? AppTheme.primary : AppTheme.warning,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Ketua Rombongan (Anda)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_userPersonalData?.isComplete == true)
                                ? AppTheme.primarySubtle
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (_userPersonalData?.isComplete == true)
                                  ? const Color(0xFFD4E0D2)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Text(
                            (_userPersonalData?.isComplete == true) ? 'Data Lengkap' : 'Belum Lengkap',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: (_userPersonalData?.isComplete == true) ? AppTheme.primary : const Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.border),

                    if (_userPersonalData?.isComplete == true) ...[
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_userPersonalData!.namaLengkap} ${_userPersonalData!.namaBelakang}'.trim(),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.badge, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_userPersonalData!.jenisIdentitas}: ${_userPersonalData!.nomorKtp}',
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No. HP: ${_userPersonalData!.noTelepon}',
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.contact_phone, size: 16, color: AppTheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kontak Darurat: ${_userPersonalData!.noTeleponDarurat}',
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.secondary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_userPersonalData!.alamat}, ${_userPersonalData!.kelurahan}, ${_userPersonalData!.kecamatan}, ${_userPersonalData!.kotaKabupaten}, ${_userPersonalData!.provinsi}',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.pushNamed(context, AppRoutes.personalData);
                            if (mounted) await _loadCurrentUserData();
                          },
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Ubah Data Diri'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35), width: 1.2),
                            backgroundColor: AppTheme.primarySubtle.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            textStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentUser?.namaLengkap ?? 'Pengguna',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF92400E), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Data identitas (KTP, alamat, data fisik) wajib diisi untuk syarat SIMAKSI.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
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
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
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
                    const Icon(Icons.group_add, color: AppTheme.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Data Anggota Rombongan (${_memberControllers.length} Orang)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lengkapi nama, alamat, dan kontak darurat masing-masing anggota rombongan:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Lanjutkan ke Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: date != null ? AppTheme.primary : AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(
              date != null ? AppDateUtils.formatDateIndonesian(date) : 'Pilih Tanggal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                color: date != null ? AppTheme.textPrimary : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
