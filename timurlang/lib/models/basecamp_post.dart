// ============================================
// TimurLang - Basecamp Post Model
// ============================================

class BasecampPost {
  final String id;
  final String gunungId;
  final String? userIdPetugas;
  final String namaPos;
  final String lokasiDeskripsi;
  final String? kontakPos;
  final DateTime createdAt;

  BasecampPost({
    required this.id,
    required this.gunungId,
    this.userIdPetugas,
    required this.namaPos,
    required this.lokasiDeskripsi,
    this.kontakPos,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gunung_id': gunungId,
      'user_id_petugas': userIdPetugas,
      'nama_pos': namaPos,
      'lokasi_deskripsi': lokasiDeskripsi,
      'kontak_pos': kontakPos,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BasecampPost.fromMap(Map<String, dynamic> map) {
    return BasecampPost(
      id: map['id'] as String,
      gunungId: map['gunung_id'] as String,
      userIdPetugas: map['user_id_petugas'] as String?,
      namaPos: map['nama_pos'] as String,
      lokasiDeskripsi: map['lokasi_deskripsi'] as String,
      kontakPos: map['kontak_pos'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
