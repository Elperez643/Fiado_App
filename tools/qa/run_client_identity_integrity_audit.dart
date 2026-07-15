import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final explicitDb = _explicitDatabasePath(args);
  final dbPath = explicitDb ?? await _resolveDatabasePath(args);
  final file = File(dbPath);
  if (!await file.exists()) {
    if (explicitDb == null) {
      await file.parent.create(recursive: true);
    } else {
      stderr.writeln('No se encontro la base SQLite: ${file.absolute.path}');
      stderr.writeln(
        'Usa: dart run tools/qa/run_client_identity_integrity_audit.dart --db RUTA',
      );
      exitCode = 1;
      return;
    }
  }

  final db = await databaseFactory.openDatabase(
    file.absolute.path,
    options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onCreate: _createAuditSchema,
    ),
  );
  try {
    await _ensureClientIdentitySchema(db);
    final report = await _audit(db, file.absolute.path);
    stdout.write(report.consoleOutput);
    await File(
      'CLIENT_IDENTITY_INTEGRITY_AUDIT.md',
    ).writeAsString(report.markdown);
    stdout.writeln('Wrote CLIENT_IDENTITY_INTEGRITY_AUDIT.md');
    if (report.hasCriticalFindings) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<void> _createAuditSchema(Database db, int version) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createClientesTable);
  await db.execute(DatabaseSchema.createMovimientosTable);
  await db.execute(DatabaseSchema.createComprobantesTable);
  await db.execute(DatabaseSchema.createCreditoCiclosTable);
  await db.execute(DatabaseSchema.createClientScoresTable);
  await db.execute(DatabaseSchema.createBusinessRecommendationsCacheTable);
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_audit_movimientos_negocio_cliente_id '
    'ON ${DatabaseSchema.movimientosTable}(negocio_id, cliente_id)',
  );
}

Future<void> _ensureClientIdentitySchema(Database db) async {
  if (!await _hasTable(db, DatabaseSchema.movimientosTable)) return;

  await _addColumnIfMissing(
    db,
    DatabaseSchema.movimientosTable,
    'cliente_id',
    'INTEGER',
  );
  await _addColumnIfMissing(
    db,
    DatabaseSchema.movimientosTable,
    'cliente_nombre_snapshot',
    'TEXT',
  );
  await _addColumnIfMissing(
    db,
    DatabaseSchema.movimientosTable,
    'cliente_telefono_snapshot',
    'TEXT',
  );

  await db.execute('''
UPDATE ${DatabaseSchema.movimientosTable}
SET cliente_nombre_snapshot = COALESCE(cliente_nombre_snapshot, cliente_nombre),
    cliente_telefono_snapshot = COALESCE(cliente_telefono_snapshot, cliente_telefono)
WHERE cliente_nombre_snapshot IS NULL
   OR cliente_telefono_snapshot IS NULL
''');

  if (await _hasTable(db, DatabaseSchema.clientesTable)) {
    await db.execute('''
UPDATE ${DatabaseSchema.movimientosTable}
SET cliente_id = (
  SELECT c.id
  FROM ${DatabaseSchema.clientesTable} c
  WHERE c.negocio_id = ${DatabaseSchema.movimientosTable}.negocio_id
    AND COALESCE(c.is_active, 1) = 1
    AND (
      (
        ${DatabaseSchema.movimientosTable}.cliente_telefono IS NOT NULL
        AND ${DatabaseSchema.movimientosTable}.cliente_telefono != ''
        AND c.telefono = ${DatabaseSchema.movimientosTable}.cliente_telefono
      )
      OR LOWER(c.nombre) = LOWER(${DatabaseSchema.movimientosTable}.cliente_nombre)
    )
  ORDER BY
    CASE
      WHEN c.telefono = ${DatabaseSchema.movimientosTable}.cliente_telefono THEN 0
      ELSE 1
    END,
    c.id DESC
  LIMIT 1
)
WHERE cliente_id IS NULL
''');
  }

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_movimientos_negocio_cliente_id_fecha '
    'ON ${DatabaseSchema.movimientosTable}(negocio_id, cliente_id, fecha DESC)',
  );
}

Future<void> _addColumnIfMissing(
  Database db,
  String table,
  String column,
  String definition,
) async {
  if (await _hasColumn(db, table, column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}

String? _explicitDatabasePath(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      return args[i + 1];
    }
  }
  return null;
}

