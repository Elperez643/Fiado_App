import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

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
    await File(
      'MULTI_BUSINESS_ISOLATION_AUDIT.md',
    ).writeAsString(report.markdown);
    stdout.writeln('Wrote MULTI_BUSINESS_ISOLATION_AUDIT.md');
    if (report.criticalIssues > 0) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<_IsolationReport> _audit(
  Database db,
  String dbPath,
  bool createdQaDb,
) async {
  final checks = <_IsolationCheck>[
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
    await _countCheck(db, 'movimientos sin negocio_id', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable}
WHERE negocio_id IS NULL OR negocio_id = 0
'''),
    await _countCheck(db, 'deuda_items con negocio distinto al movimiento', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.deudaItemsTable} di
JOIN ${DatabaseSchema.movimientosTable} m ON m.id = di.movimiento_id
WHERE di.negocio_id IS NULL
   OR m.negocio_id IS NULL
   OR di.negocio_id != m.negocio_id
'''),
    await _countCheck(db, 'deuda_items con producto de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.deudaItemsTable} di
JOIN ${DatabaseSchema.productosTable} p ON p.id = di.producto_id
WHERE di.producto_id IS NOT NULL
  AND di.negocio_id != p.negocio_id
'''),
    await _countCheck(db, 'comprobantes con negocio distinto al movimiento', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.comprobantesTable} c
JOIN ${DatabaseSchema.movimientosTable} m ON m.id = c.movimiento_id
WHERE c.negocio_id IS NULL
   OR m.negocio_id IS NULL
   OR c.negocio_id != m.negocio_id
'''),
    await _countCheck(db, 'ciclos con cliente de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.creditoCiclosTable} cc
JOIN ${DatabaseSchema.clientesTable} c ON c.id = cc.cliente_id
WHERE cc.negocio_id != c.negocio_id
'''),
    await _countCheck(db, 'client_scores con cliente de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.clientScoresTable} cs
JOIN ${DatabaseSchema.clientesTable} c ON c.id = cs.cliente_id
WHERE cs.negocio_id != c.negocio_id
'''),
    await _countCheck(db, 'imagenes con producto de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.productoImagenesTable} pi
JOIN ${DatabaseSchema.productosTable} p ON p.id = pi.producto_id
WHERE pi.negocio_id != p.negocio_id
'''),
    await _countCheck(db, 'metricas con producto de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.inventoryProductMetricsTable} ipm
JOIN ${DatabaseSchema.productosTable} p ON p.id = ipm.producto_id
WHERE ipm.negocio_id != p.negocio_id
'''),
    await _countCheck(db, 'colaboradores sin negocio asignado', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.usuariosTable}
WHERE tipo_usuario = 'colaborador'
  AND (negocio_id IS NULL OR negocio_id = 0)
  AND activo = 1
'''),
    await _countCheck(db, 'solicitudes con colaborador de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.solicitudesAutorizacionTable} s
JOIN ${DatabaseSchema.usuariosTable} u ON u.id = s.colaborador_id
WHERE u.negocio_id != s.negocio_id
'''),
    await _countCheck(db, 'auditorias con colaborador de otro negocio', '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.auditoriasTable} a
JOIN ${DatabaseSchema.usuariosTable} u ON u.id = a.colaborador_id
WHERE a.colaborador_id IS NOT NULL
  AND u.negocio_id != a.negocio_id
'''),
  ];

  final businessBreakdown = await _safeRows(db, '''
SELECT u.id AS negocio_id,
       u.nombre AS negocio,
       (SELECT COUNT(*) FROM ${DatabaseSchema.clientesTable} c WHERE c.negocio_id = u.id) AS clientes,
       (SELECT COUNT(*) FROM ${DatabaseSchema.productosTable} p WHERE p.negocio_id = u.id AND p.activo = 1) AS productos,
       (SELECT COUNT(*) FROM ${DatabaseSchema.movimientosTable} m WHERE m.negocio_id = u.id AND COALESCE(m.is_active, 1) = 1) AS movimientos
FROM ${DatabaseSchema.usuariosTable} u
WHERE u.tipo_usuario = 'negocio'
ORDER BY u.id
''');

  return _IsolationReport(
    dbPath: dbPath,
    createdQaDb: createdQaDb,
    checks: checks,
    businessBreakdown: businessBreakdown,
  );
}

Future<_IsolationCheck> _countCheck(
  Database db,
  String label,
  String sql,
) async {
  for (final table in _tablesInSql(sql)) {
    if (!await _tableExists(db, table)) {
      return _IsolationCheck(label, 0, 'SKIP', 'Tabla $table no existe.');
    }
  }
  final count = _firstInt(await db.rawQuery(sql));
  return _IsolationCheck(
    label,
    count,
    count == 0 ? 'OK' : 'CRITICAL',
    count == 0 ? 'Sin fuga detectada.' : 'Se encontraron $count filas.',
  );
}

Future<List<Map<String, Object?>>> _safeRows(Database db, String sql) async {
  for (final table in _tablesInSql(sql)) {
    if (!await _tableExists(db, table)) return const [];
  }
  return db.rawQuery(sql);
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = [
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    'qa_data/multi_business_isolation.db',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return 'qa_data/multi_business_isolation.db';
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
  await db.execute(DatabaseSchema.createClientScoresTable);
  await db.execute(DatabaseSchema.createSolicitudesAutorizacionTable);
  await db.execute(DatabaseSchema.createAuditoriasTable);
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

class _IsolationCheck {
  final String label;
  final int count;
  final String status;
  final String detail;

  const _IsolationCheck(this.label, this.count, this.status, this.detail);

  bool get critical => status == 'CRITICAL';
}

class _IsolationReport {
  final String dbPath;
  final bool createdQaDb;
  final List<_IsolationCheck> checks;
  final List<Map<String, Object?>> businessBreakdown;

  const _IsolationReport({
    required this.dbPath,
    required this.createdQaDb,
    required this.checks,
    required this.businessBreakdown,
  });

  int get criticalIssues => checks.where((check) => check.critical).length;

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('MULTI_BUSINESS_ISOLATION_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('created_qa_db: $createdQaDb')
      ..writeln('critical_issues: $criticalIssues')
      ..writeln('check,status,count,detail');
    for (final check in checks) {
      buffer.writeln(
        '"${check.label}",${check.status},${check.count},"${check.detail}"',
      );
    }
    buffer
      ..writeln()
      ..writeln('business_breakdown')
      ..writeln('negocio_id,negocio,clientes,productos,movimientos');
    for (final row in businessBreakdown) {
      buffer.writeln(
        '${row['negocio_id']},"${row['negocio']}",${row['clientes']},${row['productos']},${row['movimientos']}',
      );
    }
    return buffer.toString();
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# Multi-Business Isolation Audit')
      ..writeln()
      ..writeln('- Database: `$dbPath`')
      ..writeln('- Created QA DB: $createdQaDb')
      ..writeln('- Critical issues: $criticalIssues')
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
      ..writeln('## Business Breakdown')
      ..writeln()
      ..writeln('| negocio_id | negocio | clientes | productos | movimientos |')
      ..writeln('| ---: | --- | ---: | ---: | ---: |');
    for (final row in businessBreakdown) {
      buffer.writeln(
        '| ${row['negocio_id']} | ${row['negocio']} | ${row['clientes']} | ${row['productos']} | ${row['movimientos']} |',
      );
    }
    return buffer.toString();
  }
}
