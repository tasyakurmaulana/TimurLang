// ============================================
// TimurLang - Basecamp Post Model
// Mengatur kuota, status jalur buka/tutup & tarif SIMAKSI per basecamp
// ============================================

class BasecampPost {
  final String id;
  final String gunungId;
  final String? userIdPetugas;
  final String namaPos;
  final String lokasiDeskripsi;
  final String? kontakPos;
  final String statusJalur; // 'Buka' atau 'Tutup'
  final int kuotaHarian;
  final int sisaKuotaHariIni;
  final double hargaSimaksi; // Tarif per orang per hari dalam IDR
  final String? checkpointsJson; // JSON serialization of List<TrailCheckpoint>
  final DateTime createdAt;
  final DateTime? updatedAt;

  BasecampPost({
    required this.id,
    required this.gunungId,
    this.userIdPetugas,
    required this.namaPos,
    required this.lokasiDeskripsi,
    this.kontakPos,
    this.statusJalur = 'Buka',
    this.kuotaHarian = 100,
    int? sisaKuotaHariIni,
    this.hargaSimaksi = 15000.0,
    this.checkpointsJson,
    required this.createdAt,
    this.updatedAt,
  }) : sisaKuotaHariIni = sisaKuotaHariIni ?? kuotaHarian;

  bool get isBuka => statusJalur.toLowerCase() == 'buka';
  bool get hasRemainingQuota => sisaKuotaHariIni > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gunung_id': gunungId,
      'user_id_petugas': userIdPetugas,
      'nama_pos': namaPos,
      'lokasi_deskripsi': lokasiDeskripsi,
      'kontak_pos': kontakPos,
      'status_jalur': statusJalur,
      'kuota_harian': kuotaHarian,
      'sisa_kuota_hari_ini': sisaKuotaHariIni,
      'harga_simaksi': hargaSimaksi,
      'checkpoints_json': checkpointsJson,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toIso8601String(),
    };
  }

  factory BasecampPost.fromMap(Map<String, dynamic> map) {
    final int kuota = (map['kuota_harian'] as num?)?.toInt() ?? 100;
    final int sisa = (map['sisa_kuota_hari_ini'] as num?)?.toInt() ?? kuota;
    final double harga = (map['harga_simaksi'] as num?)?.toDouble() ?? 15000.0;

    return BasecampPost(
      id: map['id'] as String,
      gunungId: (map['gunung_id'] as String?) ?? 'mtn-001',
      userIdPetugas: map['user_id_petugas'] as String?,
      namaPos: (map['nama_pos'] as String?) ?? 'Pos Basecamp',
      lokasiDeskripsi: (map['lokasi_deskripsi'] as String?) ?? '',
      kontakPos: map['kontak_pos'] as String?,
      statusJalur: (map['status_jalur'] as String?) ?? 'Buka',
      kuotaHarian: kuota,
      sisaKuotaHariIni: sisa,
      hargaSimaksi: harga,
      checkpointsJson: map['checkpoints_json'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  BasecampPost copyWith({
    String? id,
    String? gunungId,
    String? userIdPetugas,
    String? namaPos,
    String? lokasiDeskripsi,
    String? kontakPos,
    String? statusJalur,
    int? kuotaHarian,
    int? sisaKuotaHariIni,
    double? hargaSimaksi,
    String? checkpointsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BasecampPost(
      id: id ?? this.id,
      gunungId: gunungId ?? this.gunungId,
      userIdPetugas: userIdPetugas ?? this.userIdPetugas,
      namaPos: namaPos ?? this.namaPos,
      lokasiDeskripsi: lokasiDeskripsi ?? this.lokasiDeskripsi,
      kontakPos: kontakPos ?? this.kontakPos,
      statusJalur: statusJalur ?? this.statusJalur,
      kuotaHarian: kuotaHarian ?? this.kuotaHarian,
      sisaKuotaHariIni: sisaKuotaHariIni ?? this.sisaKuotaHariIni,
      hargaSimaksi: hargaSimaksi ?? this.hargaSimaksi,
      checkpointsJson: checkpointsJson ?? this.checkpointsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
