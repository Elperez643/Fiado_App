import 'dart:convert';

import '../../core/sync/sync_status.dart';

class SyncQueueItemModel {
  final int? id;
  final String entityType;
  final int entityId;
  final String operation;
  final String payload;
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncQueueItemModel({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.status = SyncStatus.pending,
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncQueueItemModel.create({
    required String entityType,
    required int entityId,
    required String operation,
    required Map<String, Object?> payload,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return SyncQueueItemModel(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: jsonEncode(payload),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory SyncQueueItemModel.fromMap(Map<String, Object?> map) {
    return SyncQueueItemModel(
      id: (map['id'] as num?)?.toInt(),
      entityType: map['entity_type'] as String,
      entityId: (map['entity_id'] as num).toInt(),
      operation: map['operation'] as String,
      payload: map['payload'] as String,
      status: map['status'] as String? ?? SyncStatus.pending,
      attempts: (map['attempts'] as num? ?? 0).toInt(),
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload,
      'status': status,
      'attempts': attempts,
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> payloadAsMap() {
    return jsonDecode(payload) as Map<String, dynamic>;
  }
}
