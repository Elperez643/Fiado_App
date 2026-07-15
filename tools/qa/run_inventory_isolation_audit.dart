import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await _resolveDatabasePath(args);
  final file = File(dbPath);
  if (!await file.exists()) {
    stderr.writeln('No se encontro la base SQLite: ${file.absolute.path}');
    stderr.writeln(
      'Usa: dart run tools/qa/run_inventory_isolation_audit.dart --db RUTA',
    );
    exitCode = 1;
    return;
  }

  final db = await databaseFactory.openDatabase(file.absolute.path);
  try {
    final report = await _audit(db, file.absolute.path);
    stdout.write(report.consoleOutput);
    await File('INVENTORY_ISOLATION_AUDIT.md').writeAsString(report.markdown);
    stdout.writeln('Wrote INVENTORY_ISOLATION_AUDIT.md');
    if (report.globalProducts > 0 ||
        report.orphanImages > 0 ||
        report.orphanMetrics > 0) {
      exitCode = 2;
    }
  } finally {
    await db.close();
  }
}

Future<_InventoryIsolationReport> _audit(Database db, String dbPath) async {
  final users = await db.rawQuery('''
SELECT id, nombre, telefono, tipo_usuario, negocio_id, activo
FROM ${DatabaseSchema.usuariosTable}
ORDER BY tipo_usuario, id
''');

  final totalProducts = _firstInt(
    await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable}',
    ),
  );
  final activeProducts = _firstInt(
    await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable} WHERE activo = 1',
    ),
  );
  final globalProducts = _firstInt(
    await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable} WHERE negocio_id IS NULL OR negocio_id = 0',
    ),
  );
  final productsByBusiness = await db.rawQuery('''
SELECT COALESCE(CAST(negocio_id AS TEXT), 'NULL') AS negocio_id,
       COUNT(*) AS total,
       SUM(CASE WHEN activo = 1 THEN 1 ELSE 0 END) AS activos
FROM ${DatabaseSchema.productosTable}
GROUP BY negocio_id
ORDER BY negocio_id
''');
  final productsByVisibleBusiness = await db.rawQuery('''
SELECT u.id AS negocio_id,
       u.nombre AS negocio,
       COUNT(p.id) AS productos_visibles
FROM ${DatabaseSchema.usuariosTable} u
LEFT JOIN ${DatabaseSchema.productosTable} p
  ON p.negocio_id = u.id AND p.activo = 1
WHERE u.tipo_usuario = 'negocio'
GROUP BY u.id, u.nombre
ORDER BY u.id
''');
  final collaboratorsByBusiness = await db.rawQuery('''
SELECT negocio_id, COUNT(*) AS colaboradores
FROM ${DatabaseSchema.usuariosTable}
WHERE tipo_usuario = 'colaborador'
GROUP BY negocio_id
ORDER BY negocio_id
''');
  final orphanImages = _firstInt(
    await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.productoImagenesTable} pi
LEFT JOIN ${DatabaseSchema.productosTable} p
  ON p.id = pi.producto_id AND p.negocio_id = pi.negocio_id
