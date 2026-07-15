import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_queue_item_model.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';

class FinancialCloudSyncResult {
  final int sent;
  final int received;
  final int errors;
  final String? message;

  const FinancialCloudSyncResult({
    required this.sent,
    required this.received,
    required this.errors,
    this.message,
  });

  FinancialCloudSyncResult combine(FinancialCloudSyncResult other) {
    return FinancialCloudSyncResult(
      sent: sent + other.sent,
      received: received + other.received,
      errors: errors + other.errors,
      message: other.message ?? message,
    );
  }
}

class FinancialSyncHelpers {
  final AuthRepository authRepository;
  final SyncQueueRepository syncQueueRepository;
  final LocalDatabase databaseHelper;
  final Future<SharedPreferences> sharedPreferences;

  const FinancialSyncHelpers({
    required this.authRepository,
    required this.syncQueueRepository,
    required this.databaseHelper,
    required this.sharedPreferences,
  });

  Future<int> resolveNegocioId() async {
    final user = await authRepository.obtenerUsuarioActual();
    if (user == null) throw StateError('No hay una sesion local activa.');
    if (user.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
      throw StateError('El usuario Personal no sincroniza datos de negocio.');
    }
    final negocioId = user.tipoUsuario == UsuarioSqliteModel.tipoNegocio
        ? user.id
        : user.negocioId;
    if (negocioId == null) {
      throw StateError('El usuario actual no tiene negocio asociado.');
    }
    return negocioId;
  }

  Future<List<SyncQueueItemModel>> pendingItems(String table) async {
    final pending = await syncQueueRepository.obtenerPendientes(limit: 500);
    return pending
        .where((item) => item.entityType.toLowerCase() == table)
        .toList();
  }

  Future<String?> remoteIdForLocalId(String table, int? id) async {
    if (id == null) return null;
    final db = await databaseHelper.database;
    final rows = await db.query(
      table,
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['remote_id'] as String?;
  }

  Future<int?> localIdForRemoteId(String table, String? remoteId) async {
    if (remoteId == null || remoteId.isEmpty) return null;
    final db = await databaseHelper.database;
    final rows = await db.query(
      table,
      columns: ['id'],
      where: 'remote_id = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['id'] as num?)?.toInt();
  }

  Future<Map<String, Object?>?> resolveClientByNamePhone({
    required int negocioId,
    required String? name,
    required String? phone,
  }) async {
    final db = await databaseHelper.database;
    final where = phone != null && phone.isNotEmpty
        ? 'negocio_id = ? AND telefono = ?'
        : 'negocio_id = ? AND LOWER(nombre) = LOWER(?)';
    final args = phone != null && phone.isNotEmpty
        ? <Object?>[negocioId, phone]
        : <Object?>[negocioId, name ?? ''];
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> resolveClientByLocalId({
    required int negocioId,
    required int? clientId,
  }) async {
    if (clientId == null) return null;
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      where: 'negocio_id = ? AND id = ?',
      whereArgs: [negocioId, clientId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markSynced({
    required String table,
    required int localId,
    required String? serverId,
    required String? serverUpdatedAt,
  }) async {
    final db = await databaseHelper.database;
    final columns = await _columns(db, table);
    final values = <String, Object?>{
      if (columns.contains('remote_id')) 'remote_id': serverId,
      if (columns.contains('sync_status')) 'sync_status': SyncStatus.synced,
      if (columns.contains('last_synced_at'))
        'last_synced_at': DateTime.now().toIso8601String(),
      if (serverUpdatedAt != null && columns.contains('updated_at'))
        'updated_at': serverUpdatedAt,
    };
    if (values.isEmpty) return;
    await db.update(table, values, where: 'id = ?', whereArgs: [localId]);
  }

  Future<Set<String>> _columns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name'] as String).toSet();
  }

  Future<int> upsertByRemoteId({
    required String table,
    required Map<String, Object?> values,
    required String remoteId,
    String? fallbackWhere,
    List<Object?>? fallbackArgs,
  }) async {
    final db = await databaseHelper.database;
    final columns = await _columns(db, table);
    var existing = <Map<String, Object?>>[];
    if (columns.contains('remote_id')) {
      existing = await db.query(
        table,
        columns: ['id', 'updated_at'],
        where: 'remote_id = ?',
        whereArgs: [remoteId],
        limit: 1,
      );
    }
    if (existing.isEmpty && fallbackWhere != null) {
      final fallback = await db.query(
        table,
        columns: ['id', 'updated_at'],
        where: fallbackWhere,
        whereArgs: fallbackArgs,
        limit: 1,
      );
      if (fallback.isNotEmpty) {
        await db.update(
          table,
          values,
          where: 'id = ?',
          whereArgs: [fallback.first['id']],
        );
        return (fallback.first['id'] as num).toInt();
      }
    }
    if (existing.isEmpty) {
      return db.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
    final localUpdated = existing.first['updated_at'] as String?;
    final remoteUpdated = values['updated_at'] as String?;
    if (localUpdated != null &&
        remoteUpdated != null &&
        DateTime.tryParse(
              localUpdated,
            )?.isAfter(DateTime.parse(remoteUpdated)) ==
            true) {
      return (existing.first['id'] as num).toInt();
    }
    await db.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
    return (existing.first['id'] as num).toInt();
  }

  String? stringOrNull(Object? value) {
    final text = value?.toString();
    return text == null || text.trim().isEmpty ? null : text.trim();
  }

  int intValue(Object? value) {
    return (value as num?)?.toInt() ?? int.tryParse('${value ?? ''}') ?? 0;
  }

  int? intValueOrNull(Object? value) {
    if (value == null) return null;
    return (value as num?)?.toInt() ?? int.tryParse('$value');
  }

  double doubleValue(Object? value) {
    return (value as num?)?.toDouble() ??
        double.tryParse('${value ?? ''}') ??
        0;
  }
}
