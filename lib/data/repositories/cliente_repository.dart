import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../../models/cliente.dart';
import '../models/cliente_sqlite_model.dart';
import '../models/sync_outbox_item.dart';
import 'sync_outbox_repository.dart';
import 'sync_queue_repository.dart';

class ClienteRepository {
  final LocalDatabase databaseHelper;
  final SyncQueueRepository syncQueueRepository;
  final SyncOutboxRepository syncOutboxRepository;

  ClienteRepository({
    LocalDatabase? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
    SyncOutboxRepository? syncOutboxRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(),
       syncOutboxRepository =
           syncOutboxRepository ??
           SyncOutboxRepository(databaseHelper: databaseHelper);

  Future<List<Cliente>> obtenerClientes({
    required int negocioId,
    int limit = 50,
    int offset = 0,
    String? busqueda,
  }) async {
    final db = await databaseHelper.database;
    final normalizedSearch = busqueda?.trim();
    final whereParts = <String>['negocio_id = ?'];
    final whereArgs = <Object?>[negocioId];
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      whereParts.add('(nombre LIKE ? OR telefono LIKE ?)');
      whereArgs.addAll(['%$normalizedSearch%', '%$normalizedSearch%']);
    }
    whereParts.add('COALESCE(is_active, 1) = 1');

    final rows = await db.query(
      DatabaseSchema.clientesTable,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'nombre COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );

    return _clientesConSaldoCalculado(db: db, negocioId: negocioId, rows: rows);
  }

  Future<Cliente?> buscarPorTelefono(
    String telefono, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      where: 'negocio_id = ? AND telefono = ? AND COALESCE(is_active, 1) = 1',
      whereArgs: [negocioId, telefono],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final clientes = await _clientesConSaldoCalculado(
      db: db,
      negocioId: negocioId,
      rows: rows,
    );
    return clientes.first;
  }

  Future<bool> existeClientePorTelefono(String telefono, int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      columns: ['id'],
      where: 'negocio_id = ? AND telefono = ? AND COALESCE(is_active, 1) = 1',
      whereArgs: [negocioId, telefono],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> existeClientePorNombre(String nombre, int negocioId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      columns: ['id'],
      where:
          'negocio_id = ? AND LOWER(nombre) = LOWER(?) AND COALESCE(is_active, 1) = 1',
      whereArgs: [negocioId, nombre.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> guardarCliente(Cliente cliente, {required int negocioId}) async {
    final db = await databaseHelper.database;
    final model = ClienteSqliteModel.fromLegacy(cliente, negocioId: negocioId);
    final existing = await db.query(
      DatabaseSchema.clientesTable,
      where: 'negocio_id = ? AND telefono = ?',
      whereArgs: [negocioId, cliente.telefono],
      limit: 1,
    );

    final int entityId;
    late final ClienteSqliteModel savedModel;
    late final String operation;
    if (existing.isEmpty) {
      entityId = await db.insert(
        DatabaseSchema.clientesTable,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      savedModel = model.copyWith(id: entityId);
      operation = 'create';
    } else {
      entityId = existing.first['id'] as int;
      final current = ClienteSqliteModel.fromMap(existing.first);
      savedModel = model.copyWith(
        id: entityId,
        uuid: current.uuid,
        createdAt: current.createdAt,
        syncVersion: current.syncVersion + 1,
        syncStatus: SyncStatus.updated,
      );
      await db.update(
        DatabaseSchema.clientesTable,
        savedModel.toMap(includeId: true),
        where: 'id = ?',
        whereArgs: [entityId],
      );
      operation = 'update';
    }
    await _enqueueClientOutbox(savedModel, operation);
  }

  Future<void> actualizarCliente({
    required Cliente cliente,
    required int negocioId,
    String? telefonoAnterior,
  }) async {
    final db = await databaseHelper.database;
    var model = ClienteSqliteModel.fromLegacy(
      cliente,
      negocioId: negocioId,
    ).copyWith(syncStatus: SyncStatus.updated, updatedAt: DateTime.now());
    var entityId = model.id;
    ClienteSqliteModel? savedModel;

    await db.transaction((transaction) async {
      if (telefonoAnterior != null && telefonoAnterior != cliente.telefono) {
        final previousRows = await transaction.query(
          DatabaseSchema.clientesTable,
          where: 'negocio_id = ? AND telefono = ?',
          whereArgs: [negocioId, telefonoAnterior],
          limit: 1,
        );
        entityId = previousRows.isEmpty
            ? null
            : previousRows.first['id'] as int?;
      }

      entityId ??= cliente.id;

      if (entityId == null) {
        final existingRows = await transaction.query(
          DatabaseSchema.clientesTable,
          columns: ['id'],
          where: 'negocio_id = ? AND telefono = ?',
          whereArgs: [negocioId, cliente.telefono],
          limit: 1,
        );
        entityId = existingRows.isEmpty
            ? null
            : existingRows.first['id'] as int?;
      }

      if (entityId != null) {
        final duplicates = await transaction.query(
          DatabaseSchema.clientesTable,
          columns: ['id'],
          where:
              'negocio_id = ? AND telefono = ? AND id != ? AND COALESCE(is_active, 1) = 1',
          whereArgs: [negocioId, cliente.telefono, entityId],
          limit: 1,
        );
        if (duplicates.isNotEmpty) {
          throw StateError(
            'Ya existe un cliente con ese telefono en este negocio.',
          );
        }
      }

      if (entityId == null) {
        entityId = await transaction.insert(
          DatabaseSchema.clientesTable,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        savedModel = model.copyWith(id: entityId);
      } else {
        final currentRows = await transaction.query(
          DatabaseSchema.clientesTable,
          where: 'id = ?',
          whereArgs: [entityId],
          limit: 1,
        );
        if (currentRows.isNotEmpty) {
          final current = ClienteSqliteModel.fromMap(currentRows.first);
          model = model.copyWith(
            uuid: current.uuid,
            createdAt: current.createdAt,
            syncVersion: current.syncVersion + 1,
          );
        }
        await transaction.update(
          DatabaseSchema.clientesTable,
          model.copyWith(id: entityId).toMap(includeId: true),
          where: 'id = ?',
          whereArgs: [entityId],
        );
        savedModel = model.copyWith(id: entityId);
      }
    });
    await _enqueueClientOutbox(savedModel!, 'update');
  }

  Future<void> eliminarPorTelefono(
    String telefono, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      where: 'negocio_id = ? AND telefono = ?',
      whereArgs: [negocioId, telefono],
      limit: 1,
    );
    final deletedAt = DateTime.now();
    await db.update(
      DatabaseSchema.clientesTable,
      {
        'is_active': 0,
        'deleted_at': deletedAt.toIso8601String(),
        'updated_at': deletedAt.toIso8601String(),
        'sync_version':
            ((rows.firstOrNull?['sync_version'] as num?) ?? 0).toInt() + 1,
        'sync_status': SyncStatus.deleted,
      },
      where: 'negocio_id = ? AND telefono = ?',
      whereArgs: [negocioId, telefono],
    );
    if (rows.isNotEmpty) {
      final model = ClienteSqliteModel.fromMap(rows.first).copyWith(
        isActive: false,
        deletedAt: deletedAt,
        updatedAt: deletedAt,
        syncVersion: ((rows.first['sync_version'] as num?) ?? 0).toInt() + 1,
        syncStatus: SyncStatus.deleted,
      );
      await _enqueueClientOutbox(model, 'delete');
    }
  }

  Future<void> guardarClientes(
    List<Cliente> clientes, {
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    await db.transaction((transaction) async {
      await transaction.delete(
        DatabaseSchema.clientesTable,
        where: 'negocio_id = ?',
        whereArgs: [negocioId],
      );
      final batch = transaction.batch();

      for (final cliente in clientes) {
        batch.insert(
          DatabaseSchema.clientesTable,
          ClienteSqliteModel.fromLegacy(cliente, negocioId: negocioId).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    for (final cliente in clientes) {
      final rows = await db.query(
        DatabaseSchema.clientesTable,
        where: 'negocio_id = ? AND telefono = ?',
        whereArgs: [negocioId, cliente.telefono],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await syncQueueRepository.enqueueCreate(
          entityType: DatabaseSchema.clientesTable,
          entityId: rows.first['id'] as int,
          payload: rows.first,
        );
      }
    }
  }

  Future<void> upsertFromSync({
    required int negocioId,
    required Map<String, Object?> payload,
  }) async {
    final db = await databaseHelper.database;
    final uuid = payload['uuid'] as String? ?? payload['entityUuid'] as String?;
    if (uuid == null || uuid.trim().isEmpty) return;
    final now = DateTime.now();
    final updatedAt =
        DateTime.tryParse(payload['updatedAt']?.toString() ?? '') ?? now;
    final deletedAt = DateTime.tryParse(payload['deletedAt']?.toString() ?? '');
    final existing = await db.query(
      DatabaseSchema.clientesTable,
      where: 'negocio_id = ? AND uuid = ?',
      whereArgs: [negocioId, uuid],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final localUpdated = DateTime.tryParse(
        existing.first['updated_at']?.toString() ?? '',
      );
      if (localUpdated != null && localUpdated.isAfter(updatedAt)) return;
    }
    final values = {
      'negocio_id': negocioId,
      'uuid': uuid,
      'nombre':
          payload['nombre'] as String? ?? payload['name'] as String? ?? '',
      'telefono':
          payload['telefono'] as String? ?? payload['phone'] as String? ?? '',
      'address':
          payload['direccion'] as String? ?? payload['address'] as String?,
      'deuda': (payload['deuda'] as num? ?? payload['debt'] as num? ?? 0)
          .toDouble(),
      'is_active': deletedAt == null ? 1 : 0,
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at':
          payload['createdAt'] as String? ??
          existing.firstOrNull?['created_at'] as String? ??
          now.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_version': (payload['syncVersion'] as num? ?? 0).toInt(),
      'sync_status': SyncStatus.synced,
      'remote_id': payload['serverId'] as String? ?? payload['id'] as String?,
      'last_synced_at': now.toIso8601String(),
    };
    if (existing.isEmpty) {
      await db.insert(DatabaseSchema.clientesTable, values);
    } else {
      await db.update(
        DatabaseSchema.clientesTable,
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<void> markClientSyncedByUuid({
    required String uuid,
    required DateTime serverTime,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.clientesTable,
      {
        'sync_status': SyncStatus.synced,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': serverTime.toIso8601String(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> _enqueueClientOutbox(
    ClienteSqliteModel model,
    String operation,
  ) async {
    await syncOutboxRepository.enqueue(
      SyncOutboxItem.pending(
        businessId: model.negocioId.toString(),
        module: 'clients',
        entityType: 'client',
        entityUuid: model.uuid,
        operation: operation,
        payload: {
          'uuid': model.uuid,
          'businessId': model.negocioId.toString(),
          'nombre': model.nombre,
          'telefono': model.telefono,
          'direccion': model.address,
          'deuda': model.deuda,
          'updatedAt': model.updatedAt.toIso8601String(),
          'deletedAt': model.deletedAt?.toIso8601String(),
          'syncVersion': model.syncVersion,
        },
      ),
    );
  }

  Future<void> recalcularDeudasDesdeMovimientos({
    required int negocioId,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientesTable,
      columns: ['id', 'nombre', 'telefono', 'deuda'],
      where: 'negocio_id = ? AND COALESCE(is_active, 1) = 1',
      whereArgs: [negocioId],
    );
    for (final row in rows) {
      final deuda = await _calcularDeudaCliente(
        db: db,
        negocioId: negocioId,
        id: (row['id'] as num?)?.toInt(),
        nombre: row['nombre'] as String? ?? '',
        telefono: row['telefono'] as String? ?? '',
      );
      final actual = (row['deuda'] as num? ?? 0).toDouble();
      if ((actual - deuda).abs() < 0.01) continue;
      await db.update(
        DatabaseSchema.clientesTable,
        {'deuda': deuda},
        where: 'id = ? AND negocio_id = ?',
        whereArgs: [row['id'], negocioId],
      );
    }
  }

  Future<List<Cliente>> _clientesConSaldoCalculado({
    required Database db,
    required int negocioId,
    required List<Map<String, Object?>> rows,
  }) async {
    final clientes = <Cliente>[];
    for (final row in rows) {
      final model = ClienteSqliteModel.fromMap(row);
      final cliente = model.toLegacyModel();
      cliente.deuda = await _calcularDeudaCliente(
        db: db,
        negocioId: negocioId,
        id: model.id,
        nombre: model.nombre,
        telefono: model.telefono,
      );
      clientes.add(cliente);
    }
    return clientes;
  }

  Future<double> _calcularDeudaCliente({
    required Database db,
    required int negocioId,
    required int? id,
    required String nombre,
    required String telefono,
  }) async {
    final rows = await db.rawQuery(
      '''
SELECT COALESCE(SUM(
  CASE
    WHEN tipo = 'deuda' THEN monto
    WHEN tipo = 'pago' THEN -monto
    ELSE 0
  END
), 0) AS saldo
FROM ${DatabaseSchema.movimientosTable}
WHERE negocio_id = ?
  AND COALESCE(is_active, 1) = 1
  AND deleted_at IS NULL
  AND (
    (? IS NOT NULL AND cliente_id = ?)
    OR (
      cliente_id IS NULL
      AND ? != ''
      AND (
        cliente_telefono = ?
        OR cliente_telefono_snapshot = ?
      )
    )
    OR (
      cliente_id IS NULL
      AND ? != ''
      AND (
        LOWER(cliente_nombre) = LOWER(?)
        OR LOWER(cliente_nombre_snapshot) = LOWER(?)
      )
    )
  )
''',
      [negocioId, id, id, telefono, telefono, telefono, nombre, nombre, nombre],
    );
    final saldo = (rows.first['saldo'] as num? ?? 0).toDouble();
    return saldo < 0 ? 0 : saldo;
  }
}
