// ============================================
// TimurLang - Blockchain Service
// Simple SHA-256 chain for Simaksi tickets
// ============================================

import 'package:uuid/uuid.dart';
import '../models/simaksi_permit.dart';
import '../config/constants.dart';
import '../utils/crypto_utils.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'sync_service.dart';

class BlockchainService {
  static final BlockchainService instance = BlockchainService._internal();
  BlockchainService._internal();

  final _db = DatabaseService.instance;

  /// Create a new Simaksi permit with blockchain hash
  Future<SimaksiPermit> createPermit({
    required String userId,
    required String gunungId,
    String? basecampId,
    String? namaBasecamp,
    required DateTime tanggalNaik,
    required DateTime tanggalTurun,
    required int jumlahAnggota,
    String? namaGunung,
    double? totalBiaya,
    String? matauang,
    String? dataAnggota,
  }) async {
    final permitId = const Uuid().v4();
    final now = DateTime.now();
    
    // Get previous hash (blockchain chain)
    final previousHash = await _db.getLastPermitHash();
    final actualPrevHash = previousHash == 'GENESIS' 
        ? CryptoUtils.genesisHash 
        : previousHash;

    // Calculate nonce (simple increment)
    final permits = await _db.getPermitsByUser(userId);
    final nonce = permits.length + 1;

    // Generate block hash
    final blockHash = CryptoUtils.createBlockHash(
      permitId: permitId,
      userId: userId,
      previousHash: actualPrevHash,
      nonce: nonce,
      timestamp: now,
    );

    final permit = SimaksiPermit(
      id: permitId,
      userId: userId,
      gunungId: gunungId,
      basecampId: basecampId,
      namaBasecamp: namaBasecamp,
      tanggalNaik: tanggalNaik,
      tanggalTurun: tanggalTurun,
      jumlahAnggota: jumlahAnggota,
      statusIzin: AppConstants.statusTerdaftar,
      blockHash: blockHash,
      previousHash: actualPrevHash,
      nonce: nonce,
      namaGunung: namaGunung,
      totalBiaya: totalBiaya,
      matauang: matauang,
      dataAnggota: dataAnggota,
      createdAt: now,
    );

    // Simpan lokal
    await _db.insertPermit(permit);

    // Kurangi sisa kuota basecamp secara realtime saat pendaftaran SIMAKSI berhasil
    if (permit.basecampId != null && permit.basecampId!.isNotEmpty) {
      await _db.reduceBasecampQuota(permit.basecampId!, permit.jumlahAnggota);
      if (SupabaseService.instance.isInitialized) {
        await SupabaseService.instance.reduceBasecampQuota(permit.basecampId!, permit.jumlahAnggota);
      }
    }

    // Sinkronkan ke Supabase (online)
    if (SupabaseService.instance.isInitialized) {
      final synced = await SupabaseService.instance.syncPermit(permit);
      if (!synced) {
        await SyncService.instance.addToQueue(
          tableName: 'simaksi_permits',
          recordId: permit.id,
          action: 'INSERT',
          payload: permit.toMap(),
        );
      }
    }

    return permit;
  }

  /// Verify a ticket hash integrity
  Future<({bool valid, String message, SimaksiPermit? permit})> verifyTicket(String blockHash) async {
    try {
      final cleanHash = blockHash.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\r\n]'), '').trim();
      if (cleanHash.isEmpty) {
        return (valid: false, message: 'Hash atau data tiket kosong', permit: null);
      }

      SimaksiPermit? permit = await _db.getPermitByHash(cleanHash);

      // Cek ke Supabase jika online agar selalu mendapatkan status izin terbaru
      if (SupabaseService.instance.isInitialized) {
        final remotePermit = await SupabaseService.instance.getPermitByHash(cleanHash);
        if (remotePermit != null) {
          permit = remotePermit;
          await _db.insertPermit(remotePermit);
        }
      }

      if (permit == null) {
        return (valid: false, message: 'Tiket tidak ditemukan dalam sistem database', permit: null);
      }

      // Recompute hash to verify integrity
      final isValid = CryptoUtils.verifyBlockHash(
        permitId: permit.id,
        userId: permit.userId,
        previousHash: permit.previousHash,
        nonce: permit.nonce,
        timestamp: permit.createdAt,
        expectedHash: permit.blockHash,
      );

      if (!isValid) {
        return (valid: false, message: 'Integritas data tidak valid - hash tidak cocok', permit: permit);
      }

      // QR Code adalah tiket sekali pakai (single-use)
      if (permit.statusIzin == AppConstants.statusDiJalur) {
        return (
          valid: false,
          message: 'QR Code sekali pakai sudah pernah digunakan! Tiket ini sudah tervalidasi dan pendaki sedang di jalur.',
          permit: permit,
        );
      }

      if (permit.statusIzin == AppConstants.statusSelesai) {
        return (valid: false, message: 'QR Code sudah tidak berlaku (status: Selesai)', permit: permit);
      }

      if (permit.statusIzin == AppConstants.statusDitolak) {
        return (valid: false, message: 'Tiket ditolak oleh Basecamp', permit: permit);
      }

      return (valid: true, message: 'Tiket valid ✓ - Status: ${permit.statusIzin}', permit: permit);
    } catch (e) {
      return (valid: false, message: 'Error verifikasi: ${e.toString()}', permit: null);
    }
  }

  /// Validate and check-in a permit (Basecamp)
  Future<({bool success, String message})> checkInPermit(String blockHash) async {
    final verification = await verifyTicket(blockHash);
    if (!verification.valid) {
      return (success: false, message: verification.message);
    }

    final permit = verification.permit!;
    if (permit.statusIzin == AppConstants.statusDiJalur) {
      return (success: false, message: 'Pendaki sudah di jalur (QR sudah pernah digunakan)');
    }

    await _db.updatePermitStatus(permit.id, AppConstants.statusDiJalur);
    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.updatePermitStatus(permit.id, AppConstants.statusDiJalur);
    }

    return (
      success: true,
      message: 'Check-in berhasil! ${permit.jumlahAnggota} orang telah masuk ke jalur pendakian.',
    );
  }

  /// Check-out a permit (Basecamp)
  Future<({bool success, String message})> checkOutPermit(String blockHash) async {
    SimaksiPermit? permit = await _db.getPermitByHash(blockHash);
    if (permit == null && SupabaseService.instance.isInitialized) {
      permit = await SupabaseService.instance.getPermitByHash(blockHash);
      if (permit != null) {
        await _db.insertPermit(permit);
      }
    }
    if (permit == null) {
      return (success: false, message: 'Tiket tidak ditemukan');
    }

    if (permit.statusIzin != AppConstants.statusDiJalur) {
      return (success: false, message: 'Pendaki tidak sedang di jalur');
    }

    await _db.updatePermitStatus(permit.id, AppConstants.statusSelesai);
    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.updatePermitStatus(permit.id, AppConstants.statusSelesai);
    }
    return (success: true, message: 'Check-out berhasil. Pendakian selesai!');
  }
}
