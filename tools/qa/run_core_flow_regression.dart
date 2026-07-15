import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = _stringOption(args, 'db') ?? 'qa_data/core_flow_regression.db';
  final file = File(dbPath);
  if (await file.exists()) await file.delete();
  await file.parent.create(recursive: true);

  final db = await databaseFactory.openDatabase(
    file.absolute.path,
    options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onCreate: _createSchema,
    ),
  );

  try {
    final report = await _runRegression(db, file.absolute.path);
    stdout.write(report.consoleOutput);
    await File('CORE_FLOW_REGRESSION_REPORT.md').writeAsString(report.markdown);
    stdout.writeln('Wrote CORE_FLOW_REGRESSION_REPORT.md');
    if (report.failed > 0) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<_RegressionReport> _runRegression(Database db, String dbPath) async {
  final now = DateTime.now().toIso8601String();
  final checks = <_FlowCheck>[];

  final negocio1 = await db.insert(DatabaseSchema.usuariosTable, {
    'nombre': 'Negocio QA 1',
    'telefono': '8090000001',
    'tipo_usuario': 'negocio',
    'password_hash': 'qa',
    'activo': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'synced',
  });
  final negocio2 = await db.insert(DatabaseSchema.usuariosTable, {
    'nombre': 'Negocio QA 2',
    'telefono': '8090000002',
    'tipo_usuario': 'negocio',
    'password_hash': 'qa',
    'activo': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'synced',
  });
  final colaborador = await db.insert(DatabaseSchema.usuariosTable, {
    'nombre': 'Colaborador QA',
    'telefono': '8090000003',
    'tipo_usuario': 'colaborador',
    'negocio_id': negocio1,
    'password_hash': 'qa',
    'activo': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'synced',
  });

  final cliente = await db.insert(DatabaseSchema.clientesTable, {
    'negocio_id': negocio1,
    'nombre': 'Cliente QA',
    'telefono': '8091111111',
    'deuda': 0.0,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.clientesTable, {
    'negocio_id': negocio2,
    'nombre': 'Cliente QA',
    'telefono': '8091111111',
    'deuda': 0.0,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });

  final producto = await db.insert(DatabaseSchema.productosTable, {
    'negocio_id': negocio1,
    'nombre': 'Producto QA',
    'categoria': 'QA',
    'cantidad': 10,
    'costo_unitario': 100.0,
    'precio_venta': 130.0,
    'porcentaje_ganancia': 30.0,
    'stock_minimo': 2,
    'codigo_referencia': 'P-QA-1',
    'activo': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });

  final movimiento = await db.insert(DatabaseSchema.movimientosTable, {
    'negocio_id': negocio1,
    'cliente_id': cliente,
    'cliente_nombre': 'Cliente QA',
    'cliente_telefono': '8091111111',
    'cliente_nombre_snapshot': 'Cliente QA',
    'cliente_telefono_snapshot': '8091111111',
    'tipo': 'deuda',
    'monto': 260.0,
    'concepto': 'Fiado QA',
    'fecha': now,
    'created_at': now,
    'updated_at': now,
    'is_active': 1,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.deudaItemsTable, {
    'negocio_id': negocio1,
    'movimiento_id': movimiento,
    'producto_id': producto,
    'nombre_producto': 'Producto QA',
    'codigo_referencia': 'P-QA-1',
    'cantidad': 2,
    'precio_unitario': 130.0,
    'subtotal': 260.0,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.comprobantesTable, {
    'negocio_id': negocio1,
    'tipo': 'deuda',
    'movimiento_id': movimiento,
    'cliente_nombre': 'Cliente QA',
    'cliente_telefono': '8091111111',
    'negocio_nombre': 'Negocio QA 1',
    'codigo_comprobante': 'QA-0001',
    'fecha': now,
    'subtotal': 260.0,
    'total': 260.0,
    'payload_json': '{}',
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.creditoCiclosTable, {
    'negocio_id': negocio1,
    'cliente_id': cliente,
    'fecha_inicio': now,
    'fecha_limite_30': now,
    'fecha_limite_45': now,
    'fecha_bloqueo_60': now,
    'estado': 'activo',
    'monto_total': 260.0,
    'monto_pagado': 0.0,
    'saldo_pendiente': 260.0,
    'bloqueado': 0,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.clientScoresTable, {
    'negocio_id': negocio1,
    'cliente_id': cliente,
    'score': 55,
    'risk_level': 'Riesgo medio',
    'suggested_credit_limit': 500.0,
    'last_calculated_at': now,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });
  await db.insert(DatabaseSchema.solicitudesAutorizacionTable, {
    'negocio_id': negocio1,
    'colaborador_id': colaborador,
    'tipo_solicitud': 'editar_producto',
    'entidad': 'productos',
    'entidad_id': producto,
    'datos_despues': '{}',
    'estado': 'pendiente',
    'created_at': now,
    'updated_at': now,
    'sync_status': 'pending',
  });

  await db.update(
    DatabaseSchema.clientesTable,
    {
      'nombre': 'Cliente QA Editado',
      'telefono': '8092222222',
      'updated_at': now,
      'sync_status': 'updated',
    },
    where: 'id = ? AND negocio_id = ?',
    whereArgs: [cliente, negocio1],
  );

  checks.add(
    await _expectCount(
      db,
      'Editar cliente mantiene movimientos enlazados por cliente_id',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.movimientosTable}
WHERE negocio_id = ? AND cliente_id = ? AND cliente_nombre_snapshot = ?
''',
      [negocio1, cliente, 'Cliente QA'],
      1,
    ),
  );
  checks.add(
    await _expectCount(
      db,
      'Cliente editado no contamina negocio 2 con mismo telefono original',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.clientesTable}
WHERE negocio_id = ? AND telefono = ?
''',
      [negocio2, '8091111111'],
      1,
    ),
  );
  checks.add(
    await _expectCount(
      db,
      'Deuda con articulos conserva movimiento_id',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.deudaItemsTable}
WHERE negocio_id = ? AND movimiento_id = ? AND producto_id = ?
''',
      [negocio1, movimiento, producto],
      1,
    ),
  );
  checks.add(
    await _expectCount(
      db,
      'Comprobante conserva movimiento_id',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.comprobantesTable}
WHERE negocio_id = ? AND movimiento_id = ?
''',
      [negocio1, movimiento],
      1,
    ),
  );
  checks.add(
    await _expectCount(
      db,
      'Score usa cliente_id estable',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.clientScoresTable}
WHERE negocio_id = ? AND cliente_id = ?
''',
      [negocio1, cliente],
      1,
    ),
  );
  checks.add(
    await _expectCount(
      db,
      'Colaborador queda aislado a su negocio',
      '''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.usuariosTable}
WHERE id = ? AND negocio_id = ? AND tipo_usuario = 'colaborador'
''',
      [colaborador, negocio1],
      1,
    ),
  );

  return _RegressionReport(dbPath: dbPath, checks: checks);
}

Future<_FlowCheck> _expectCount(
  Database db,
  String label,
  String sql,
  List<Object?> args,
  int expected,
) async {
  final actual = _firstInt(await db.rawQuery(sql, args));
  return _FlowCheck(
    label: label,
    expected: expected,
    actual: actual,
    passed: actual == expected,
  );
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createClientesTable);
  await db.execute(DatabaseSchema.createProductosTable);
  await db.execute(DatabaseSchema.createMovimientosTable);
  await db.execute(DatabaseSchema.createDeudaItemsTable);
  await db.execute(DatabaseSchema.createComprobantesTable);
  await db.execute(DatabaseSchema.createCreditoCiclosTable);
  await db.execute(DatabaseSchema.createClientScoresTable);
  await db.execute(DatabaseSchema.createSolicitudesAutorizacionTable);
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

class _FlowCheck {
  final String label;
  final int expected;
  final int actual;
  final bool passed;

  const _FlowCheck({
    required this.label,
    required this.expected,
    required this.actual,
    required this.passed,
  });
}

class _RegressionReport {
  final String dbPath;
  final List<_FlowCheck> checks;

  const _RegressionReport({required this.dbPath, required this.checks});

  int get failed => checks.where((check) => !check.passed).length;

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('CORE_FLOW_REGRESSION')
      ..writeln('database: $dbPath')
      ..writeln('failed: $failed')
      ..writeln('check,expected,actual,status');
    for (final check in checks) {
      buffer.writeln(
        '"${check.label}",${check.expected},${check.actual},${check.passed ? 'OK' : 'FAIL'}',
      );
    }
    return buffer.toString();
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# Core Flow Regression Report')
      ..writeln()
      ..writeln('- Database: `$dbPath`')
      ..writeln('- Failed checks: $failed')
      ..writeln()
      ..writeln('| Check | Expected | Actual | Status |')
      ..writeln('| --- | ---: | ---: | --- |');
    for (final check in checks) {
      buffer.writeln(
        '| ${check.label} | ${check.expected} | ${check.actual} | ${check.passed ? 'OK' : 'FAIL'} |',
      );
    }
    return buffer.toString();
  }
}
