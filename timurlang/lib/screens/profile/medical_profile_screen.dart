// ============================================
// TimurLang - Medical Profile Screen
// Protected by Biometric Authentication
// ============================================

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/medical_profile.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/custom_text_field.dart';

class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  MedicalProfile? _profile;
  bool _isEditing = false;

  final _golDarahCtrl = TextEditingController();
  final _riwayatPenyakitCtrl = TextEditingController();
  final _alergiCtrl = TextEditingController();
  final _kontakNamaCtrl = TextEditingController();
  final _kontakTeleponCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() => _isChecking = true);
    final success = await AuthService.instance.verifyBiometricForMedical();
    
    if (success) {
      await _loadProfile();
      setState(() => _isAuthenticated = true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autentikasi gagal. Anda bisa menggunakan sandi perangkat jika biometrik tidak berhasil berkali-kali.')),
        );
      }
    }
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _loadProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final profile = await DatabaseService.instance.getMedicalProfile(user.id);
    if (profile != null) {
      _profile = profile;
      _golDarahCtrl.text = profile.golonganDarah;
      _riwayatPenyakitCtrl.text = profile.riwayatPenyakit;
      _alergiCtrl.text = profile.alergi;
      _kontakNamaCtrl.text = profile.kontakDaruratNama;
      _kontakTeleponCtrl.text = profile.kontakDaruratTelepon;
    }
  }

  Future<void> _saveProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final newProfile = MedicalProfile(
      id: _profile?.id ?? const Uuid().v4(),
      userId: user.id,
      golonganDarah: _golDarahCtrl.text.trim(),
      riwayatPenyakit: _riwayatPenyakitCtrl.text.trim(),
      alergi: _alergiCtrl.text.trim(),
      kontakDaruratNama: _kontakNamaCtrl.text.trim(),
      kontakDaruratTelepon: _kontakTeleponCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );

    if (_profile == null) {
      await DatabaseService.instance.insertMedicalProfile(newProfile);
    } else {
      await DatabaseService.instance.updateMedicalProfile(newProfile);
    }

    setState(() {
      _profile = newProfile;
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil medis disimpan'), backgroundColor: AppTheme.safeGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memverifikasi Biometrik...'),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rekam Medis')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: AppTheme.dangerRed),
              const SizedBox(height: 16),
              const Text('Akses Ditolak', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Data rekam medis dikunci.'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekam Medis Darurat'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _isEditing ? _buildForm() : _buildView(),
      ),
    );
  }

  Widget _buildView() {
    if (_profile == null) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.medical_information, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('Belum ada data rekam medis.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Isi Rekam Medis'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard('Golongan Darah', _profile!.golonganDarah, Icons.bloodtype, AppTheme.dangerRed),
        _infoCard('Riwayat Penyakit', _profile!.riwayatPenyakit, Icons.sick, AppTheme.warningYellow),
        _infoCard('Alergi', _profile!.alergi, Icons.coronavirus, AppTheme.accentAmber),
        const SizedBox(height: 16),
        const Text('Kontak Darurat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _infoCard('Nama Kontak', _profile!.kontakDaruratNama, Icons.person, AppTheme.skyBlue),
        _infoCard('No. Telepon', _profile!.kontakDaruratTelepon, Icons.phone, AppTheme.skyBlue),
      ],
    );
  }

  Widget _infoCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        CustomTextField(controller: _golDarahCtrl, label: 'Golongan Darah (A/B/AB/O)'),
        CustomTextField(controller: _riwayatPenyakitCtrl, label: 'Riwayat Penyakit (Bawaan)', maxLines: 3),
        CustomTextField(controller: _alergiCtrl, label: 'Alergi (Obat/Makanan/Lainnya)', maxLines: 2),
        const Divider(height: 32),
        const Text('Kontak Darurat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        CustomTextField(controller: _kontakNamaCtrl, label: 'Nama Kontak Darurat'),
        CustomTextField(controller: _kontakTeleponCtrl, label: 'No. Telepon Darurat', keyboardType: TextInputType.phone),
        const SizedBox(height: 24),
        Row(
          children: [
            if (_profile != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _loadProfile(); // reset fields
                    });
                  },
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
