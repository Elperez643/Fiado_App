import 'dart:convert';
import 'dart:math';

class SyncOutboxItem {
  static const statusPending = 'pending';
  static const statusSyncing = 'syncing';
  static const statusSynced = 'synced';
  static const statusFailed = 'failed';

  final int? id;
  final String uuid;
  final String businessId;
  final String module;
  final String entityType;
  final String entityUuid;
  final String operation;
  final String payloadJson;
  final String status;
  final int attemptCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncOutboxItem({
    this.id,
    required this.uuid,
    required this.businessId,
    required this.module,
    required this.entityType,
    required this.entityUuid,
    required this.operation,
    required this.payloadJson,
    required this.status,
    required this.attemptCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncOutboxItem.pending({
    required String businessId,
    required String module,
    required String entityType,
    required String entityUuid,
    required String operation,
    required Map<String, Object?> payload,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return SyncOutboxItem(
      uuid: _newUuid('outbox'),
      businessId: businessId,
      module: module,
      entityType: entityType,
      entityUuid: entityUuid,
      operation: operation,
      payloadJson: jsonEncode(payload),
      status: statusPending,
      attemptCount: 0,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory SyncOutboxItem.fromMap(Map<String, Object?> map) {
    return SyncOutboxItem(
      id: (map['id'] as num?)?.toInt(),
      uuid: map['uuid'] as String,
      businessId: map['business_id'] as String,
      module: map['module'] as String,
      entityType: map['entity_type'] as String,
      entityUuid: map['entity_uuid'] as String,
      operation: map['operation'] as String,
      payloadJson: map['payload_json'] as String,
      status: map['status'] as String,
      attemptCount: (map['attempt_count'] as num? ?? 0).toInt(),
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'uuid': uuid,
      'business_id': businessId,
      'module': module,
      'entity_type': entityType,
      'entity_uuid': entityUuid,
      'operation': operation,
      'payload_json': payloadJson,
      'status': status,
      'attempt_count': attemptCount,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> payloadAsMap() {
    final decoded = jsonDecode(payloadJson);
    return decoded is Map<String, dynamic> ? decoded : <String, Object?>{};
  }
}

String _newUuid(String prefix) {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
  return '$prefix-${hex.join()}';
}