WHERE p.id IS NULL
'''),
  );
  final orphanMetrics = _firstInt(
    await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.inventoryProductMetricsTable} m
LEFT JOIN ${DatabaseSchema.productosTable} p
  ON p.id = m.producto_id AND p.negocio_id = m.negocio_id
WHERE p.id IS NULL
'''),
  );
  final productQueue = await db.rawQuery(
    '''
SELECT entity_type, status, COUNT(*) AS total
FROM ${DatabaseSchema.syncQueueTable}
WHERE entity_type IN (?, ?)
GROUP BY entity_type, status
ORDER BY entity_type, status
''',
    [DatabaseSchema.productosTable, DatabaseSchema.productoImagenesTable],
  );
  final globalRows = await db.rawQuery('''
SELECT id, nombre, codigo_referencia, negocio_id, activo, created_at
FROM ${DatabaseSchema.productosTable}
WHERE negocio_id IS NULL OR negocio_id = 0
ORDER BY id
LIMIT 100
''');

  return _InventoryIsolationReport(
    dbPath: dbPath,
    users: users,
    totalProducts: totalProducts,
    activeProducts: activeProducts,
    globalProducts: globalProducts,
    productsByBusiness: productsByBusiness,
    productsByVisibleBusiness: productsByVisibleBusiness,
    collaboratorsByBusiness: collaboratorsByBusiness,
    orphanImages: orphanImages,
    orphanMetrics: orphanMetrics,
    productQueue: productQueue,
    globalRows: globalRows,
  );
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = <String>[
    DatabaseSchema.databaseName,
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return candidates.last;
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

class _InventoryIsolationReport {
  final String dbPath;
  final List<Map<String, Object?>> users;
  final int totalProducts;
  final int activeProducts;
  final int globalProducts;
  final List<Map<String, Object?>> productsByBusiness;
  final List<Map<String, Object?>> productsByVisibleBusiness;
  final List<Map<String, Object?>> collaboratorsByBusiness;
  final int orphanImages;
  final int orphanMetrics;
  final List<Map<String, Object?>> productQueue;
  final List<Map<String, Object?>> globalRows;

  const _InventoryIsolationReport({
    required this.dbPath,
    required this.users,
    required this.totalProducts,
    required this.activeProducts,
    required this.globalProducts,
    required this.productsByBusiness,
    required this.productsByVisibleBusiness,
    required this.collaboratorsByBusiness,
    required this.orphanImages,
    required this.orphanMetrics,
    required this.productQueue,
    required this.globalRows,
  });

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('INVENTORY_ISOLATION_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('total_productos: $totalProducts')
      ..writeln('productos_activos: $activeProducts')
      ..writeln('productos_negocio_null_0: $globalProducts')
      ..writeln('imagenes_huerfanas: $orphanImages')
      ..writeln('metricas_huerfanas: $orphanMetrics')
      ..writeln('')
      ..writeln('productos_por_negocio_id');
    for (final row in productsByBusiness) {
      buffer.writeln(
        '${row['negocio_id']}: total=${row['total']}, activos=${row['activos']}',
      );
    }
    buffer
      ..writeln('')
      ..writeln('productos_visibles_por_negocio');
    for (final row in productsByVisibleBusiness) {
      buffer.writeln(
        '${row['negocio_id']} ${row['negocio']}: ${row['productos_visibles']}',
      );
    }
    buffer
      ..writeln('')
      ..writeln('colaboradores_por_negocio');
    for (final row in collaboratorsByBusiness) {
      buffer.writeln('${row['negocio_id']}: ${row['colaboradores']}');
    }
    if (globalRows.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('productos_globales_muestra');
      for (final row in globalRows) {
        buffer.writeln(
          'id=${row['id']}, nombre=${row['nombre']}, codigo=${row['codigo_referencia']}, negocio_id=${row['negocio_id']}, activo=${row['activo']}',
        );
      }
    }
    return buffer.toString();
  }

  String get markdown {
    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer()
      ..writeln('# Inventory Isolation Audit')
      ..writeln()
      ..writeln('- Fecha: $now')
      ..writeln('- Base SQLite: `$dbPath`')
      ..writeln('- Total productos: $totalProducts')
      ..writeln('- Productos activos: $activeProducts')
      ..writeln('- Productos con `negocio_id` null/0: $globalProducts')
      ..writeln('- Imagenes huerfanas: $orphanImages')
      ..writeln('- Metricas huerfanas: $orphanMetrics')
      ..writeln()
      ..writeln('## Regla')
      ..writeln()
      ..writeln(
        'Los productos no son globales. Cada producto pertenece exclusivamente a un negocio.',
      )
      ..writeln()
      ..writeln('## Productos Por Negocio')
      ..writeln()
      ..writeln('| negocio_id | total | activos |')
      ..writeln('| --- | ---: | ---: |');
    for (final row in productsByBusiness) {
      buffer.writeln(
        '| `${row['negocio_id']}` | ${row['total']} | ${row['activos']} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Visibilidad Por Negocio')
      ..writeln()
      ..writeln('| negocio_id | negocio | productos visibles |')
      ..writeln('| ---: | --- | ---: |');
    for (final row in productsByVisibleBusiness) {
      buffer.writeln(
        '| ${row['negocio_id']} | ${_md(row['negocio'])} | ${row['productos_visibles']} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Productos Globales Detectados')
      ..writeln()
      ..writeln('| id | nombre | codigo | negocio_id | activo |')
      ..writeln('| ---: | --- | --- | --- | ---: |');
    if (globalRows.isEmpty) {
      buffer.writeln('| - | ninguno | - | - | - |');
    } else {
      for (final row in globalRows) {
        buffer.writeln(
          '| ${row['id']} | ${_md(row['nombre'])} | ${_md(row['codigo_referencia'])} | ${_md(row['negocio_id'])} | ${row['activo']} |',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## Sync Queue Productos')
      ..writeln()
      ..writeln('| entity_type | status | total |')
      ..writeln('| --- | --- | ---: |');
    if (productQueue.isEmpty) {
      buffer.writeln('| ninguno | - | 0 |');
    } else {
      for (final row in productQueue) {
        buffer.writeln(
          '| `${row['entity_type']}` | `${row['status']}` | ${row['total']} |',
        );
      }
    }
    return buffer.toString();
  }

  static String _md(Object? value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return '-';
    return text.replaceAll('|', '\\|').replaceAll('\n', ' ');
  }
}
