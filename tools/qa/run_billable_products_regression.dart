import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/data/repositories/billable_product_query.dart';

Future<void> main(List<String> args) async {
  const output = 'qa_data/billable_products_regression.db';
  final file = File(output);

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await file.parent.create(recursive: true);
  if (await file.exists()) await file.delete();

  final db = await databaseFactory.openDatabase(file.absolute.path);
  try {
    await _createSchema(db);
    await _seed(db);

    final initial = await BillableProductQuery.obtenerProductosFacturables(
      db,
      negocioId: 1,
    );
    _assert(initial.length == 2, 'Debe devolver 2 productos facturables.');
    _assert(
      initial.any((item) => item.nombre == 'Producto Con Imagen'),
      'Debe incluir producto con imagen.',
    );
    _assert(
      initial.any((item) => item.nombre == 'Producto Sin Imagen'),
      'Debe incluir producto sin imagen.',
    );
    _assert(
      initial.every((item) => item.stock > 0 && item.activo),
      'Todos los facturables deben estar activos y con stock.',
    );
    _assert(
      initial.every((item) => item.negocioId == 1),
      'No debe mezclar productos de otro negocio.',
    );

    await db.query(
      DatabaseSchema.productosTable,
      where: 'nombre LIKE ?',
      whereArgs: ['%No Existe%'],
      limit: 5,
    );
    final afterVisualSearch =
        await BillableProductQuery.obtenerProductosFacturables(
          db,
          negocioId: 1,
        );
    _assert(
      afterVisualSearch.length == initial.length,
      'Busqueda/listado visual no debe afectar productos facturables.',
    );

    await db.insert(DatabaseSchema.inventoryProductMetricsTable, {
      'negocio_id': 1,
      'producto_id': 1,
      'product_name': 'Producto Con Imagen',
      'current_stock': 5,
      'status': 'critico',
      'dirty': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    final afterMetrics = await BillableProductQuery.obtenerProductosFacturables(
      db,
      negocioId: 1,
    );
    _assert(
      afterMetrics.length == initial.length,
      'Metricas de inventario no deben afectar productos facturables.',
    );

    final withoutStockFilter =
        await BillableProductQuery.obtenerProductosFacturables(
          db,
          negocioId: 1,
          soloConStock: false,
        );
    _assert(
      withoutStockFilter.length == 3,
      'soloConStock=false debe incluir producto activo con stock 0.',
    );

    stdout.writeln('BILLABLE_PRODUCTS_REGRESSION_OK');
    stdout.writeln('facturables_con_stock: ${initial.length}');
    stdout.writeln(
      'facturables_sin_filtro_stock: ${withoutStockFilter.length}',
    );
    stdout.writeln('database: ${file.absolute.path}');
  } finally {
    await db.close();
  }
}

Future<void> _createSchema(Database db) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createProductosTable);
  await db.execute(DatabaseSchema.createProductoImagenesTable);
  await db.execute(DatabaseSchema.createInventoryProductMetricsTable);
}

Future<void> _seed(Database db) async {
  final now = DateTime.now().toIso8601String();
  for (final business in [
    (id: 1, name: 'Negocio QA'),
    (id: 2, name: 'Otro Negocio'),
  ]) {
    await db.insert(DatabaseSchema.usuariosTable, {
      'id': business.id,
      'nombre': business.name,
      'telefono': '809900000${business.id}',
      'tipo_usuario': 'negocio',
      'password_hash': 'qa-only',
      'activo': 1,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'synced',
    });
  }

  await _insertProduct(
    db,
    id: 1,
    negocioId: 1,
    nombre: 'Producto Con Imagen',
    stock: 5,
    activo: true,
    now: now,
  );
  await db.insert(DatabaseSchema.productoImagenesTable, {
    'negocio_id': 1,
    'producto_id': 1,
    'local_path': 'qa_data/producto_1.jpg',
    'orden': 0,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'synced',
  });
  await _insertProduct(
    db,
    id: 2,
    negocioId: 1,
    nombre: 'Producto Sin Imagen',
    stock: 3,
    activo: true,
    now: now,
  );
  await _insertProduct(
    db,
    id: 3,
    negocioId: 1,
    nombre: 'Producto Stock Cero',
    stock: 0,
    activo: true,
    now: now,
  );
  await _insertProduct(
    db,
    id: 4,
    negocioId: 1,
    nombre: 'Producto Inactivo',
    stock: 7,
    activo: false,
    now: now,
  );
  await _insertProduct(
    db,
    id: 5,
    negocioId: 2,
    nombre: 'Producto Otro Negocio',
    stock: 9,
    activo: true,
    now: now,
  );
}

Future<void> _insertProduct(
  Database db, {
  required int id,
  required int negocioId,
  required String nombre,
  required int stock,
  required bool activo,
  required String now,
}) {
  return db.insert(DatabaseSchema.productosTable, {
    'id': id,
    'negocio_id': negocioId,
    'nombre': nombre,
    'categoria': 'QA',
    'descripcion': null,
    'cantidad': stock,
    'costo_unitario': 50.0,
    'precio_compra': 50.0,
    'precio_venta': 75.0,
    'porcentaje_ganancia': 50.0,
    'stock_minimo': 1,
    'codigo_referencia': 'QA-$id',
    'activo': activo ? 1 : 0,
    'sync_status': 'synced',
    'created_at': now,
    'updated_at': now,
    'legacy_id': 'qa-product-$id',
    'ubicacion': 'estante-$id',
    'tipo_medida': 'unidad',
    'nivel_demanda': 'media',
    'es_clave': 0,
    'disponibilidad_confirmada': 1,
    'disponibilidad_corregida': 0,
    'requiere_verificacion_administrador': 0,
    'rotacion_semana_anterior': 0,
  });
}

void _assert(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
