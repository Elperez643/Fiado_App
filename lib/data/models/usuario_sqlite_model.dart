class UsuarioSqliteModel {
  static const String tipoPersonal = 'personal';
  static const String tipoNegocio = 'negocio';
  static const String tipoColaborador = 'colaborador';

  final int? id;
  final String? remoteId;
  final String nombre;
  final String telefono;
  final String tipoUsuario;
  final int? negocioId;
  final String passwordHash;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;

  const UsuarioSqliteModel({
    this.id,
    this.remoteId,
    required this.nombre,
    required this.telefono,
    required this.tipoUsuario,
    this.negocioId,
    required this.passwordHash,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
  });

  factory UsuarioSqliteModel.fromMap(Map<String, Object?> map) {
    return UsuarioSqliteModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as String?,
      nombre: map['nombre'] as String,
      telefono: map['telefono'] as String,
      tipoUsuario: map['tipo_usuario'] as String,
      negocioId: map['negocio_id'] as int?,
      passwordHash: map['password_hash'] as String,
      activo: (map['activo'] as num? ?? 1).toInt() == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return {
      if (includeId) 'id': id,
      'remote_id': remoteId,
      'nombre': nombre,
      'telefono': telefono,
      'tipo_usuario': tipoUsuario,
      'negocio_id': negocioId,
      'password_hash': passwordHash,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  UsuarioSqliteModel copyWith({
    int? id,
    String? remoteId,
    String? nombre,
    String? telefono,
    String? tipoUsuario,
    int? negocioId,
    String? passwordHash,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
  }) {
    return UsuarioSqliteModel(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
      negocioId: negocioId ?? this.negocioId,
      passwordHash: passwordHash ?? this.passwordHash,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
