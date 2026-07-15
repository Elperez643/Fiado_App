import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_queue_item_model.dart';
import '../contracts/data_contract_registry.dart';

class SyncQueueSummary {
  final int pendingCount;
  final int failedCount;
  final DateTime? lastAttemptAt;
  final int processedCount;

  const SyncQueueSummary({
    required this.pendingCount,
    required this.failedCount,
    required this.lastAttemptAt,
    required this.processedCount,
  });
}

class SyncQueueRepository {
  static final _queueChangesController = StreamController<void>.broadcast();

  static Stream<void> get queueChanges => _queueChangesController.stream;

  static const localOnlyEntityTypes =
      DataContractRegistry.localOnlyQueueEntityTypes;

  final LocalDatabase databaseHelper;

  SyncQueueRepository({LocalDatabase? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> enqueueCreate({
    required String entityType,
    required int entityId,
    required Map<String, Object?> payload,
  }) {
    return _enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperationType.create,
      payload: payload,
    );
  }

  Future<int> enqueueUpdate({
    required String entityType,
    required int entityId,
    required Map<String, Object?> payload,
  }) {
    return _enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperationType.update,
      payload: payload,
    );
  }

  Future<int> enqueueDelete({
    required String entityType,
    required int entityId,
    required Map<String, Object?> payload,
  }) {
    return _enqueue(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperationType.delete,
      payload: payload,
    );
  }

  Future<List<SyncQueueItemModel>> obtenerPendientes({int limit = 100}) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.syncQueueTable,
      where: 'status IN (?, ?, ?)',
      whereArgs: [SyncStatus.pending, SyncStatus.failed, SyncStatus.retry],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SyncQueueItemModel.fromMap).toList();
  }

  Future<void> marcarComoProcesado(int id) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.syncQueueTable,
      {
        'status': SyncStatus.synced,
        'attempts': 0,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> marcarComoFallido(int id, String error) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.syncQueueTable,
      {
        'status': SyncStatus.failed,
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementarIntento(int id) async {
    final db = await databaseHelper.database;
    await db.rawUpdate(
      '''
UPDATE ${DatabaseSchema.syncQueueTable}
SET attempts = attempts + 1, updated_at = ?
WHERE id = ?
''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<int> limpiarProcesados() async {
    final db = await databaseHelper.database;
    return db.delete(
      DatabaseSchema.syncQueueTable,
      where: 'status = ?',
      whereArgs: [SyncStatus.synced],
    );
  }

  Future<int> marcarLocalesNoSoportadosComoProcesados() async {
    final db = await databaseHelper.database;
    return db.update(
      DatabaseSchema.syncQueueTable,
      {
        'status': SyncStatus.synced,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where:
          'entity_type IN (${List.filled(localOnlyEntityTypes.length, '?').join(', ')}) '
          'AND status IN (?, ?, ?)',
      whereArgs: [
        ...localOnlyEntityTypes,
        SyncStatus.pending,
        SyncStatus.failed,
        SyncStatus.retry,
      ],
    );
  }

  Future<SyncQueueSummary> obtenerResumen() async {
    final db = await databaseHelper.database;
    final counts = await db.rawQuery(
      '''
SELECT
  SUM(CASE WHEN status IN (?, ?) THEN 1 ELSE 0 END) AS pending_count,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS failed_count,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS processed_count,
  MAX(CASE WHEN attempts > 0 THEN updated_at ELSE NULL END) AS last_attempt_at
FROM ${DatabaseSchema.syncQueueTable}
''',
      [
        SyncStatus.pending,
        SyncStatus.retry,
        SyncStatus.failed,
        SyncStatus.synced,
      ],
    );
    final row = counts.first;
    final lastAttempt = row['last_attempt_at'] as String?;
    return SyncQueueSummary(
      pendingCount: (row['pending_count'] as num? ?? 0).toInt(),
      failedCount: (row['failed_count'] as num? ?? 0).toInt(),
      processedCount: (row['processed_count'] as num? ?? 0).toInt(),
      lastAttemptAt: lastAttempt == null ? null : DateTime.parse(lastAttempt),
    );
  }

  Future<int> _enqueue({
    required String entityType,
    required int entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    if (!DataContractRegistry.knownQueueEntityTypes.contains(entityType)) {
      throw StateError(
        'No se puede encolar entidad sin contrato: entityType=$entityType; '
        'tabla esperada=$entityType; endpoint esperado=no registrado; '
        'archivo probable=lib/data/contracts/data_contract_registry.dart; '
        'accion recomendada: registrar handler o declarar local-only.',
      );
    }
    final db = await databaseHelper.database;
    final item = SyncQueueItemModel.create(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: {
        ...payload,
        '_sync': {
          'entity_type': entityType,
          'entity_id': entityId,
          'operation': operation,
        },
      },
    );
    final id = await db.insert(
      DatabaseSchema.syncQueueTable,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    _queueChangesController.add(null);
    return id;
  }
}
