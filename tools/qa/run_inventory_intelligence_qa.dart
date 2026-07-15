import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final results = <_Result>[];
  for (final products in [1000, 10000, 50000]) {
    stdout.writeln(
      'Running inventory intelligence cache QA: $products products',
    );
    final file = File('qa_data/inventory_intelligence_cache_$products.db');
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();

    final db = await databaseFactory.openDatabase(file.absolute.path);
    try {
      await _createSchema(db);
      await _seed(db, products);
      final initialMs = await _time(() => _recalculateAll(db, products));
      final oneMs = await _time(() => _recalculateProduct(db, 1));
      final hundredMs = await _time(() async {
        for (var i = 1; i <= 100; i++) {
          await _recalculateProduct(db, i);
        }
      });
      final cacheMs = await _time(() async {
        await db.query(
          DatabaseSchema.inventoryProductMetricsTable,
          where: 'negocio_id = ?',
          whereArgs: [1],
          limit: 200,
        );
      });
      final dashboardMs = await _time(() async {
        await db.rawQuery('''
SELECT
  SUM(inventory_cost_value) AS cost,
  SUM(inventory_sale_value) AS sale,
  SUM(potential_profit) AS profit,
  SUM(recommended_restock_quantity) AS restock,
  SUM(CASE WHEN status = 'critico' THEN 1 ELSE 0 END) AS critical,
  SUM(CASE WHEN status = 'sin_movimiento' THEN 1 ELSE 0 END) AS no_movement
FROM ${DatabaseSchema.inventoryProductMetricsTable}
WHERE negocio_id = 1
''');
      });
      final sizeMb = (await file.length()) / (1024 * 1024);
      final result = _Result(
        products: products,
        initialMs: initialMs,
        oneMs: oneMs,
        hundredMs: hundredMs,
        cacheMs: cacheMs,
        dashboardMs: dashboardMs,
        dbMb: sizeMb,
      );
      results.add(result);
      stdout.writeln(result.toLog());
    } finally {
      await db.close();
    }
  }
  await _writeReport(results);
}

Future<void> _createSchema(Database db) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createProductosTable);
  await db.execute(DatabaseSchema.createMovimientosTable);
  await db.execute(DatabaseSchema.createDeudaItemsTable);
  await db.execute(DatabaseSchema.createInventoryProductMetricsTable);
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_qa_deuda_producto ON deuda_items(negocio_id, producto_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_qa_metric_status ON inventory_product_metrics(negocio_id, status)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_qa_metric_dirty ON inventory_product_metrics(negocio_id, dirty)',
  );
}

Future<void> _seed(Database db, int products) async {
  final now = DateTime.now();
  await db.insert(DatabaseSchema.usuariosTable, {
    'id': 1,
    'nombre': 'QA Negocio',
    'telefono': '8090000000',
    'tipo_usuario': 'negocio',
    'password_hash': 'qa',
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  });

  var batch = db.batch();
  for (var i = 1; i <= products; i++) {
    batch.insert(DatabaseSchema.productosTable, {
      'id': i,
      'negocio_id': 1,
      'nombre': 'Producto $i',
      'categoria': 'Categoria ${i % 12}',
      'cantidad': i % 17 == 0 ? 0 : (i % 140) + 1,
      'costo_unitario': 40 + (i % 90),
      'precio_compra': 40 + (i % 90),
      'precio_venta': 65 + (i % 120),
      'porcentaje_ganancia': 25,
      'stock_minimo': 12,
      'codigo_referencia': 'SKU-$i',
      'activo': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'legacy_id': 'prod-$i',
      'ubicacion': 'estante-${i % 30}',
    });
    if (i % 1000 == 0) {
      await batch.commit(noResult: true);
      batch = db.batch();
    }
  }
  await batch.commit(noResult: true);

  batch = db.batch();
  for (var i = 1; i <= products * 2; i++) {
    final date = now.subtract(Duration(days: i % 75)).toIso8601String();
    batch.insert(DatabaseSchema.movimientosTable, {
      'id': i,
      'negocio_id': 1,
      'cliente_nombre': 'Cliente ${i % 500}',
      'tipo': 'deuda',
      'monto': 100.0,
      'fecha': date,
      'created_at': date,
      'updated_at': date,
    });
    final productId = (i % products) + 1;
    batch.insert(DatabaseSchema.deudaItemsTable, {
      'negocio_id': 1,
      'movimiento_id': i,
      'producto_id': productId,
      'nombre_producto': 'Producto $productId',
      'cantidad': (i % 3) + 1,
      'precio_unitario': 100.0,
      'subtotal': 100.0,
      'created_at': date,
      'updated_at': date,
    });
    if (i % 1000 == 0) {
      await batch.commit(noResult: true);
      batch = db.batch();
    }
  }
  await batch.commit(noResult: true);
}

Future<void> _recalculateAll(Database db, int products) async {
  const batchSize = 500;
  for (var start = 1; start <= products; start += batchSize) {
    final end = start + batchSize - 1;
    final ids = [for (var i = start; i <= end && i <= products; i++) i];
    await _recalculateMany(db, ids);
  }
}

