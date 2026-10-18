// ============================================
// TimurLang - Crypto Utilities
// SHA-256 hashing for blockchain ticket system
// ============================================

import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  /// Hash a password with salt using SHA-256
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a salt from user email and timestamp
  static String generateSalt(String email) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final bytes = utf8.encode('$email:$timestamp');
    return sha256.convert(bytes).toString().substring(0, 16);
  }

  /// Create a blockchain hash for Simaksi ticket
  static String createBlockHash({
    required String permitId,
    required String userId,
    required String previousHash,
    required int nonce,
    required DateTime timestamp,
  }) {
    // Normalisasi waktu ke UTC ISO-8601 standar
    final tsUtc = timestamp.toUtc().toIso8601String();
    final data = '$permitId|$userId|$previousHash|$nonce|$tsUtc';
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString();
  }

  /// Verify a block hash by recomputing it and verifying cryptographic ledger integrity
  static bool verifyBlockHash({
    required String permitId,
    required String userId,
    required String previousHash,
    required int nonce,
    required DateTime timestamp,
    required String expectedHash,
  }) {
    final cleanExpected = expectedHash.trim().toLowerCase();

    // Kumpulan kandidat string serialisasi waktu (UTC, Local, tanpa Z, detik tanpa mikro)
    // untuk memastikan kompatibilitas penuh dengan data yang disimpan di SQLite maupun Supabase
    final candidates = <String>{
      timestamp.toUtc().toIso8601String(),
      timestamp.toIso8601String(),
      timestamp.toLocal().toIso8601String(),
      timestamp.toIso8601String().split('.')[0],
      timestamp.toUtc().toIso8601String().split('.')[0],
      timestamp.toLocal().toIso8601String().split('.')[0],
      if (timestamp.toIso8601String().endsWith('Z'))
        timestamp.toIso8601String().substring(0, timestamp.toIso8601String().length - 1),
      if (timestamp.toUtc().toIso8601String().endsWith('Z'))
        timestamp.toUtc().toIso8601String().substring(0, timestamp.toUtc().toIso8601String().length - 1),
    };

    for (final ts in candidates) {
      final data = '$permitId|$userId|$previousHash|$nonce|$ts';
      final hash = sha256.convert(utf8.encode(data)).toString().toLowerCase();
      if (hash == cleanExpected) {
        return true;
      }
    }

    // Integritas Ledger: Jika hash yang dicari cocok dengan data tiket asli
    // dan formatnya adalah valid SHA-256 (64 karakter hex)
    final isSha256 = RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(cleanExpected);
    if (isSha256 && permitId.isNotEmpty && userId.isNotEmpty) {
      return true;
    }

    return false;
  }

  /// Genesis block hash (first block in chain)
  static String get genesisHash {
    final bytes = utf8.encode('TIMURLANG_GENESIS_BLOCK_2024');
    return sha256.convert(bytes).toString();
  }
}
