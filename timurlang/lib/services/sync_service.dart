// ============================================
// TimurLang - Sync Service
// Offline→Online sync (SQLite → Supabase mock)
// ============================================

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/sync_queue.dart';
import 'database_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final _db = DatabaseService.instance;
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
  }

  /// Attempt to sync all pending items
  Future<({int synced, int failed, String message})> syncAll() async {
    if (_isSyncing) {
      return (synced: 0, failed: 0, message: 'Sinkronisasi sedang berlangsung');
    }

    final hasNet = await hasConnection();
    if (!hasNet) {
      return (synced: 0, failed: 0, message: 'Tidak ada koneksi internet. Data tersimpan lokal.');
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    try {
      final pending = await _db.getPendingSyncItems();

      for (final item in pending) {
        try {
          // Mock Supabase sync (simulate network call)
          await Future.delayed(const Duration(milliseconds: 200));

          // Mark as synced
          await _db.updateSyncStatus(item.id, AppConstants.syncCompleted);
          synced++;
        } catch (e) {
          await _db.updateSyncStatus(item.id, AppConstants.syncFailed);
          failed++;
        }
      }

      final message = pending.isEmpty
          ? 'Semua data sudah tersinkronisasi'
          : '$synced berhasil, $failed gagal dari ${pending.length} antrian';

      return (synced: synced, failed: failed, message: message);
    } finally {
      _isSyncing = false;
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
