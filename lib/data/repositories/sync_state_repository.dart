import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../models/sync_state_model.dart';

class SyncStateRepository {
  final LocalDatabase databaseHelper;

  SyncStateRepository({LocalDatabase? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<SyncStateModel?> getState({
    required String businessId,
    required String module,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.syncStateTable,
      where: 'business_id = ? AND module = ?',
      whereArgs: [businessId, module],
      limit: 1,
    );
    return rows.isEmpty ? null : SyncStateModel.fromMap(rows.first);
  }

  Future<List<SyncStateModel>> allStates() async {
    final db = await databaseHelper.database;
    final rows = await db.query(DatabaseSchema.syncStateTable);
    return rows.map(SyncStateModel.fromMap).toList(growable: false);
  }

  Future<void> upsert({
    required String businessId,
    required String module,
    DateTime? lastPullAt,
    DateTime? lastPushAt,
    DateTime? lastSuccessAt,
    String? lastError,
    required int pendingCount,
  }) async {
    final db = await databaseHelper.database;
    final now = DateTime.now();
    await db.insert(
      DatabaseSchema.syncStateTable,
      SyncStateModel(
        businessId: businessId,
        module: module,
        lastPullAt: lastPullAt,
        lastPushAt: lastPushAt,
        lastSuccessAt: lastSuccessAt,
        lastError: lastError,
        pendingCount: pendingCount,
        updatedAt: now,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePendingCount({
    required String businessId,
    required String module,
    required int pendingCount,
  }) async {
    final current = await getState(businessId: businessId, module: module);
    await upsert(
      businessId: businessId,
      module: module,
      lastPullAt: current?.lastPullAt,
      lastPushAt: current?.lastPushAt,
      lastSuccessAt: current?.lastSuccessAt,
      lastError: current?.lastError,
      pendingCount: pendingCount,
    );
  }

  Future<int> totalPendingCount() async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(pending_count), 0) AS total FROM ${DatabaseSchema.syncStateTable}',
    );
    return (rows.first['total'] as num? ?? 0).toInt();
  }

  Future<String?> lastError() async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.syncStateTable,
      columns: ['last_error'],
      where: 'last_error IS NOT NULL',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['last_error'] as String?;
  }

  Future<String?> lastErrorWithPendingWork() async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.syncStateTable,
      columns: ['last_error'],
      where: 'last_error IS NOT NULL AND pending_count > 0',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['last_error'] as String?;
  }

  Future<DateTime?> lastSuccessAt() async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.syncStateTable,
      columns: ['last_success_at'],
      where: 'last_success_at IS NOT NULL',
      orderBy: 'last_success_at DESC',
      limit: 1,
    );
    final value = rows.isEmpty
        ? null
        : rows.first['last_success_at'] as String?;
    return value == null ? null : DateTime.tryParse(value);
  }
}
