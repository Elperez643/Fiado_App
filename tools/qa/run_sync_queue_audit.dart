import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

const _openStatuses = {'pending', 'failed', 'retry'};
const _localOnlyEntityTypes = {'usuarios', 'subscriptions', 'user_onboarding'};

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await _resolveDatabasePath(args);
  final repair = _hasFlag(args, 'repair');
  final fixSynced = repair || _hasFlag(args, 'fix-synced');
  final cleanOrphans = repair || _hasFlag(args, 'clean-orphans');

  final dbFile = File(dbPath);
  if (!await dbFile.exists()) {
    stderr.writeln('No se encontro la base SQLite: ${dbFile.absolute.path}');
    stderr.writeln(
      'Usa: dart run tools/qa/run_sync_queue_audit.dart --db RUTA',
    );
    exitCode = 1;
    return;
  }

  final db = await databaseFactory.openDatabase(dbFile.absolute.path);
  try {
    final report = await _audit(
      db,
      dbFile.absolute.path,
      fixSynced: fixSynced,
      cleanOrphans: cleanOrphans,
    );
    stdout.write(report.consoleOutput);
    await File('SYNC_QUEUE_AUDIT_REPORT.md').writeAsString(report.markdown);
    stdout.writeln('Wrote SYNC_QUEUE_AUDIT_REPORT.md');
    if (report.remainingOpenItems > 0) {
      exitCode = 2;
    }
  } finally {
    await db.close();
  }
}