Future<_ClientIdentityReport> _audit(Database db, String dbPath) async {
  final hasMovimientoClienteId = await _hasColumn(
    db,
    DatabaseSchema.movimientosTable,
    'cliente_id',
  );
  final hasBusinessRecommendations = await _hasTable(
    db,
    DatabaseSchema.businessRecommendationsCacheTable,
  );
  final hasClientScores = await _hasTable(db, DatabaseSchema.clientScoresTable);
  final hasCreditCycles = await _hasTable(
    db,
    DatabaseSchema.creditoCiclosTable,
  );
  final hasReceipts = await _hasTable(db, DatabaseSchema.comprobantesTable);

  final movimientosSinClienteId = hasMovimientoClienteId
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable}
WHERE cliente_id IS NULL
  AND COALESCE(is_active, 1) = 1
'''),
        )
      : _firstInt(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.movimientosTable}',
          ),
        );

  final movimientosHuerfanos = hasMovimientoClienteId
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable} m
LEFT JOIN ${DatabaseSchema.clientesTable} c
  ON c.id = m.cliente_id
  AND c.negocio_id = m.negocio_id
WHERE m.cliente_id IS NOT NULL
  AND c.id IS NULL
  AND COALESCE(m.is_active, 1) = 1
'''),
        )
      : 0;

  final pagosSinClienteId = hasMovimientoClienteId
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable}
WHERE tipo = 'pago'
  AND cliente_id IS NULL
  AND COALESCE(is_active, 1) = 1
'''),
        )
      : _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable}
WHERE tipo = 'pago'
'''),
        );

  final ciclosHuerfanos = hasCreditCycles
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.creditoCiclosTable} cc
LEFT JOIN ${DatabaseSchema.clientesTable} c
  ON c.id = cc.cliente_id
  AND c.negocio_id = cc.negocio_id
WHERE c.id IS NULL
'''),
        )
      : 0;

  final scoresHuerfanos = hasClientScores
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.clientScoresTable} cs
LEFT JOIN ${DatabaseSchema.clientesTable} c
  ON c.id = cs.cliente_id
  AND c.negocio_id = cs.negocio_id
WHERE c.id IS NULL
  AND cs.deleted_at IS NULL
'''),
        )
      : 0;

  final comprobantesSinMovimiento = hasReceipts
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.comprobantesTable} c
LEFT JOIN ${DatabaseSchema.movimientosTable} m
  ON m.id = c.movimiento_id
  AND m.negocio_id = c.negocio_id
WHERE c.movimiento_id IS NULL
   OR m.id IS NULL
'''),
        )
      : 0;

  final recomendacionesPorTelefono = hasBusinessRecommendations
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.businessRecommendationsCacheTable}
WHERE action_route LIKE '%telefono%'
   OR action_route LIKE '%phone%'
   OR id LIKE '%telefono%'
   OR id LIKE '%phone%'
'''),
        )
      : 0;

  final sampleMovimientos = hasMovimientoClienteId
      ? await db.rawQuery('''
SELECT m.id, m.negocio_id, m.cliente_id, m.cliente_nombre,
       m.cliente_telefono, m.tipo, m.monto, m.fecha
FROM ${DatabaseSchema.movimientosTable} m
WHERE m.cliente_id IS NULL
   OR NOT EXISTS (
     SELECT 1 FROM ${DatabaseSchema.clientesTable} c
     WHERE c.id = m.cliente_id AND c.negocio_id = m.negocio_id
   )
ORDER BY m.fecha DESC
LIMIT 20
''')
      : await db.rawQuery('''
SELECT m.id, m.negocio_id, NULL AS cliente_id, m.cliente_nombre,
       m.cliente_telefono, m.tipo, m.monto, m.fecha
FROM ${DatabaseSchema.movimientosTable} m
ORDER BY m.fecha DESC
LIMIT 20
''');

  return _ClientIdentityReport(
    dbPath: dbPath,
    movimientosSinClienteId: movimientosSinClienteId,
    pagosSinClienteId: pagosSinClienteId,
    ciclosHuerfanos: ciclosHuerfanos,
    scoresHuerfanos: scoresHuerfanos,
    recomendacionesPorTelefono: recomendacionesPorTelefono,
    comprobantesSinMovimiento: comprobantesSinMovimiento,
    movimientosHuerfanos: movimientosHuerfanos,
    sampleMovimientos: sampleMovimientos,
    schemaHasMovimientoClienteId: hasMovimientoClienteId,
  );
}

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  return (rows.first.values.first as num?)?.toInt() ?? 0;
}

