import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  final output = _stringOption(args, 'output', 'qa_data/fiado_stress_test.db');
  final reset = args.contains('--reset');
  final clients = _intOption(args, 'clients', 1000);
  final products = _intOption(args, 'products', 500);
  final movements = _intOption(args, 'movements', clients * 3);
  final debtItems = _intOption(args, 'debt-items', movements);
  final audits = _intOption(args, 'audits', clients ~/ 20);
  final creditCycles = _intOption(args, 'credit-cycles', clients);
  final syncQueue = _intOption(args, 'sync-queue', clients ~/ 2);

  _guardQaPath(output, args.contains('--allow-real-db'));

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final file = File(output);
  await file.parent.create(recursive: true);
  if (reset && await file.exists()) {
    await file.delete();
  }

  final dbPath = file.absolute.path;
  final db = await databaseFactory.openDatabase(dbPath);
  try {
    await _createSchema(db);
    await _seedBusiness(db);
    final timings = <String, int>{};
    timings['insert_clients_ms'] = await _time(() => _seedClients(db, clients));
    timings['insert_products_ms'] = await _time(
      () => _seedProducts(db, products),
    );
    timings['insert_movements_ms'] = await _time(
      () => _seedMovements(db, clients: clients, movements: movements),
    );
    timings['insert_debt_items_ms'] = await _time(
      () => _seedDebtItems(
        db,
        products: products,
        movements: movements,
        items: debtItems,
      ),
    );
    timings['insert_credit_cycles_ms'] = await _time(
      () => _seedCreditCycles(db, clients: clients, cycles: creditCycles),
    );
    timings['insert_sync_queue_ms'] = await _time(
      () => _seedSyncQueue(db, items: syncQueue),
    );
    timings['insert_audits_ms'] = await _time(
      () => _seedAudits(db, products: products, audits: audits),
    );

    stdout.writeln('QA SQLite data generated');
    stdout.writeln('database: $dbPath');
    stdout.writeln('clients: $clients');
    stdout.writeln('products: $products');
    stdout.writeln('movements: $movements');
    stdout.writeln('debt_items: $debtItems');
    stdout.writeln('credit_cycles: $creditCycles');
    stdout.writeln('sync_queue: $syncQueue');
    stdout.writeln('audits: $audits');
    for (final entry in timings.entries) {
      stdout.writeln('${entry.key}: ${entry.value}');
    }
  } finally {
    await db.close();
  }

  final sizeMb = (await File(dbPath).length()) / (1024 * 1024);
  stdout.writeln('size_mb: ${sizeMb.toStringAsFixed(2)}');
}

Future<int> _time(Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  return stopwatch.elapsedMilliseconds;
}

Future<void> _createSchema(Database db) async {
  final statements = <String>[
    DatabaseSchema.createUsuariosTable,
    DatabaseSchema.createSesionesTable,
    DatabaseSchema.createSubscriptionsTable,
    DatabaseSchema.createClientesTable,
    DatabaseSchema.createProductosTable,
    DatabaseSchema.createProductoImagenesTable,
    DatabaseSchema.createMovimientosTable,
    DatabaseSchema.createPagosTable,
    DatabaseSchema.createDeudaItemsTable,
    DatabaseSchema.createComprobantesTable,
    DatabaseSchema.createCreditoCiclosTable,
    DatabaseSchema.createCreditoCicloMovimientosTable,
    DatabaseSchema.createCreditoRecordatoriosTable,
    DatabaseSchema.createCreditoExcepcionesTable,
    DatabaseSchema.createClientScoresTable,
    DatabaseSchema.createSolicitudesAutorizacionTable,
    DatabaseSchema.createAuditoriasTable,
    DatabaseSchema.createAuditoriaItemsTable,
    DatabaseSchema.createUserOnboardingTable,
    DatabaseSchema.createSyncQueueTable,
    ...DatabaseSchema.initialIndexes,
  ];

  for (final statement in statements) {
    await db.execute(statement);
  }
}

