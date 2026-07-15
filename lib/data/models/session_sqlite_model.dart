class SessionSqliteModel {
  final int? id;
  final int usuarioId;
  final DateTime startedAt;
  final DateTime lastActiveAt;
  final bool isActive;
  final String? jwtToken;

  const SessionSqliteModel({
    this.id,
    required this.usuarioId,
    required this.startedAt,
    required this.lastActiveAt,
    this.isActive = true,
    this.jwtToken,
  });

  factory SessionSqliteModel.fromMap(Map<String, Object?> map) {
    return SessionSqliteModel(
      id: map['id'] as int?,
      usuarioId: map['usuario_id'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      lastActiveAt: DateTime.parse(map['last_active_at'] as String),
      isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
      jwtToken: map['jwt_token'] as String?,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'usuario_id': usuarioId,
      'started_at': startedAt.toIso8601String(),
      'last_active_at': lastActiveAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'jwt_token': jwtToken,
    };
  }

  SessionSqliteModel copyWith({
    int? id,
    int? usuarioId,
    DateTime? startedAt,
    DateTime? lastActiveAt,
    bool? isActive,
    String? jwtToken,
  }) {
    return SessionSqliteModel(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      startedAt: startedAt ?? this.startedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
      jwtToken: jwtToken ?? this.jwtToken,
    );
  }
}
