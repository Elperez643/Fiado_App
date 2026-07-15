import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/user_onboarding_sqlite_model.dart';

class UserOnboardingRepository {
  static const initialOnboardingVersion = 'initial_v1';

  final DatabaseHelper databaseHelper;

  UserOnboardingRepository({DatabaseHelper? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  String onboardingKeyFor(String tipoUsuario) {
    return '${initialOnboardingVersion}_$tipoUsuario';
  }

  Future<UserOnboardingSqliteModel?> obtenerEstadoOnboarding(
    int usuarioId,
    String onboardingKey,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.userOnboardingTable,
      where: 'usuario_id = ? AND onboarding_key = ?',
      whereArgs: [usuarioId, onboardingKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserOnboardingSqliteModel.fromMap(rows.first);
  }

  Future<bool> debeMostrarOnboarding(int usuarioId, String tipoUsuario) async {
    final estado = await crearSiNoExiste(usuarioId, tipoUsuario);
    return !estado.completed && !estado.skipped;
  }

  Future<UserOnboardingSqliteModel> crearSiNoExiste(
    int usuarioId,
    String tipoUsuario,
  ) async {
    final key = onboardingKeyFor(tipoUsuario);
    final existing = await obtenerEstadoOnboarding(usuarioId, key);
    if (existing != null) return existing;

    final db = await databaseHelper.database;
    final model = UserOnboardingSqliteModel.create(
      usuarioId: usuarioId,
      tipoUsuario: tipoUsuario,
      onboardingKey: key,
    );
    final id = await db.insert(
      DatabaseSchema.userOnboardingTable,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final saved = id == 0
        ? await obtenerEstadoOnboarding(usuarioId, key)
        : UserOnboardingSqliteModel.fromMap({
            ...model.toMap(includeId: true),
            'id': id,
          });
    final result = saved ?? model;
    return result;
  }

  Future<void> marcarCompletado(int usuarioId, String tipoUsuario) async {
    await _marcarEstado(
      usuarioId: usuarioId,
      tipoUsuario: tipoUsuario,
      completed: true,
      skipped: false,
    );
  }

  Future<void> marcarOmitido(int usuarioId, String tipoUsuario) async {
    await _marcarEstado(
      usuarioId: usuarioId,
      tipoUsuario: tipoUsuario,
      completed: false,
      skipped: true,
    );
  }

  Future<void> _marcarEstado({
    required int usuarioId,
    required String tipoUsuario,
    required bool completed,
    required bool skipped,
  }) async {
    final existing = await crearSiNoExiste(usuarioId, tipoUsuario);
    final db = await databaseHelper.database;
    final now = DateTime.now();
    final values = {
      'completed': completed ? 1 : 0,
      'completed_at': completed ? now.toIso8601String() : null,
      'skipped': skipped ? 1 : 0,
      'skipped_at': skipped ? now.toIso8601String() : null,
      'updated_at': now.toIso8601String(),
      'sync_status': SyncStatus.updated,
    };
    await db.update(
      DatabaseSchema.userOnboardingTable,
      values,
      where: 'id = ?',
      whereArgs: [existing.id],
    );
  }
}
