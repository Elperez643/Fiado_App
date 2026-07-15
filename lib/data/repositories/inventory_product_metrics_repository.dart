import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../inventory_intelligence/inventory_insight.dart';
import '../models/inventory_product_metric_sqlite_model.dart';

class InventoryProductMetricsRepository {
  final DatabaseHelper databaseHelper;

  InventoryProductMetricsRepository({DatabaseHelper? databaseHelper})
    : databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  Future<void> upsertMetric(InventoryProductMetricSqliteModel metric) async {
    final db = await databaseHelper.database;
    await db.insert(
      DatabaseSchema.inventoryProductMetricsTable,
      metric.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<InventoryInsight>> getMetricsByBusiness(int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT m.*, p.legacy_id
FROM ${DatabaseSchema.inventoryProductMetricsTable} m
LEFT JOIN ${DatabaseSchema.productosTable} p ON p.id = m.producto_id
WHERE m.negocio_id = ?
ORDER BY m.status ASC, m.product_name COLLATE NOCASE ASC
''',
      [negocioId],
    );
    return rows
        .map(
          (row) => InventoryProductMetricSqliteModel.fromMap(
            row,
          ).toInsight(legacyProductId: row['legacy_id'] as String?),
        )
        .toList(growable: false);
  }

  Future<List<InventoryInsight>> getCriticalProducts(int negocioId) async {
    return _queryInsights(
      negocioId,
      where:
          "m.status IN ('${InventoryInsight.statusOutOfStock}', '${InventoryInsight.statusCritical}', '${InventoryInsight.statusLowStock}')",
      orderBy:
          "CASE m.status WHEN '${InventoryInsight.statusOutOfStock}' THEN 1 WHEN '${InventoryInsight.statusCritical}' THEN 2 WHEN '${InventoryInsight.statusLowStock}' THEN 3 ELSE 9 END, m.current_stock ASC",
    );
  }

  Future<List<InventoryInsight>> getRestockSuggestions(int negocioId) async {
    return _queryInsights(
      negocioId,
      where: 'm.recommended_restock_quantity > 0',
      orderBy: 'm.recommended_restock_quantity DESC',
    );
  }

  Future<List<InventoryInsight>> getNoMovementProducts(int negocioId) async {
    return _queryInsights(
      negocioId,
      where: "m.status = '${InventoryInsight.statusNoMovement}'",
      orderBy: 'm.inventory_cost_value DESC',
    );
  }

  Future<void> markProductDirty({
    required int negocioId,
    required int productoId,
  }) async {
    final db = await databaseHelper.database;
    final now = DateTime.now().toIso8601String();
    final updated = await db.update(
      DatabaseSchema.inventoryProductMetricsTable,
      {'dirty': 1, 'updated_at': now},
      where: 'negocio_id = ? AND producto_id = ?',
      whereArgs: [negocioId, productoId],
    );
    if (updated == 0) {
      await db.insert(
        DatabaseSchema.inventoryProductMetricsTable,
        {
          'negocio_id': negocioId,
          'producto_id': productoId,
          'status': InventoryInsight.statusNormal,
          'dirty': 1,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> markAllDirtyForBusiness(int negocioId) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.inventoryProductMetricsTable,
      {'dirty': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
    );
  }

  Future<int> dirtyCount(int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.inventoryProductMetricsTable} WHERE negocio_id = ? AND dirty = 1',
      [negocioId],
    );
    return (rows.first['total'] as num? ?? 0).toInt();
  }

  Future<bool> hasMetrics(int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM ${DatabaseSchema.inventoryProductMetricsTable} WHERE negocio_id = ? LIMIT 1',
      [negocioId],
    );
    return rows.isNotEmpty;
  }

  Future<int> metricsCount(int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.inventoryProductMetricsTable} WHERE negocio_id = ?',
      [negocioId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> activeProductCount(int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable} WHERE negocio_id = ? AND activo = 1',
      [negocioId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> recalculateDirtyProducts({
    required int negocioId,
    int batchSize = 200,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.inventoryProductMetricsTable,
      columns: ['producto_id'],
      where: 'negocio_id = ? AND dirty = 1',
      whereArgs: [negocioId],
      limit: batchSize,
    );
    for (final row in rows) {
      await recalculateProductMetric(
        negocioId: negocioId,
        productoId: (row['producto_id'] as num).toInt(),
      );
    }
    return rows.length;
  }

  Future<InventoryInsight?> recalculateProductMetric({
    required int negocioId,
    required int productoId,
  }) async {
    final metric = await _calculateMetric(negocioId, productoId);
    if (metric == null) return null;
    await upsertMetric(metric);
    return metric.toInsight();
  }

  Future<int> recalculateBusinessMetricsInBatches({
    required int negocioId,
    int batchSize = 200,
  }) async {
    final db = await databaseHelper.database;
    var offset = 0;
    var processed = 0;
    while (true) {
      final rows = await db.query(
        DatabaseSchema.productosTable,
        columns: ['id'],
        where: 'negocio_id = ? AND activo = 1',
        whereArgs: [negocioId],
        orderBy: 'id ASC',
        limit: batchSize,
        offset: offset,
      );
      if (rows.isEmpty) break;
      final productIds = rows
          .map((row) => (row['id'] as num).toInt())
          .toList(growable: false);
      await _recalculateProductMetricsBatch(
        negocioId: negocioId,
        productoIds: productIds,
      );
      processed += rows.length;
      offset += rows.length;
    }
    return processed;
  }

  Future<void> _recalculateProductMetricsBatch({
    required int negocioId,
    required List<int> productoIds,
  }) async {
    if (productoIds.isEmpty) return;
    final db = await databaseHelper.database;
    final placeholders = List.filled(productoIds.length, '?').join(', ');
    final productRows = await db.query(
      DatabaseSchema.productosTable,
      where: 'negocio_id = ? AND activo = 1 AND id IN ($placeholders)',
      whereArgs: [negocioId, ...productoIds],
    );
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final movementRows = await db.rawQuery(
      '''
SELECT
  di.producto_id,
  COALESCE(SUM(CASE
    WHEN COALESCE(m.fecha, di.created_at) >= ? THEN di.cantidad
    ELSE 0
  END), 0) AS sold_quantity_30_days,
  MAX(COALESCE(m.fecha, di.created_at)) AS last_movement_at
FROM ${DatabaseSchema.deudaItemsTable} di
LEFT JOIN ${DatabaseSchema.movimientosTable} m ON m.id = di.movimiento_id
WHERE di.negocio_id = ?
  AND di.producto_id IN ($placeholders)
  AND di.deleted_at IS NULL
GROUP BY di.producto_id
''',
      [cutoff, negocioId, ...productoIds],
    );
    final movementByProductId = {
      for (final row in movementRows) (row['producto_id'] as num).toInt(): row,
    };

    final batch = db.batch();
    for (final product in productRows) {
      final productId = (product['id'] as num).toInt();
      final movement = movementByProductId[productId];
      final metric = _metricFromRow({
        ...product,
        'sold_quantity_30_days': movement?['sold_quantity_30_days'] ?? 0,
        'last_movement_at': movement?['last_movement_at'],
      }, negocioId: negocioId);
      batch.insert(
        DatabaseSchema.inventoryProductMetricsTable,
        metric.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<InventoryProductMetricSqliteModel?> _calculateMetric(
    int negocioId,
    int productoId,
  ) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT
  p.*,
  COALESCE(SUM(CASE
    WHEN COALESCE(m.fecha, di.created_at) >= ? THEN di.cantidad
    ELSE 0
  END), 0) AS sold_quantity_30_days,
  MAX(COALESCE(m.fecha, di.created_at)) AS last_movement_at
FROM ${DatabaseSchema.productosTable} p
LEFT JOIN ${DatabaseSchema.deudaItemsTable} di
  ON di.producto_id = p.id AND di.deleted_at IS NULL
LEFT JOIN ${DatabaseSchema.movimientosTable} m ON m.id = di.movimiento_id
WHERE p.negocio_id = ?
  AND p.id = ?
  AND p.activo = 1
GROUP BY p.id
LIMIT 1
''',
      [
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        negocioId,
        productoId,
      ],
    );
    if (rows.isEmpty) return null;
    return _metricFromRow(rows.first, negocioId: negocioId);
  }

  InventoryProductMetricSqliteModel _metricFromRow(
    Map<String, Object?> row, {
    required int negocioId,
  }) {
    final now = DateTime.now();
    final stock = (row['cantidad'] as num? ?? 0).toInt();
    final minimum = (row['stock_minimo'] as num? ?? 0).toInt();
    final unitCost =
        (row['costo_unitario'] as num?)?.toDouble() ??
        (row['precio_compra'] as num?)?.toDouble() ??
        0;
    final salePrice = (row['precio_venta'] as num? ?? 0).toDouble();
    final sold30 = (row['sold_quantity_30_days'] as num? ?? 0).toDouble();
    final average = sold30 / 30;
    final coverage = average > 0 ? stock / average : null;
    final target = average > 0 ? (average * 15).ceil() : 0;
    final restock = target - stock;
    final lastText = row['last_movement_at'] as String?;
    final last = lastText == null ? null : DateTime.tryParse(lastText);

    return InventoryProductMetricSqliteModel(
      negocioId: negocioId,
      productoId: (row['id'] as num).toInt(),
      productName: row['nombre'] as String?,
      codeReference: row['codigo_referencia'] as String?,
      category: row['categoria'] as String?,
      location: row['ubicacion'] as String? ?? 'Sin ubicacion',
      currentStock: stock,
      minimumStock: minimum,
      unitCost: unitCost,
      salePrice: salePrice,
      profitMarginPercent: (row['porcentaje_ganancia'] as num? ?? 0).toDouble(),
      inventoryCostValue: stock * unitCost,
      inventorySaleValue: stock * salePrice,
      potentialProfit: stock * (salePrice - unitCost),
      soldQuantity30Days: sold30,
      averageDailyMovement: average,
      coverageDays: coverage,
      recommendedRestockQuantity: restock > 0 ? restock.toDouble() : 0,
      status: _status(
        stock: stock,
        minimum: minimum,
        coverage: coverage,
        last: last,
        now: now,
      ),
      lastMovementAt: last,
      lastCalculatedAt: now,
      dirty: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<InventoryInsight>> _queryInsights(
    int negocioId, {
    required String where,
    required String orderBy,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.rawQuery(
      '''
SELECT m.*, p.legacy_id
FROM ${DatabaseSchema.inventoryProductMetricsTable} m
LEFT JOIN ${DatabaseSchema.productosTable} p ON p.id = m.producto_id
WHERE m.negocio_id = ? AND $where
ORDER BY $orderBy
''',
      [negocioId],
    );
    return rows
        .map(
          (row) => InventoryProductMetricSqliteModel.fromMap(
            row,
          ).toInsight(legacyProductId: row['legacy_id'] as String?),
        )
        .toList(growable: false);
  }

  String _status({
    required int stock,
    required int minimum,
    required double? coverage,
    required DateTime? last,
    required DateTime now,
  }) {
    if (stock <= 0) return InventoryInsight.statusOutOfStock;
    if (coverage != null && coverage <= 3) {
      return InventoryInsight.statusCritical;
    }
    if (stock <= minimum) return InventoryInsight.statusLowStock;
    if (last == null || now.difference(last).inDays >= 30) {
      return InventoryInsight.statusNoMovement;
    }
    if (coverage != null && coverage >= 60 && stock > minimum) {
      return InventoryInsight.statusOverStock;
    }
    return InventoryInsight.statusNormal;
  }
}
