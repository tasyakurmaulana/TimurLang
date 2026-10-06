// ============================================
// TimurLang - Auth Service
// Local encryption, session, biometric
// ============================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../utils/crypto_utils.dart';
import 'database_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final _db = DatabaseService.instance;
  final _localAuth = LocalAuthentication();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isBasecamp => _currentUser?.peran == AppConstants.roleBasecamp;
  bool get isPendaki => _currentUser?.peran == AppConstants.rolePendaki;

  /// Register a new user
  Future<({bool success, String message})> register({
    required String namaLengkap,
    required String email,
    required String password,
    required String peran,
  }) async {
    try {
      // Check if email exists
      final existing = await _db.getUserByEmail(email);
      if (existing != null) {
        return (success: false, message: 'Email sudah terdaftar');
      }

      final salt = CryptoUtils.generateSalt(email);
      final passwordHash = CryptoUtils.hashPassword(password, salt);
      final now = DateTime.now();

      final user = User(
        id: const Uuid().v4(),
        peran: peran,
        namaLengkap: namaLengkap,
        email: email,
        passwordHash: '$salt:$passwordHash', // store salt:hash
        createdAt: now,
        updatedAt: now,
      );

      await _db.insertUser(user);
      return (success: true, message: 'Registrasi berhasil!');
    } catch (e) {
      return (success: false, message: 'Gagal mendaftar: ${e.toString()}');
    }
  }

  /// Login with email and password
  Future<({bool success, String message})> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _db.getUserByEmail(email);
      if (user == null) {
        return (success: false, message: 'Email tidak ditemukan');
      }

      // Extract salt and verify
      final parts = user.passwordHash.split(':');
      if (parts.length != 2) {
        return (success: false, message: 'Data akun rusak');
      }

      final salt = parts[0];
      final storedHash = parts[1];
      final inputHash = CryptoUtils.hashPassword(password, salt);

      if (inputHash != storedHash) {
        return (success: false, message: 'Kata sandi salah');
      }

      // Create session
      _currentUser = user;
      await _saveSession(user);

      return (success: true, message: 'Login berhasil!');
    } catch (e) {
      return (success: false, message: 'Gagal login: ${e.toString()}');
    }
  }

  /// Biometric authentication
  Future<({bool success, String message})> authenticateBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheck || !isDeviceSupported) {
        return (success: false, message: 'Perangkat tidak mendukung biometrik');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifikasi sidik jari untuk mengakses TimurLang',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // Try to restore session
        final restored = await restoreSession();
        if (restored) {
          return (success: true, message: 'Autentikasi biometrik berhasil');
        }
        return (success: false, message: 'Sesi tidak ditemukan. Silakan login dengan kata sandi.');
      }

      return (success: false, message: 'Autentikasi biometrik gagal');
    } catch (e) {
      return (success: false, message: 'Error biometrik: ${e.toString()}');
    }
  }

  /// Biometric for medical profile access
  Future<bool> verifyBiometricForMedical() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Verifikasi sidik jari untuk mengakses data medis darurat',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  /// Save session to SharedPreferences
  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userIdKey, user.id);
    await prefs.setString(AppConstants.userRoleKey, user.peran);
    await prefs.setString(AppConstants.sessionTokenKey, const Uuid().v4());
  }

  /// Restore session on app start
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.userIdKey);
      if (userId == null) return false;

      final user = await _db.getUserById(userId);
      if (user == null) return false;

      _currentUser = user;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.userRoleKey);
    await prefs.remove(AppConstants.sessionTokenKey);
    _currentUser = null;
  }

  /// Update user profile
  Future<({bool success, String message})> updateProfile({
    String? namaLengkap,
    String? fotoProfilUrl,
  }) async {
    try {
      if (_currentUser == null) {
        return (success: false, message: 'Pengguna belum login');
      }

      final updated = _currentUser!.copyWith(
        namaLengkap: namaLengkap,
        fotoProfilUrl: fotoProfilUrl,
        updatedAt: DateTime.now(),
      );

      await _db.updateUser(updated);
      _currentUser = updated;
      return (success: true, message: 'Profil berhasil diperbarui');
    } catch (e) {
      return (success: false, message: 'Gagal memperbarui profil: ${e.toString()}');
    }
  }
}
