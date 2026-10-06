// ============================================
// TimurLang - Mountain Model
// ============================================

class Mountain {
  final String id;
  final String namaGunung;
  final int elevasiMdpl;
  final String tingkatBahaya; // Grade 1-5
  final bool sumberAirTersedia;
  final String statusJalur; // Buka/Tutup/Waspada
  final double koordinatLat;
  final double koordinatLong;
  final String? deskripsi;
  final String? fotoUrl;
  final int? kuotaHarian;
  final DateTime createdAt;

  Mountain({
    required this.id,
    required this.namaGunung,
    required this.elevasiMdpl,
    required this.tingkatBahaya,
    required this.sumberAirTersedia,
    required this.statusJalur,
    required this.koordinatLat,
    required this.koordinatLong,
    this.deskripsi,
    this.fotoUrl,
    this.kuotaHarian,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_gunung': namaGunung,
      'elevasi_mdpl': elevasiMdpl,
      'tingkat_bahaya': tingkatBahaya,
      'sumber_air_tersedia': sumberAirTersedia ? 1 : 0,
      'status_jalur': statusJalur,
      'koordinat_lat': koordinatLat,
      'koordinat_long': koordinatLong,
      'deskripsi': deskripsi,
      'foto_url': fotoUrl,
      'kuota_harian': kuotaHarian,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Mountain.fromMap(Map<String, dynamic> map) {
    return Mountain(
      id: map['id'] as String,
      namaGunung: map['nama_gunung'] as String,
      elevasiMdpl: map['elevasi_mdpl'] as int,
      tingkatBahaya: map['tingkat_bahaya'] as String,
      sumberAirTersedia: (map['sumber_air_tersedia'] as int) == 1,
      statusJalur: map['status_jalur'] as String,
      koordinatLat: (map['koordinat_lat'] as num).toDouble(),
      koordinatLong: (map['koordinat_long'] as num).toDouble(),
      deskripsi: map['deskripsi'] as String?,
      fotoUrl: map['foto_url'] as String?,
      kuotaHarian: map['kuota_harian'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
