// ============================================
// TimurLang - Database Service (SQLite)
// Offline-first architecture core
// ============================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../config/constants.dart';
import '../data/seed_data.dart';
import '../models/user.dart';
import '../models/medical_profile.dart';
import '../models/mountain.dart';
import '../models/basecamp_post.dart';
import '../models/simaksi_permit.dart';
import '../models/sos_incident.dart';
import '../models/sync_queue.dart';
import '../models/course_feedback.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  /// Inisialisasi database factory untuk platform web
  /// Menggunakan databaseFactoryFfiWebNoWebWorker agar berjalan langsung di main thread
  /// dan menghindari isu SharedWorker / postMessage null di berbagai browser
  static void initForWeb() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (kIsWeb) {
      path = AppConstants.dbName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, AppConstants.dbName);
    }

    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Pastikan seluruh data 46 gunung dan 112 basecamp terisi
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM mountains'),
      ) ?? 0;
      if (count < 46) {
        await _seedMountains(db);
        await _seedBasecamps(db);
        await _seedBasecampUsers(db);
      }
    } catch (_) {}

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        peran TEXT NOT NULL,
        nama_lengkap TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        foto_profil_url TEXT,
        is_biometric_enabled INTEGER DEFAULT 0,
        biometric_token TEXT,
        gunung_id TEXT,
        nama_basecamp TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE user_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        session_token TEXT NOT NULL,
        is_biometric_enabled INTEGER DEFAULT 0,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE medical_profiles (
        id TEXT PRIMARY KEY,
        user_id TEXT UNIQUE NOT NULL,
        golongan_darah TEXT NOT NULL,
        riwayat_penyakit TEXT NOT NULL,
        alergi TEXT NOT NULL,
        kontak_darurat_nama TEXT NOT NULL,
        kontak_darurat_telepon TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE mountains (
        id TEXT PRIMARY KEY,
        nama_gunung TEXT NOT NULL,
        elevasi_mdpl INTEGER NOT NULL,
        tingkat_bahaya TEXT NOT NULL,
        sumber_air_tersedia INTEGER NOT NULL,
        status_jalur TEXT NOT NULL,
        koordinat_lat REAL NOT NULL,
        koordinat_long REAL NOT NULL,
        deskripsi TEXT,
        foto_url TEXT,
        kuota_harian INTEGER,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE basecamp_posts (
        id TEXT PRIMARY KEY,
        gunung_id TEXT NOT NULL,
        user_id_petugas TEXT,
        nama_pos TEXT NOT NULL,
        lokasi_deskripsi TEXT NOT NULL,
        kontak_pos TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (gunung_id) REFERENCES mountains(id),
        FOREIGN KEY (user_id_petugas) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE simaksi_permits (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        gunung_id TEXT NOT NULL,
        basecamp_id TEXT,
        tanggal_naik TEXT NOT NULL,
        tanggal_turun TEXT NOT NULL,
        jumlah_anggota INTEGER NOT NULL,
        status_izin TEXT NOT NULL,
        block_hash TEXT NOT NULL,
        previous_hash TEXT NOT NULL,
        nonce INTEGER NOT NULL,
        nama_gunung TEXT,
        total_biaya REAL,
        matauang TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (gunung_id) REFERENCES mountains(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sos_incident_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        gunung_id TEXT,
        basecamp_id TEXT,
        koordinat_lat REAL NOT NULL,
        koordinat_long REAL NOT NULL,
        tipe_pemicu TEXT NOT NULL,
        status_penanganan TEXT NOT NULL,
        waktu_kejadian TEXT NOT NULL,
        nama_pendaki TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queues (
        id TEXT PRIMARY KEY,
        nama_tabel TEXT NOT NULL,
        record_id TEXT NOT NULL,
        aksi_tipe TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status_sinkronisasi TEXT NOT NULL,
        synced_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE course_feedbacks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        nama_pengguna TEXT NOT NULL,
        kesan_pesan TEXT NOT NULL,
        rating INTEGER,
        submitted_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Seed data gunung, basecamp, dan akun basecamp
    await _seedMountains(db);
    await _seedBasecamps(db);
    await _seedBasecampUsers(db);
  }

  /// Migrasi database saat versi naik
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Tambah kolom is_biometric_enabled ke tabel users
      await db.execute(
        'ALTER TABLE users ADD COLUMN is_biometric_enabled INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // Tambah kolom biometric_token ke tabel users
      await db.execute(
        'ALTER TABLE users ADD COLUMN biometric_token TEXT',
      );
    }
    if (oldVersion < 4) {
      // Tambah kolom gunung_id dan nama_basecamp ke users, serta basecamp_id ke sos_incident_logs
      try {
        await db.execute('ALTER TABLE users ADD COLUMN gunung_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN nama_basecamp TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE sos_incident_logs ADD COLUMN basecamp_id TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // Hapus data lama sesuai instruksi pengguna:
      // kosongkan data gunung, basecamp, riwayat simaksi, dan akun basecamp
      try {
        await db.delete('simaksi_permits');
        await db.delete('basecamp_posts');
        await db.delete('mountains');
        await db.delete('users', where: 'peran = ?', whereArgs: ['basecamp']);
      } catch (_) {}

      // Masukkan 46 gunung, 112 basecamp, dan 112 akun pengelola basecamp
      await _seedMountains(db);
      await _seedBasecamps(db);
      await _seedBasecampUsers(db);
    }
  }

  Future<void> _seedMountains(Database db) async {
    final batch = db.batch();
    for (final m in SeedData.initialMountains) {
      batch.insert('mountains', m, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedBasecamps(Database db) async {
    final batch = db.batch();
    for (final bc in SeedData.initialBasecampPosts) {
      batch.insert('basecamp_posts', bc, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _seedBasecampUsers(Database db) async {
    final batch = db.batch();
    for (final u in SeedData.initialBasecampUsers) {
      batch.insert('users', u, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Reset total data gunung, basecamp, riwayat simaksi, dan isi ulang 112 basecamp & 46 gunung
  Future<void> resetAndSeedBasecampData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('simaksi_permits');
      await txn.delete('basecamp_posts');
      await txn.delete('mountains');
      await txn.delete('users', where: 'peran = ?', whereArgs: ['basecamp']);

      for (final m in SeedData.initialMountains) {
        await txn.insert('mountains', m, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final bc in SeedData.initialBasecampPosts) {
        await txn.insert('basecamp_posts', bc, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final u in SeedData.initialBasecampUsers) {
        await txn.insert('users', u, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── USER CRUD ──

  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users');
    return maps.map((m) => User.fromMap(m)).toList();
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  /// Update status biometrik user beserta token biometriknya
  Future<void> updateBiometricStatus(String userId, bool enabled, {String? token}) async {
    final db = await database;
    await db.update(
      'users',
      {
        'is_biometric_enabled': enabled ? 1 : 0,
        'biometric_token': enabled ? token : null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Ambil semua user yang telah mengaktifkan sidik jari di perangkat ini
  Future<List<User>> getBiometricUsers() async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'is_biometric_enabled = 1',
      orderBy: 'updated_at DESC, created_at DESC',
    );
    return maps.map((m) => User.fromMap(m)).toList();
  }

  /// Ambil user terakhir yang mengaktifkan sidik jari
  Future<User?> getLastBiometricUser() async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'is_biometric_enabled = 1',
      orderBy: 'updated_at DESC, created_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  // ── MEDICAL PROFILE CRUD ──

  Future<void> insertMedicalProfile(MedicalProfile profile) async {
    final db = await database;
    await db.insert('medical_profiles', profile.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<MedicalProfile?> getMedicalProfile(String userId) async {
    final db = await database;
    final maps = await db.query('medical_profiles', where: 'user_id = ?', whereArgs: [userId]);
    if (maps.isEmpty) return null;
    return MedicalProfile.fromMap(maps.first);
  }

  Future<void> updateMedicalProfile(MedicalProfile profile) async {
    final db = await database;
    await db.update('medical_profiles', profile.toMap(), where: 'id = ?', whereArgs: [profile.id]);
  }

  // ── MOUNTAIN CRUD ──

  Future<List<Mountain>> getAllMountains() async {
    final db = await database;
    final maps = await db.query('mountains', orderBy: 'nama_gunung ASC');
    return maps.map((m) => Mountain.fromMap(m)).toList();
  }

  Future<List<Mountain>> filterMountains({
    int? minElevasi,
    int? maxElevasi,
    String? tingkatBahaya,
    bool? sumberAir,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (minElevasi != null) {
      where.add('elevasi_mdpl >= ?');
      args.add(minElevasi);
    }
    if (maxElevasi != null) {
      where.add('elevasi_mdpl <= ?');
      args.add(maxElevasi);
    }
    if (tingkatBahaya != null) {
      where.add('tingkat_bahaya = ?');
      args.add(tingkatBahaya);
    }
    if (sumberAir != null) {
      where.add('sumber_air_tersedia = ?');
      args.add(sumberAir ? 1 : 0);
    }

    final maps = await db.query(
      'mountains',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'elevasi_mdpl DESC',
    );
    return maps.map((m) => Mountain.fromMap(m)).toList();
  }

  Future<Mountain?> getMountainById(String id) async {
    final db = await database;
    final maps = await db.query('mountains', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Mountain.fromMap(maps.first);
  }

  Future<void> updateMountainStatus(String id, String status) async {
    final db = await database;
    await db.update('mountains', {'status_jalur': status}, where: 'id = ?', whereArgs: [id]);
  }

  // ── BASECAMP CRUD ──

  Future<void> insertBasecampPost(BasecampPost post) async {
    final db = await database;
    await db.insert('basecamp_posts', post.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BasecampPost>> getAllBasecampPosts() async {
    final db = await database;
    final maps = await db.query('basecamp_posts');
    return maps.map((m) => BasecampPost.fromMap(m)).toList();
  }

  Future<List<BasecampPost>> getBasecampsByMountain(String gunungId) async {
    final db = await database;
    final maps = await db.query('basecamp_posts', where: 'gunung_id = ?', whereArgs: [gunungId]);
    return maps.map((m) => BasecampPost.fromMap(m)).toList();
  }

  /// Mengambil basecamp yang sudah terdaftar akun petugasnya untuk gunung tertentu
  Future<List<BasecampPost>> getRegisteredBasecampsByMountain(String gunungId) async {
    final db = await database;
    // Cari yang user_id_petugas terisi (sudah ada akun terdaftar)
    final registeredMaps = await db.query(
      'basecamp_posts',
      where: 'gunung_id = ? AND user_id_petugas IS NOT NULL',
      whereArgs: [gunungId],
      orderBy: 'created_at DESC',
    );
    if (registeredMaps.isNotEmpty) {
      return registeredMaps.map((m) => BasecampPost.fromMap(m)).toList();
    }
    // Jika belum ada yang register khusus, ambil basecamp post default gunung tersebut
    final fallbackMaps = await db.query(
      'basecamp_posts',
      where: 'gunung_id = ?',
      whereArgs: [gunungId],
    );
    return fallbackMaps.map((m) => BasecampPost.fromMap(m)).toList();
  }

  /// Mengambil profil basecamp post milik petugas yang sedang login
  Future<BasecampPost?> getBasecampByUserId(String userId) async {
    final db = await database;
    final maps = await db.query(
      'basecamp_posts',
      where: 'user_id_petugas = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return BasecampPost.fromMap(maps.first);
  }

  Future<BasecampPost?> getBasecampById(String id) async {
    final db = await database;
    final maps = await db.query('basecamp_posts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return BasecampPost.fromMap(maps.first);
  }

  // ── SIMAKSI PERMIT CRUD ──

  Future<void> insertPermit(SimaksiPermit permit) async {
    final db = await database;
    await db.insert('simaksi_permits', permit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SimaksiPermit>> getAllPermits() async {
    final db = await database;
    final maps = await db.query('simaksi_permits');
    return maps.map((m) => SimaksiPermit.fromMap(m)).toList();
  }

  Future<List<SimaksiPermit>> getPermitsByUser(String userId) async {
    final db = await database;
    final maps = await db.query('simaksi_permits', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return maps.map((m) => SimaksiPermit.fromMap(m)).toList();
  }

  /// Mengambil tiket SIMAKSI aktif yang sedang 'Di Jalur' dari seorang pendaki
  Future<SimaksiPermit?> getActivePermitForHiker(String userId) async {
    final db = await database;
    final maps = await db.query(
      'simaksi_permits',
      where: 'user_id = ? AND status_izin = ?',
      whereArgs: [userId, AppConstants.statusDiJalur],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return SimaksiPermit.fromMap(maps.first);
    }
    // Fallback cek status tervalidasi atau terdaftar jika belum check-in
    final fallback = await db.query(
      'simaksi_permits',
      where: 'user_id = ? AND status_izin IN (?, ?)',
      whereArgs: [userId, AppConstants.statusTervalidasi, AppConstants.statusTerdaftar],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (fallback.isNotEmpty) {
      return SimaksiPermit.fromMap(fallback.first);
    }
    return null;
  }

  Future<SimaksiPermit?> getPermitByHash(String blockHash) async {
    final db = await database;
    final clean = blockHash.trim();
    // 1. Cari berdasarkan block_hash (case-insensitive & trim)
    var maps = await db.query(
      'simaksi_permits',
      where: 'LOWER(TRIM(block_hash)) = LOWER(?)',
      whereArgs: [clean],
    );
    if (maps.isNotEmpty) return SimaksiPermit.fromMap(maps.first);

    // 2. Fallback: Cari berdasarkan id tiket (jika barcode membaca ID permit)
    maps = await db.query(
      'simaksi_permits',
      where: 'id = ?',
      whereArgs: [clean],
    );
    if (maps.isNotEmpty) return SimaksiPermit.fromMap(maps.first);

    return null;
  }

  Future<List<SimaksiPermit>> getActivePermits() async {
    final db = await database;
    final maps = await db.query(
      'simaksi_permits',
      where: 'status_izin IN (?, ?, ?)',
      whereArgs: [AppConstants.statusTerdaftar, AppConstants.statusTervalidasi, AppConstants.statusDiJalur],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => SimaksiPermit.fromMap(m)).toList();
  }

  /// Mengambil izin pendaki aktif khusus untuk akun basecamp tertentu
  Future<List<SimaksiPermit>> getActivePermitsForBasecamp({
    required String gunungId,
    String? basecampId,
  }) async {
    final db = await database;
    String whereClause = 'gunung_id = ? AND status_izin = ?';
    List<dynamic> whereArgs = [gunungId, AppConstants.statusDiJalur];

    if (basecampId != null && basecampId.isNotEmpty) {
      whereClause = 'gunung_id = ? AND (basecamp_id = ? OR basecamp_id IS NULL) AND status_izin = ?';
      whereArgs = [gunungId, basecampId, AppConstants.statusDiJalur];
    }

    final maps = await db.query(
      'simaksi_permits',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => SimaksiPermit.fromMap(m)).toList();
  }

  Future<List<SimaksiPermit>> getPermitsByMountain(String gunungId) async {
    final db = await database;
    final maps = await db.query(
      'simaksi_permits',
      where: 'gunung_id = ? AND status_izin IN (?, ?)',
      whereArgs: [gunungId, AppConstants.statusTervalidasi, AppConstants.statusDiJalur],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => SimaksiPermit.fromMap(m)).toList();
  }

  Future<void> updatePermitStatus(String id, String status) async {
    final db = await database;
    await db.update('simaksi_permits', {'status_izin': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getLastPermitHash() async {
    final db = await database;
    final maps = await db.query('simaksi_permits', orderBy: 'created_at DESC', limit: 1);
    if (maps.isEmpty) return 'GENESIS';
    return maps.first['block_hash'] as String;
  }

  // ── SOS INCIDENT CRUD ──

  Future<void> insertSosIncident(SosIncident incident) async {
    final db = await database;
    await db.insert('sos_incident_logs', incident.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SosIncident>> getAllSosIncidents() async {
    final db = await database;
    final maps = await db.query('sos_incident_logs');
    return maps.map((m) => SosIncident.fromMap(m)).toList();
  }

  Future<List<SosIncident>> getActiveSOSIncidents() async {
    final db = await database;
    final maps = await db.query(
      'sos_incident_logs',
      where: 'status_penanganan = ?',
      whereArgs: [AppConstants.sosActive],
      orderBy: 'waktu_kejadian DESC',
    );
    return maps.map((m) => SosIncident.fromMap(m)).toList();
  }

  /// Mengambil insiden SOS darurat aktif khusus untuk akun basecamp terkait
  Future<List<SosIncident>> getActiveSOSIncidentsForBasecamp({
    required String gunungId,
    String? basecampId,
  }) async {
    final allActive = await getActiveSOSIncidents();
    final List<SosIncident> matched = [];

    for (final inc in allActive) {
      // 1. Cek langsung dari gunung_id dan basecamp_id di SOS incident
      if (inc.gunungId != null && inc.gunungId == gunungId) {
        if (basecampId == null || inc.basecampId == null || inc.basecampId == basecampId) {
          matched.add(inc);
          continue;
        }
      }

      // 2. Jika sinyal darurat belum memiliki gunungId (SOS umum / pendaki darurat tanpa tiket),
      // pos basecamp siaga tetap harus menerima peringatan darurat ini
      if (inc.gunungId == null) {
        matched.add(inc);
        continue;
      }

      // 3. Jika gunung_id belum tercatat di SOS, cek tiket SIMAKSI pendaki yang berstatus 'Di Jalur'
      final permit = await getActivePermitForHiker(inc.userId);
      if (permit != null && permit.gunungId == gunungId) {
        if (basecampId == null || permit.basecampId == null || permit.basecampId == basecampId) {
          matched.add(inc);
        }
      }
    }

    return matched;
  }

  Future<void> updateSOSStatus(String id, String status) async {
    final db = await database;
    await db.update('sos_incident_logs', {'status_penanganan': status}, where: 'id = ?', whereArgs: [id]);
  }

  // ── SYNC QUEUE ──

  Future<void> insertSyncQueue(SyncQueue queue) async {
    final db = await database;
    await db.insert('sync_queues', queue.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncQueue>> getPendingSyncItems() async {
    final db = await database;
    final maps = await db.query(
      'sync_queues',
      where: 'status_sinkronisasi = ?',
      whereArgs: [AppConstants.syncPending],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => SyncQueue.fromMap(m)).toList();
  }

  Future<void> updateSyncStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'sync_queues',
      {'status_sinkronisasi': status, 'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── COURSE FEEDBACK ──

  Future<void> insertFeedback(CourseFeedback feedback) async {
    final db = await database;
    await db.insert('course_feedbacks', feedback.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CourseFeedback>> getAllFeedbacks() async {
    final db = await database;
    final maps = await db.query('course_feedbacks', orderBy: 'submitted_at DESC');
    return maps.map((m) => CourseFeedback.fromMap(m)).toList();
  }
}
