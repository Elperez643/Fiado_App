import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_feature_flags.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_outbox_item.dart';

class SyncStatusDiagnosticSnapshot {
  final int pendingOutboxCount;
  final int failedOutboxCount;
  final int pendingLegacyQueueCount;
  final int failedLegacyQueueCount;
  final int activePendingLegacyQueueCount;
  final int activeFailedLegacyQueueCount;
  final List<String> pendingModules;
  final List<String> failedModules;
  final String? latestOutboxError;
  final String? latestActiveStateError;
  final String? latestActiveLegacyError;
  final DateTime? lastSuccessfulSyncAt;

  const SyncStatusDiagnosticSnapshot({
    required this.pendingOutboxCount,
    required this.failedOutboxCount,
    required this.pendingLegacyQueueCount,
    required this.failedLegacyQueueCount,
    required this.activePendingLegacyQueueCount,
    required this.activeFailedLegacyQueueCount,
    required this.pendingModules,
    required this.failedModules,
    this.latestOutboxError,
    this.latestActiveStateError,
    this.latestActiveLegacyError,
    this.lastSuccessfulSyncAt,
  });

  String? sourceForError(String? visibleError) {
    if (visibleError == null || visibleError.trim().isEmpty) return null;
    if (visibleError == latestOutboxError) return 'sync_outbox';
    if (visibleError == latestActiveStateError) return 'sync_state';
    if (visibleError == latestActiveLegacyError) return 'sync_queue';
    return 'notifier-memory-or-auth';
  }
}

class SyncStatusDiagnosticsRepository {
  final LocalDatabase databaseHelper;

  SyncStatusDiagnosticsRepository({LocalDatabase? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<SyncStatusDiagnosticSnapshot> snapshot() async {
    final db = await databaseHelper.database;
    final outboxRows = await db.query(
      DatabaseSchema.syncOutboxTable,
      columns: ['module', 'status', 'last_error', 'updated_at'],
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        SyncOutboxItem.statusPending,
        SyncOutboxItem.statusSyncing,
        SyncOutboxItem.statusFailed,
      ],
      orderBy: 'updated_at DESC',
    );
    final legacyRows = await db.query(
      DatabaseSchema.syncQueueTable,
      columns: ['entity_type', 'status', 'last_error', 'updated_at'],
      where: 'status IN (?, ?, ?)',
      whereArgs: [SyncStatus.pending, SyncStatus.retry, SyncStatus.failed],
      orderBy: 'updated_at DESC',
    );
    final stateRows = await db.query(
      DatabaseSchema.syncStateTable,
      columns: [
        'module',
        'pending_count',
        'last_error',
        'last_success_at',
        'updated_at',
      ],
      orderBy: 'updated_at DESC',
    );

    final pendingOutbox = outboxRows.where(
      (row) => row['status'] != SyncOutboxItem.statusFailed,
    );
    final failedOutbox = outboxRows.where(
      (row) => row['status'] == SyncOutboxItem.statusFailed,
    );
    final pendingLegacy = legacyRows.where(
      (row) => row['status'] != SyncStatus.failed,
    );
    final failedLegacy = legacyRows.where(
      (row) => row['status'] == SyncStatus.failed,
    );
    final legacyIsActive = SyncFeatureFlags.enableLegacySync;
    final lastSuccessValues =
        stateRows
            .map(
              (row) =>
                  DateTime.tryParse(row['last_success_at']?.toString() ?? ''),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();

    return SyncStatusDiagnosticSnapshot(
      pendingOutboxCount: pendingOutbox.length,
      failedOutboxCount: failedOutbox.length,
      pendingLegacyQueueCount: pendingLegacy.length,
      failedLegacyQueueCount: failedLegacy.length,
      activePendingLegacyQueueCount: legacyIsActive ? pendingLegacy.length : 0,
      activeFailedLegacyQueueCount: legacyIsActive ? failedLegacy.length : 0,
      pendingModules: {
        ...pendingOutbox.map((row) => row['module'].toString()),
        if (legacyIsActive)
          ...pendingLegacy.map((row) => row['entity_type'].toString()),
      }.toList()..sort(),
      failedModules: {
        ...failedOutbox.map((row) => row['module'].toString()),
        if (legacyIsActive)
          ...failedLegacy.map((row) => row['entity_type'].toString()),
      }.toList()..sort(),
      latestOutboxError: _firstError(failedOutbox),
      latestActiveStateError: _firstError(
        stateRows.where(
          (row) =>
              (row['pending_count'] as num? ?? 0).toInt() > 0 &&
              row['last_error'] != null,
        ),
      ),
      latestActiveLegacyError: legacyIsActive
          ? _firstError(failedLegacy)
          : null,
      lastSuccessfulSyncAt: lastSuccessValues.isEmpty
          ? null
          : lastSuccessValues.last,
    );
  }

  Future<void> debugPrintSummary() async {
    if (!kDebugMode) return;
    final db = await databaseHelper.database;
    await _printRows(
      db,
      table: DatabaseSchema.syncStateTable,
      columns: [
        'id',
        'module',
        'pending_count',
        'last_error',
        'last_pull_at',
        'last_push_at',
        'last_success_at',
        'updated_at',
      ],
    );
    await _printRows(
      db,
      table: DatabaseSchema.syncOutboxTable,
      columns: [
        'id',
        'module',
        'entity_type',
        'status',
        'attempt_count',
        'last_error',
        'created_at',
        'updated_at',
      ],
    );
    await _printRows(
      db,
      table: DatabaseSchema.syncQueueTable,
      columns: [
        'id',
        'entity_type',
        'status',
        'attempts',
        'last_error',
        'created_at',
        'updated_at',
      ],
    );
  }

  static String? _firstError(Iterable<Map<String, Object?>> rows) {
    for (final row in rows) {
      final error = row['last_error']?.toString();
      if (error != null && error.trim().isNotEmpty) return error;
    }
    return null;
  }

  static Future<void> _printRows(
    Database db, {
    required String table,
    required List<String> columns,
  }) async {
    final rows = await db.query(table, columns: columns, orderBy: 'id ASC');
    debugPrint(
      '[sync-status-storage-summary] table=$table rows=${jsonEncode(rows)}',
    );
  }
}
