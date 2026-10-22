// ============================================
// TimurLang - Personal Data Screen
// Syarat Wajib Identitas Pendaki untuk SIMAKSI
// ============================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/user_personal_data.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/image_helper.dart';
import '../../widgets/custom_text_field.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nomorKtpCtrl = TextEditingController();
  final _namaLengkapCtrl = TextEditingController();
  final _namaBelakangCtrl = TextEditingController();
  final _noTeleponCtrl = TextEditingController();
  final _noTeleponDaruratCtrl = TextEditingController();
  final _surelCtrl = TextEditingController();
  final _beratBadanCtrl = TextEditingController();
  final _tinggiBadanCtrl = TextEditingController();
  final _kotaKabupatenCtrl = TextEditingController();
  final _kecamatanCtrl = TextEditingController();
  final _kelurahanCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();

  // State dropdowns & values
  String _kewarganegaraan = 'WNI';
  String _jenisIdentitas = 'KTP';
  String _jenisKelamin = 'Laki-laki';
  String _provinsi = 'Jawa Barat';
  DateTime? _tanggalLahir;
  String? _fileKtpUrl; // Base64 Data URI
  bool _isLoading = true;
  bool _isSaving = false;
  UserPersonalData? _existingData;

  final ImagePicker _picker = ImagePicker();

  static const List<String> _provinsiList = [
    'Aceh',
    'Sumatera Utara',
    'Sumatera Barat',
    'Riau',
    'Kepulauan Riau',
    'Jambi',
    'Sumatera Selatan',
    'Kepulauan Bangka Belitung',
    'Bengkulu',
    'Lampung',
    'DKI Jakarta',
    'Banten',
    'Jawa Barat',
    'Jawa Tengah',
    'DI Yogyakarta',
    'Jawa Timur',
    'Bali',
    'Nusa Tenggara Barat',
    'Nusa Tenggara Timur',
    'Kalimantan Barat',
    'Kalimantan Tengah',
    'Kalimantan Selatan',
    'Kalimantan Timur',
    'Kalimantan Utara',
    'Sulawesi Utara',
    'Gorontalo',
    'Sulawesi Tengah',
    'Sulawesi Barat',
    'Sulawesi Selatan',
    'Sulawesi Tenggara',
    'Maluku',
    'Maluku Utara',
    'Papua',
    'Papua Barat',
    'Papua Selatan',
    'Papua Tengah',
    'Papua Pegunungan',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nomorKtpCtrl.dispose();
    _namaLengkapCtrl.dispose();
    _namaBelakangCtrl.dispose();
    _noTeleponCtrl.dispose();
    _noTeleponDaruratCtrl.dispose();
    _surelCtrl.dispose();
    _beratBadanCtrl.dispose();
    _tinggiBadanCtrl.dispose();
    _kotaKabupatenCtrl.dispose();
    _kecamatanCtrl.dispose();
    _kelurahanCtrl.dispose();
    _alamatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Default pre-fill dari akun login
    _namaLengkapCtrl.text = user.namaLengkap;
    _surelCtrl.text = user.email;

    // Tarik data dari database lokal
    var data = await DatabaseService.instance.getPersonalData(user.id);

    // Coba tarik dari Supabase jika belum ada di lokal
    if (data == null && SupabaseService.instance.isInitialized) {
      try {
        data = await SupabaseService.instance.getPersonalData(user.id);
        if (data != null) {
          await DatabaseService.instance.insertPersonalData(data);
        }
      } catch (_) {}
    }

    if (data != null && mounted) {
      _existingData = data;
      _kewarganegaraan = data.kewarganegaraan;
      _jenisIdentitas = data.jenisIdentitas;
      _nomorKtpCtrl.text = data.nomorKtp;
      _fileKtpUrl = data.fileKtpUrl;
      _namaLengkapCtrl.text = data.namaLengkap;
      _namaBelakangCtrl.text = data.namaBelakang ?? '';
      _tanggalLahir = data.tanggalLahir;
      _jenisKelamin = data.jenisKelamin;
      _noTeleponCtrl.text = data.noTelepon;
      _noTeleponDaruratCtrl.text = data.noTeleponDarurat;
      _surelCtrl.text = data.surel;
      if (data.beratBadan != null) _beratBadanCtrl.text = data.beratBadan!.toString();
      if (data.tinggiBadan != null) _tinggiBadanCtrl.text = data.tinggiBadan!.toString();
      if (_provinsiList.contains(data.provinsi)) {
        _provinsi = data.provinsi;
      }
      _kotaKabupatenCtrl.text = data.kotaKabupaten;
      _kecamatanCtrl.text = data.kecamatan;
      _kelurahanCtrl.text = data.kelurahan;
      _alamatCtrl.text = data.alamat;
    } else {
      // Ambil kontak darurat dari rekam medis jika sudah pernah diisi
      final med = await DatabaseService.instance.getMedicalProfile(user.id);
      if (med != null && mounted) {
        if (_noTeleponDaruratCtrl.text.isEmpty) {
          _noTeleponDaruratCtrl.text = med.kontakDaruratTelepon;
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickKtpImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final base64Uri = await ImageHelper.xFileToBase64(picked);
        setState(() {
          _fileKtpUrl = base64Uri;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto identitas berhasil dipilih'),
              backgroundColor: AppTheme.safeGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    }
  }

  void _showKtpSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Unggah Foto Dokumen Identitas (KTP / Paspor)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
                title: const Text('Ambil Foto Kamera', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickKtpImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.skyBlue),
                title: const Text('Pilih dari Galeri', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickKtpImage(ImageSource.gallery);
                },
              ),
              if (_fileKtpUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.dangerRed),
                  title: const Text('Hapus Foto KTP', style: TextStyle(color: AppTheme.dangerRed)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _fileKtpUrl = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTanggalLahir() async {
    final now = DateTime.now();
    final initial = _tanggalLahir ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _tanggalLahir = picked);
    }
  }

  Future<void> _savePersonalData() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua kolom wajib bertanda bintang (*)'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    if (_tanggalLahir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih tanggal lahir Anda'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final personalData = UserPersonalData(
      id: _existingData?.id ?? const Uuid().v4(),
      userId: user.id,
      kewarganegaraan: _kewarganegaraan,
      jenisIdentitas: _jenisIdentitas,
      nomorKtp: _nomorKtpCtrl.text.trim(),
      fileKtpUrl: _fileKtpUrl,
      namaLengkap: _namaLengkapCtrl.text.trim(),
      namaBelakang: _namaBelakangCtrl.text.trim().isEmpty ? null : _namaBelakangCtrl.text.trim(),
      tanggalLahir: _tanggalLahir!,
      jenisKelamin: _jenisKelamin,
      noTelepon: _noTeleponCtrl.text.trim(),
      noTeleponDarurat: _noTeleponDaruratCtrl.text.trim(),
      surel: _surelCtrl.text.trim(),
      beratBadan: double.tryParse(_beratBadanCtrl.text.trim()),
      tinggiBadan: double.tryParse(_tinggiBadanCtrl.text.trim()),
      provinsi: _provinsi,
      kotaKabupaten: _kotaKabupatenCtrl.text.trim(),
      kecamatan: _kecamatanCtrl.text.trim(),
      kelurahan: _kelurahanCtrl.text.trim(),
      alamat: _alamatCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );

    // Simpan ke database lokal
    await DatabaseService.instance.insertPersonalData(personalData);

    // Sinkronkan ke Supabase jika online
    bool syncedToSupabase = false;
    if (SupabaseService.instance.isInitialized) {
      syncedToSupabase = await SupabaseService.instance.syncPersonalData(personalData);
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
        _existingData = personalData;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedToSupabase
                ? 'Data diri berhasil disimpan ke Supabase & lokal! Syarat SIMAKSI terpenuhi ✓'
                : 'Data diri berhasil disimpan di perangkat lokal! Syarat SIMAKSI terpenuhi ✓',
          ),
          backgroundColor: AppTheme.safeGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      // Kembali ke halaman sebelumnya dengan hasil true
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Diri Pendaki'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _savePersonalData,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Simpan',
                      style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Info Syarat SIMAKSI
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen.withValues(alpha: 0.18),
                            AppTheme.cardDark,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, color: AppTheme.primaryGreen, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Syarat Wajib SIMAKSI Digital',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Data diri resmi sesuai kartu identitas diperlukan demi verifikasi keselamatan & asuransi pendakian.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── BAGIAN 1: DOKUMEN IDENTITAS ──
                    _sectionHeader('1. Dokumen Identitas', Icons.badge_outlined),
                    const SizedBox(height: 12),

                    // Kewarganegaraan
                    _dropdownField<String>(
                      label: 'Jenis Kewarganegaraan *',
                      value: _kewarganegaraan,
                      items: const ['WNI', 'WNA'],
                      onChanged: (v) => setState(() => _kewarganegaraan = v!),
                    ),
                    const SizedBox(height: 14),

                    // Jenis Identitas
                    _dropdownField<String>(
                      label: 'Jenis Kartu Identitas *',
                      value: _jenisIdentitas,
                      items: const ['KTP', 'Paspor', 'SIM', 'KITAS'],
                      onChanged: (v) => setState(() => _jenisIdentitas = v!),
                    ),
                    const SizedBox(height: 14),

                    // Nomor KTP / Identitas
                    CustomTextField(
                      controller: _nomorKtpCtrl,
                      label: 'Nomor Identitas / KTP / Paspor *',
                      prefixIcon: Icons.credit_card,
                      keyboardType: TextInputType.text,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor identitas wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    // Upload File Foto KTP
                    const Text(
                      'Unggah Foto / File KTP (Opsional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showKtpSourceSheet,
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _fileKtpUrl != null ? AppTheme.safeGreen : AppTheme.border),
                        ),
                        child: _fileKtpUrl != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image(
                                      image: ImageHelper.getImageProvider(_fileKtpUrl!)!,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, size: 14, color: AppTheme.safeGreen),
                                          SizedBox(width: 4),
                                          Text('KTP Terunggah', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_upload_outlined, size: 36, color: AppTheme.textSecondary),
                                  const SizedBox(height: 8),
                                  const Text('Ketuk untuk unggah foto KTP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  const Text('Kamera atau Galeri Foto', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── BAGIAN 2: DATA PRIBADI ──
                    _sectionHeader('2. Data Pribadi', Icons.person_outline),
                    const SizedBox(height: 12),

                    CustomTextField(
                      controller: _namaLengkapCtrl,
                      label: 'Nama Depan / Nama Lengkap *',
                      prefixIcon: Icons.person,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama lengkap wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      controller: _namaBelakangCtrl,
                      label: 'Nama Belakang (Opsional)',
                      prefixIcon: Icons.badge,
                    ),
                    const SizedBox(height: 14),

                    // Tanggal Lahir Picker Card
                    GestureDetector(
                      onTap: _pickTanggalLahir,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _tanggalLahir != null ? AppTheme.primaryGreen : AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined, color: AppTheme.primaryGreen, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tanggal Lahir *', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _tanggalLahir != null
                                        ? AppDateUtils.formatDateIndonesian(_tanggalLahir!)
                                        : 'Pilih Tanggal Lahir',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _tanggalLahir != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Jenis Kelamin
                    _dropdownField<String>(
                      label: 'Jenis Kelamin *',
                      value: _jenisKelamin,
                      items: const ['Laki-laki', 'Perempuan'],
                      onChanged: (v) => setState(() => _jenisKelamin = v!),
                    ),
                    const SizedBox(height: 14),

                    // Berat & Tinggi Badan Row
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _beratBadanCtrl,
                            label: 'Berat Badan (kg)',
                            prefixIcon: Icons.fitness_center,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: CustomTextField(
                            controller: _tinggiBadanCtrl,
                            label: 'Tinggi Badan (cm)',
                            prefixIcon: Icons.height,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── BAGIAN 3: KONTAK & DARURAT ──
                    _sectionHeader('3. Kontak & Darurat', Icons.contact_phone_outlined),
                    const SizedBox(height: 12),

                    CustomTextField(
                      controller: _surelCtrl,
                      label: 'Surel / Email *',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Surel wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      controller: _noTeleponCtrl,
                      label: 'No. Telepon / WhatsApp Pendaki *',
                      prefixIcon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor telepon wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      controller: _noTeleponDaruratCtrl,
                      label: 'No. Telepon Darurat (Keluarga / Kerabat) *',
                      prefixIcon: Icons.contact_emergency_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nomor darurat wajib diisi' : null,
                    ),
                    const SizedBox(height: 28),

                    // ── BAGIAN 4: ALAMAT DOMISILI (SESUAI KTP) ──
                    _sectionHeader('4. Alamat (Sesuai KTP)', Icons.home_outlined),
                    const SizedBox(height: 12),

                    // Provinsi Dropdown
                    _dropdownField<String>(
                      label: 'Provinsi (Sesuai KTP) *',
                      value: _provinsi,
                      items: _provinsiList,
                      onChanged: (v) => setState(() => _provinsi = v!),
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      controller: _kotaKabupatenCtrl,
                      label: 'Kota / Kabupaten (Sesuai KTP) *',
                      prefixIcon: Icons.location_city,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Kota/Kabupaten wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _kecamatanCtrl,
                            label: 'Kecamatan *',
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: CustomTextField(
                            controller: _kelurahanCtrl,
                            label: 'Kelurahan *',
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    CustomTextField(
                      controller: _alamatCtrl,
                      label: 'Alamat Lengkap (Jalan, RT/RW, No. Rumah) *',
                      prefixIcon: Icons.map_outlined,
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat lengkap wajib diisi' : null,
                    ),
                    const SizedBox(height: 36),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _savePersonalData,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSaving ? 'Menyimpan Data...' : 'Simpan Data Diri',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentOrange, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.surface,
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(item.toString(), style: const TextStyle(color: AppTheme.textPrimary)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
