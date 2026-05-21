enum SyncOperationType { create, update, delete }

class SyncOperation {
  final String id;
  final String entityName;
  final String entityId;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  const SyncOperation({
    required this.id,
    required this.entityName,
    required this.entityId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });
}