Future<_AuditReport> _audit(
  Database db,
  String dbPath, {
  required bool fixSynced,
  required bool cleanOrphans,
}) async {
  if (!await _tableExists(db, DatabaseSchema.syncQueueTable)) {
    return _AuditReport(
      dbPath: dbPath,
      rows: const [],
      repairedSynced: 0,
      cleanedOrphans: 0,
      notes: const ['La tabla sync_queue no existe en esta base.'],
    );
  }

  final rows = await db.query(
    DatabaseSchema.syncQueueTable,
    where:
        'LOWER(status) IN (${List.filled(_openStatuses.length, '?').join(', ')})',
    whereArgs: _openStatuses.toList(),
    orderBy: 'created_at ASC',
  );

  final audited = <_QueueAuditRow>[];
  var repairedSynced = 0;
  var cleanedOrphans = 0;

  for (final row in rows) {
    final audit = await _auditRow(db, row);
    audited.add(audit);

    if (fixSynced && audit.canMarkQueueSynced) {
      await db.update(
        DatabaseSchema.syncQueueTable,
        {
          'status': 'synced',
          'last_error': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [audit.queueId],
      );
      repairedSynced++;
      continue;
    }

    if (cleanOrphans && audit.isOrphan) {
      await db.delete(
        DatabaseSchema.syncQueueTable,
        where: 'id = ?',
        whereArgs: [audit.queueId],
      );
      cleanedOrphans++;
    }
  }

  final remaining = await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.syncQueueTable}
WHERE LOWER(status) IN (${List.filled(_openStatuses.length, '?').join(', ')})
''', _openStatuses.toList());

  final remainingOpenItems = _firstInt(remaining);
  return _AuditReport(
    dbPath: dbPath,
    rows: audited,
    repairedSynced: repairedSynced,
    cleanedOrphans: cleanedOrphans,
    remainingOpenItems: remainingOpenItems,
    notes: [
      if (!fixSynced && audited.any((row) => row.canMarkQueueSynced))
        'Hay registros que ya estan synced localmente; ejecuta con --fix-synced o --repair para marcarlos como procesados.',
      if (!cleanOrphans && audited.any((row) => row.isOrphan))
        'Hay registros huerfanos; ejecuta con --clean-orphans o --repair para limpiarlos.',
    ],
  );
}

Future<_QueueAuditRow> _auditRow(Database db, Map<String, Object?> row) async {
  final queueId = (row['id'] as num).toInt();
  final entityType = row['entity_type']?.toString() ?? '';
  final entityId = (row['entity_id'] as num?)?.toInt() ?? 0;
  final operation = row['operation']?.toString() ?? '';
  final status = row['status']?.toString() ?? '';
  final lastError = row['last_error']?.toString();
  final attempts = (row['attempts'] as num?)?.toInt() ?? 0;

  if (!_isSafeTableName(entityType) || !await _tableExists(db, entityType)) {
    return _QueueAuditRow(
      queueId: queueId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status,
      attempts: attempts,
      lastError: lastError,
      entityExists: false,
      tableExists: false,
      localSyncStatus: null,
      remoteId: null,
      diagnosis: 'Entidad huerfana: tabla no existe.',
    );
  }

  final columns = await _columns(db, entityType);
  final selectedColumns = <String>['id'];
  if (columns.contains('sync_status')) selectedColumns.add('sync_status');
  if (columns.contains('remote_id')) selectedColumns.add('remote_id');
  if (columns.contains('deleted_at')) selectedColumns.add('deleted_at');

  final entityRows = await db.query(
    entityType,
    columns: selectedColumns,
    where: 'id = ?',
    whereArgs: [entityId],
    limit: 1,
  );

  if (entityRows.isEmpty) {
    return _QueueAuditRow(
      queueId: queueId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status,
      attempts: attempts,
      lastError: lastError,
      entityExists: false,
      tableExists: true,
      localSyncStatus: null,
      remoteId: null,
      diagnosis: 'Entidad huerfana: no existe fila local con ese id.',
    );
  }

  final entity = entityRows.first;
  final localSyncStatus = entity['sync_status']?.toString();
  final remoteId = entity['remote_id']?.toString();
  final deletedAt = entity['deleted_at']?.toString();
  final hasRemoteId = remoteId != null && remoteId.trim().isNotEmpty;
  final localSynced = localSyncStatus == 'synced';
  final canMarkSynced = localSynced && (hasRemoteId || operation == 'delete');
  final localOnly = _localOnlyEntityTypes.contains(entityType);

  final diagnosis = localOnly
      ? 'Entidad local/no soportada por sync cloud simple; puede marcarse synced para no contar como pendiente.'
      : canMarkSynced
      ? 'Backend/local ya parecen sincronizados; la cola puede marcarse synced.'
      : deletedAt != null && deletedAt.trim().isNotEmpty
      ? 'Entidad eliminada localmente; revisar si requiere push delete.'
      : status == 'failed'
      ? 'Fallo pendiente de reintento. Revisar last_error.'
      : 'Pendiente real de sincronizacion.';

  return _QueueAuditRow(
    queueId: queueId,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    status: status,
    attempts: attempts,
    lastError: lastError,
    entityExists: true,
    tableExists: true,
    localSyncStatus: localSyncStatus,
    remoteId: remoteId,
    diagnosis: diagnosis,
  );
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;

  final candidates = <String>[
    DatabaseSchema.databaseName,
    'qa_data/${DatabaseSchema.databaseName}',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];

  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return candidates.last;
}

Future<bool> _tableExists(Database db, String table) async {
  if (!_isSafeTableName(table)) return false;
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [table],
  );
  return rows.isNotEmpty;
}

Future<Set<String>> _columns(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((row) => row['name'].toString()).toSet();
}

bool _isSafeTableName(String value) {
  return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value);
}

String? _stringOption(List<String> args, String name, [String? fallback]) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  final index = args.indexOf('--$name');
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return fallback;
}

bool _hasFlag(List<String> args, String name) {
  return args.contains('--$name');
}

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  return (rows.first.values.first as num? ?? 0).toInt();
}

class _QueueAuditRow {
  final int queueId;
  final String entityType;
  final int entityId;
  final String operation;
  final String status;
  final int attempts;
  final String? lastError;
  final bool tableExists;
  final bool entityExists;
  final String? localSyncStatus;
  final String? remoteId;
  final String diagnosis;

  const _QueueAuditRow({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.tableExists,
    required this.entityExists,
    required this.localSyncStatus,
    required this.remoteId,
    required this.diagnosis,
  });

  bool get isOrphan => !tableExists || !entityExists;

  bool get canMarkQueueSynced {
    if (!entityExists) return false;
    if (_localOnlyEntityTypes.contains(entityType)) return true;
    return localSyncStatus == 'synced' &&
        ((remoteId != null && remoteId!.trim().isNotEmpty) ||
            operation == 'delete');
  }

  String get csv {
    return [
      queueId,
      entityType,
      entityId,
      operation,
      status,
      attempts,
      localSyncStatus ?? '',
      remoteId ?? '',
      isOrphan,
      canMarkQueueSynced,
      _csv(lastError ?? ''),
      _csv(diagnosis),
    ].join(',');
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _AuditReport {
  final String dbPath;
  final List<_QueueAuditRow> rows;
  final int repairedSynced;
  final int cleanedOrphans;
  final int remainingOpenItems;
  final List<String> notes;

  const _AuditReport({
    required this.dbPath,
    required this.rows,
    required this.repairedSynced,
    required this.cleanedOrphans,
    this.remainingOpenItems = 0,
    this.notes = const [],
  });

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('SYNC_QUEUE_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('open_items_before: ${rows.length}')
      ..writeln('repaired_synced: $repairedSynced')
      ..writeln('cleaned_orphans: $cleanedOrphans')
      ..writeln('open_items_after: $remainingOpenItems')
      ..writeln(
        'queue_id,entity_type,entity_id,operation,status,attempts,local_sync_status,remote_id,is_orphan,can_mark_synced,last_error,diagnosis',
      );
    for (final row in rows) {
      buffer.writeln(row.csv);
    }
    for (final note in notes) {
      buffer.writeln('note: $note');
    }
    return buffer.toString();
  }

  String get markdown {
    final grouped = <String, int>{};
    for (final row in rows) {
      grouped[row.entityType] = (grouped[row.entityType] ?? 0) + 1;
    }
    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer()
      ..writeln('# Sync Queue Audit Report')
      ..writeln()
      ..writeln('- Fecha: $now')
      ..writeln('- Base SQLite: `$dbPath`')
      ..writeln('- Elementos abiertos antes: ${rows.length}')
      ..writeln('- Marcados synced por auditor: $repairedSynced')
      ..writeln('- Huerfanos limpiados por auditor: $cleanedOrphans')
      ..writeln('- Elementos abiertos despues: $remainingOpenItems')
      ..writeln()
      ..writeln('## Resumen Por Entidad')
      ..writeln()
      ..writeln('| entity_type | abiertos |')
      ..writeln('| --- | ---: |');
    if (grouped.isEmpty) {
      buffer.writeln('| ninguno | 0 |');
    } else {
      for (final entry in grouped.entries) {
        buffer.writeln('| `${entry.key}` | ${entry.value} |');
      }
    }
    buffer
      ..writeln()
      ..writeln('## Detalle')
      ..writeln()
      ..writeln(
        '| entity_type | entity_id | operation | status | last_error | diagnostico |',
      )
      ..writeln('| --- | ---: | --- | --- | --- | --- |');
    if (rows.isEmpty) {
      buffer.writeln('| ninguno | 0 | - | - | - | Cola limpia |');
    } else {
      for (final row in rows) {
        buffer.writeln(
          '| `${row.entityType}` | ${row.entityId} | `${row.operation}` | `${row.status}` | ${_md(row.lastError)} | ${_md(row.diagnosis)} |',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## Criterios')
      ..writeln()
      ..writeln(
        '- Se auditan registros con estado `pending`, `failed` o `retry`.',
      )
      ..writeln(
        '- Si la entidad local existe con `sync_status = synced` y tiene `remote_id`, la cola puede marcarse `synced`.',
      )
      ..writeln(
        '- `usuarios`, `subscriptions` y `user_onboarding` son locales/no soportadas por el sync cloud simple actual; se pueden marcar `synced` para que no cuenten como pendientes falsos.',
      )
      ..writeln(
        '- Si la tabla o la fila local no existe, el registro se considera huerfano.',
      )
      ..writeln(
        '- El auditor solo modifica datos cuando se ejecuta con `--repair`, `--fix-synced` o `--clean-orphans`.',
      );
    if (notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Notas');
      for (final note in notes) {
        buffer.writeln('- $note');
      }
    }
    return buffer.toString();
  }

  static String _md(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    return value.replaceAll('|', '\\|').replaceAll('\n', ' ');
  }
}