Future<void> _recalculateProduct(Database db, int productId) {
  return _recalculateMany(db, [productId]);
}

Future<void> _recalculateMany(Database db, List<int> ids) async {
  final placeholders = List.filled(ids.length, '?').join(', ');
  final cutoff = DateTime.now()
      .subtract(const Duration(days: 30))
      .toIso8601String();
  final rows = await db.rawQuery(
    '''
SELECT
  p.*,
  COALESCE(SUM(CASE
    WHEN COALESCE(m.fecha, di.created_at) >= ? THEN di.cantidad
    ELSE 0
  END), 0) AS sold_30,
  MAX(COALESCE(m.fecha, di.created_at)) AS last_movement_at
FROM productos p
LEFT JOIN deuda_items di ON di.producto_id = p.id AND di.deleted_at IS NULL
LEFT JOIN movimientos m ON m.id = di.movimiento_id
WHERE p.negocio_id = 1 AND p.id IN ($placeholders)
GROUP BY p.id
''',
    [cutoff, ...ids],
  );
  final batch = db.batch();
  final now = DateTime.now();
  for (final row in rows) {
    final stock = (row['cantidad'] as num? ?? 0).toInt();
    final min = (row['stock_minimo'] as num? ?? 0).toInt();
    final cost = (row['costo_unitario'] as num? ?? 0).toDouble();
    final sale = (row['precio_venta'] as num? ?? 0).toDouble();
    final sold = (row['sold_30'] as num? ?? 0).toDouble();
    final avg = sold / 30;
    final coverage = avg > 0 ? stock / avg : null;
    final restock = avg > 0 ? ((avg * 15).ceil() - stock).clamp(0, 1 << 31) : 0;
    final last = row['last_movement_at'] == null
        ? null
        : DateTime.tryParse(row['last_movement_at'] as String);
    batch.insert(
      DatabaseSchema.inventoryProductMetricsTable,
      {
        'negocio_id': 1,
        'producto_id': row['id'],
        'product_name': row['nombre'],
        'code_reference': row['codigo_referencia'],
        'category': row['categoria'],
        'location': row['ubicacion'],
        'current_stock': stock,
        'minimum_stock': min,
        'unit_cost': cost,
        'sale_price': sale,
        'profit_margin_percent': row['porcentaje_ganancia'],
        'inventory_cost_value': stock * cost,
        'inventory_sale_value': stock * sale,
        'potential_profit': stock * (sale - cost),
        'sold_quantity_30_days': sold,
        'average_daily_movement': avg,
        'coverage_days': coverage,
        'recommended_restock_quantity': restock,
        'status': _status(stock, min, coverage, last, now),
        'last_movement_at': last?.toIso8601String(),
        'last_calculated_at': now.toIso8601String(),
        'dirty': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  await batch.commit(noResult: true);
}

String _status(
  int stock,
  int minimum,
  double? coverage,
  DateTime? last,
  DateTime now,
) {
  if (stock <= 0) return 'agotado';
  if (coverage != null && coverage <= 3) return 'critico';
  if (stock <= minimum) return 'bajo_stock';
  if (last == null || now.difference(last).inDays >= 30) {
    return 'sin_movimiento';
  }
  if (coverage != null && coverage >= 60 && stock > minimum) {
    return 'sobre_stock';
  }
  return 'normal';
}

Future<int> _time(Future<void> Function() action) async {
  final watch = Stopwatch()..start();
  await action();
  watch.stop();
  return watch.elapsedMilliseconds;
}

Future<void> _writeReport(List<_Result> results) async {
  final buffer = StringBuffer()
    ..writeln('# Inventory Intelligence QA Results')
    ..writeln()
    ..writeln(
      '| Productos | Inicial ms | 1 dirty ms | 100 dirty ms | Cache pantalla ms | Dashboard cache ms | DB MB |',
    )
    ..writeln('| ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (final result in results) {
    buffer.writeln(
      '| ${result.products} | ${result.initialMs} | ${result.oneMs} | ${result.hundredMs} | ${result.cacheMs} | ${result.dashboardMs} | ${result.dbMb.toStringAsFixed(2)} |',
    );
  }
  await File(
    'INVENTORY_INTELLIGENCE_QA_RESULTS.md',
  ).writeAsString(buffer.toString());
  stdout.writeln('Wrote INVENTORY_INTELLIGENCE_QA_RESULTS.md');
}

class _Result {
  final int products;
  final int initialMs;
  final int oneMs;
  final int hundredMs;
  final int cacheMs;
  final int dashboardMs;
  final double dbMb;

  const _Result({
    required this.products,
    required this.initialMs,
    required this.oneMs,
    required this.hundredMs,
    required this.cacheMs,
    required this.dashboardMs,
    required this.dbMb,
  });

  String toLog() {
    return 'products=$products,initial_ms=$initialMs,one_dirty_ms=$oneMs,100_dirty_ms=$hundredMs,cache_ms=$cacheMs,dashboard_ms=$dashboardMs,db_mb=${dbMb.toStringAsFixed(2)}';
  }
}
