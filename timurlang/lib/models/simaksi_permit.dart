// ============================================
// TimurLang - Simaksi Permit Model
// Blockchain-enabled hiking permit with group members support
// ============================================

import 'dart:convert';

class MemberInfo {
  final String nama;
  final String alamat;
  final String kontakDarurat;
  final bool isKetua;
  final String? noKtp;
  final String? noTelepon;

  MemberInfo({
    required this.nama,
    required this.alamat,
    required this.kontakDarurat,
    this.isKetua = false,
    this.noKtp,
    this.noTelepon,
  });

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'alamat': alamat,
      'kontak_darurat': kontakDarurat,
      'is_ketua': isKetua,
      if (noKtp != null) 'no_ktp': noKtp,
      if (noTelepon != null) 'no_telepon': noTelepon,
    };
  }

  factory MemberInfo.fromMap(Map<String, dynamic> map) {
    return MemberInfo(
      nama: (map['nama'] as String?) ?? '',
      alamat: (map['alamat'] as String?) ?? '',
      kontakDarurat: (map['kontak_darurat'] as String?) ?? '',
      isKetua: map['is_ketua'] == true,
      noKtp: map['no_ktp'] as String?,
      noTelepon: map['no_telepon'] as String?,
    );
  }
}

class SimaksiPermit {
  final String id;
  final String userId;
  final String gunungId;
  final String? basecampId;
  final DateTime tanggalNaik;
  final DateTime tanggalTurun;
  final int jumlahAnggota;
  final String statusIzin;
  final String blockHash;
  final String previousHash;
  final int nonce;
  final String? namaGunung; // join field
  final String? namaBasecamp; // join field
  final double? totalBiaya;
  final String? matauang;
  final String? dataAnggota; // JSON serialized list of MemberInfo
  final DateTime createdAt;

  SimaksiPermit({
    required this.id,
    required this.userId,
    required this.gunungId,
    this.basecampId,
    required this.tanggalNaik,
    required this.tanggalTurun,
    required this.jumlahAnggota,
    required this.statusIzin,
    required this.blockHash,
    required this.previousHash,
    required this.nonce,
    this.namaGunung,
    this.namaBasecamp,
    this.totalBiaya,
    this.matauang,
    this.dataAnggota,
    required this.createdAt,
  });

  /// Mengambil daftar anggota rombongan yang telah diparsing
  List<MemberInfo> get members {
    if (dataAnggota == null || dataAnggota!.isEmpty) return [];
    try {
      final decoded = jsonDecode(dataAnggota!);
      if (decoded is List) {
        return decoded
            .map((m) => MemberInfo.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'gunung_id': gunungId,
      'basecamp_id': basecampId,
      'tanggal_naik': tanggalNaik.toIso8601String(),
      'tanggal_turun': tanggalTurun.toIso8601String(),
      'jumlah_anggota': jumlahAnggota,
      'status_izin': statusIzin,
      'block_hash': blockHash,
      'previous_hash': previousHash,
      'nonce': nonce,
      'nama_gunung': namaGunung,
      'nama_basecamp': namaBasecamp,
      'total_biaya': totalBiaya,
      'matauang': matauang,
      'data_anggota': dataAnggota,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SimaksiPermit.fromMap(Map<String, dynamic> map) {
    return SimaksiPermit(
      id: map['id'] as String,
      userId: (map['user_id'] as String?) ?? '',
      gunungId: (map['gunung_id'] as String?) ?? '',
      basecampId: map['basecamp_id'] as String?,
      tanggalNaik: map['tanggal_naik'] != null
          ? DateTime.tryParse(map['tanggal_naik'].toString()) ?? DateTime.now()
          : DateTime.now(),
      tanggalTurun: map['tanggal_turun'] != null
          ? DateTime.tryParse(map['tanggal_turun'].toString()) ?? DateTime.now()
          : DateTime.now(),
      jumlahAnggota: (map['jumlah_anggota'] as num?)?.toInt() ?? 1,
      statusIzin: (map['status_izin'] as String?) ?? 'Terdaftar',
      blockHash: (map['block_hash'] as String?) ?? '',
      previousHash: (map['previous_hash'] as String?) ?? '',
      nonce: (map['nonce'] as num?)?.toInt() ?? 0,
      namaGunung: map['nama_gunung'] as String?,
      namaBasecamp: _cleanBasecampName(map['resolved_nama_basecamp'] as String?) ??
          _cleanBasecampName(map['nama_basecamp'] as String?) ??
          (map['b_nama_pos'] as String?) ??
          (map['nama_pos'] as String?),
      totalBiaya: map['total_biaya'] != null ? (map['total_biaya'] as num).toDouble() : null,
      matauang: map['matauang'] as String?,
      dataAnggota: map['data_anggota'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SimaksiPermit copyWith({
    String? statusIzin,
    String? basecampId,
    String? dataAnggota,
    String? namaGunung,
    String? namaBasecamp,
  }) {
    return SimaksiPermit(
      id: id,
      userId: userId,
      gunungId: gunungId,
      basecampId: basecampId ?? this.basecampId,
      tanggalNaik: tanggalNaik,
      tanggalTurun: tanggalTurun,
      jumlahAnggota: jumlahAnggota,
      statusIzin: statusIzin ?? this.statusIzin,
      blockHash: blockHash,
      previousHash: previousHash,
      nonce: nonce,
      namaGunung: namaGunung ?? this.namaGunung,
      namaBasecamp: namaBasecamp ?? this.namaBasecamp,
      totalBiaya: totalBiaya,
      matauang: matauang,
      dataAnggota: dataAnggota ?? this.dataAnggota,
      createdAt: createdAt,
    );
  }

  static String? _cleanBasecampName(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == 'Pos Basecamp Resmi') return null;
    return trimmed;
  }
}
