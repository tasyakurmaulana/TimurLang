// ============================================
// TimurLang - User Model
// ============================================

class User {
  final String id;
  final String peran; // 'pendaki' or 'basecamp'
  final String namaLengkap;
  final String email;
  final String passwordHash;
  final String? fotoProfilUrl;
  final bool isBiometricEnabled;
  final String? biometricToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.peran,
    required this.namaLengkap,
    required this.email,
    required this.passwordHash,
    this.fotoProfilUrl,
    this.isBiometricEnabled = false,
    this.biometricToken,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peran': peran,
      'nama_lengkap': namaLengkap,
      'email': email,
      'password_hash': passwordHash,
      'foto_profil_url': fotoProfilUrl,
      'is_biometric_enabled': isBiometricEnabled ? 1 : 0,
      'biometric_token': biometricToken,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      peran: map['peran'] as String,
      namaLengkap: map['nama_lengkap'] as String,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      fotoProfilUrl: map['foto_profil_url'] as String?,
      isBiometricEnabled: map['is_biometric_enabled'] == true ||
          map['is_biometric_enabled'] == 1,
      biometricToken: map['biometric_token'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  User copyWith({
    String? id,
    String? peran,
    String? namaLengkap,
    String? email,
    String? passwordHash,
    String? fotoProfilUrl,
    bool? isBiometricEnabled,
    String? biometricToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      peran: peran ?? this.peran,
      namaLengkap: namaLengkap ?? this.namaLengkap,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      fotoProfilUrl: fotoProfilUrl ?? this.fotoProfilUrl,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      biometricToken: biometricToken ?? this.biometricToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
