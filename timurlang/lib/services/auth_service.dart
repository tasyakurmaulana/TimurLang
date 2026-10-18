// ============================================
// TimurLang - Auth Service
// Local encryption, session, biometric
// Sync auth ke Supabase (online)
// ============================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../models/basecamp_post.dart';
import '../utils/crypto_utils.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'sync_service.dart';
import 'basecamp_alert_service.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final _db = DatabaseService.instance;
  final _supabase = SupabaseService.instance;
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
    String? gunungId,
    String? namaBasecamp,
  }) async {
    try {
      // Check if email exists locally
      final existing = await _db.getUserByEmail(email);
      if (existing != null) {
        return (success: false, message: 'Email sudah terdaftar');
      }

      // Check if email exists online (Supabase)
      if (_supabase.isInitialized) {
        final existingOnline = await _supabase.getUserByEmail(email);
        if (existingOnline != null) {
          return (success: false, message: 'Email sudah terdaftar (online)');
        }
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
        gunungId: gunungId,
        namaBasecamp: namaBasecamp,
        createdAt: now,
        updatedAt: now,
      );

      // Simpan ke database lokal (SQLite)
      await _db.insertUser(user);

      // Jika role basecamp, catat juga entri pos basecamp resmi di tabel basecamp_posts
      if (peran == AppConstants.roleBasecamp && gunungId != null && namaBasecamp != null) {
        final post = BasecampPost(
          id: 'bc-${user.id.substring(0, 8)}',
          gunungId: gunungId,
          userIdPetugas: user.id,
          namaPos: namaBasecamp,
          lokasiDeskripsi: 'Basecamp Resmi $namaBasecamp',
          kontakPos: email,
          createdAt: now,
        );
        await _db.insertBasecampPost(post);
        if (_supabase.isInitialized) {
          await _supabase.syncBasecampPost(post);
        }
      }

      // Sync ke Supabase (online) jika tersedia
      if (_supabase.isInitialized) {
        final synced = await _supabase.syncUser(user);
        if (!synced) {
          // Jika gagal sync, tambahkan ke antrian sync
          await SyncService.instance.addToQueue(
            tableName: 'users',
            recordId: user.id,
            action: 'INSERT',
            payload: user.toMap(),
          );
        }
      }

      return (success: true, message: 'Registrasi berhasil!');
    } catch (e) {
      return (success: false, message: 'Gagal mendaftar: ${e.toString()}');
    }
  }

  /// Auto-login setelah register (tanpa perlu input ulang)
  Future<({bool success, String message})> autoLoginAfterRegister({
    required String email,
    required String password,
  }) async {
    return await login(email: email, password: password);
  }

  /// Cek apakah perangkat mendukung biometrik
  Future<bool> checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Aktifkan biometrik untuk user saat ini
  /// Dipanggil setelah registrasi atau dari pengaturan profil
  Future<({bool success, String message})> enableBiometric() async {
    try {
      if (_currentUser == null) {
        return (success: false, message: 'Pengguna belum login');
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheck || !isDeviceSupported) {
        return (success: false, message: 'Perangkat tidak mendukung biometrik atau sensor belum terdaftar');
      }

      // Verifikasi sidik jari pengguna
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari untuk mengaktifkan login biometrik akun ${_currentUser!.namaLengkap}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (!authenticated) {
        return (success: false, message: 'Verifikasi sidik jari dibatalkan atau gagal');
      }

      // Generate biometric token unik untuk akun ini
      final biometricToken = const Uuid().v4();

      // Update flag dan token di database lokal
      await _db.updateBiometricStatus(_currentUser!.id, true, token: biometricToken);

      // Update objek user saat ini
      _currentUser = _currentUser!.copyWith(
        isBiometricEnabled: true,
        biometricToken: biometricToken,
      );

      // Simpan preferensi biometrik di SharedPreferences (multi-account)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.biometricEnabledKey, true);
      await prefs.setString(AppConstants.lastBiometricUserIdKey, _currentUser!.id);

      final registeredIds = prefs.getStringList(AppConstants.registeredBiometricUserIdsKey) ?? [];
      if (!registeredIds.contains(_currentUser!.id)) {
        registeredIds.add(_currentUser!.id);
        await prefs.setStringList(AppConstants.registeredBiometricUserIdsKey, registeredIds);
      }

      // Sync ke Supabase jika aktif
      if (_supabase.isInitialized) {
        try {
          await _supabase.updateUser(_currentUser!);
        } catch (e) {
          debugPrint('⚠️ Supabase sync biometric failed: $e');
        }
      }

      return (success: true, message: 'Sidik jari berhasil diaktifkan untuk akun ${_currentUser!.namaLengkap}!');
    } catch (e) {
      return (success: false, message: 'Gagal mengaktifkan biometrik: ${e.toString()}');
    }
  }

  /// Nonaktifkan biometrik untuk user saat ini
  Future<({bool success, String message})> disableBiometric() async {
    try {
      if (_currentUser == null) {
        return (success: false, message: 'Pengguna belum login');
      }

      await _db.updateBiometricStatus(_currentUser!.id, false);
      _currentUser = _currentUser!.copyWith(isBiometricEnabled: false, biometricToken: null);

      final prefs = await SharedPreferences.getInstance();
      final registeredIds = prefs.getStringList(AppConstants.registeredBiometricUserIdsKey) ?? [];
      registeredIds.remove(_currentUser!.id);
      await prefs.setStringList(AppConstants.registeredBiometricUserIdsKey, registeredIds);

      if (registeredIds.isEmpty) {
        await prefs.setBool(AppConstants.biometricEnabledKey, false);
        await prefs.remove(AppConstants.lastBiometricUserIdKey);
      } else {
        await prefs.setString(AppConstants.lastBiometricUserIdKey, registeredIds.last);
      }

      if (_supabase.isInitialized) {
        try {
          await _supabase.updateUser(_currentUser!);
        } catch (_) {}
      }

      return (success: true, message: 'Sidik jari berhasil dinonaktifkan');
    } catch (e) {
      return (success: false, message: 'Gagal menonaktifkan biometrik: ${e.toString()}');
    }
  }

  /// Ambil daftar semua user yang telah mengaktifkan biometrik di perangkat ini
  Future<List<User>> getBiometricEnabledUsers() async {
    try {
      final users = await _db.getBiometricUsers();
      if (users.isNotEmpty) return users;

      final prefs = await SharedPreferences.getInstance();
      final registeredIds = prefs.getStringList(AppConstants.registeredBiometricUserIdsKey) ?? [];
      final List<User> result = [];
      for (final id in registeredIds) {
        final u = await _db.getUserById(id);
        if (u != null && u.isBiometricEnabled) {
          result.add(u);
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error getBiometricEnabledUsers: $e');
      return [];
    }
  }

  /// Login with email and password
  Future<({bool success, String message})> login({
    required String email,
    required String password,
  }) async {
    try {
      // Coba cari user di database lokal dulu
      User? user = await _db.getUserByEmail(email);

      // Jika tidak ada lokal, coba dari Supabase
      if (user == null && _supabase.isInitialized) {
        user = await _supabase.getUserByEmail(email);
        if (user != null) {
          // Simpan ke lokal untuk offline access
          await _db.insertUser(user);
        }
      }

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

      // Jika role basecamp, pastikan post basecamp tersimpan di SQLite lokal
      if (user.peran == AppConstants.roleBasecamp && _supabase.isInitialized) {
        final existingPost = await _db.getBasecampByUserId(user.id);
        if (existingPost == null) {
          final post = await _supabase.getBasecampByUserId(user.id);
          if (post != null) {
            await _db.insertBasecampPost(post);
          }
        }
      }

      // Sync data dua arah di background agar perangkat baru langsung terisi data terkini
      SyncService.instance.syncAll();

      // Jika role basecamp, aktifkan radar siaga darurat di latar belakang
      if (user.peran == AppConstants.roleBasecamp) {
        BasecampAlertService.instance.startMonitoring(user: user);
      }

      return (success: true, message: 'Login berhasil!');
    } catch (e) {
      return (success: false, message: 'Gagal login: ${e.toString()}');
    }
  }

  /// Biometric authentication (login)
  /// Mendukung multi-akun: spesifik berdasarkan email atau userId,
  /// atau otomatis jika hanya ada 1 akun dengan sidik jari aktif.
  Future<({bool success, String message})> authenticateBiometric({
    String? email,
    String? userId,
  }) async {
    try {
      User? user;

      if (email != null && email.trim().isNotEmpty) {
        final queryEmail = email.trim();
        user = await _db.getUserByEmail(queryEmail);
        if (user == null && _supabase.isInitialized) {
          user = await _supabase.getUserByEmail(queryEmail);
          if (user != null) {
            await _db.insertUser(user);
          }
        }
        if (user == null) {
          return (
            success: false,
            message: 'Akun dengan email $queryEmail tidak ditemukan.',
          );
        }
      } else if (userId != null && userId.trim().isNotEmpty) {
        user = await _db.getUserById(userId.trim());
        if (user == null && _supabase.isInitialized) {
          user = await _supabase.getUserById(userId.trim());
          if (user != null) {
            await _db.insertUser(user);
          }
        }
        if (user == null) {
          return (
            success: false,
            message: 'Data akun tidak ditemukan.',
          );
        }
      } else {
        // Jika tidak dispesifikasikan, cari akun yang aktif biometrik di perangkat ini
        final biometricUsers = await getBiometricEnabledUsers();
        if (biometricUsers.isEmpty) {
          return (
            success: false,
            message: 'Belum ada akun dengan sidik jari aktif di perangkat ini. Silakan login dengan kata sandi terlebih dahulu.',
          );
        } else if (biometricUsers.length == 1) {
          user = biometricUsers.first;
        } else {
          return (
            success: false,
            message: 'multiple_accounts',
          );
        }
      }

      if (!user.isBiometricEnabled) {
        return (
          success: false,
          message: 'Sidik jari belum diaktifkan untuk akun ${user.email}. Silakan masuk dengan kata sandi dan aktifkan di profil.',
        );
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheck || !isDeviceSupported) {
        return (success: false, message: 'Perangkat tidak mendukung biometrik atau sensor belum diatur.');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari Anda untuk masuk sebagai ${user.namaLengkap}',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated) {
        _currentUser = user;
        await _saveSession(user);
        return (success: true, message: 'Selamat datang kembali, ${user.namaLengkap}!');
      }

      return (success: false, message: 'Verifikasi sidik jari dibatalkan.');
    } catch (e) {
      return (success: false, message: 'Error biometrik: ${e.toString()}');
    }
  }

  /// Biometric for medical profile access
  Future<bool> verifyBiometricForMedical() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;

      return await _localAuth.authenticate(
        localizedReason:
            'Verifikasi sidik jari untuk mengakses data medis darurat',
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
    final sessionToken = const Uuid().v4();
    final expiresAt = DateTime.now().add(
      const Duration(hours: AppConstants.sessionExpiryHours),
    );

    await prefs.setString(AppConstants.userIdKey, user.id);
    await prefs.setString(AppConstants.userRoleKey, user.peran);
    await prefs.setString(AppConstants.sessionTokenKey, sessionToken);
    await prefs.setString('session_expires_at', expiresAt.toIso8601String());
    // Simpan status biometrik dari user record
    await prefs.setBool(AppConstants.biometricEnabledKey, user.isBiometricEnabled);
    if (user.isBiometricEnabled) {
      await prefs.setString(AppConstants.lastBiometricUserIdKey, user.id);
      final registeredIds = prefs.getStringList(AppConstants.registeredBiometricUserIdsKey) ?? [];
      if (!registeredIds.contains(user.id)) {
        registeredIds.add(user.id);
        await prefs.setStringList(AppConstants.registeredBiometricUserIdsKey, registeredIds);
      }
    }
  }

  /// Restore session on app start
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(AppConstants.userIdKey);
      if (userId == null) return false;

      // Cek apakah session sudah expired
      final expiresAtStr = prefs.getString('session_expires_at');
      if (expiresAtStr != null) {
        final expiresAt = DateTime.parse(expiresAtStr);
        if (DateTime.now().isAfter(expiresAt)) {
          // Session expired, hapus dan minta login ulang
          await logout();
          return false;
        }
      }

      // Coba dari database lokal
      User? user = await _db.getUserById(userId);

      // Jika tidak ada lokal, coba dari Supabase
      if (user == null && _supabase.isInitialized) {
        user = await _supabase.getUserById(userId);
        if (user != null) {
          await _db.insertUser(user);
        }
      }

      if (user == null) return false;

      _currentUser = user;
      // Sync background data terbaru dari server
      SyncService.instance.pullFromSupabase();

      // Jika akun basecamp, aktifkan pemantauan darurat latar belakang
      if (user.peran == AppConstants.roleBasecamp) {
        BasecampAlertService.instance.startMonitoring(user: user);
      }

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
    await prefs.remove('session_expires_at');
    // Matikan pemantauan radar basecamp
    await BasecampAlertService.instance.stopMonitoring();
    // Jangan hapus biometricEnabledKey agar tetap bisa login biometrik
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

      // Update lokal
      await _db.updateUser(updated);
      _currentUser = updated;

      // Sync ke Supabase
      if (_supabase.isInitialized) {
        final synced = await _supabase.updateUser(updated);
        if (!synced) {
          await SyncService.instance.addToQueue(
            tableName: 'users',
            recordId: updated.id,
            action: 'UPDATE',
            payload: updated.toMap(),
          );
        }
      }

      return (success: true, message: 'Profil berhasil diperbarui');
    } catch (e) {
      return (
        success: false,
        message: 'Gagal memperbarui profil: ${e.toString()}',
      );
    }
  }
}
