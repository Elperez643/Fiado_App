class SyncStateModel {
  final int? id;
  final String businessId;
  final String module;
  final DateTime? lastPullAt;
  final DateTime? lastPushAt;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final int pendingCount;
  final DateTime updatedAt;

  const SyncStateModel({
    this.id,
    required this.businessId,
    required this.module,
    this.lastPullAt,
    this.lastPushAt,
    this.lastSuccessAt,
    this.lastError,
    required this.pendingCount,
    required this.updatedAt,
  });

  factory SyncStateModel.fromMap(Map<String, Object?> map) {
    return SyncStateModel(
      id: (map['id'] as num?)?.toInt(),
      businessId: map['business_id'] as String,
      module: map['module'] as String,
      lastPullAt: _date(map['last_pull_at']),
      lastPushAt: _date(map['last_push_at']),
      lastSuccessAt: _date(map['last_success_at']),
      lastError: map['last_error'] as String?,
      pendingCount: (map['pending_count'] as num? ?? 0).toInt(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'business_id': businessId,
      'module': module,
      'last_pull_at': lastPullAt?.toIso8601String(),
      'last_push_at': lastPushAt?.toIso8601String(),
      'last_success_at': lastSuccessAt?.toIso8601String(),
      'last_error': lastError,
      'pending_count': pendingCount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

DateTime? _date(Object? value) {
  final text = value as String?;
  return text == null ? null : DateTime.tryParse(text);
}
