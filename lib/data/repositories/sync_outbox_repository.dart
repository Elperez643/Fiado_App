import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../models/sync_outbox_item.dart';
import '../services/sync_endpoint_registry.dart';

class SyncOutboxRepository {
  static const int inventoryImageMaxAttempts = 5;

  final LocalDatabase databaseHelper;

  SyncOutboxRepository({LocalDatabase? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<int> enqueue(SyncOutboxItem item) async {
    final endpoint = SyncEndpointRegistry.forModule(item.module);
    endpoint.validatePayload(item.payloadAsMap());
    final db = await databaseHelper.database;
    return db.insert(
      DatabaseSchema.syncOutboxTable,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<SyncOutboxItem>> pending({
    String? module,
    int limit = 100,
  }) async {
    final db = await databaseHelper.database;
    final retryGuard = 'NOT (module = ? AND status = ? AND attempt_count >= ?)';
    final where = module == null
        ? 'status IN (?, ?, ?) AND $retryGuard'
        : 'module = ? AND status IN (?, ?, ?) AND $retryGuard';
    final args = module == null
        ? <Object?>[
            SyncOutboxItem.statusPending,
            SyncOutboxItem.statusSyncing,
            SyncOutboxItem.statusFailed,
            'inventory_images',
            SyncOutboxItem.statusFailed,
            inventoryImageMaxAttempts,
          ]
        : <Object?>[
            module,
            SyncOutboxItem.statusPending,
            SyncOutboxItem.statusSyncing,
            SyncOutboxItem.statusFailed,
            'inventory_images',
            SyncOutboxItem.statusFailed,
            inventoryImageMaxAttempts,
          ];
    final rows = await db.query(
      DatabaseSchema.syncOutboxTable,
      where: where,
      whereArgs: args,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SyncOutboxItem.fromMap).toList(growable: false);
  }

  Future<int> pendingCount({String? module}) async {
    final db = await databaseHelper.database;
    final retryGuard = 'NOT (module = ? AND status = ? AND attempt_count >= ?)';
    final where = module == null
        ? 'status IN (?, ?, ?) AND $retryGuard'
        : 'module = ? AND status IN (?, ?, ?) AND $retryGuard';
    final args = module == null
        ? <Object?>[
            SyncOutboxItem.statusPending,
            SyncOutboxItem.statusSyncing,
            SyncOutboxItem.statusFailed,
            'inventory_images',
            SyncOutboxItem.statusFailed,
            inventoryImageMaxAttempts,
          ]
        : <Object?>[
            module,
            SyncOutboxItem.statusPending,
            SyncOutboxItem.statusSyncing,
            SyncOutboxItem.statusFailed,
            'inventory_images',
            SyncOutboxItem.statusFailed,
            inventoryImageMaxAttempts,
          ];
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.syncOutboxTable} WHERE $where',
      args,
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markSyncing(List<SyncOutboxItem> items) async {
    if (items.isEmpty) return;
    final db = await databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in items) {
      batch.update(
        DatabaseSchema.syncOutboxTable,
        {
          'status': SyncOutboxItem.statusSyncing,
          'attempt_count': item.attemptCount + 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> reactivateLegacyInventoryImageEvents() async {
    final db = await databaseHelper.database;
    return db.update(
      DatabaseSchema.syncOutboxTable,
      {
        'status': SyncOutboxItem.statusPending,
        'attempt_count': 0,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'module = ? AND status IN (?, ?)',
      whereArgs: [
        'inventory_images',
        SyncOutboxItem.statusFailed,
        SyncOutboxItem.statusSyncing,
      ],
    );
  }

  Future<void> markSynced(List<SyncOutboxItem> items) async {
    if (items.isEmpty) return;
    final db = await databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in items) {
      batch.update(
        DatabaseSchema.syncOutboxTable,
        {
          'status': SyncOutboxItem.statusSynced,
          'attempt_count': 0,
          'last_error': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markFailed(List<SyncOutboxItem> items, String error) async {
    if (items.isEmpty) return;
    final db = await databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final item in items) {
      batch.update(
        DatabaseSchema.syncOutboxTable,
        {
          'status': SyncOutboxItem.statusFailed,
          'last_error': error,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<String?> lastError({String? module}) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.syncOutboxTable,
      columns: ['last_error'],
      where: module == null
          ? 'status = ? AND last_error IS NOT NULL'
          : 'module = ? AND status = ? AND last_error IS NOT NULL',
      whereArgs: module == null
          ? [SyncOutboxItem.statusFailed]
          : [module, SyncOutboxItem.statusFailed],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['last_error'] as String?;
  }

  Future<int> failedCount({String? module}) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM ${DatabaseSchema.syncOutboxTable} '
      'WHERE status = ?${module == null ? '' : ' AND module = ?'}',
      [SyncOutboxItem.statusFailed, ?module],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
