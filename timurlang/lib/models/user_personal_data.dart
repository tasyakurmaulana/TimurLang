// ============================================
// TimurLang - User Personal Data Model
// Syarat wajib pendaftaran izin SIMAKSI
// ============================================

class UserPersonalData {
  final String id;
  final String userId;
  final String kewarganegaraan; // 'WNI' or 'WNA'
  final String jenisIdentitas; // 'KTP', 'Paspor', 'SIM', 'KITAS'
  final String nomorKtp;
  final String? fileKtpUrl; // Base64 data URI atau image URL
  final String namaLengkap;
  final String? namaBelakang;
  final DateTime tanggalLahir;
  final String jenisKelamin; // 'Laki-laki' or 'Perempuan'
  final String noTelepon;
  final String noTeleponDarurat;
  final String surel;
  final double? beratBadan; // dalam kg
  final double? tinggiBadan; // dalam cm
  final String provinsi;
  final String kotaKabupaten;
  final String kecamatan;
  final String kelurahan;
  final String alamat;
  final DateTime updatedAt;

  UserPersonalData({
    required this.id,
    required this.userId,
    required this.kewarganegaraan,
    required this.jenisIdentitas,
    required this.nomorKtp,
    this.fileKtpUrl,
    required this.namaLengkap,
    this.namaBelakang,
    required this.tanggalLahir,
    required this.jenisKelamin,
    required this.noTelepon,
    required this.noTeleponDarurat,
    required this.surel,
    this.beratBadan,
    this.tinggiBadan,
    required this.provinsi,
    required this.kotaKabupaten,
    required this.kecamatan,
    required this.kelurahan,
    required this.alamat,
    required this.updatedAt,
  });

  /// Nama lengkap gabungan (depan + belakang)
  String get namaGabungan {
    if (namaBelakang != null && namaBelakang!.trim().isNotEmpty) {
      return '$namaLengkap ${namaBelakang!.trim()}'.trim();
    }
    return namaLengkap.trim();
  }

  /// Cek kelengkapan data diri sesuai syarat SIMAKSI
  bool get isComplete {
    return nomorKtp.trim().isNotEmpty &&
        namaLengkap.trim().isNotEmpty &&
        noTelepon.trim().isNotEmpty &&
        noTeleponDarurat.trim().isNotEmpty &&
        surel.trim().isNotEmpty &&
        provinsi.trim().isNotEmpty &&
        kotaKabupaten.trim().isNotEmpty &&
        kecamatan.trim().isNotEmpty &&
        kelurahan.trim().isNotEmpty &&
        alamat.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'kewarganegaraan': kewarganegaraan,
      'jenis_identitas': jenisIdentitas,
      'nomor_ktp': nomorKtp,
      'file_ktp_url': fileKtpUrl,
      'nama_lengkap': namaLengkap,
      'nama_belakang': namaBelakang,
      'tanggal_lahir': tanggalLahir.toIso8601String().split('T')[0],
      'jenis_kelamin': jenisKelamin,
      'no_telepon': noTelepon,
      'no_telepon_darurat': noTeleponDarurat,
      'surel': surel,
      'berat_badan': beratBadan,
      'tinggi_badan': tinggiBadan,
      'provinsi': provinsi,
      'kota_kabupaten': kotaKabupaten,
      'kecamatan': kecamatan,
      'kelurahan': kelurahan,
      'alamat': alamat,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserPersonalData.fromMap(Map<String, dynamic> map) {
    return UserPersonalData(
      id: (map['id'] as String?) ?? (map['user_id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      kewarganegaraan: (map['kewarganegaraan'] as String?) ?? 'WNI',
      jenisIdentitas: (map['jenis_identitas'] as String?) ?? 'KTP',
      nomorKtp: (map['nomor_ktp'] as String?) ?? '',
      fileKtpUrl: map['file_ktp_url'] as String?,
      namaLengkap: (map['nama_lengkap'] as String?) ?? '',
      namaBelakang: map['nama_belakang'] as String?,
      tanggalLahir: map['tanggal_lahir'] != null
          ? DateTime.tryParse(map['tanggal_lahir'].toString()) ?? DateTime(2000, 1, 1)
          : DateTime(2000, 1, 1),
      jenisKelamin: (map['jenis_kelamin'] as String?) ?? 'Laki-laki',
      noTelepon: (map['no_telepon'] as String?) ?? '',
      noTeleponDarurat: (map['no_telepon_darurat'] as String?) ?? '',
      surel: (map['surel'] as String?) ?? '',
      beratBadan: map['berat_badan'] != null ? (map['berat_badan'] as num).toDouble() : null,
      tinggiBadan: map['tinggi_badan'] != null ? (map['tinggi_badan'] as num).toDouble() : null,
      provinsi: (map['provinsi'] as String?) ?? '',
      kotaKabupaten: (map['kota_kabupaten'] as String?) ?? '',
      kecamatan: (map['kecamatan'] as String?) ?? '',
      kelurahan: (map['kelurahan'] as String?) ?? '',
      alamat: (map['alamat'] as String?) ?? '',
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserPersonalData copyWith({
    String? kewarganegaraan,
    String? jenisIdentitas,
    String? nomorKtp,
    String? fileKtpUrl,
    String? namaLengkap,
    String? namaBelakang,
    DateTime? tanggalLahir,
    String? jenisKelamin,
    String? noTelepon,
    String? noTeleponDarurat,
    String? surel,
    double? beratBadan,
    double? tinggiBadan,
    String? provinsi,
    String? kotaKabupaten,
    String? kecamatan,
    String? kelurahan,
    String? alamat,
    DateTime? updatedAt,
  }) {
    return UserPersonalData(
      id: id,
      userId: userId,
      kewarganegaraan: kewarganegaraan ?? this.kewarganegaraan,
      jenisIdentitas: jenisIdentitas ?? this.jenisIdentitas,
      nomorKtp: nomorKtp ?? this.nomorKtp,
      fileKtpUrl: fileKtpUrl ?? this.fileKtpUrl,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      namaBelakang: namaBelakang ?? this.namaBelakang,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      noTelepon: noTelepon ?? this.noTelepon,
      noTeleponDarurat: noTeleponDarurat ?? this.noTeleponDarurat,
      surel: surel ?? this.surel,
      beratBadan: beratBadan ?? this.beratBadan,
      tinggiBadan: tinggiBadan ?? this.tinggiBadan,
      provinsi: provinsi ?? this.provinsi,
      kotaKabupaten: kotaKabupaten ?? this.kotaKabupaten,
      kecamatan: kecamatan ?? this.kecamatan,
      kelurahan: kelurahan ?? this.kelurahan,
      alamat: alamat ?? this.alamat,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
