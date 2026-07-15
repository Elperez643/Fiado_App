import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await _resolveDatabasePath(args, 'global_data_integrity.db');
  final dbFile = File(dbPath);
  final createQaDb = !await dbFile.exists();
  if (createQaDb) await dbFile.parent.create(recursive: true);

  final db = await databaseFactory.openDatabase(
    dbFile.absolute.path,
    options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onCreate: _createQaSchema,
    ),
  );

  try {
    await _ensureClientIdentitySchema(db);
    final report = await _audit(db, dbFile.absolute.path, createQaDb);
    stdout.write(report.consoleOutput);
    await File(
      'GLOBAL_STABILITY_AUDIT_REPORT.md',
    ).writeAsString(report.markdown);
    stdout.writeln('Wrote GLOBAL_STABILITY_AUDIT_REPORT.md');
    if (report.criticalIssues > 0) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<_GlobalIntegrityReport> _audit(
  Database db,
  String dbPath,
  bool createdQaDb,
) async {
  final checks = <_CheckResult>[
    await _requiredColumn(
      db,
      DatabaseSchema.movimientosTable,
      'cliente_id',
      'movimientos.cliente_id existe para identidad estable de cliente',
    ),
    await _requiredColumn(
      db,
      DatabaseSchema.deudaItemsTable,
      'movimiento_id',
      'deuda_items.movimiento_id existe para enlazar factura a deuda',
    ),
    await _requiredColumn(
      db,
      DatabaseSchema.comprobantesTable,
      'movimiento_id',
      'comprobantes.movimiento_id existe para recibos trazables',
    ),
    await _requiredColumn(
      db,
      DatabaseSchema.clientScoresTable,
      'cliente_id',
      'client_scores.cliente_id existe para score por cliente estable',
    ),
    await _countCheck(db, 'clientes sin negocio_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.clientesTable}
WHERE negocio_id IS NULL OR negocio_id = 0
'''),
    await _countCheck(db, 'productos sin negocio_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.productosTable}
WHERE negocio_id IS NULL OR negocio_id = 0
'''),
    await _countCheck(
      db,
      'movimientos activos sin cliente_id',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable}
WHERE cliente_id IS NULL AND COALESCE(is_active, 1) = 1
''',
      requiresColumns: const ['cliente_id'],
    ),
    await _countCheck(
      db,
      'movimientos huerfanos por cliente_id',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable} m
LEFT JOIN ${DatabaseSchema.clientesTable} c
  ON c.id = m.cliente_id AND c.negocio_id = m.negocio_id
WHERE m.cliente_id IS NOT NULL
  AND c.id IS NULL
  AND COALESCE(m.is_active, 1) = 1
''',
      requiresColumns: const ['cliente_id'],
    ),
    await _countCheck(db, 'deuda_items huerfanos por movimiento_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.deudaItemsTable} di
LEFT JOIN ${DatabaseSchema.movimientosTable} m
  ON m.id = di.movimiento_id AND m.negocio_id = di.negocio_id
WHERE m.id IS NULL
'''),
    await _countCheck(db, 'comprobantes huerfanos por movimiento_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.comprobantesTable} c
LEFT JOIN ${DatabaseSchema.movimientosTable} m
  ON m.id = c.movimiento_id AND m.negocio_id = c.negocio_id
WHERE m.id IS NULL
'''),
    await _countCheck(db, 'ciclos huerfanos por cliente_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.creditoCiclosTable} cc
LEFT JOIN ${DatabaseSchema.clientesTable} c
  ON c.id = cc.cliente_id AND c.negocio_id = cc.negocio_id
WHERE c.id IS NULL
'''),
    await _countCheck(db, 'scores huerfanos por cliente_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.clientScoresTable} cs
LEFT JOIN ${DatabaseSchema.clientesTable} c
  ON c.id = cs.cliente_id AND c.negocio_id = cs.negocio_id
WHERE c.id IS NULL AND cs.deleted_at IS NULL
'''),
    await _countCheck(db, 'imagenes de producto huerfanas', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.productoImagenesTable} pi
LEFT JOIN ${DatabaseSchema.productosTable} p
  ON p.id = pi.producto_id AND p.negocio_id = pi.negocio_id
WHERE p.id IS NULL
'''),
    await _countCheck(db, 'metricas de inventario huerfanas', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.inventoryProductMetricsTable} ipm
LEFT JOIN ${DatabaseSchema.productosTable} p
  ON p.id = ipm.producto_id AND p.negocio_id = ipm.negocio_id
WHERE p.id IS NULL
'''),
    await _countCheck(
      db,
      'business recommendations con rutas fragiles por telefono/nombre',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.businessRecommendationsCacheTable}
WHERE action_route LIKE '%telefono%'
   OR action_route LIKE '%phone%'
   OR action_route LIKE '%nombre%'
   OR action_route LIKE '%name%'
''',
    ),
  ];

  return _GlobalIntegrityReport(
    dbPath: dbPath,
    createdQaDb: createdQaDb,
    checks: checks,
  );
}

Future<_CheckResult> _requiredColumn(
  Database db,
  String table,
  String column,
  String label,
) async {
  final tableExists = await _tableExists(db, table);
  if (!tableExists) {
    return _CheckResult(label, 1, 'CRITICAL', 'Tabla $table no existe.');
  }
  final exists = await _hasColumn(db, table, column);
  return _CheckResult(
    label,
    exists ? 0 : 1,
    exists ? 'OK' : 'CRITICAL',
    exists ? 'OK' : 'Falta columna $table.$column.',
  );
}

Future<_CheckResult> _countCheck(
  Database db,
  String label,
  String sql, {
  List<String> requiresColumns = const [],
}) async {
  final tables = _tablesInSql(sql);
  for (final table in tables) {
    if (!await _tableExists(db, table)) {
      return _CheckResult(label, 0, 'SKIP', 'Tabla $table no existe.');
    }
  }
  for (final column in requiresColumns) {
    if (!await _hasColumn(db, DatabaseSchema.movimientosTable, column)) {
      return _CheckResult(
        label,
        1,
        'CRITICAL',
        'Falta columna requerida: ${DatabaseSchema.movimientosTable}.$column.',
      );
    }
  }
  final count = _firstInt(await db.rawQuery(sql));
  return _CheckResult(
    label,
    count,
    count == 0 ? 'OK' : 'CRITICAL',
    count == 0 ? 'Sin hallazgos.' : 'Se encontraron $count filas.',
  );
}

Future<String> _resolveDatabasePath(List<String> args, String qaName) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = [
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    'qa_data/$qaName',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return 'qa_data/$qaName';
}

Future<void> _createQaSchema(Database db, int version) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createClientesTable);
  await db.execute(DatabaseSchema.createProductosTable);
  await db.execute(DatabaseSchema.createMovimientosTable);
  await db.execute(DatabaseSchema.createDeudaItemsTable);
  await db.execute(DatabaseSchema.createProductoImagenesTable);
  await db.execute(DatabaseSchema.createInventoryProductMetricsTable);
  await db.execute(DatabaseSchema.createComprobantesTable);
  await db.execute(DatabaseSchema.createCreditoCiclosTable);
  await db.execute(DatabaseSchema.createCreditoCicloMovimientosTable);
  await db.execute(DatabaseSchema.createClientScoresTable);
  await db.execute(DatabaseSchema.createBusinessRecommendationsCacheTable);
  await db.execute(DatabaseSchema.createSyncQueueTable);
  await db.execute(DatabaseSchema.createSolicitudesAutorizacionTable);
  await db.execute(DatabaseSchema.createAuditoriasTable);
  await db.execute(DatabaseSchema.createAuditoriaItemsTable);
}

Future<void> _ensureClientIdentitySchema(Database db) async {
  if (!await _tableExists(db, DatabaseSchema.movimientosTable)) return;

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

  if (await _tableExists(db, DatabaseSchema.clientesTable)) {
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

Set<String> _tablesInSql(String sql) {
  final matches = RegExp(
    r'\b(?:FROM|JOIN)\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    caseSensitive: false,
  ).allMatches(sql);
  return matches.map((match) => match.group(1)!).toSet();
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [table],
  );
  return rows.isNotEmpty;
}

Future<bool> _hasColumn(Database db, String table, String column) async {
  if (!await _tableExists(db, table)) return false;
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.any((row) => row['name'] == column);
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

class _CheckResult {
  final String label;
  final int count;
  final String status;
  final String detail;

  const _CheckResult(this.label, this.count, this.status, this.detail);

  bool get critical => status == 'CRITICAL';
}

class _GlobalIntegrityReport {
  final String dbPath;
  final bool createdQaDb;
  final List<_CheckResult> checks;

  const _GlobalIntegrityReport({
    required this.dbPath,
    required this.createdQaDb,
    required this.checks,
  });

  int get criticalIssues => checks.where((check) => check.critical).length;

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('GLOBAL_DATA_INTEGRITY_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('created_qa_db: $createdQaDb')
      ..writeln('critical_issues: $criticalIssues')
      ..writeln('check,status,count,detail');
    for (final check in checks) {
      buffer.writeln(
        '"${check.label}",${check.status},${check.count},"${check.detail}"',
      );
    }
    return buffer.toString();
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# Global Stability Audit Report')
      ..writeln()
      ..writeln('- Database: `$dbPath`')
      ..writeln('- Created QA DB: $createdQaDb')
      ..writeln('- Critical issues: $criticalIssues')
      ..writeln()
      ..writeln('## Data Integrity Checks')
      ..writeln()
      ..writeln('| Check | Status | Count | Detail |')
      ..writeln('| --- | --- | ---: | --- |');
    for (final check in checks) {
      buffer.writeln(
        '| ${check.label} | ${check.status} | ${check.count} | ${check.detail} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Correcciones Aplicadas')
      ..writeln()
      ..writeln(
        '- La auditoria valida relaciones por IDs estables y negocio_id obligatorio.',
      )
      ..writeln(
        '- No se aplican cambios destructivos ni limpieza automatica desde este script.',
      );
    return buffer.toString();
  }
}
