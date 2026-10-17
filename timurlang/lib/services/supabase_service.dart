// ============================================
// TimurLang - Supabase Service
// Online database operations (Supabase)
// ============================================

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user.dart' as app_user;
import '../models/medical_profile.dart';
import '../models/mountain.dart';
import '../models/simaksi_permit.dart';
import '../models/sos_incident.dart';
import '../models/course_feedback.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get isConfigured => SupabaseConfig.isConfigured;

  /// Initialize Supabase client
  Future<void> initialize() async {
    if (_initialized) return;
    if (!SupabaseConfig.isConfigured) {
      debugPrint('⚠️ Supabase belum dikonfigurasi. Menggunakan mode offline saja.');
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _initialized = true;
      debugPrint('✅ Supabase berhasil diinisialisasi');
    } catch (e) {
      debugPrint('❌ Gagal inisialisasi Supabase: $e');
      _initialized = false;
    }
  }

  SupabaseClient? get client => _client;

  // ══════════════════════════════════════════
  // USER OPERATIONS
  // ══════════════════════════════════════════

  /// Sync user ke Supabase (setelah register lokal)
  Future<bool> syncUser(app_user.User user) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('users').upsert({
        'id': user.id,
        'peran': user.peran,
        'nama_lengkap': user.namaLengkap,
        'email': user.email,
        'password_hash': user.passwordHash,
        'foto_profil_url': user.fotoProfilUrl,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Gagal sync user: $e');
      return false;
    }
  }

  /// Get user by email dari Supabase
  Future<app_user.User?> getUserByEmail(String email) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();
      if (response == null) return null;
      return _mapToUser(response);
    } catch (e) {
      debugPrint('❌ Gagal get user by email: $e');
      return null;
    }
  }

  /// Get user by ID dari Supabase
  Future<app_user.User?> getUserById(String id) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return _mapToUser(response);
    } catch (e) {
      debugPrint('❌ Gagal get user by id: $e');
      return null;
    }
  }

  /// Update user di Supabase
  Future<bool> updateUser(app_user.User user) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('users').update({
        'nama_lengkap': user.namaLengkap,
        'foto_profil_url': user.fotoProfilUrl,
        'updated_at': user.updatedAt.toIso8601String(),
      }).eq('id', user.id);
      return true;
    } catch (e) {
      debugPrint('❌ Gagal update user: $e');
      return false;
    }
  }

  app_user.User _mapToUser(Map<String, dynamic> map) {
    return app_user.User(
      id: map['id'] as String,
      peran: map['peran'] as String,
      namaLengkap: map['nama_lengkap'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      fotoProfilUrl: map['foto_profil_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // ══════════════════════════════════════════
  // MEDICAL PROFILE OPERATIONS
  // ══════════════════════════════════════════

  Future<bool> syncMedicalProfile(MedicalProfile profile) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('medical_profiles').upsert({
        'id': profile.id,
        'user_id': profile.userId,
        'golongan_darah': profile.golonganDarah,
        'riwayat_penyakit': profile.riwayatPenyakit,
        'alergi': profile.alergi,
        'kontak_darurat_nama': profile.kontakDaruratNama,
        'kontak_darurat_telepon': profile.kontakDaruratTelepon,
        'updated_at': profile.updatedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Gagal sync medical profile: $e');
      return false;
    }
  }

  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('medical_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return MedicalProfile.fromMap(response);
    } catch (e) {
      debugPrint('❌ Gagal get medical profile: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════
  // MOUNTAIN OPERATIONS
  // ══════════════════════════════════════════

  Future<List<Mountain>> getAllMountains() async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('mountains')
          .select()
          .order('nama_gunung');
      return (response as List).map((m) {
        // Convert Supabase boolean to int for compatibility
        final map = Map<String, dynamic>.from(m);
        if (map['sumber_air_tersedia'] is bool) {
          map['sumber_air_tersedia'] = (map['sumber_air_tersedia'] as bool) ? 1 : 0;
        }
        return Mountain.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('❌ Gagal get mountains: $e');
      return [];
    }
  }

  Future<bool> updateMountainStatus(String id, String status) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!
          .from('mountains')
          .update({'status_jalur': status})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ Gagal update mountain status: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════
  // SIMAKSI PERMIT OPERATIONS
  // ══════════════════════════════════════════

  Future<bool> syncPermit(SimaksiPermit permit) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('simaksi_permits').upsert({
        'id': permit.id,
        'user_id': permit.userId,
        'gunung_id': permit.gunungId,
        'basecamp_id': permit.basecampId,
        'tanggal_naik': permit.tanggalNaik.toIso8601String().split('T')[0],
        'tanggal_turun': permit.tanggalTurun.toIso8601String().split('T')[0],
        'jumlah_anggota': permit.jumlahAnggota,
        'status_izin': permit.statusIzin,
        'block_hash': permit.blockHash,
        'previous_hash': permit.previousHash,
        'nonce': permit.nonce,
        'nama_gunung': permit.namaGunung,
        'total_biaya': permit.totalBiaya,
        'matauang': permit.matauang,
        'created_at': permit.createdAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Gagal sync permit: $e');
      return false;
    }
  }

  Future<List<SimaksiPermit>> getPermitsByUser(String userId) async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('simaksi_permits')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((m) => SimaksiPermit.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('❌ Gagal get permits: $e');
      return [];
    }
  }

  Future<bool> updatePermitStatus(String id, String status) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!
          .from('simaksi_permits')
          .update({'status_izin': status})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ Gagal update permit status: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════
  // SOS INCIDENT OPERATIONS
  // ══════════════════════════════════════════

  Future<bool> syncSosIncident(SosIncident incident) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('sos_incident_logs').upsert({
        'id': incident.id,
        'user_id': incident.userId,
        'gunung_id': incident.gunungId,
        'koordinat_lat': incident.koordinatLat,
        'koordinat_long': incident.koordinatLong,
        'tipe_pemicu': incident.tipePemicu,
        'status_penanganan': incident.statusPenanganan,
        'waktu_kejadian': incident.waktuKejadian.toIso8601String(),
        'nama_pendaki': incident.namaPendaki,
        'created_at': incident.createdAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Gagal sync SOS incident: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════
  // COURSE FEEDBACK OPERATIONS
  // ══════════════════════════════════════════

  Future<bool> syncFeedback(CourseFeedback feedback) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('course_feedbacks').upsert({
        'id': feedback.id,
        'user_id': feedback.userId,
        'nama_pengguna': feedback.namaPengguna,
        'kesan_pesan': feedback.kesanPesan,
        'rating': feedback.rating,
        'submitted_at': feedback.submittedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('❌ Gagal sync feedback: $e');
      return false;
    }
  }

  Future<List<CourseFeedback>> getAllFeedbacks() async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('course_feedbacks')
          .select()
          .order('submitted_at', ascending: false);
      return (response as List)
          .map((m) => CourseFeedback.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('❌ Gagal get feedbacks: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════
  // GENERIC SYNC OPERATIONS
  // ══════════════════════════════════════════

  /// Upsert data ke tabel tertentu
  Future<bool> upsertToTable(String tableName, Map<String, dynamic> data) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from(tableName).upsert(data);
      return true;
    } catch (e) {
      debugPrint('❌ Gagal upsert ke $tableName: $e');
      return false;
    }
  }

  /// Cek koneksi ke Supabase
  Future<bool> checkConnection() async {
    if (!_initialized || _client == null) return false;
    try {
      // Simple ping - try to read mountains count
      await _client!.from('mountains').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
