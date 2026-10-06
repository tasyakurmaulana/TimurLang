// ============================================
// TimurLang - Profile Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _namaCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    if (user != null) {
      _namaCtrl.text = user.namaLengkap;
      _urlCtrl.text = user.fotoProfilUrl ?? '';
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final result = await AuthService.instance.updateProfile(
      namaLengkap: _namaCtrl.text.trim(),
      fotoProfilUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
    );
    setState(() {
      _isLoading = false;
      if (result.success) _isEditing = false;
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

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.embedded) const SizedBox(height: 32),
          // Profile Photo
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardDark,
                  border: Border.all(color: AppTheme.primaryGreen, width: 3),
                  image: user.fotoProfilUrl != null && user.fotoProfilUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(user.fotoProfilUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user.fotoProfilUrl == null || user.fotoProfilUrl!.isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.white54)
                    : null,
              ),
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 24),

          if (!_isEditing) ...[
            Text(user.namaLengkap, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.email, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.5)),
              ),
              child: Text(
                user.peran.toUpperCase(),
                style: const TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profil'),
              ),
            ),
          ] else ...[
            CustomTextField(
              controller: _namaCtrl,
              label: 'Nama Lengkap',
              prefixIcon: Icons.person,
            ),
            CustomTextField(
              controller: _urlCtrl,
              label: 'URL Foto Profil (Opsional)',
              prefixIcon: Icons.link,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _namaCtrl.text = user.namaLengkap;
                        _urlCtrl.text = user.fotoProfilUrl ?? '';
                      });
                    },
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan'),
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
}
