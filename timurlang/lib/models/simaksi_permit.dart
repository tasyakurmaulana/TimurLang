// ============================================
// TimurLang - Simaksi Permit Model
// Blockchain-enabled hiking permit
// ============================================

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
  final double? totalBiaya;
  final String? matauang;
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
    this.totalBiaya,
    this.matauang,
    required this.createdAt,
  });

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
      'total_biaya': totalBiaya,
      'matauang': matauang,
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
      totalBiaya: map['total_biaya'] != null ? (map['total_biaya'] as num).toDouble() : null,
      matauang: map['matauang'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  SimaksiPermit copyWith({String? statusIzin, String? basecampId}) {
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
      namaGunung: namaGunung,
      totalBiaya: totalBiaya,
      matauang: matauang,
      createdAt: createdAt,
    );
  }
}
