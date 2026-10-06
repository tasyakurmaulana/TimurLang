// ============================================
// TimurLang - Sync Queue Model
// ============================================

class SyncQueue {
  final String id;
  final String namaTabel;
  final String recordId;
  final String aksiTipe; // 'insert', 'update', 'delete'
  final String payloadJson;
  final String statusSinkronisasi;
  final DateTime? syncedAt;
  final DateTime createdAt;

  SyncQueue({
    required this.id,
    required this.namaTabel,
    required this.recordId,
    required this.aksiTipe,
    required this.payloadJson,
    required this.statusSinkronisasi,
    this.syncedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_tabel': namaTabel,
      'record_id': recordId,
      'aksi_tipe': aksiTipe,
      'payload_json': payloadJson,
      'status_sinkronisasi': statusSinkronisasi,
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncQueue.fromMap(Map<String, dynamic> map) {
    return SyncQueue(
      id: map['id'] as String,
      namaTabel: map['nama_tabel'] as String,
      recordId: map['record_id'] as String,
      aksiTipe: map['aksi_tipe'] as String,
      payloadJson: map['payload_json'] as String,
      statusSinkronisasi: map['status_sinkronisasi'] as String,
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
