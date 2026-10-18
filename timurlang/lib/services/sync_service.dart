// ============================================
// TimurLang - Sync Service
// Offline→Online sync (SQLite → Supabase)
// ============================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/sync_queue.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final _db = DatabaseService.instance;
  final _supabase = SupabaseService.instance;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Check if device has internet connection
  Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Add item to sync queue
  Future<void> addToQueue({
    required String tableName,
    required String recordId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final queue = SyncQueue(
      id: const Uuid().v4(),
      namaTabel: tableName,
      recordId: recordId,
      aksiTipe: action,
      payloadJson: jsonEncode(payload),
      statusSinkronisasi: AppConstants.syncPending,
      createdAt: DateTime.now(),
    );

    await _db.insertSyncQueue(queue);

    // Coba langsung sync jika ada koneksi
    final hasNet = await hasConnection();
    if (hasNet && _supabase.isInitialized) {
      await _syncSingleItem(queue);
    }
  }

  /// Sync satu item ke Supabase
  Future<bool> _syncSingleItem(SyncQueue item) async {
    if (!_supabase.isInitialized) return false;

    try {
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      final success = await _supabase.upsertToTable(item.namaTabel, payload);

      if (success) {
        await _db.updateSyncStatus(item.id, AppConstants.syncCompleted);
        return true;
      } else {
        await _db.updateSyncStatus(item.id, AppConstants.syncFailed);
        return false;
      }
    } catch (e) {
      await _db.updateSyncStatus(item.id, AppConstants.syncFailed);
      return false;
    }
  }

  /// Attempt to sync all pending items and local data to Supabase
  Future<({int synced, int failed, String message})> syncAll() async {
    if (_isSyncing) {
      return (synced: 0, failed: 0, message: 'Sinkronisasi sedang berlangsung');
    }

    final hasNet = await hasConnection();
    if (!hasNet) {
      return (synced: 0, failed: 0, message: 'Tidak ada koneksi internet. Data tersimpan lokal.');
    }

    if (!_supabase.isInitialized) {
      await _supabase.initialize();
      if (!_supabase.isInitialized) {
        return (synced: 0, failed: 0, message: 'Supabase belum terhubung. Periksa konfigurasi URL & API Key.');
      }
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      // 1. Sync semua Users lokal
      final allUsers = await _db.getAllUsers();
      for (final u in allUsers) {
        final ok = await _supabase.syncUser(u);
        if (ok) {
          synced++;
        } else {
          failed++;
        }
      }

      // 2. Sync semua Basecamp Posts lokal
      final allBasecamps = await _db.getAllBasecampPosts();
      for (final bc in allBasecamps) {
        final ok = await _supabase.syncBasecampPost(bc);
        if (ok) {
          synced++;
        } else {
          failed++;
        }
      }

      // 3. Sync semua Simaksi Permits lokal
      final allPermits = await _db.getAllPermits();
      for (final p in allPermits) {
        final ok = await _supabase.syncPermit(p);
        if (ok) {
          synced++;
        } else {
          failed++;
        }
      }

      // 4. Sync semua SOS Incidents lokal
      final allSos = await _db.getAllSosIncidents();
      for (final sos in allSos) {
        final ok = await _supabase.syncSosIncident(sos);
        if (ok) {
          synced++;
        } else {
          failed++;
        }
      }

      // 5. Proses antrian sync queues
      final pending = await _db.getPendingSyncItems();
      for (final item in pending) {
        final success = await _syncSingleItem(item);
        if (success) {
          synced++;
        } else {
          failed++;
        }
      }

      // 6. Tarik data terbaru dari Supabase ke lokal SQLite (Basecamp, Simaksi, SOS)
      final pullResult = await pullFromSupabase();

      final message = 'Sinkronisasi online selesai! $synced data diunggah, ${pullResult.pulled} data terbaru disinkronkan dari server.';
      return (synced: synced + pullResult.pulled, failed: failed, message: message);
    } finally {
      _isSyncing = false;
    }
  }

  /// Tarik data terbaru dari Supabase ke SQLite lokal (Basecamp, Simaksi, SOS)
  Future<({int pulled, String message})> pullFromSupabase() async {
    if (!_supabase.isInitialized) {
      await _supabase.initialize();
      if (!_supabase.isInitialized) {
        return (pulled: 0, message: 'Supabase belum terhubung');
      }
    }

    int count = 0;
    try {
      // 1. Tarik Basecamp Posts
      final basecamps = await _supabase.getAllBasecampPosts();
      for (final bc in basecamps) {
        await _db.insertBasecampPost(bc);
        count++;
      }

      // 2. Tarik Simaksi Permits
      final permits = await _supabase.getAllPermits();
      for (final p in permits) {
        await _db.insertPermit(p);
        count++;
      }

      // 3. Tarik Insiden SOS
      final incidents = await _supabase.getAllSosIncidents();
      for (final inc in incidents) {
        await _db.insertSosIncident(inc);
        count++;
      }

      return (pulled: count, message: 'Berhasil mengunduh $count data terbaru dari server');
    } catch (e) {
      return (pulled: count, message: 'Gagal mengunduh data dari server: $e');
    }
  }

  /// Get sync status summary
  Future<({int pending, int completed, int failed})> getSyncStatus() async {
    final pending = await _db.getPendingSyncItems();
    return (
      pending: pending.length,
      completed: 0, // Would need separate query
      failed: 0,
    );
  }

  /// Listen for connectivity changes and auto-sync
  void startAutoSync() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (!result.contains(ConnectivityResult.none)) {
        // Internet restored - attempt sync
        await syncAll();
      }
    });
  }
}
