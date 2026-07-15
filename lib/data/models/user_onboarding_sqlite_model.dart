class UserOnboardingSqliteModel {
  final int? id;
  final int usuarioId;
  final String tipoUsuario;
  final String onboardingKey;
  final bool completed;
  final DateTime? completedAt;
  final bool skipped;
  final DateTime? skippedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const UserOnboardingSqliteModel({
    this.id,
    required this.usuarioId,
    required this.tipoUsuario,
    required this.onboardingKey,
    this.completed = false,
    this.completedAt,
    this.skipped = false,
    this.skippedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory UserOnboardingSqliteModel.create({
    required int usuarioId,
    required String tipoUsuario,
    required String onboardingKey,
  }) {
    final now = DateTime.now();
    return UserOnboardingSqliteModel(
      usuarioId: usuarioId,
      tipoUsuario: tipoUsuario,
      onboardingKey: onboardingKey,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserOnboardingSqliteModel.fromMap(Map<String, Object?> map) {
    return UserOnboardingSqliteModel(
      id: map['id'] as int?,
      usuarioId: (map['usuario_id'] as num).toInt(),
      tipoUsuario: map['tipo_usuario'] as String,
      onboardingKey: map['onboarding_key'] as String,
      completed: ((map['completed'] as num?)?.toInt() ?? 0) == 1,
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      skipped: ((map['skipped'] as num?)?.toInt() ?? 0) == 1,
      skippedAt: map['skipped_at'] == null
          ? null
          : DateTime.parse(map['skipped_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'usuario_id': usuarioId,
      'tipo_usuario': tipoUsuario,
      'onboarding_key': onboardingKey,
      'completed': completed ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'skipped': skipped ? 1 : 0,
      'skipped_at': skippedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
}
