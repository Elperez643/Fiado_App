import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

const _openStatuses = {'pending', 'failed', 'retry'};
const _localOnlyEntityTypes = {'usuarios', 'subscriptions', 'user_onboarding'};
const _businessScopedEntityTypes = {
  'clientes',
  'productos',
  'producto_imagenes',
  'movimientos',
  'deuda_items',
  'comprobantes',
  'credito_ciclos',
  'credito_recordatorios',
  'credito_excepciones',
  'client_scores',
  'solicitudes_autorizacion',
  'auditorias',
  'auditoria_items',
};

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await _resolveDatabasePath(args);
  final file = File(dbPath);
  final createQaDb = !await file.exists();
  if (createQaDb) await file.parent.create(recursive: true);

  final db = await databaseFactory.openDatabase(
    file.absolute.path,
    options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onCreate: _createQaSchema,
    ),
  );

  try {
    final report = await _audit(db, file.absolute.path, createQaDb);
    stdout.write(report.consoleOutput);
    await File('SYNC_INTEGRITY_AUDIT_REPORT.md').writeAsString(report.markdown);
    stdout.writeln('Wrote SYNC_INTEGRITY_AUDIT_REPORT.md');
    if (report.criticalIssues > 0) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<_SyncIntegrityReport> _audit(
  Database db,
  String dbPath,
  bool createdQaDb,
) async {
  if (!await _tableExists(db, DatabaseSchema.syncQueueTable)) {
    return _SyncIntegrityReport(
      dbPath: dbPath,
      createdQaDb: createdQaDb,
      rows: const [],
      criticalIssues: 1,
      notes: const ['CRITICAL: tabla sync_queue no existe.'],
    );
  }

  final rows = await db.query(
    DatabaseSchema.syncQueueTable,
    where:
        'LOWER(status) IN (${List.filled(_openStatuses.length, '?').join(', ')})',
    whereArgs: _openStatuses.toList(),
    orderBy: 'created_at ASC',
  );

  final audited = <_SyncRow>[];
  var criticalIssues = 0;
  final notes = <String>[];

  for (final row in rows) {
    final auditedRow = await _auditQueueRow(db, row);
    audited.add(auditedRow);
    if (auditedRow.critical) criticalIssues++;
  }

  final failedRows = _firstInt(
    await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.syncQueueTable}
WHERE LOWER(status) = 'failed'
'''),
  );
  if (failedRows > 0) {
    notes.add('Hay $failedRows registros failed pendientes de reintento.');
  }
  if (audited.any((row) => row.localOnlyOpen)) {
    notes.add(
      'Hay entidades locales no soportadas abiertas; deben marcarse synced o excluirse de cola.',
    );
  }

  return _SyncIntegrityReport(
    dbPath: dbPath,
    createdQaDb: createdQaDb,
    rows: audited,
    criticalIssues: criticalIssues,
    notes: notes,
  );
}

Future<_SyncRow> _auditQueueRow(Database db, Map<String, Object?> row) async {
  final queueId = (row['id'] as num?)?.toInt() ?? 0;
  final entityType = row['entity_type']?.toString() ?? '';
  final entityId = (row['entity_id'] as num?)?.toInt() ?? 0;
  final operation = row['operation']?.toString() ?? '';
  final status = row['status']?.toString() ?? '';
  final lastError = row['last_error']?.toString() ?? '';
  final payloadText = row['payload']?.toString() ?? '{}';
  final payload = _decodePayload(payloadText);
  final localOnly = _localOnlyEntityTypes.contains(entityType);
  final businessScoped = _businessScopedEntityTypes.contains(entityType);

  if (!_isSafeTableName(entityType) || !await _tableExists(db, entityType)) {
    return _SyncRow(
      queueId: queueId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status,
      lastError: lastError,
      diagnosis: 'CRITICAL: tabla local no existe para entity_type.',
      critical: true,
      localOnlyOpen: localOnly,
    );
  }

  final entityRows = await db.query(
    entityType,
    where: 'id = ?',
    whereArgs: [entityId],
    limit: 1,
  );
  if (operation != 'delete' && entityRows.isEmpty) {
    return _SyncRow(
      queueId: queueId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status,
      lastError: lastError,
      diagnosis: 'CRITICAL: sync_queue apunta a entidad huerfana.',
      critical: true,
      localOnlyOpen: localOnly,
    );
  }

  final entity = entityRows.isEmpty ? <String, Object?>{} : entityRows.first;
  final localSyncStatus = entity['sync_status']?.toString();
  final remoteId = entity['remote_id']?.toString();
  final negocioId = entity['negocio_id'] ?? payload['negocio_id'];
  final missingBusinessId =
      businessScoped &&
      operation != 'delete' &&
      (negocioId == null || negocioId == 0);

  if (localOnly) {
    return _SyncRow(
      queueId: queueId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status,
      lastError: lastError,
      localSyncStatus: localSyncStatus,
      remoteId: remoteId?.toString(),
      negocioId: negocioId,
      diagnosis:
          'CRITICAL: entidad local/no soportada no debe quedar como pendiente.',
      critical: true,
      localOnlyOpen: true,
    );
  }

  if (missingBusinessId) {
    return _SyncRow(
      queueId: queueId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      status: status,
      lastError: lastError,
      localSyncStatus: localSyncStatus,
      remoteId: remoteId?.toString(),
      negocioId: negocioId,
      diagnosis: 'CRITICAL: entidad de negocio sin negocio_id en cola/local.',
      critical: true,
      localOnlyOpen: false,
    );
  }

  final syncedButOpen =
      localSyncStatus == 'synced' &&
      (operation == 'delete' ||
          (remoteId != null && remoteId.trim().isNotEmpty));

  return _SyncRow(
    queueId: queueId,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    status: status,
    lastError: lastError,
    localSyncStatus: localSyncStatus,
    remoteId: remoteId?.toString(),
    negocioId: negocioId,
    diagnosis: syncedButOpen
        ? 'CRITICAL: entidad ya parece synced pero cola sigue abierta.'
        : 'Pendiente real de sincronizacion o reintento.',
    critical: syncedButOpen,
    localOnlyOpen: false,
  );
}

Map<String, Object?> _decodePayload(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return decoded.cast<String, Object?>();
  } catch (_) {
    return const {};
  }
  return const {};
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = [
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    'qa_data/sync_integrity.db',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return 'qa_data/sync_integrity.db';
}

Future<void> _createQaSchema(Database db, int version) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createClientesTable);
  await db.execute(DatabaseSchema.createProductosTable);
  await db.execute(DatabaseSchema.createProductoImagenesTable);
  await db.execute(DatabaseSchema.createMovimientosTable);
  await db.execute(DatabaseSchema.createDeudaItemsTable);
  await db.execute(DatabaseSchema.createComprobantesTable);
  await db.execute(DatabaseSchema.createCreditoCiclosTable);
  await db.execute(DatabaseSchema.createCreditoRecordatoriosTable);
  await db.execute(DatabaseSchema.createCreditoExcepcionesTable);
  await db.execute(DatabaseSchema.createClientScoresTable);
  await db.execute(DatabaseSchema.createSolicitudesAutorizacionTable);
  await db.execute(DatabaseSchema.createAuditoriasTable);
  await db.execute(DatabaseSchema.createAuditoriaItemsTable);
  await db.execute(DatabaseSchema.createSyncQueueTable);
  await db.execute(DatabaseSchema.createSubscriptionsTable);
  await db.execute(DatabaseSchema.createUserOnboardingTable);
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [table],
  );
  return rows.isNotEmpty;
}

bool _isSafeTableName(String value) {
  return RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(value);
}

String? _stringOption(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  final index = args.indexOf('--$name');
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return null;
}

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  return (rows.first.values.first as num? ?? 0).toInt();
}

class _SyncRow {
  final int queueId;
  final String entityType;
  final int entityId;
  final String operation;
  final String status;
  final String lastError;
  final String? localSyncStatus;
  final String? remoteId;
  final Object? negocioId;
  final String diagnosis;
  final bool critical;
  final bool localOnlyOpen;

  const _SyncRow({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.status,
    required this.lastError,
    required this.diagnosis,
    required this.critical,
    required this.localOnlyOpen,
    this.localSyncStatus,
    this.remoteId,
    this.negocioId,
  });
}

class _SyncIntegrityReport {
  final String dbPath;
  final bool createdQaDb;
  final List<_SyncRow> rows;
  final int criticalIssues;
  final List<String> notes;

  const _SyncIntegrityReport({
    required this.dbPath,
    required this.createdQaDb,
    required this.rows,
    required this.criticalIssues,
    required this.notes,
  });

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('SYNC_INTEGRITY_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('created_qa_db: $createdQaDb')
      ..writeln('open_items: ${rows.length}')
      ..writeln('critical_issues: $criticalIssues')
      ..writeln(
        'queue_id,entity_type,entity_id,operation,status,local_sync_status,remote_id,negocio_id,last_error,diagnosis',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.queueId},${row.entityType},${row.entityId},${row.operation},'
        '${row.status},${row.localSyncStatus ?? ''},${row.remoteId ?? ''},'
        '${row.negocioId ?? ''},"${row.lastError}","${row.diagnosis}"',
      );
    }
    for (final note in notes) {
      buffer.writeln('note: $note');
    }
    return buffer.toString();
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# Sync Integrity Audit Report')
      ..writeln()
      ..writeln('- Database: `$dbPath`')
      ..writeln('- Created QA DB: $createdQaDb')
      ..writeln('- Open items: ${rows.length}')
      ..writeln('- Critical issues: $criticalIssues')
      ..writeln()
      ..writeln(
        '| queue_id | entity_type | entity_id | operation | status | negocio_id | diagnosis |',
      )
      ..writeln('| ---: | --- | ---: | --- | --- | --- | --- |');
    for (final row in rows) {
      buffer.writeln(
        '| ${row.queueId} | ${row.entityType} | ${row.entityId} | ${row.operation} | ${row.status} | ${row.negocioId ?? ''} | ${row.diagnosis} |',
      );
    }
    if (notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Notes');
      for (final note in notes) {
        buffer.writeln('- $note');
      }
    }
    return buffer.toString();
  }
}
