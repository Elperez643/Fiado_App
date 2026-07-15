import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';
import 'local_database.dart';

class DatabaseHelper implements LocalDatabase {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  @override
  Future<Database> get database async {
    final currentDatabase = _database;
    if (currentDatabase != null && currentDatabase.isOpen) {
      return currentDatabase;
    }

    _database = await _openDatabase().timeout(const Duration(seconds: 18));
    return _database!;
  }

  @override
  Future<void> initialize() async {
    await database;
  }

  Future<Database> _openDatabase() async {
    debugPrint('[startup] database init inicio');
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, DatabaseSchema.databaseName);
    debugPrint('[startup] database path listo');

    final db = await openDatabase(
      databasePath,
      version: DatabaseSchema.version,
      onConfigure: (db) async {
        // Las llaves foraneas quedan activas desde la apertura para mantener
        // integridad cuando la app crezca hacia sincronizacion cloud.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
      onDowngrade: rejectDestructiveDowngrade,
    );
    debugPrint('[startup] database lista');
    return db;
  }

  @visibleForTesting
  static Future<void> rejectDestructiveDowngrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    throw StateError(
      'Downgrade SQLite bloqueado para proteger datos: '
      '$oldVersion->$newVersion. Instala una version compatible o agrega '
      'una migracion no destructiva.',
    );
  }

  Future<void> _onOpen(Database db) async {
    debugPrint('[startup] database onOpen');
    await _ensureClientIdentityColumns(db);
    await _ensureClientUuidColumns(db);
    await _ensureProductCloudSyncColumns(db);
    await _ensureFinancialCloudSyncColumns(db);
    await _ensureNewSyncBaseTables(db);
    await db.execute(DatabaseSchema.createInventoryProductMetricsTable);
    await db.execute(DatabaseSchema.createWhatsappCampaignPublicationsTable);
    for (final indexStatement in DatabaseSchema.initialIndexes) {
      if (indexStatement.contains('idx_inventory_metrics_') ||
          indexStatement.contains('idx_whatsapp_campaigns_') ||
          indexStatement.contains('idx_movimientos_negocio_cliente_id_fecha')) {
        await db.execute(indexStatement);
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[startup] database onCreate v$version');
    final batch = db.batch();
    for (final statement in DatabaseSchema.createTableStatements) {
      batch.execute(statement);
    }

    for (final indexStatement in DatabaseSchema.initialIndexes) {
      batch.execute(indexStatement);
    }

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[startup] database onUpgrade $oldVersion->$newVersion');
    // Punto controlado para migraciones futuras:
    if (oldVersion < 2) {
      await db.execute(DatabaseSchema.createProductosTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('productos')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 3) {
      await db.execute(DatabaseSchema.createUsuariosTable);
      await db.execute(DatabaseSchema.createSesionesTable);
      await db.execute(DatabaseSchema.createSubscriptionsTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('usuarios') ||
            indexStatement.contains('subscriptions')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 4) {
      await db.execute(DatabaseSchema.createSolicitudesAutorizacionTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('solicitudes_autorizacion')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        DatabaseSchema.solicitudesAutorizacionTable,
        'aprobado_por_usuario_id',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        DatabaseSchema.solicitudesAutorizacionTable,
        'resolved_at',
        'TEXT',
      );
    }
    if (oldVersion < 6) {
      await db.execute(DatabaseSchema.createAuditoriasTable);
      await db.execute(DatabaseSchema.createAuditoriaItemsTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('auditorias') ||
            indexStatement.contains('auditoria_items')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 7) {
      await db.execute(DatabaseSchema.createSyncQueueTable);
      await _ensureSyncStatusColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('sync_queue') ||
            indexStatement.contains('sync_status')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 8) {
      await _addColumnIfMissing(
        db,
        DatabaseSchema.productosTable,
        'codigo_referencia',
        'TEXT',
      );
      await db.execute(DatabaseSchema.createProductoImagenesTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('productos_codigo_activo') ||
            indexStatement.contains('productos_nombre_activo') ||
            indexStatement.contains('producto_imagenes')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(
        db,
        DatabaseSchema.movimientosTable,
        'concepto',
        'TEXT',
      );
      await db.execute(DatabaseSchema.createDeudaItemsTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('deuda_items')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 10) {
      await db.execute(DatabaseSchema.createComprobantesTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('comprobantes')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 11) {
      await _migrateClientesBusinessScope(db);
      await _ensureBusinessColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains(
          'idx_movimientos_negocio_cliente_id_fecha',
        )) {
          continue;
        }
        await db.execute(indexStatement);
      }
    }
    if (oldVersion < 12) {
      await _ensureSubscriptionBillingColumns(db);
    }
    if (oldVersion < 13) {
      await db.execute(DatabaseSchema.createCreditoCiclosTable);
      await db.execute(DatabaseSchema.createCreditoCicloMovimientosTable);
      await db.execute(DatabaseSchema.createCreditoRecordatoriosTable);
      await db.execute(DatabaseSchema.createCreditoExcepcionesTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('credito_')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 14) {
      await db.execute(DatabaseSchema.createUserOnboardingTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('user_onboarding')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 15) {
      await _ensureClientCloudSyncColumns(db);
      await _addColumnIfMissing(
        db,
        DatabaseSchema.sesionesTable,
        'jwt_token',
        'TEXT',
      );
    }
    if (oldVersion < 16) {
      await _ensureProductCloudSyncColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('productos') ||
            indexStatement.contains('producto_imagenes')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 17) {
      await _ensureFinancialCloudSyncColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('movimientos') ||
            indexStatement.contains('deuda_items') ||
            indexStatement.contains('comprobantes') ||
            indexStatement.contains('credito_')) {
          if (indexStatement.contains(
            'idx_movimientos_negocio_cliente_id_fecha',
          )) {
            continue;
          }
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 18) {
      await _ensureOperationalCloudSyncColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('auditorias') ||
            indexStatement.contains('auditoria_items') ||
            indexStatement.contains('solicitudes_autorizacion')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 19) {
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains(
          'idx_movimientos_negocio_cliente_telefono_fecha',
        )) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 20) {
      await db.execute(DatabaseSchema.createClientScoresTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('client_scores')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 21) {
      await _ensureProductCostMarginColumns(db);
    }
    if (oldVersion < 22) {
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('idx_productos_negocio_activo_stock') ||
            indexStatement.contains('idx_deuda_items_negocio_producto')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 23) {
      await db.execute(DatabaseSchema.createInventoryProductMetricsTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('idx_inventory_metrics_')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 24) {
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('idx_credito_ciclos_negocio_')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 25) {
      await db.execute(DatabaseSchema.createBusinessRecommendationsCacheTable);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('idx_business_recommendations_')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 26) {
      await _ensureClientIdentityColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains(
          'idx_movimientos_negocio_cliente_id_fecha',
        )) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 27) {
      await _ensureFinancialIdempotencyColumns(db);
      for (final indexStatement in DatabaseSchema.initialIndexes) {
        if (indexStatement.contains('idx_movimientos_negocio_local_uuid') ||
            indexStatement.contains('idx_deuda_items_negocio_local_uuid')) {
          await db.execute(indexStatement);
        }
      }
    }
    if (oldVersion < 28) {
      await _ensureNewSyncBaseTables(db);
    }
    if (oldVersion < 29) {
      await _ensureClientUuidColumns(db);
    }
  }

  Future<void> _ensureClientIdentityColumns(Database db) async {
    const movimientosTable = DatabaseSchema.movimientosTable;
    const clientesTable = DatabaseSchema.clientesTable;

    final initialMovimientoColumns = await _getTableColumns(
      db,
      movimientosTable,
    );
    debugPrint(
      '[db] movimientos columns before ensure client identity: $initialMovimientoColumns',
    );

    await _addColumnIfMissing(db, movimientosTable, 'cliente_id', 'INTEGER');
    var movimientoColumns = await _getTableColumns(db, movimientosTable);

    await _addColumnIfMissing(
      db,
      movimientosTable,
      'cliente_nombre_snapshot',
      'TEXT',
    );
    movimientoColumns = await _getTableColumns(db, movimientosTable);

    await _addColumnIfMissing(
      db,
      movimientosTable,
      'cliente_telefono_snapshot',
      'TEXT',
    );
    movimientoColumns = await _getTableColumns(db, movimientosTable);
    debugPrint(
      '[db] movimientos columns after ensure client identity: $movimientoColumns',
    );

    final clienteColumns = await _getTableColumns(db, clientesTable);
    final hasClienteId = movimientoColumns.contains('cliente_id');
    final hasNegocioId = movimientoColumns.contains('negocio_id');
    final hasClienteNombre = movimientoColumns.contains('cliente_nombre');
    final hasClienteTelefono = movimientoColumns.contains('cliente_telefono');
    final hasClienteNombreSnapshot = movimientoColumns.contains(
      'cliente_nombre_snapshot',
    );
    final hasClienteTelefonoSnapshot = movimientoColumns.contains(
      'cliente_telefono_snapshot',
    );

    if (hasClienteNombre && hasClienteNombreSnapshot) {
      await db.execute('''
UPDATE $movimientosTable
SET cliente_nombre_snapshot = COALESCE(cliente_nombre_snapshot, cliente_nombre)
''');
    } else if (!hasClienteNombre) {
      debugPrint(
        '[db] skip movimiento cliente_nombre snapshot backfill: missing cliente_nombre',
      );
    } else {
      debugPrint(
        '[db] skip movimiento cliente_nombre snapshot backfill: missing cliente_nombre_snapshot',
      );
    }

    if (hasClienteTelefono && hasClienteTelefonoSnapshot) {
      await db.execute('''
UPDATE $movimientosTable
SET cliente_telefono_snapshot = COALESCE(cliente_telefono_snapshot, cliente_telefono)
''');
    } else if (!hasClienteTelefono) {
      debugPrint(
        '[db] skip movimiento cliente_telefono snapshot backfill: missing cliente_telefono',
      );
    } else {
      debugPrint(
        '[db] skip movimiento cliente_telefono snapshot backfill: missing cliente_telefono_snapshot',
      );
    }

    final requiredMovimientoColumns = {
      'negocio_id',
      'cliente_id',
      'cliente_nombre_snapshot',
      'cliente_telefono_snapshot',
    };
    final missingMovimientoColumns = requiredMovimientoColumns
        .where((column) => !movimientoColumns.contains(column))
        .toList();
    final requiredClienteColumns = {
      'id',
      'negocio_id',
      'nombre',
      'telefono',
      'is_active',
    };
    final missingClienteColumns = requiredClienteColumns
        .where((column) => !clienteColumns.contains(column))
        .toList();

    if (!hasNegocioId ||
        !hasClienteId ||
        !hasClienteNombreSnapshot ||
        !hasClienteTelefonoSnapshot ||
        missingClienteColumns.isNotEmpty) {
      if (missingMovimientoColumns.isNotEmpty) {
        debugPrint(
          '[db] skip movimiento cliente_id backfill: missing movimientos.${missingMovimientoColumns.join(', ')}',
        );
      }
      if (missingClienteColumns.isNotEmpty) {
        debugPrint(
          '[db] skip movimiento cliente_id backfill: missing clientes.${missingClienteColumns.join(', ')}',
        );
      }
      return;
    }

    try {
      await db.execute('''
UPDATE $movimientosTable
SET cliente_id = (
  SELECT c.id
  FROM $clientesTable c
  WHERE c.negocio_id = $movimientosTable.negocio_id
    AND COALESCE(c.is_active, 1) = 1
    AND (
      (
        $movimientosTable.cliente_telefono_snapshot IS NOT NULL
        AND $movimientosTable.cliente_telefono_snapshot != ''
        AND c.telefono = $movimientosTable.cliente_telefono_snapshot
      )
      OR (
        $movimientosTable.cliente_nombre_snapshot IS NOT NULL
        AND $movimientosTable.cliente_nombre_snapshot != ''
        AND LOWER(c.nombre) = LOWER($movimientosTable.cliente_nombre_snapshot)
      )
    )
  ORDER BY
    CASE WHEN c.telefono = $movimientosTable.cliente_telefono_snapshot THEN 0 ELSE 1 END,
    c.id
  LIMIT 1
)
WHERE cliente_id IS NULL
''');
    } on DatabaseException catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('no such column')) {
        debugPrint(
          '[db] skip movimiento cliente_id backfill: column missing during update: $error',
        );
        return;
      }
      debugPrint('[db] movimiento cliente_id backfill failed: $error');
      rethrow;
    }
  }

  @visibleForTesting
  Future<void> ensureClientIdentityColumnsForTesting(Database db) {
    return _ensureClientIdentityColumns(db);
  }

  Future<void> _ensureProductCostMarginColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productosTable,
      'costo_unitario',
      'REAL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productosTable,
      'porcentaje_ganancia',
      'REAL DEFAULT 0',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.productosTable}
SET costo_unitario = COALESCE(NULLIF(costo_unitario, 0), precio_compra, 0)
''');
  }

  Future<void> _migrateClientesBusinessScope(Database db) async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseSchema.clientesTable})',
    );
    final hasNegocioId = columns.any((row) => row['name'] == 'negocio_id');
    final telefonoColumn = columns
        .where((row) => row['name'] == 'telefono')
        .cast<Map<String, Object?>>()
        .firstOrNull;
    final telefonoIsUnique = (telefonoColumn?['pk'] as int? ?? 0) == 0;

    if (hasNegocioId) return;

    await db.execute('ALTER TABLE clientes RENAME TO clientes_legacy_v10');
    await db.execute(DatabaseSchema.createClientesTable);
    await db.execute('''
INSERT INTO clientes (
  id, negocio_id, uuid, nombre, telefono, deuda, created_at, updated_at,
  sync_status, remote_id
)
SELECT
  id, NULL, 'client-' || lower(hex(randomblob(16))), nombre, telefono, deuda, created_at, updated_at,
  COALESCE(sync_status, 'pending'), remote_id
FROM clientes_legacy_v10
''');
    await db.execute('DROP TABLE clientes_legacy_v10');
    if (telefonoIsUnique) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clientes_telefono ON clientes(telefono)',
      );
    }
  }

  Future<void> _ensureBusinessColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'negocio_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'personal_user_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.pagosTable,
      'negocio_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productosTable,
      'negocio_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'negocio_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.deudaItemsTable,
      'negocio_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.comprobantesTable,
      'negocio_id',
      'INTEGER',
    );
  }

  Future<void> _ensureSyncStatusColumns(Database db) async {
    const tables = [
      DatabaseSchema.clientesTable,
      DatabaseSchema.movimientosTable,
      DatabaseSchema.productosTable,
      DatabaseSchema.usuariosTable,
      DatabaseSchema.subscriptionsTable,
      DatabaseSchema.solicitudesAutorizacionTable,
      DatabaseSchema.auditoriasTable,
      DatabaseSchema.auditoriaItemsTable,
    ];

    for (final table in tables) {
      await _addColumnIfMissing(
        db,
        table,
        'sync_status',
        "TEXT DEFAULT 'pending'",
      );
    }
  }

  Future<void> _ensureSubscriptionBillingColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.subscriptionsTable,
      'billing_cycle',
      "TEXT DEFAULT 'mensual'",
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.subscriptionsTable,
      'discount_percent',
      'INTEGER DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.subscriptionsTable,
      'original_price',
      'REAL',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.subscriptionsTable,
      'final_price',
      'REAL',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.subscriptionsTable,
      'currency_code',
      "TEXT DEFAULT 'USD'",
    );
    await db.execute('''
UPDATE ${DatabaseSchema.subscriptionsTable}
SET
  billing_cycle = COALESCE(billing_cycle, 'mensual'),
  discount_percent = COALESCE(discount_percent, 0),
  original_price = COALESCE(original_price, precio_mensual),
  final_price = COALESCE(final_price, precio_mensual),
  currency_code = COALESCE(currency_code, 'USD')
''');
  }

  Future<void> _ensureClientCloudSyncColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.clientesTable,
      'address',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.clientesTable,
      'is_active',
      'INTEGER DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.clientesTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.clientesTable,
      'last_synced_at',
      'TEXT',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.clientesTable}
SET is_active = COALESCE(is_active, 1)
''');
    await _ensureClientUuidColumns(db);
  }

  Future<void> _ensureClientUuidColumns(Database db) async {
    await _addColumnIfMissing(db, DatabaseSchema.clientesTable, 'uuid', 'TEXT');
    await _addColumnIfMissing(
      db,
      DatabaseSchema.clientesTable,
      'sync_version',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.clientesTable}
SET uuid = 'client-' || lower(hex(randomblob(16)))
WHERE uuid IS NULL OR uuid = ''
''');
    for (final indexStatement in DatabaseSchema.initialIndexes) {
      if (indexStatement.contains('idx_clientes_uuid') ||
          indexStatement.contains('idx_clientes_negocio_uuid') ||
          indexStatement.contains('idx_clientes_negocio_updated_at') ||
          indexStatement.contains('idx_clientes_negocio_deleted_at')) {
        await db.execute(indexStatement);
      }
    }
  }

  Future<void> _ensureProductCloudSyncColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productosTable,
      'sync_version',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productosTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productosTable,
      'last_synced_at',
      'TEXT',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.productosTable}
SET legacy_id = 'product-' || lower(hex(randomblob(16)))
WHERE legacy_id IS NULL OR legacy_id = ''
''');
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'uuid',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'product_uuid',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'remote_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'remote_url',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'storage_key',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'content_hash',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.productoImagenesTable,
      'content_available',
      'INTEGER DEFAULT 1',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.productoImagenesTable}
SET uuid = 'image-' || lower(hex(randomblob(16)))
WHERE uuid IS NULL OR uuid = ''
''');
    await db.execute('''
UPDATE ${DatabaseSchema.productoImagenesTable}
SET product_uuid = (
  SELECT p.legacy_id
  FROM ${DatabaseSchema.productosTable} p
  WHERE p.id = ${DatabaseSchema.productoImagenesTable}.producto_id
)
WHERE product_uuid IS NULL OR product_uuid = ''
''');
    for (final indexStatement in DatabaseSchema.initialIndexes) {
      if (indexStatement.contains('idx_productos_negocio_legacy_id') ||
          indexStatement.contains('idx_productos_negocio_updated_at') ||
          indexStatement.contains('idx_productos_negocio_deleted_at') ||
          indexStatement.contains('idx_producto_imagenes_uuid') ||
          indexStatement.contains('idx_producto_imagenes_product_uuid')) {
        await db.execute(indexStatement);
      }
    }
  }

  Future<void> _ensureFinancialCloudSyncColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'updated_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'is_active',
      'INTEGER DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.deudaItemsTable,
      'remote_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.deudaItemsTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.deudaItemsTable,
      'last_synced_at',
      'TEXT',
    );
    await _ensureFinancialIdempotencyColumns(db);
    await _addColumnIfMissing(
      db,
      DatabaseSchema.comprobantesTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.comprobantesTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.creditoCiclosTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.creditoRecordatoriosTable,
      'remote_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.creditoRecordatoriosTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.creditoExcepcionesTable,
      'remote_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.creditoExcepcionesTable,
      'last_synced_at',
      'TEXT',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.movimientosTable}
SET updated_at = COALESCE(updated_at, created_at),
    is_active = COALESCE(is_active, 1)
''');
  }

  Future<void> _ensureFinancialIdempotencyColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.movimientosTable,
      'local_uuid',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.deudaItemsTable,
      'local_uuid',
      'TEXT',
    );
  }

  Future<void> _ensureNewSyncBaseTables(Database db) async {
    await db.execute(DatabaseSchema.createSyncOutboxTable);
    await db.execute(DatabaseSchema.createSyncStateTable);
    for (final indexStatement in DatabaseSchema.initialIndexes) {
      if (indexStatement.contains('idx_sync_outbox_') ||
          indexStatement.contains('idx_sync_state_')) {
        await db.execute(indexStatement);
      }
    }
  }

  Future<void> _ensureOperationalCloudSyncColumns(Database db) async {
    await _addColumnIfMissing(
      db,
      DatabaseSchema.solicitudesAutorizacionTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.solicitudesAutorizacionTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.auditoriasTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.auditoriasTable,
      'last_synced_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.auditoriaItemsTable,
      'negocio_id',
      'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.auditoriaItemsTable,
      'remote_id',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.auditoriaItemsTable,
      'deleted_at',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DatabaseSchema.auditoriaItemsTable,
      'last_synced_at',
      'TEXT',
    );
    await db.execute('''
UPDATE ${DatabaseSchema.auditoriaItemsTable}
SET negocio_id = (
  SELECT negocio_id
  FROM ${DatabaseSchema.auditoriasTable} a
  WHERE a.id = ${DatabaseSchema.auditoriaItemsTable}.auditoria_id
)
WHERE negocio_id IS NULL
''');
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.map((row) => row['name'] as String).toSet();
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    final db = await database;
    return db.transaction((_) => action());
  }

  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  @override
  Future<void> close() async {
    final currentDatabase = _database;
    if (currentDatabase != null && currentDatabase.isOpen) {
      await currentDatabase.close();
    }
    _database = null;
  }
}
