// ============================================
// TimurLang - SOS Incident Log Model
// ============================================

class SosIncident {
  final String id;
  final String userId;
  final String? gunungId;
  final String? basecampId;
  final double koordinatLat;
  final double koordinatLong;
  final String tipePemicu; // 'fall_detection' or 'manual'
  final String statusPenanganan; // 'darurat_aktif' / 'ditangani' / 'dibatalkan'
  final DateTime waktuKejadian;
  final String? namaPendaki;
  final DateTime createdAt;

  SosIncident({
    required this.id,
    required this.userId,
    this.gunungId,
    this.basecampId,
    required this.koordinatLat,
    required this.koordinatLong,
    required this.tipePemicu,
    required this.statusPenanganan,
    required this.waktuKejadian,
    this.namaPendaki,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'gunung_id': gunungId,
      'basecamp_id': basecampId,
      'koordinat_lat': koordinatLat,
      'koordinat_long': koordinatLong,
      'tipe_pemicu': tipePemicu,
      'status_penanganan': statusPenanganan,
      'waktu_kejadian': waktuKejadian.toIso8601String(),
      'nama_pendaki': namaPendaki,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SosIncident.fromMap(Map<String, dynamic> map) {
    return SosIncident(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      gunungId: map['gunung_id'] as String?,
      basecampId: map['basecamp_id'] as String?,
      koordinatLat: (map['koordinat_lat'] as num).toDouble(),
      koordinatLong: (map['koordinat_long'] as num).toDouble(),
      tipePemicu: map['tipe_pemicu'] as String,
      statusPenanganan: map['status_penanganan'] as String,
      waktuKejadian: DateTime.parse(map['waktu_kejadian'] as String),
      namaPendaki: map['nama_pendaki'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
