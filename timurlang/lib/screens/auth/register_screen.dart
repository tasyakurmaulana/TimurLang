// ============================================
// TimurLang - Register Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = AppConstants.rolePendaki;
  bool _isLoading = false;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    final result = await AuthService.instance.register(
      namaLengkap: _namaCtrl.text.trim(),
      email: email,
      password: password,
      peran: _selectedRole,
    );

    if (!mounted) return;

    if (result.success) {
      // Auto-login setelah registrasi berhasil
      final loginResult = await AuthService.instance.autoLoginAfterRegister(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (loginResult.success) {
        // Cek apakah perangkat mendukung biometrik
        final biometricAvailable =
            await AuthService.instance.checkBiometricAvailability();

        if (biometricAvailable && mounted) {
          // Tampilkan dialog aktivasi sidik jari
          await _showBiometricDialog();
        }

        if (!mounted) return;

        // Navigasi ke home sesuai peran
        final user = AuthService.instance.currentUser!;
        if (user.peran == 'basecamp') {
          Navigator.pushReplacementNamed(context, AppRoutes.basecampDashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        // Auto-login gagal, kembali ke login manual
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrasi berhasil! Silakan login.'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Dialog untuk mengaktifkan sidik jari setelah registrasi
  Future<void> _showBiometricDialog() async {
    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: AppTheme.primaryGreen, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aktifkan Sidik Jari?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gunakan sidik jari untuk:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 12),
            _BiometricFeatureItem(
              icon: Icons.login,
              text: 'Login cepat tanpa kata sandi',
            ),
            SizedBox(height: 8),
            _BiometricFeatureItem(
              icon: Icons.medical_information,
              text: 'Akses data rekam medis darurat',
            ),
            SizedBox(height: 16),
            Text(
              'Anda bisa mengaktifkan atau menonaktifkan ini nanti di pengaturan profil.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nanti Saja', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.fingerprint, size: 20),
            label: const Text('Aktifkan'),
          ),
        ],
      ),
    );

    if (shouldEnable == true && mounted) {
      // Proses verifikasi sidik jari
      final result = await AuthService.instance.enableBiometric();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppTheme.safeGreen : AppTheme.dangerRed,
            duration: const Duration(seconds: 2),
          ),
        );
        if (result.success) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D3B13), Color(0xFF121212)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Daftar Akun',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buat akun baru untuk mulai mendaki',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 32),
                // Role selection
                const Text(
                  'Daftar Sebagai',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _roleCard(
                        'Pendaki',
                        Icons.hiking,
                        AppConstants.rolePendaki,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _roleCard(
                        'Basecamp',
                        Icons.house,
                        AppConstants.roleBasecamp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        controller: _namaCtrl,
                        label: 'Nama Lengkap',
                        prefixIcon: Icons.person_outline,
                        validator: (v) => Validators.required(v, 'Nama'),
                      ),
                      CustomTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      CustomTextField(
                        controller: _passwordCtrl,
                        label: 'Kata Sandi',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        validator: Validators.password,
                      ),
                      CustomTextField(
                        controller: _confirmCtrl,
                        label: 'Konfirmasi Kata Sandi',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Daftar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(String label, IconData icon, String role) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryGreen : Colors.white54, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryGreen : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget item fitur biometrik di dialog
class _BiometricFeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BiometricFeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