Future<bool> _hasTable(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [table],
  );
  return rows.isNotEmpty;
}

Future<bool> _hasColumn(Database db, String table, String column) async {
  if (!await _hasTable(db, table)) return false;
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.any((row) => row['name'] == column);
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final candidates = [
    'qa_data/device_fiado_app.db',
    'qa_data/device_fiado_app_after.db',
    'qa_data/client_identity_integrity.db',
    '.dart_tool/sqflite_common_ffi/databases/${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return candidates.last;
}

class _ClientIdentityReport {
  final String dbPath;
  final int movimientosSinClienteId;
  final int pagosSinClienteId;
  final int ciclosHuerfanos;
  final int scoresHuerfanos;
  final int recomendacionesPorTelefono;
  final int comprobantesSinMovimiento;
  final int movimientosHuerfanos;
  final List<Map<String, Object?>> sampleMovimientos;
  final bool schemaHasMovimientoClienteId;

  const _ClientIdentityReport({
    required this.dbPath,
    required this.movimientosSinClienteId,
    required this.pagosSinClienteId,
    required this.ciclosHuerfanos,
    required this.scoresHuerfanos,
    required this.recomendacionesPorTelefono,
    required this.comprobantesSinMovimiento,
    required this.movimientosHuerfanos,
    required this.sampleMovimientos,
    required this.schemaHasMovimientoClienteId,
  });

  bool get hasCriticalFindings =>
      !schemaHasMovimientoClienteId ||
      movimientosHuerfanos > 0 ||
      ciclosHuerfanos > 0 ||
      scoresHuerfanos > 0 ||
      recomendacionesPorTelefono > 0;

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('CLIENT_IDENTITY_INTEGRITY_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('schema_movimientos_cliente_id: $schemaHasMovimientoClienteId')
      ..writeln('movimientos_sin_cliente_id: $movimientosSinClienteId')
      ..writeln('pagos_sin_cliente_id: $pagosSinClienteId')
      ..writeln('movimientos_huerfanos: $movimientosHuerfanos')
      ..writeln('ciclos_huerfanos: $ciclosHuerfanos')
      ..writeln('scores_huerfanos: $scoresHuerfanos')
      ..writeln('recomendaciones_por_telefono: $recomendacionesPorTelefono')
      ..writeln('comprobantes_sin_movimiento: $comprobantesSinMovimiento')
      ..writeln()
      ..writeln('sample_movimientos')
      ..writeln(
        'id,negocio_id,cliente_id,cliente_nombre,cliente_telefono,tipo,monto,fecha',
      );
    for (final row in sampleMovimientos) {
      buffer.writeln(
        '${row['id']},${row['negocio_id']},${row['cliente_id']},'
        '"${row['cliente_nombre']}","${row['cliente_telefono']}",'
        '${row['tipo']},${row['monto']},${row['fecha']}',
      );
    }
    return buffer.toString();
  }

  String get markdown =>
      '''
# Client Identity Integrity Audit

- database: `$dbPath`
- schema movimientos.cliente_id: $schemaHasMovimientoClienteId
- movimientos sin cliente_id: $movimientosSinClienteId
- pagos sin cliente_id: $pagosSinClienteId
- movimientos huerfanos: $movimientosHuerfanos
- ciclos huerfanos: $ciclosHuerfanos
- scores huerfanos: $scoresHuerfanos
- recomendaciones por telefono: $recomendacionesPorTelefono
- comprobantes sin movimiento: $comprobantesSinMovimiento

## Sample Movimientos

| id | negocio_id | cliente_id | cliente | telefono | tipo | monto | fecha |
| --- | --- | --- | --- | --- | --- | --- | --- |
${sampleMovimientos.map((row) => '| ${row['id']} | ${row['negocio_id']} | ${row['cliente_id']} | ${row['cliente_nombre']} | ${row['cliente_telefono']} | ${row['tipo']} | ${row['monto']} | ${row['fecha']} |').join('\n')}
''';
}
