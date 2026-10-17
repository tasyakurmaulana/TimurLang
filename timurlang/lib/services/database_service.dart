// ============================================
// TimurLang - Database Service (SQLite)
// Offline-first architecture core
// ============================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../config/constants.dart';
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
  /// Harus dipanggil di main() SEBELUM menggunakan database
  static void initForWeb() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
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

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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

    // Seed mountain data
    await _seedMountains(db);
    await _seedBasecamps(db);
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
  }

  Future<void> _seedMountains(Database db) async {
    final mountains = [
      {
        'id': 'mtn-001', 'nama_gunung': 'Gunung Semeru', 'elevasi_mdpl': 3676,
        'tingkat_bahaya': 'Grade 4 - Sangat Sulit', 'sumber_air_tersedia': 1,
        'status_jalur': 'Buka', 'koordinat_lat': -8.108, 'koordinat_long': 112.922,
        'deskripsi': 'Gunung tertinggi di Pulau Jawa dengan puncak Mahameru. Jalur pendakian melalui Ranu Pani melewati savana dan danau Ranu Kumbolo yang ikonik. Erupsi aktif dengan lontaran material vulkanik.',
        'kuota_harian': 300, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-002', 'nama_gunung': 'Gunung Rinjani', 'elevasi_mdpl': 3726,
        'tingkat_bahaya': 'Grade 4 - Sangat Sulit', 'sumber_air_tersedia': 1,
        'status_jalur': 'Buka', 'koordinat_lat': -8.411, 'koordinat_long': 116.457,
        'deskripsi': 'Gunung berapi aktif tertinggi kedua di Indonesia, terletak di Lombok, NTB. Terdapat Danau Segara Anak di kaldera dan sumber air panas alami.',
        'kuota_harian': 200, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-003', 'nama_gunung': 'Gunung Kerinci', 'elevasi_mdpl': 3805,
        'tingkat_bahaya': 'Grade 3 - Sulit', 'sumber_air_tersedia': 1,
        'status_jalur': 'Buka', 'koordinat_lat': -1.697, 'koordinat_long': 101.264,
        'deskripsi': 'Gunung tertinggi di Sumatera dan puncak tertinggi di luar Papua. Terletak di Taman Nasional Kerinci Seblat dengan keanekaragaman hayati tinggi.',
        'kuota_harian': 150, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-004', 'nama_gunung': 'Gunung Merbabu', 'elevasi_mdpl': 3145,
        'tingkat_bahaya': 'Grade 2 - Sedang', 'sumber_air_tersedia': 0,
        'status_jalur': 'Buka', 'koordinat_lat': -7.455, 'koordinat_long': 110.440,
        'deskripsi': 'Gunung dormant di perbatasan Jawa Tengah. Terkenal dengan savana luas dan panorama sunrise yang memukau. Jalur via Selo paling populer.',
        'kuota_harian': 400, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-005', 'nama_gunung': 'Gunung Prau', 'elevasi_mdpl': 2565,
        'tingkat_bahaya': 'Grade 1 - Mudah', 'sumber_air_tersedia': 0,
        'status_jalur': 'Buka', 'koordinat_lat': -7.186, 'koordinat_long': 109.923,
        'deskripsi': 'Gunung ramah pemula di Dataran Tinggi Dieng, Jawa Tengah. Terkenal dengan golden sunrise dan lautan awan. Jalur pendek dan landai.',
        'kuota_harian': 500, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-006', 'nama_gunung': 'Gunung Bromo', 'elevasi_mdpl': 2329,
        'tingkat_bahaya': 'Grade 1 - Mudah', 'sumber_air_tersedia': 0,
        'status_jalur': 'Waspada Cuaca Ekstrem', 'koordinat_lat': -7.942, 'koordinat_long': 112.953,
        'deskripsi': 'Gunung berapi aktif di Taman Nasional Bromo Tengger Semeru. Terkenal dengan lautan pasir dan sunrise dari Penanjakan.',
        'kuota_harian': 600, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-007', 'nama_gunung': 'Gunung Gede Pangrango', 'elevasi_mdpl': 2958,
        'tingkat_bahaya': 'Grade 2 - Sedang', 'sumber_air_tersedia': 1,
        'status_jalur': 'Buka', 'koordinat_lat': -6.787, 'koordinat_long': 106.980,
        'deskripsi': 'Taman Nasional di Jawa Barat dengan Suryakencana sebagai padang edelweiss terluas. Sumber air melimpah sepanjang jalur.',
        'kuota_harian': 300, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-008', 'nama_gunung': 'Gunung Lawu', 'elevasi_mdpl': 3265,
        'tingkat_bahaya': 'Grade 3 - Sulit', 'sumber_air_tersedia': 1,
        'status_jalur': 'Buka', 'koordinat_lat': -7.625, 'koordinat_long': 111.192,
        'deskripsi': 'Gunung mistis di perbatasan Jawa Tengah-Jawa Timur. Terkenal dengan situs candi peninggalan kerajaan Majapahit dan hutan cemara.',
        'kuota_harian': 350, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-009', 'nama_gunung': 'Gunung Cartensz Pyramid', 'elevasi_mdpl': 4884,
        'tingkat_bahaya': 'Grade 5 - Ekstrem', 'sumber_air_tersedia': 1,
        'status_jalur': 'Tutup', 'koordinat_lat': -4.078, 'koordinat_long': 137.158,
        'deskripsi': 'Puncak tertinggi Indonesia dan Oseania (Seven Summits). Terletak di Papua dengan akses terbatas, memerlukan izin khusus dan kemampuan rock climbing.',
        'kuota_harian': 20, 'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'mtn-010', 'nama_gunung': 'Gunung Slamet', 'elevasi_mdpl': 3428,
        'tingkat_bahaya': 'Grade 3 - Sulit', 'sumber_air_tersedia': 1,
        'status_jalur': 'Buka', 'koordinat_lat': -7.242, 'koordinat_long': 109.208,
        'deskripsi': 'Gunung tertinggi kedua di Jawa setelah Semeru. Jalur panjang dan menantang melalui hutan lebat dan medan berpasir.',
        'kuota_harian': 250, 'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final m in mountains) {
      await db.insert('mountains', m);
    }
  }

  Future<void> _seedBasecamps(Database db) async {
    final basecamps = [
      {'id': 'bc-001', 'gunung_id': 'mtn-001', 'nama_pos': 'Pos Ranu Pani', 'lokasi_deskripsi': 'Desa Ranu Pani, Lumajang, Jawa Timur', 'kontak_pos': '0334-8880001', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-002', 'gunung_id': 'mtn-002', 'nama_pos': 'Pos Senaru', 'lokasi_deskripsi': 'Desa Senaru, Lombok Utara, NTB', 'kontak_pos': '0370-8880002', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-003', 'gunung_id': 'mtn-003', 'nama_pos': 'Pos Kersik Tuo', 'lokasi_deskripsi': 'Kersik Tuo, Kayu Aro, Kerinci, Jambi', 'kontak_pos': '0748-8880003', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-004', 'gunung_id': 'mtn-004', 'nama_pos': 'Pos Selo', 'lokasi_deskripsi': 'Desa Selo, Boyolali, Jawa Tengah', 'kontak_pos': '0276-8880004', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-005', 'gunung_id': 'mtn-005', 'nama_pos': 'Pos Dieng Kulon', 'lokasi_deskripsi': 'Desa Dieng Kulon, Banjarnegara, Jawa Tengah', 'kontak_pos': '0286-8880005', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-006', 'gunung_id': 'mtn-006', 'nama_pos': 'Pos Cemoro Lawang', 'lokasi_deskripsi': 'Cemoro Lawang, Probolinggo, Jawa Timur', 'kontak_pos': '0335-8880006', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-007', 'gunung_id': 'mtn-007', 'nama_pos': 'Pos Cibodas', 'lokasi_deskripsi': 'Cibodas, Cianjur, Jawa Barat', 'kontak_pos': '0263-8880007', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-008', 'gunung_id': 'mtn-008', 'nama_pos': 'Pos Cemoro Sewu', 'lokasi_deskripsi': 'Cemoro Sewu, Magetan, Jawa Timur', 'kontak_pos': '0351-8880008', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-009', 'gunung_id': 'mtn-009', 'nama_pos': 'Pos Sugapa', 'lokasi_deskripsi': 'Sugapa, Intan Jaya, Papua', 'kontak_pos': '0901-8880009', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'bc-010', 'gunung_id': 'mtn-010', 'nama_pos': 'Pos Bambangan', 'lokasi_deskripsi': 'Bambangan, Purbalingga, Jawa Tengah', 'kontak_pos': '0281-8880010', 'created_at': DateTime.now().toIso8601String()},
    ];

    for (final bc in basecamps) {
      await db.insert('basecamp_posts', bc);
    }
  }

  // ── USER CRUD ──

  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<List<BasecampPost>> getBasecampsByMountain(String gunungId) async {
    final db = await database;
    final maps = await db.query('basecamp_posts', where: 'gunung_id = ?', whereArgs: [gunungId]);
    return maps.map((m) => BasecampPost.fromMap(m)).toList();
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

  Future<List<SimaksiPermit>> getPermitsByUser(String userId) async {
    final db = await database;
    final maps = await db.query('simaksi_permits', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return maps.map((m) => SimaksiPermit.fromMap(m)).toList();
  }

  Future<SimaksiPermit?> getPermitByHash(String blockHash) async {
    final db = await database;
    final maps = await db.query('simaksi_permits', where: 'block_hash = ?', whereArgs: [blockHash]);
    if (maps.isEmpty) return null;
    return SimaksiPermit.fromMap(maps.first);
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
