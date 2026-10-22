// ============================================
// TimurLang - Profile Screen
// With Direct Photo Pick / Camera Upload
// ============================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/image_helper.dart';
import '../../widgets/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _namaCtrl = TextEditingController();
  
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isPersonalDataComplete = false;
  
  // Holds current photo (base64 Data URI or network URL)
  String? _currentPhotoUrl;
  bool _photoChanged = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkPersonalDataStatus();
  }

  Future<void> _checkPersonalDataStatus() async {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      final pData = await DatabaseService.instance.getPersonalData(user.id);
      if (mounted) {
        setState(() {
          _isPersonalDataComplete = pData != null && pData.isComplete;
        });
      }
    }
  }

  void _loadUserData() {
    final user = AuthService.instance.currentUser;
    if (user != null) {
      _namaCtrl.text = user.namaLengkap;
      _currentPhotoUrl = user.fotoProfilUrl;
      _photoChanged = false;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Pilih Sumber Foto Profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primary),
                title: const Text('Kamera', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                title: const Text('Galeri Foto', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (file != null) {
        final base64String = await ImageHelper.xFileToBase64(file);
        setState(() {
          _currentPhotoUrl = base64String;
          _photoChanged = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih foto: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  /// Full save for edit mode
  Future<void> _saveProfile() async {
    if (_namaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap tidak boleh kosong'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService.instance.updateProfile(
      namaLengkap: _namaCtrl.text.trim(),
      fotoProfilUrl: _currentPhotoUrl,
    );

    setState(() {
      _isLoading = false;
      if (result.success) {
        _isEditing = false;
        _photoChanged = false;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppTheme.safeGreen : AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    final imageProvider = ImageHelper.getImageProvider(_currentPhotoUrl);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.embedded) const SizedBox(height: 32),

          // Profile Avatar (With Edit Camera Badge in Edit Mode)
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _isEditing ? _pickImage : null,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceSubtle,
                      border: Border.all(
                        color: _isEditing ? AppTheme.primary : AppTheme.border,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: imageProvider != null
                          ? DecorationImage(
                              image: imageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageProvider == null
                        ? const Icon(Icons.person_rounded, size: 68, color: AppTheme.textSecondary)
                        : null,
                  ),
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.surface, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_isEditing) ...[
            Text(
              user.namaLengkap,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(user.email, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.5)),
              ),
              child: Text(
                user.peran.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentOrange,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_note),
                label: const Text('Edit Profil'),
              ),
            ),
            const SizedBox(height: 20),

            // ── Keamanan & Biometrik ──
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: SwitchListTile(
                value: user.isBiometricEnabled,
                activeThumbColor: AppTheme.primaryGreen,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fingerprint, color: AppTheme.primaryGreen),
                ),
                title: const Text('Login Sidik Jari', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                subtitle: Text(
                  user.isBiometricEnabled
                      ? 'Sidik jari aktif untuk login cepat'
                      : 'Aktifkan untuk masuk tanpa kata sandi',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                onChanged: (bool value) async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (value) {
                    final res = await AuthService.instance.enableBiometric();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: res.success ? AppTheme.safeGreen : AppTheme.dangerRed,
                      ),
                    );
                    setState(() {});
                  } else {
                    final res = await AuthService.instance.disableBiometric();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res.message),
                        backgroundColor: res.success ? AppTheme.safeGreen : AppTheme.dangerRed,
                      ),
                    );
                    setState(() {});
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            // ── Data Diri Pendaki (Wajib SIMAKSI) ──
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isPersonalDataComplete
                      ? AppTheme.safeGreen.withValues(alpha: 0.35)
                      : AppTheme.accentOrange.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (_isPersonalDataComplete ? AppTheme.safeGreen : AppTheme.accentOrange)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    color: _isPersonalDataComplete ? AppTheme.safeGreen : AppTheme.accentOrange,
                  ),
                ),
                title: const Text(
                  'Data Diri Lengkap',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  _isPersonalDataComplete
                      ? 'KTP, identitas & alamat domisili terverifikasi'
                      : 'Wajib diisi untuk pengajuan izin pendakian SIMAKSI',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () async {
                  await Navigator.pushNamed(context, AppRoutes.personalData);
                  _checkPersonalDataStatus();
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── Rekam Medis Darurat ──
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_services_outlined, color: AppTheme.dangerRed),
                ),
                title: const Text('Data Rekam Medis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(
                  'Data medis & kontak darurat (Dilindungi Sidik Jari)',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.medicalProfile);
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── SOS Darurat & Deteksi Jatuh (Pindah ke Profil) ──
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.35), width: 1.2),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sos_rounded, color: AppTheme.dangerRed, size: 24),
                ),
                title: const Text(
                  'SOS & Deteksi Jatuh',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  'Sirine darurat, deteksi jatuh otomatis & koordinat SAR',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.fallDetection);
                },
              ),
            ),
          ] else ...[
            CustomTextField(
              controller: _namaCtrl,
              label: 'Nama Lengkap',
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: 12),

            // Info Card about photo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.accentOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _photoChanged
                          ? 'Foto baru siap disimpan ke database.'
                          : 'Ketuk foto di atas untuk mengambil foto atau memilih dari galeri.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _loadUserData();
                      });
                    },
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return SafeArea(child: content);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: content,
    );
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }
}
