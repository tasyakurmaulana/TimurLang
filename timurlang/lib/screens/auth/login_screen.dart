// ============================================
// TimurLang - Login Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService.instance.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      rememberMe: _rememberMe,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      final user = AuthService.instance.currentUser!;
      if (user.peran == 'basecamp') {
        Navigator.pushReplacementNamed(context, AppRoutes.basecampDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _biometricLogin() async {
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      // Jika email sudah diisi, langsung autentikasi untuk email tersebut
      await _executeBiometricAuth(email: email);
      return;
    }

    // Jika email belum diisi, ambil akun-akun dengan sidik jari aktif di perangkat ini
    setState(() => _isLoading = true);
    final users = await AuthService.instance.getBiometricEnabledUsers();
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada akun dengan sidik jari aktif. Masukkan email & kata sandi terlebih dahulu.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    if (users.length == 1) {
      // Hanya ada 1 akun dengan sidik jari aktif
      await _executeBiometricAuth(userId: users.first.id);
      return;
    }

    // Ada lebih dari 1 akun (Multi-Akun): Tampilkan pemilih akun
    final selectedUser = await _showAccountPickerSheet(users);
    if (selectedUser != null && mounted) {
      await _executeBiometricAuth(userId: selectedUser.id);
    }
  }

  Future<void> _executeBiometricAuth({String? email, String? userId}) async {
    setState(() => _isLoading = true);
    final result = await AuthService.instance.authenticateBiometric(
      email: email,
      userId: userId,
      rememberMe: _rememberMe,
    );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.success) {
      final user = AuthService.instance.currentUser!;
      if (user.peran == 'basecamp') {
        Navigator.pushReplacementNamed(context, AppRoutes.basecampDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      if (result.message != 'Verifikasi sidik jari dibatalkan.') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppTheme.dangerRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<User?> _showAccountPickerSheet(List<User> users) {
    return showModalBottomSheet<User>(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fingerprint, color: AppTheme.primaryGreen, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Akun Sidik Jari',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pilih akun yang ingin Anda akses dengan sidik jari',
                            style: TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final u = users[index];
                      final isBasecamp = u.peran == 'basecamp';
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isBasecamp
                                ? AppTheme.accentOrange.withValues(alpha: 0.2)
                                : AppTheme.primaryGreen.withValues(alpha: 0.2),
                            child: Icon(
                              isBasecamp ? Icons.house : Icons.person,
                              color: isBasecamp ? AppTheme.accentOrange : AppTheme.primaryGreen,
                            ),
                          ),
                          title: Text(
                            u.namaLengkap,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            u.email,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isBasecamp
                                  ? AppTheme.accentOrange.withValues(alpha: 0.2)
                                  : AppTheme.primaryGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              u.peran.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isBasecamp ? AppTheme.accentOrange : AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, u),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.mountainGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.terrain, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'TimurLang',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masuk ke akun Anda',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 40),
                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _emailCtrl,
                            label: 'Email',
                            hint: 'masukkan@email.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),
                          CustomTextField(
                            controller: _passwordCtrl,
                            label: 'Kata Sandi',
                            hint: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            isPassword: true,
                            validator: Validators.password,
                          ),
                          const SizedBox(height: 6),
                          // Remember Me checkbox
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: AppTheme.primaryGreen,
                                    checkColor: Colors.white,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _rememberMe = !_rememberMe;
                                    });
                                  },
                                  child: Text(
                                    'Ingat Saya',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Masuk'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Biometric button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _biometricLogin,
                              icon: const Icon(Icons.fingerprint, size: 22),
                              label: const Text('Masuk dengan Sidik Jari'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum punya akun? ',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                                child: const Text(
                                  'Daftar',
                                  style: TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
