import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/local_database.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/session_sqlite_model.dart';
import '../models/usuario_sqlite_model.dart';
import '../services/cloud_auth_service.dart';
import 'sync_queue_repository.dart';
import 'subscription_repository.dart';

class AuthRepository {
  static const invalidCredentialsMessage =
      'La información introducida está incorrecta o incompleta.';
  static const duplicateUserMessage =
      'Ya existe un usuario registrado con esta información.';
  static const bool bypassSubscriptionChecksDuringStabilization = true;
  static const collaboratorLimitMessage =
      'Has alcanzado el limite de colaboradores de tu plan actual. Cambia a un plan superior para agregar mas colaboradores.';

  final LocalDatabase databaseHelper;
  final SubscriptionRepository subscriptionRepository;
  final SyncQueueRepository syncQueueRepository;

  AuthRepository({
    LocalDatabase? databaseHelper,
    SubscriptionRepository? subscriptionRepository,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       subscriptionRepository =
           subscriptionRepository ?? SubscriptionRepository(),
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<UsuarioSqliteModel> registrarUsuarioPersonal(
    String nombre,
    String telefono,
  ) {
    return _registrarUsuario(
      nombre: nombre,
      telefono: telefono,
      tipoUsuario: UsuarioSqliteModel.tipoPersonal,
      password: telefono,
    );
  }

  Future<UsuarioSqliteModel> registrarUsuarioNegocio(
    String nombreNegocio,
    String nombreAdmin,
    String telefono,
    String password, {
    String planId = 'basico',
  }) async {
    final usuario = await _registrarUsuario(
      nombre: '$nombreNegocio - $nombreAdmin',
      telefono: telefono,
      tipoUsuario: UsuarioSqliteModel.tipoNegocio,
      password: password,
    );
    await subscriptionRepository.crearTrialParaNegocio(usuario.id!);
    await subscriptionRepository.seleccionarPlan(usuario.id!, planId);
    return usuario;
  }

  Future<UsuarioSqliteModel> crearColaboradorDesdeNegocio({
    required int usuarioNegocioId,
    required String nombre,
    required String telefono,
    required String password,
  }) async {
    final negocio = await obtenerUsuarioPorId(usuarioNegocioId);
    if (negocio == null ||
        negocio.tipoUsuario != UsuarioSqliteModel.tipoNegocio ||
        !negocio.activo) {
      throw StateError(
        'Solo un usuario Negocio activo puede crear colaboradores.',
      );
    }

    // TODO: Rehabilitar validaciones de suscripcion al completar la etapa de
    // estabilizacion local-first.
    if (!bypassSubscriptionChecksDuringStabilization) {
      final access = await subscriptionRepository.validarAccesoNegocio(
        usuarioNegocioId,
      );
      if (!access.hasAccess) {
        throw StateError('La suscripcion del negocio no esta activa.');
      }

      if (!await subscriptionRepository.puedeCrearColaborador(
        usuarioNegocioId,
      )) {
        throw StateError(collaboratorLimitMessage);
      }
    }

    return _registrarUsuario(
      nombre: nombre,
      telefono: telefono,
      tipoUsuario: UsuarioSqliteModel.tipoColaborador,
      password: password,
      negocioId: usuarioNegocioId,
    );
  }

  Future<UsuarioSqliteModel> login(String telefono, String password) async {
    final normalizedPhone = telefono.trim();
    final normalizedPassword = password.trim();
    if (normalizedPhone.isEmpty || normalizedPassword.isEmpty) {
      throw StateError(invalidCredentialsMessage);
    }

    final usuario = await obtenerUsuarioPorTelefono(normalizedPhone);
    if (usuario == null || !usuario.activo) {
      throw StateError(invalidCredentialsMessage);
    }

    if (!validarPassword(normalizedPassword, usuario.passwordHash)) {
      throw StateError(invalidCredentialsMessage);
    }

    await cerrarSesionesActivas();
    await crearSesion(usuario.id!);
    return usuario;
  }

  Future<UsuarioSqliteModel> loginWithCloudFallback({
    required String telefono,
    required String password,
    required Future<CloudLoginResult> Function() cloudLogin,
    bool cloudFirst = false,
  }) async {
    final normalizedPhone = telefono.trim();
    final localUser = await obtenerUsuarioPorTelefono(normalizedPhone);

    if (localUser != null && !cloudFirst) {
      return login(normalizedPhone, password);
    }

    final cloudResult = await cloudLogin().timeout(const Duration(seconds: 15));
    if (cloudResult.success && cloudResult.user != null) {
      final linkedUser = await upsertUsuarioDesdeCloud(
        cloudResult.user!,
        password: password,
      );
      await cerrarSesionesActivas();
      await crearSesion(linkedUser.id!);
      if (cloudResult.token != null && cloudResult.token!.trim().isNotEmpty) {
        await guardarJwtTokenActual(cloudResult.token!);
      }
      return linkedUser;
    }

    if (localUser != null) {
      return login(normalizedPhone, password);
    }

    throw StateError(invalidCredentialsMessage);
  }

  Future<void> logout() {
    return cerrarSesionesActivas();
  }

  Future<String?> obtenerJwtTokenActual() async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.sesionesTable,
      columns: ['jwt_token'],
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'last_active_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final token = rows.first['jwt_token'] as String?;
    return token == null || token.trim().isEmpty ? null : token.trim();
  }

  Future<void> guardarJwtTokenActual(String token) async {
    final db = await databaseHelper.database;
    final updated = await db.update(
      DatabaseSchema.sesionesTable,
      {
        'jwt_token': token.trim(),
        'last_active_at': DateTime.now().toIso8601String(),
      },
      where: 'is_active = ?',
      whereArgs: [1],
    );
    if (updated == 0) {
      throw StateError('No hay una sesion local activa para guardar el token.');
    }
  }

  Future<void> marcarSesionActualReemplazada() async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.sesionesTable,
      {
        'is_active': 0,
        'jwt_token': null,
        'last_active_at': DateTime.now().toIso8601String(),
      },
      where: 'is_active = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateRemoteId(int localUserId, String remoteId) async {
    final normalizedRemoteId = remoteId.trim();
    if (normalizedRemoteId.isEmpty) return;
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.usuariosTable,
      {
        'remote_id': normalizedRemoteId,
        'sync_status': SyncStatus.synced,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localUserId],
    );
  }

  Future<UsuarioSqliteModel?> vincularUsuarioCloudPorTelefono({
    required String telefono,
    required CloudAuthenticatedUser cloudUser,
    String? jwtToken,
  }) async {
    final normalizedPhone = telefono.trim();
    final remoteId = cloudUser.remoteId.trim();
    if (normalizedPhone.isEmpty || remoteId.isEmpty) return null;

    final db = await databaseHelper.database;
    final existing = await obtenerUsuarioPorTelefono(normalizedPhone);
    if (existing == null) return null;

    await db.update(
      DatabaseSchema.usuariosTable,
      {
        'remote_id': remoteId,
        'sync_status': SyncStatus.synced,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [existing.id],
    );

    if (jwtToken != null && jwtToken.trim().isNotEmpty) {
      try {
        await guardarJwtTokenActual(jwtToken);
      } catch (error) {
        // Best-effort: el token cloud principal ya queda en almacenamiento seguro.
      }
    }

    return obtenerUsuarioPorId(existing.id!);
  }

  Future<UsuarioSqliteModel?> obtenerUsuarioActual() async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery('''
SELECT u.*
FROM ${DatabaseSchema.usuariosTable} u
INNER JOIN ${DatabaseSchema.sesionesTable} s ON s.usuario_id = u.id
WHERE s.is_active = 1 AND u.activo = 1
ORDER BY s.last_active_at DESC
LIMIT 1
''');
    if (rows.isEmpty) return null;
    return UsuarioSqliteModel.fromMap(rows.first);
  }

  Future<bool> existeUsuarioPorTelefono(String telefono) async {
    return (await obtenerUsuarioPorTelefono(telefono)) != null;
  }

  bool validarPassword(String password, String passwordHash) {
    return _hashPassword(password) == passwordHash;
  }

  Future<SessionSqliteModel> crearSesion(int usuarioId) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final session = SessionSqliteModel(
      usuarioId: usuarioId,
      startedAt: now,
      lastActiveAt: now,
    );
    final id = await db.insert(DatabaseSchema.sesionesTable, session.toMap());
    return session.copyWith(id: id);
  }

  Future<void> cerrarSesionesActivas() async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.sesionesTable,
      {
        'is_active': 0,
        'jwt_token': null,
        'last_active_at': DateTime.now().toIso8601String(),
      },
      where: 'is_active = ?',
      whereArgs: [1],
    );
  }

  Future<List<UsuarioSqliteModel>> listarColaboradoresActivos(
    int usuarioNegocioId,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      where: 'negocio_id = ? AND tipo_usuario = ?',
      whereArgs: [usuarioNegocioId, UsuarioSqliteModel.tipoColaborador],
      orderBy: 'activo DESC, nombre COLLATE NOCASE ASC',
    );
    return rows.map(UsuarioSqliteModel.fromMap).toList();
  }

  Future<void> cambiarEstadoColaborador({
    required int colaboradorId,
    required bool activo,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.usuariosTable,
      {
        'activo': activo ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_status': activo ? SyncStatus.updated : SyncStatus.deleted,
      },
      where: 'id = ? AND tipo_usuario = ?',
      whereArgs: [colaboradorId, UsuarioSqliteModel.tipoColaborador],
    );
    final updated = await obtenerUsuarioPorId(colaboradorId);
    if (updated != null) {
      if (activo) {
        await syncQueueRepository.enqueueUpdate(
          entityType: DatabaseSchema.usuariosTable,
          entityId: colaboradorId,
          payload: updated.toMap(includeId: true),
        );
      } else {
        await syncQueueRepository.enqueueDelete(
          entityType: DatabaseSchema.usuariosTable,
          entityId: colaboradorId,
          payload: {
            ...updated.toMap(includeId: true),
            'deleted_at': DateTime.now().toIso8601String(),
          },
        );
      }
    }
  }

  Future<void> editarColaboradorDesdeNegocio({
    required int usuarioNegocioId,
    required int colaboradorId,
    required String nombre,
    required String telefono,
    String? nuevaPassword,
    bool? activo,
  }) async {
    final colaborador = await obtenerUsuarioPorId(colaboradorId);
    if (colaborador == null ||
        colaborador.tipoUsuario != UsuarioSqliteModel.tipoColaborador ||
        colaborador.negocioId != usuarioNegocioId) {
      throw StateError('El colaborador no pertenece a este negocio.');
    }

    final telefonoLimpio = telefono.trim();
    if (telefonoLimpio != colaborador.telefono) {
      final existente = await obtenerUsuarioPorTelefono(telefonoLimpio);
      if (existente != null && existente.id != colaboradorId) {
        throw StateError('Ya existe un usuario con ese telefono.');
      }
    }

    final values = <String, Object?>{
      'nombre': nombre.trim(),
      'telefono': telefonoLimpio,
      'activo': (activo ?? colaborador.activo) ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': SyncStatus.updated,
    };

    if (nuevaPassword != null && nuevaPassword.trim().isNotEmpty) {
      values['password_hash'] = _hashPassword(nuevaPassword.trim());
    }

    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.usuariosTable,
      values,
      where: 'id = ? AND negocio_id = ? AND tipo_usuario = ?',
      whereArgs: [
        colaboradorId,
        usuarioNegocioId,
        UsuarioSqliteModel.tipoColaborador,
      ],
    );
    final updated = await obtenerUsuarioPorId(colaboradorId);
    if (updated != null) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.usuariosTable,
        entityId: colaboradorId,
        payload: updated.toMap(includeId: true),
      );
    }
  }

  Future<UsuarioSqliteModel?> obtenerUsuarioPorId(int id) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UsuarioSqliteModel.fromMap(rows.first);
  }

  Future<UsuarioSqliteModel?> obtenerUsuarioPorTelefono(String telefono) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      where: 'telefono = ?',
      whereArgs: [telefono.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UsuarioSqliteModel.fromMap(rows.first);
  }

  Future<UsuarioSqliteModel> upsertUsuarioDesdeCloud(
    CloudAuthenticatedUser cloudUser, {
    required String password,
  }) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final phone = cloudUser.phone.trim();
    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      where: 'telefono = ? OR remote_id = ?',
      whereArgs: [phone, cloudUser.remoteId],
      limit: 1,
    );

    final tipoUsuario = _localRoleFromCloud(cloudUser.role);
    final nombre = tipoUsuario == UsuarioSqliteModel.tipoNegocio
        ? (cloudUser.businessName?.trim().isNotEmpty == true
              ? cloudUser.businessName!.trim()
              : cloudUser.name)
        : cloudUser.name;

    if (rows.isEmpty) {
      final user = UsuarioSqliteModel(
        remoteId: cloudUser.remoteId.isEmpty ? null : cloudUser.remoteId,
        nombre: nombre,
        telefono: phone,
        tipoUsuario: tipoUsuario,
        negocioId: null,
        passwordHash: _hashPassword(password),
        activo: true,
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.synced,
      );
      final id = await db.insert(DatabaseSchema.usuariosTable, {
        ...user.toMap(),
        'last_synced_at': now.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      if (tipoUsuario == UsuarioSqliteModel.tipoNegocio) {
        await subscriptionRepository.crearTrialParaNegocio(id);
      }
      return user.copyWith(id: id);
    }

    final id = rows.first['id'] as int;
    await db.update(
      DatabaseSchema.usuariosTable,
      {
        'remote_id': cloudUser.remoteId.isEmpty
            ? rows.first['remote_id']
            : cloudUser.remoteId,
        'nombre': nombre,
        'telefono': phone,
        'tipo_usuario': tipoUsuario,
        'negocio_id': tipoUsuario == UsuarioSqliteModel.tipoNegocio
            ? null
            : rows.first['negocio_id'],
        'password_hash': _hashPassword(password),
        'activo': 1,
        'updated_at': now.toIso8601String(),
        'sync_status': SyncStatus.synced,
        'last_synced_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return (await obtenerUsuarioPorId(id))!;
  }

  String _localRoleFromCloud(String role) {
    return switch (role.toLowerCase().trim()) {
      'person' || 'personal' => UsuarioSqliteModel.tipoPersonal,
      'business' || 'negocio' => UsuarioSqliteModel.tipoNegocio,
      'collaborator' || 'colaborador' => UsuarioSqliteModel.tipoColaborador,
      _ => UsuarioSqliteModel.tipoNegocio,
    };
  }

  Future<UsuarioSqliteModel> _registrarUsuario({
    required String nombre,
    required String telefono,
    required String tipoUsuario,
    required String password,
    int? negocioId,
  }) async {
    final normalizedNombre = nombre.trim();
    final normalizedTelefono = telefono.trim();
    final normalizedPassword = password.trim();
    if (normalizedNombre.isEmpty ||
        normalizedTelefono.isEmpty ||
        normalizedPassword.isEmpty) {
      throw StateError(invalidCredentialsMessage);
    }

    if (tipoUsuario == UsuarioSqliteModel.tipoColaborador &&
        negocioId == null) {
      throw StateError('El colaborador debe pertenecer a un negocio.');
    }

    if (await existeUsuarioPorTelefono(normalizedTelefono)) {
      throw StateError(duplicateUserMessage);
    }

    final db = await databaseHelper.database;
    final now = DateTime.now();
    final usuario = UsuarioSqliteModel(
      nombre: nombre.trim(),
      telefono: normalizedTelefono,
      tipoUsuario: tipoUsuario,
      negocioId: negocioId,
      passwordHash: _hashPassword(normalizedPassword),
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(
      DatabaseSchema.usuariosTable,
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    final saved = usuario.copyWith(id: id);
    return saved;
  }

  String _hashPassword(String password) {
    // Hash local temporal para no guardar texto plano. En backend cloud debe
    // reemplazarse por hashing seguro del servidor, por ejemplo Argon2/bcrypt.
    const salt = 'fiado-local-auth-v1';
    var hash = 2166136261;
    for (final unit in '$salt:$password'.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return base64Url.encode(utf8.encode(hash.toRadixString(16)));
  }
}