Future<void> _seedBusiness(Database db) async {
  final now = DateTime.now().toIso8601String();
  await db.insert(DatabaseSchema.usuariosTable, {
    'id': 1,
    'remote_id': 'qa-business-1',
    'nombre': 'QA Stress Business',
    'telefono': '8090000001',
    'tipo_usuario': 'negocio',
    'password_hash': 'qa-only',
    'activo': 1,
    'created_at': now,
    'updated_at': now,
    'sync_status': 'synced',
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}

Future<void> _seedClients(Database db, int clients) async {
  final now = DateTime.now().toIso8601String();
  await _commitChunks(db, clients, (batch, i) {
    final id = i + 1;
    batch.insert(DatabaseSchema.clientesTable, {
      'id': id,
      'negocio_id': 1,
      'nombre': 'Cliente QA ${id.toString().padLeft(6, '0')}',
      'telefono': '809${id.toString().padLeft(7, '0')}',
      'address': 'Sector QA $id',
      'deuda': (id % 17) * 125.0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'synced',
      'remote_id': 'qa-client-$id',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
}

Future<void> _seedProducts(Database db, int products) async {
  final now = DateTime.now().toIso8601String();
  await _commitChunks(db, products, (batch, i) {
    final id = i + 1;
    batch.insert(DatabaseSchema.productosTable, {
      'id': id,
      'negocio_id': 1,
      'remote_id': 'qa-product-$id',
      'nombre': 'Producto QA ${id.toString().padLeft(5, '0')}',
      'categoria': 'Categoria ${id % 12}',
      'descripcion': 'Producto generado para prueba de carga',
      'cantidad': 20 + (id % 500),
      'precio_compra': 20.0 + (id % 50),
      'precio_venta': 35.0 + (id % 80),
      'stock_minimo': 5,
      'codigo_referencia': 'QA-P-${id.toString().padLeft(6, '0')}',
      'activo': 1,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'synced',
      'legacy_id': 'qa-product-legacy-$id',
      'ubicacion': 'A-${id % 20}',
      'tipo_medida': 'unidad',
      'nivel_demanda': id % 3 == 0 ? 'alta' : 'media',
      'es_clave': id % 10 == 0 ? 1 : 0,
      'rotacion_semana_anterior': id % 30,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
}

Future<void> _seedMovements(
  Database db, {
  required int clients,
  required int movements,
}) async {
  final now = DateTime.now();
  await _commitChunks(db, movements, (batch, i) {
    final id = i + 1;
    final clientId = (i % clients) + 1;
    final date = now.subtract(Duration(minutes: i)).toIso8601String();
    batch.insert(
      DatabaseSchema.movimientosTable,
      {
        'id': id,
        'negocio_id': 1,
        'cliente_nombre': 'Cliente QA ${clientId.toString().padLeft(6, '0')}',
        'cliente_telefono': '809${clientId.toString().padLeft(7, '0')}',
        'tipo': id % 5 == 0 ? 'pago' : 'deuda',
        'monto': 100.0 + (id % 900),
        'concepto': id % 5 == 0 ? 'Pago QA' : 'Deuda QA',
        'fecha': date,
        'created_at': date,
        'updated_at': date,
        'is_active': 1,
        'sync_status': 'synced',
        'remote_id': 'qa-movement-$id',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  });
}

Future<void> _seedDebtItems(
  Database db, {
  required int products,
  required int movements,
  required int items,
}) async {
  final now = DateTime.now().toIso8601String();
  await _commitChunks(db, items, (batch, i) {
    final id = i + 1;
    final productId = (i % products) + 1;
    final movementId = (i % movements) + 1;
    final quantity = (i % 4) + 1;
    final price = 35.0 + (productId % 80);
    batch.insert(DatabaseSchema.deudaItemsTable, {
      'id': id,
      'negocio_id': 1,
      'remote_id': 'qa-debt-item-$id',
      'movimiento_id': movementId,
      'producto_id': productId,
      'nombre_producto': 'Producto QA ${productId.toString().padLeft(5, '0')}',
      'codigo_referencia': 'QA-P-${productId.toString().padLeft(6, '0')}',
      'cantidad': quantity,
      'precio_unitario': price,
      'subtotal': quantity * price,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'synced',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
}

Future<void> _seedAudits(
  Database db, {
  required int products,
  required int audits,
}) async {
  final now = DateTime.now();
  const chunkSize = 500;
  for (var start = 1; start <= audits; start += chunkSize) {
    final batch = db.batch();
    final end = (start + chunkSize - 1).clamp(1, audits);
    for (var audit = start; audit <= end; audit++) {
      final createdAt = now.subtract(Duration(hours: audit)).toIso8601String();
      batch.insert(
        DatabaseSchema.auditoriasTable,
        {
          'id': audit,
          'remote_id': 'qa-audit-$audit',
          'negocio_id': 1,
          'tipo': audit % 7 == 0 ? 'semanal' : 'diaria',
          'fecha': createdAt,
          'estado': audit % 3 == 0 ? 'finalizada' : 'en_proceso',
          'total_productos': 5,
          'productos_validados': audit % 3 == 0 ? 5 : 2,
          'observaciones': 'Auditoria QA $audit',
          'created_at': createdAt,
          'updated_at': createdAt,
          'sync_status': 'synced',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (var item = 0; item < 5; item++) {
        final id = ((audit - 1) * 5) + item + 1;
        final productId = ((audit + item) % products) + 1;
        final stock = 20 + (productId % 500);
        batch.insert(
          DatabaseSchema.auditoriaItemsTable,
          {
            'id': id,
            'negocio_id': 1,
            'remote_id': 'qa-audit-item-$id',
            'auditoria_id': audit,
            'producto_id': productId,
            'stock_sistema': stock,
            'stock_fisico': audit % 3 == 0 ? stock - (item % 2) : null,
            'estado_validacion': audit % 3 == 0
                ? (item % 2 == 0 ? 'correcto' : 'diferencia')
                : 'pendiente',
            'observacion': item % 2 == 0 ? null : 'Diferencia QA',
            'created_at': createdAt,
            'updated_at': createdAt,
            'sync_status': 'synced',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }
}

Future<void> _seedCreditCycles(
  Database db, {
  required int clients,
  required int cycles,
}) async {
  final now = DateTime.now();
  await _commitChunks(db, cycles, (batch, i) {
    final id = i + 1;
    final clientId = (i % clients) + 1;
    final start = now.subtract(Duration(days: i % 120));
    final status = id % 10 == 0
        ? 'bloqueado'
        : id % 5 == 0
        ? 'mora'
        : id % 4 == 0
        ? 'saldado'
        : 'activo';
    final total = 500.0 + (id % 1500);
    final paid = status == 'saldado' ? total : (id % 300).toDouble();
    batch.insert(
      DatabaseSchema.creditoCiclosTable,
      {
        'id': id,
        'remote_id': 'qa-credit-cycle-$id',
        'negocio_id': 1,
        'cliente_id': clientId,
        'fecha_inicio': start.toIso8601String(),
        'fecha_limite_30': start
            .add(const Duration(days: 30))
            .toIso8601String(),
        'fecha_limite_45': start
            .add(const Duration(days: 45))
            .toIso8601String(),
        'fecha_bloqueo_60': start
            .add(const Duration(days: 60))
            .toIso8601String(),
        'estado': status,
        'monto_total': total,
        'monto_pagado': paid,
        'saldo_pendiente': total - paid,
        'bloqueado': status == 'bloqueado' ? 1 : 0,
        'fecha_saldado': status == 'saldado' ? now.toIso8601String() : null,
        'created_at': start.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'sync_status': 'synced',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  });
}

Future<void> _seedSyncQueue(Database db, {required int items}) async {
  final now = DateTime.now().toIso8601String();
  await _commitChunks(db, items, (batch, i) {
    final id = i + 1;
    final entityType = switch (id % 5) {
      0 => DatabaseSchema.clientesTable,
      1 => DatabaseSchema.productosTable,
      2 => DatabaseSchema.movimientosTable,
      3 => DatabaseSchema.deudaItemsTable,
      _ => DatabaseSchema.creditoCiclosTable,
    };
    batch.insert(DatabaseSchema.syncQueueTable, {
      'id': id,
      'entity_type': entityType,
      'entity_id': id,
      'operation': id % 7 == 0 ? 'update' : 'create',
      'payload': '{"qa":true,"id":$id}',
      'status': id % 9 == 0 ? 'failed' : 'pending',
      'attempts': id % 3,
      'last_error': id % 9 == 0 ? 'QA simulated failure' : null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
}

Future<void> _commitChunks(
  Database db,
  int total,
  void Function(Batch batch, int index) add,
) async {
  const chunkSize = 1000;
  for (var start = 0; start < total; start += chunkSize) {
    final batch = db.batch();
    final end = (start + chunkSize).clamp(0, total);
    for (var i = start; i < end; i++) {
      add(batch, i);
    }
    await batch.commit(noResult: true);
  }
}

int _intOption(List<String> args, String name, int fallback) {
  final prefix = '--$name=';
  final value = args
      .where((arg) => arg.startsWith(prefix))
      .map((arg) => arg.substring(prefix.length))
      .firstOrNull;
  return value == null ? fallback : int.parse(value);
}

String _stringOption(List<String> args, String name, String fallback) {
  final prefix = '--$name=';
  return args
          .where((arg) => arg.startsWith(prefix))
          .map((arg) => arg.substring(prefix.length))
          .firstOrNull ??
      fallback;
}

void _guardQaPath(String output, bool allowRealDb) {
  if (allowRealDb) return;
  final normalized = output.replaceAll('\\', '/').toLowerCase();
  if (!normalized.contains('qa') && !normalized.contains('stress')) {
    stderr.writeln(
      'Refusing to write outside a QA/stress path. Use --allow-real-db only '
      'with a disposable database.',
    );
    exitCode = 64;
    throw const FileSystemException('Unsafe output path');
  }
}
