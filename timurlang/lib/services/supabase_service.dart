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
import '../models/basecamp_post.dart';
import '../models/simaksi_permit.dart';
import '../models/sos_incident.dart';
import '../models/user_personal_data.dart';
import '../models/course_feedback.dart';
import 'database_service.dart';

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
      // Coba kirim payload lengkap dengan kolom-kolom baru
      await _client!.from('users').upsert({
        'id': user.id,
        'peran': user.peran,
        'nama_lengkap': user.namaLengkap,
        'email': user.email,
        'password_hash': user.passwordHash,
        'foto_profil_url': user.fotoProfilUrl,
        'is_biometric_enabled': user.isBiometricEnabled,
        'biometric_token': user.biometricToken,
        'gunung_id': user.gunungId,
        'nama_basecamp': user.namaBasecamp,
        'created_at': user.createdAt.toIso8601String(),
        'updated_at': user.updatedAt.toIso8601String(),
      });
      debugPrint('✅ Berhasil sync user (${user.email}) ke Supabase');
      return true;
    } catch (e) {
      debugPrint('⚠️ Gagal sync user dengan kolom lengkap ($e), mencoba fallback kolom dasar...');
      // Fallback jika kolom baru (gunung_id, dll) belum dibuat di Supabase
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
        debugPrint('✅ Berhasil sync user (${user.email}) ke Supabase via fallback dasar');
        return true;
      } catch (e2) {
        debugPrint('❌ Gagal sync user fallback: $e2');
        return false;
      }
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
        'is_biometric_enabled': user.isBiometricEnabled,
        'biometric_token': user.biometricToken,
        'gunung_id': user.gunungId,
        'nama_basecamp': user.namaBasecamp,
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
      isBiometricEnabled: map['is_biometric_enabled'] == true || map['is_biometric_enabled'] == 1,
      biometricToken: map['biometric_token'] as String?,
      gunungId: map['gunung_id'] as String?,
      namaBasecamp: map['nama_basecamp'] as String?,
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
  // USER PERSONAL DATA OPERATIONS (Syarat SIMAKSI)
  // ══════════════════════════════════════════

  Future<bool> syncPersonalData(UserPersonalData data) async {
    if (!_initialized || _client == null) return false;
    try {
      // 1. Pastikan user lokal sudah tersinkronisasi ke tabel users di Supabase terlebih dahulu
      final localUser = await DatabaseService.instance.getUserById(data.userId);
      if (localUser != null) {
        await syncUser(localUser);
      }

      final payload = {
        'user_id': data.userId,
        'kewarganegaraan': data.kewarganegaraan,
        'jenis_identitas': data.jenisIdentitas,
        'nomor_ktp': data.nomorKtp,
        'file_ktp_url': data.fileKtpUrl,
        'nama_lengkap': data.namaLengkap,
        'nama_belakang': data.namaBelakang,
        'tanggal_lahir': data.tanggalLahir.toIso8601String().split('T')[0],
        'jenis_kelamin': data.jenisKelamin,
        'no_telepon': data.noTelepon,
        'no_telepon_darurat': data.noTeleponDarurat,
        'surel': data.surel,
        'berat_badan': data.beratBadan,
        'tinggi_badan': data.tinggiBadan,
        'provinsi': data.provinsi,
        'kota_kabupaten': data.kotaKabupaten,
        'kecamatan': data.kecamatan,
        'kelurahan': data.kelurahan,
        'alamat': data.alamat,
        'updated_at': data.updatedAt.toIso8601String(),
      };

      await _client!.from('user_personal_data').upsert(payload, onConflict: 'user_id');
      debugPrint('✅ Berhasil sync data diri (${data.userId}) ke Supabase');
      return true;
    } catch (e) {
      debugPrint('⚠️ Gagal sync data diri ke Supabase: $e');
      return false;
    }
  }

  Future<UserPersonalData?> getPersonalData(String userId) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('user_personal_data')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return UserPersonalData.fromMap(response);
    } catch (e) {
      debugPrint('⚠️ Gagal get data diri dari Supabase: $e');
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
  // BASECAMP POST OPERATIONS
  // ══════════════════════════════════════════

  Future<bool> syncBasecampPost(BasecampPost post) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('basecamp_posts').upsert({
        'id': post.id,
        'gunung_id': post.gunungId,
        'user_id_petugas': post.userIdPetugas,
        'nama_pos': post.namaPos,
        'lokasi_deskripsi': post.lokasiDeskripsi,
        'kontak_pos': post.kontakPos,
        'status_jalur': post.statusJalur,
        'kuota_harian': post.kuotaHarian,
        'sisa_kuota_hari_ini': post.sisaKuotaHariIni,
        'harga_simaksi': post.hargaSimaksi,
        'created_at': post.createdAt.toIso8601String(),
        'updated_at': (post.updatedAt ?? post.createdAt).toIso8601String(),
      });
      debugPrint('✅ Berhasil sync basecamp post (${post.namaPos}) ke Supabase');
      return true;
    } catch (e) {
      debugPrint('⚠️ Gagal sync basecamp post dengan kolom lengkap ($e), mencoba fallback dasar...');
      try {
        await _client!.from('basecamp_posts').upsert({
          'id': post.id,
          'gunung_id': post.gunungId,
          'user_id_petugas': post.userIdPetugas,
          'nama_pos': post.namaPos,
          'lokasi_deskripsi': post.lokasiDeskripsi,
          'kontak_pos': post.kontakPos,
          'created_at': post.createdAt.toIso8601String(),
        });
        debugPrint('✅ Berhasil sync basecamp post (${post.namaPos}) via fallback dasar');
        return true;
      } catch (e2) {
        debugPrint('❌ Gagal sync basecamp post fallback: $e2');
        return false;
      }
    }
  }

  /// Update pengaturan operasional basecamp ke Supabase
  Future<bool> updateBasecampSettings({
    required String basecampId,
    required String statusJalur,
    required int kuotaHarian,
    required int sisaKuotaHariIni,
    required double hargaSimaksi,
  }) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!.from('basecamp_posts').update({
        'status_jalur': statusJalur,
        'kuota_harian': kuotaHarian,
        'sisa_kuota_hari_ini': sisaKuotaHariIni,
        'harga_simaksi': hargaSimaksi,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', basecampId);
      debugPrint('✅ Berhasil update pengaturan basecamp $basecampId di Supabase');
      return true;
    } catch (e) {
      debugPrint('⚠️ Gagal update basecamp settings di Supabase: $e');
      return false;
    }
  }

  /// Kurangi sisa kuota basecamp secara realtime di Supabase
  Future<bool> reduceBasecampQuota(String basecampId, int amount) async {
    if (!_initialized || _client == null) return false;
    try {
      final res = await _client!
          .from('basecamp_posts')
          .select('kuota_harian, sisa_kuota_hari_ini')
          .eq('id', basecampId)
          .maybeSingle();
      if (res != null) {
        final kuota = (res['kuota_harian'] as num?)?.toInt() ?? 100;
        final currentSisa = (res['sisa_kuota_hari_ini'] as num?)?.toInt() ?? kuota;
        final newSisa = (currentSisa - amount).clamp(0, kuota);
        await _client!.from('basecamp_posts').update({
          'sisa_kuota_hari_ini': newSisa,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', basecampId);
        debugPrint('✅ Berhasil kurangi kuota basecamp $basecampId sebesar $amount di Supabase (sisa: $newSisa)');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Gagal reduce kuota basecamp di Supabase: $e');
      return false;
    }
  }

  /// Mengambil semua pos basecamp dari Supabase
  Future<List<BasecampPost>> getAllBasecampPosts() async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('basecamp_posts')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((m) => BasecampPost.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ Gagal get all basecamp posts: $e');
      return [];
    }
  }

  /// Mengambil basecamp berdasarkan ID gunung
  Future<List<BasecampPost>> getBasecampsByMountain(String gunungId) async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('basecamp_posts')
          .select()
          .eq('gunung_id', gunungId)
          .order('created_at', ascending: false);
      return (response as List).map((m) => BasecampPost.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ Gagal get basecamps by mountain: $e');
      return [];
    }
  }

  /// Mengambil basecamp berdasarkan user ID petugas
  Future<BasecampPost?> getBasecampByUserId(String userId) async {
    if (!_initialized || _client == null) return null;
    try {
      final response = await _client!
          .from('basecamp_posts')
          .select()
          .eq('user_id_petugas', userId)
          .maybeSingle();
      if (response == null) return null;
      return BasecampPost.fromMap(response);
    } catch (e) {
      debugPrint('❌ Gagal get basecamp by user id: $e');
      return null;
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
        if (permit.dataAnggota != null) 'data_anggota': permit.dataAnggota,
        'created_at': permit.createdAt.toIso8601String(),
      });
      debugPrint('✅ Berhasil sync permit (${permit.id}) ke Supabase');
      return true;
    } catch (e) {
      debugPrint('⚠️ Gagal sync permit lengkap: $e, mencoba fallback tanpa basecamp_id...');
      try {
        await _client!.from('simaksi_permits').upsert({
          'id': permit.id,
          'user_id': permit.userId,
          'gunung_id': permit.gunungId,
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
        debugPrint('✅ Berhasil sync permit via fallback');
        return true;
      } catch (e2) {
        debugPrint('❌ Gagal sync permit fallback: $e2');
        return false;
      }
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

  /// Mengambil semua izin SIMAKSI dari Supabase
  Future<List<SimaksiPermit>> getAllPermits() async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('simaksi_permits')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((m) => SimaksiPermit.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('❌ Gagal get all permits: $e');
      return [];
    }
  }

  /// Mengambil tiket SIMAKSI berdasarkan hash tiket blockchain
  Future<SimaksiPermit?> getPermitByHash(String blockHash) async {
    if (!_initialized || _client == null) return null;
    try {
      final clean = blockHash.trim();
      var response = await _client!
          .from('simaksi_permits')
          .select()
          .ilike('block_hash', clean)
          .maybeSingle();
      if (response != null) return SimaksiPermit.fromMap(response);

      // Fallback: Cari by id
      response = await _client!
          .from('simaksi_permits')
          .select()
          .eq('id', clean)
          .maybeSingle();
      if (response != null) return SimaksiPermit.fromMap(response);

      return null;
    } catch (e) {
      debugPrint('❌ Gagal get permit by hash: $e');
      return null;
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
        'basecamp_id': incident.basecampId,
        'koordinat_lat': incident.koordinatLat,
        'koordinat_long': incident.koordinatLong,
        'tipe_pemicu': incident.tipePemicu,
        'status_penanganan': incident.statusPenanganan,
        'waktu_kejadian': incident.waktuKejadian.toIso8601String(),
        'nama_pendaki': incident.namaPendaki,
        'created_at': incident.createdAt.toIso8601String(),
      });
      debugPrint('✅ Berhasil sync SOS incident ke Supabase');
      return true;
    } catch (e) {
      debugPrint('⚠️ Gagal sync SOS lengkap: $e, mencoba fallback tanpa basecamp_id...');
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
        debugPrint('✅ Berhasil sync SOS incident via fallback');
        return true;
      } catch (e2) {
        debugPrint('❌ Gagal sync SOS incident fallback: $e2');
        return false;
      }
    }
  }

  Future<bool> updateSosStatus(String id, String status) async {
    if (!_initialized || _client == null) return false;
    try {
      await _client!
          .from('sos_incident_logs')
          .update({'status_penanganan': status})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ Gagal update SOS status di Supabase: $e');
      return false;
    }
  }

  /// Mengambil insiden SOS yang berstatus darurat aktif ('darurat_aktif')
  Future<List<SosIncident>> getActiveSOSIncidents() async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('sos_incident_logs')
          .select()
          .eq('status_penanganan', 'darurat_aktif')
          .order('waktu_kejadian', ascending: false);
      return (response as List).map((m) => SosIncident.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ Gagal get active SOS incidents dari Supabase: $e');
      return [];
    }
  }

  /// Mengambil semua log insiden SOS dari Supabase
  Future<List<SosIncident>> getAllSosIncidents() async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('sos_incident_logs')
          .select()
          .order('waktu_kejadian', ascending: false);
      return (response as List).map((m) => SosIncident.fromMap(m)).toList();
    } catch (e) {
      debugPrint('❌ Gagal get all SOS incidents dari Supabase: $e');
      return [];
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
      // Jika gagal karena foreign key user_id belum ada di tabel users Supabase, sinkronkan user dulu lalu coba lagi
      try {
        final localUser = await DatabaseService.instance.getUserById(feedback.userId);
        if (localUser != null) {
          final userSynced = await syncUser(localUser);
          if (userSynced) {
            await _client!.from('course_feedbacks').upsert({
              'id': feedback.id,
              'user_id': feedback.userId,
              'nama_pengguna': feedback.namaPengguna,
              'kesan_pesan': feedback.kesanPesan,
              'rating': feedback.rating,
              'submitted_at': feedback.submittedAt.toIso8601String(),
            });
            debugPrint('✅ Berhasil sync feedback setelah sinkronisasi user');
            return true;
          }
        }
      } catch (retryError) {
        debugPrint('❌ Gagal retry sync feedback: $retryError');
      }
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

  Future<List<CourseFeedback>> getLatestFeedbacks({int limit = 5}) async {
    if (!_initialized || _client == null) return [];
    try {
      final response = await _client!
          .from('course_feedbacks')
          .select()
          .order('submitted_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((m) => CourseFeedback.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('❌ Gagal get latest feedbacks: $e');
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
