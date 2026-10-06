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
    final data = '$permitId|$userId|$previousHash|$nonce|${timestamp.toIso8601String()}';
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString();
  }

  /// Verify a block hash by recomputing it
  static bool verifyBlockHash({
    required String permitId,
    required String userId,
    required String previousHash,
    required int nonce,
    required DateTime timestamp,
    required String expectedHash,
  }) {
    final computedHash = createBlockHash(
      permitId: permitId,
      userId: userId,
      previousHash: previousHash,
      nonce: nonce,
      timestamp: timestamp,
    );
    return computedHash == expectedHash;
  }

  /// Genesis block hash (first block in chain)
  static String get genesisHash {
    final bytes = utf8.encode('TIMURLANG_GENESIS_BLOCK_2024');
    return sha256.convert(bytes).toString();
  }
}
