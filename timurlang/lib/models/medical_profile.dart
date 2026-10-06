// ============================================
// TimurLang - Medical Profile Model
// ============================================

class MedicalProfile {
  final String id;
  final String userId;
  final String golonganDarah;
  final String riwayatPenyakit;
  final String alergi;
  final String kontakDaruratNama;
  final String kontakDaruratTelepon;
  final DateTime updatedAt;

  MedicalProfile({
    required this.id,
    required this.userId,
    required this.golonganDarah,
    required this.riwayatPenyakit,
    required this.alergi,
    required this.kontakDaruratNama,
    required this.kontakDaruratTelepon,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'golongan_darah': golonganDarah,
      'riwayat_penyakit': riwayatPenyakit,
      'alergi': alergi,
      'kontak_darurat_nama': kontakDaruratNama,
      'kontak_darurat_telepon': kontakDaruratTelepon,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MedicalProfile.fromMap(Map<String, dynamic> map) {
    return MedicalProfile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      golonganDarah: map['golongan_darah'] as String,
      riwayatPenyakit: map['riwayat_penyakit'] as String,
      alergi: map['alergi'] as String,
      kontakDaruratNama: map['kontak_darurat_nama'] as String,
      kontakDaruratTelepon: map['kontak_darurat_telepon'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  MedicalProfile copyWith({
    String? golonganDarah,
    String? riwayatPenyakit,
    String? alergi,
    String? kontakDaruratNama,
    String? kontakDaruratTelepon,
  }) {
    return MedicalProfile(
      id: id,
      userId: userId,
      golonganDarah: golonganDarah ?? this.golonganDarah,
      riwayatPenyakit: riwayatPenyakit ?? this.riwayatPenyakit,
      alergi: alergi ?? this.alergi,
      kontakDaruratNama: kontakDaruratNama ?? this.kontakDaruratNama,
      kontakDaruratTelepon: kontakDaruratTelepon ?? this.kontakDaruratTelepon,
      updatedAt: DateTime.now(),
    );
  }
}
