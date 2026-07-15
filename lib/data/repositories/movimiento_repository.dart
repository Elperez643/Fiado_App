import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../../models/movimiento.dart';
import '../models/deuda_item_sqlite_model.dart';
import '../models/credito_ciclo_sqlite_model.dart';
import '../models/movimiento_sqlite_model.dart';
import 'credito_ciclo_repository.dart';
import 'deuda_item_repository.dart';
import 'inventory_product_metrics_repository.dart';
import 'sync_queue_repository.dart';

class MovimientoRepository {
  final DatabaseHelper databaseHelper;
  final SyncQueueRepository syncQueueRepository;
  final DeudaItemRepository deudaItemRepository;
  final CreditoCicloRepository creditoCicloRepository;
  final InventoryProductMetricsRepository inventoryMetricsRepository;

  MovimientoRepository({
    DatabaseHelper? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
    DeudaItemRepository? deudaItemRepository,
    CreditoCicloRepository? creditoCicloRepository,
    InventoryProductMetricsRepository? inventoryMetricsRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository(),
       deudaItemRepository = deudaItemRepository ?? DeudaItemRepository(),
       creditoCicloRepository =
           creditoCicloRepository ?? CreditoCicloRepository(),
       inventoryMetricsRepository =
           inventoryMetricsRepository ?? InventoryProductMetricsRepository();

  Future<List<Movimiento>> obtenerMovimientos({
    required int negocioId,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.movimientosTable,
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
      orderBy: 'fecha DESC',
      limit: limit,
      offset: offset,
    );

    return rows
        .map((row) => MovimientoSqliteModel.fromMap(row).toLegacyModel())
        .toList();
  }

  Future<List<Movimiento>> obtenerPorCliente({
    required int negocioId,
    required String nombreCliente,
    String? clienteTelefono,
    int? clienteId,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await databaseHelper.database;
    final where = clienteId != null
        ? '''
negocio_id = ? AND (
  cliente_id = ?
  OR (cliente_id IS NULL AND cliente_telefono = ?)
  OR (cliente_id IS NULL AND LOWER(cliente_nombre) = LOWER(?))
)
'''
        : clienteTelefono == null || clienteTelefono.trim().isEmpty
        ? 'negocio_id = ? AND cliente_id IS NULL AND cliente_nombre = ?'
        : 'negocio_id = ? AND cliente_id IS NULL AND cliente_telefono = ?';
    final args = clienteId != null
        ? <Object?>[negocioId, clienteId, clienteTelefono, nombreCliente]
        : clienteTelefono == null || clienteTelefono.trim().isEmpty
        ? <Object?>[negocioId, nombreCliente]
        : <Object?>[negocioId, clienteTelefono];
    final rows = await db.query(
      DatabaseSchema.movimientosTable,
      where: where,
      whereArgs: args,
      orderBy: 'fecha DESC',
      limit: limit,
      offset: offset,
    );

    return rows
        .map((row) => MovimientoSqliteModel.fromMap(row).toLegacyModel())
        .toList();
  }

  Future<int> guardarMovimiento(
    Movimiento movimiento, {
    required int negocioId,
    int? personalUserId,
    String? clienteTelefono,
    bool fiarDeTodosModos = false,
    String? motivoExcepcion,
    int? usuarioIdExcepcion,
    List<DeudaItemSqliteModel> deudaItems = const [],
  }) async {
    if (deudaItems.isNotEmpty) {
      return guardarDeudaConDetalle(
        negocioId: negocioId,
        movimiento: movimiento,
        items: deudaItems,
        personalUserId: personalUserId,
        clienteTelefono: clienteTelefono,
        fiarDeTodosModos: fiarDeTodosModos,
        motivoExcepcion: motivoExcepcion,
        usuarioIdExcepcion: usuarioIdExcepcion,
      );
    }

    late final int id;
    late final Map<String, Object?> movimientoPayload;
    CreditoCicloSqliteModel? cicloActualizado;
    Map<String, Object?>? excepcionPayload;
    final clienteId = await creditoCicloRepository.resolverClienteId(
      negocioId: negocioId,
      telefono: clienteTelefono ?? movimiento.clienteTelefono,
      nombre: movimiento.nombreCliente,
    );
    if (clienteId == null) {
      throw StateError(
        'No se encontro el cliente local para asignar el ciclo.',
      );
    }
    final model = MovimientoSqliteModel.fromLegacy(
      movimiento,
      negocioId: negocioId,
      personalUserId: personalUserId,
      clienteId: clienteId,
      clienteTelefono: clienteTelefono ?? movimiento.clienteTelefono,
      clienteNombreSnapshot: movimiento.nombreCliente,
      clienteTelefonoSnapshot: clienteTelefono ?? movimiento.clienteTelefono,
    );
    CreditoCicloSqliteModel? cicloBloqueado;
    if (movimiento.tipo == 'deuda') {
      final bloqueado = await creditoCicloRepository.clienteTieneBloqueoFiado(
        clienteId,
        negocioId,
      );
      if (bloqueado) {
        cicloBloqueado = await creditoCicloRepository.obtenerCicloActual(
          clienteId,
          negocioId,
        );
        if (!fiarDeTodosModos) {
          throw CreditoBloqueadoException(
            cicloBloqueado ??
                CreditoCicloSqliteModel.nuevo(
                  negocioId: negocioId,
                  clienteId: clienteId,
                  fechaInicio: movimiento.fecha,
                ),
          );
        }
      }
    }

    await databaseHelper.runInTransaction((transaction) async {
      id = await transaction.insert(
        DatabaseSchema.movimientosTable,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      movimientoPayload = {...model.toMap(), 'id': id};

      if (movimiento.tipo == 'deuda') {
        cicloActualizado = await creditoCicloRepository.asignarDeudaACiclo(
          movimientoId: id,
          clienteId: clienteId,
          negocioId: negocioId,
          monto: movimiento.monto,
          fecha: movimiento.fecha,
          transaction: transaction,
        );
        if (fiarDeTodosModos) {
          final excepcion = await creditoCicloRepository
              .registrarExcepcionFiarDeTodosModos(
                cicloId: cicloBloqueado?.id ?? cicloActualizado!.id!,
                negocioId: negocioId,
                clienteId: clienteId,
                usuarioId: usuarioIdExcepcion ?? personalUserId ?? negocioId,
                montoFiado: movimiento.monto,
                movimientoId: id,
                motivo: motivoExcepcion,
                fecha: movimiento.fecha,
                transaction: transaction,
              );
          excepcionPayload = excepcion.toMap(includeId: true);
        }
      } else if (movimiento.tipo == 'pago') {
        await creditoCicloRepository.registrarPagoEnCiclos(
          clienteId: clienteId,
          negocioId: negocioId,
          movimientoId: id,
          montoPago: movimiento.monto,
          fecha: movimiento.fecha,
          transaction: transaction,
        );
      }
    });

    await syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.movimientosTable,
      entityId: id,
      payload: movimientoPayload,
    );
    if (cicloActualizado?.id != null) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.creditoCiclosTable,
        entityId: cicloActualizado!.id!,
        payload: cicloActualizado!.toMap(includeId: true),
      );
    }
    if (excepcionPayload != null) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.creditoExcepcionesTable,
        entityId: excepcionPayload!['id'] as int,
        payload: excepcionPayload!,
      );
    }
    return id;
  }

  Future<int> guardarMovimientoInformativo({
    required int negocioId,
    int? personalUserId,
    required Movimiento movimiento,
  }) async {
    final db = await databaseHelper.database;
    final model = MovimientoSqliteModel.fromLegacy(
      movimiento,
      negocioId: negocioId,
      personalUserId: personalUserId,
    );
    final id = await db.insert(
      DatabaseSchema.movimientosTable,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.movimientosTable,
      entityId: id,
      payload: {...model.toMap(), 'id': id},
    );
    return id;
  }

  Future<int> guardarDeudaConDetalle({
    required int negocioId,
    required Movimiento movimiento,
    required List<DeudaItemSqliteModel> items,
    int? personalUserId,
    String? clienteTelefono,
    bool fiarDeTodosModos = false,
    String? motivoExcepcion,
    int? usuarioIdExcepcion,
  }) async {
    if (movimiento.tipo != 'deuda' && movimiento.tipo != 'pago') {
      throw StateError(
        'El detalle de mercancias solo aplica a compras registradas como deuda o pago.',
      );
    }
    deudaItemRepository.validarItems(items);
    if (items.isNotEmpty && movimiento.monto < 0) {
      throw StateError('El monto total no puede ser negativo.');
    }
    debugPrint(
      '[deuda-items] guardando deuda con detalle items=${items.length} montoFinal=${movimiento.monto}',
    );

    late final int movimientoId;
    late final Map<String, Object?> movimientoPayload;
    late final List<DeudaItemSqliteModel> itemsGuardados;
    late final List<Map<String, Object?>> productosActualizados;
    CreditoCicloSqliteModel? cicloActualizado;
    Map<String, Object?>? excepcionPayload;
    final clienteId = await creditoCicloRepository.resolverClienteId(
      negocioId: negocioId,
      telefono: clienteTelefono ?? movimiento.clienteTelefono,
      nombre: movimiento.nombreCliente,
    );
    if (clienteId == null) {
      throw StateError(
        'No se encontro el cliente local para asignar el ciclo.',
      );
    }
    final model = MovimientoSqliteModel.fromLegacy(
      movimiento,
      negocioId: negocioId,
      personalUserId: personalUserId,
      clienteId: clienteId,
      clienteTelefono: clienteTelefono ?? movimiento.clienteTelefono,
      clienteNombreSnapshot: movimiento.nombreCliente,
      clienteTelefonoSnapshot: clienteTelefono ?? movimiento.clienteTelefono,
    );
    CreditoCicloSqliteModel? cicloBloqueado;
    if (movimiento.tipo == 'deuda') {
      final bloqueado = await creditoCicloRepository.clienteTieneBloqueoFiado(
        clienteId,
        negocioId,
      );
      if (bloqueado) {
        cicloBloqueado = await creditoCicloRepository.obtenerCicloActual(
          clienteId,
          negocioId,
        );
        if (!fiarDeTodosModos) {
          throw CreditoBloqueadoException(
            cicloBloqueado ??
                CreditoCicloSqliteModel.nuevo(
                  negocioId: negocioId,
                  clienteId: clienteId,
                  fechaInicio: movimiento.fecha,
                ),
          );
        }
      }
    }

    await databaseHelper.runInTransaction((transaction) async {
      movimientoId = await transaction.insert(
        DatabaseSchema.movimientosTable,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('[deuda-items] movimiento insertado id=$movimientoId');
      movimientoPayload = {...model.toMap(), 'id': movimientoId};
      itemsGuardados = await deudaItemRepository.crearItemsParaMovimiento(
        negocioId: negocioId,
        movimientoId: movimientoId,
        items: items,
        transaction: transaction,
        encolar: false,
      );
      debugPrint(
        '[deuda-items] items guardados count=${itemsGuardados.length}',
      );
      productosActualizados = await _descontarInventarioPorCompra(
        transaction,
        negocioId,
        itemsGuardados,
      );
      if (movimiento.tipo == 'deuda') {
        cicloActualizado = await creditoCicloRepository.asignarDeudaACiclo(
          movimientoId: movimientoId,
          clienteId: clienteId,
          negocioId: negocioId,
          monto: movimiento.monto,
          fecha: movimiento.fecha,
          transaction: transaction,
        );
        if (fiarDeTodosModos) {
          final excepcion = await creditoCicloRepository
              .registrarExcepcionFiarDeTodosModos(
                cicloId: cicloBloqueado?.id ?? cicloActualizado!.id!,
                negocioId: negocioId,
                clienteId: clienteId,
                usuarioId: usuarioIdExcepcion ?? personalUserId ?? negocioId,
                montoFiado: movimiento.monto,
                movimientoId: movimientoId,
                motivo: motivoExcepcion,
                fecha: movimiento.fecha,
                transaction: transaction,
              );
          excepcionPayload = excepcion.toMap(includeId: true);
        }
      } else if (movimiento.tipo == 'pago') {
        await creditoCicloRepository.registrarPagoEnCiclos(
          clienteId: clienteId,
          negocioId: negocioId,
          movimientoId: movimientoId,
          montoPago: movimiento.monto,
          fecha: movimiento.fecha,
          transaction: transaction,
        );
      }
    });

    await syncQueueRepository.enqueueCreate(
      entityType: DatabaseSchema.movimientosTable,
      entityId: movimientoId,
      payload: movimientoPayload,
    );
    for (final item in itemsGuardados) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.deudaItemsTable,
        entityId: item.id!,
        payload: item.toMap(includeId: true),
      );
    }
    for (final producto in productosActualizados) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.productosTable,
        entityId: producto['id'] as int,
        payload: producto,
      );
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: producto['id'] as int,
      );
    }
    if (cicloActualizado?.id != null) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.creditoCiclosTable,
        entityId: cicloActualizado!.id!,
        payload: cicloActualizado!.toMap(includeId: true),
      );
    }
    if (excepcionPayload != null) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.creditoExcepcionesTable,
        entityId: excepcionPayload!['id'] as int,
        payload: excepcionPayload!,
      );
    }
    return movimientoId;
  }

  Future<List<Map<String, Object?>>> _descontarInventarioPorCompra(
    Transaction transaction,
    int negocioId,
    List<DeudaItemSqliteModel> items,
  ) async {
    final cantidadesPorProducto = <int, int>{};
    for (final item in items) {
      final productoId = item.productoId;
      if (productoId == null) continue;
      cantidadesPorProducto[productoId] =
          (cantidadesPorProducto[productoId] ?? 0) + item.cantidad;
    }

    if (cantidadesPorProducto.isEmpty) {
      return const <Map<String, Object?>>[];
    }

    final actualizados = <Map<String, Object?>>[];
    final now = DateTime.now().toIso8601String();

    for (final entry in cantidadesPorProducto.entries) {
      final productoId = entry.key;
      final cantidadComprada = entry.value;
      final rows = await transaction.query(
        DatabaseSchema.productosTable,
        where: 'negocio_id = ? AND id = ? AND activo = ?',
        whereArgs: [negocioId, productoId, 1],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('No se encontro uno de los productos seleccionados.');
      }

      final producto = rows.first;
      final stockActual = (producto['cantidad'] as num).toInt();
      if (stockActual < cantidadComprada) {
        throw StateError(
          'Stock insuficiente para ${producto['nombre']}. Disponible: $stockActual.',
        );
      }

      final nuevoStock = stockActual - cantidadComprada;
      await transaction.update(
        DatabaseSchema.productosTable,
        {
          'cantidad': nuevoStock,
          'sync_status': SyncStatus.updated,
          'updated_at': now,
        },
        where: 'id = ? AND negocio_id = ?',
        whereArgs: [productoId, negocioId],
      );

      actualizados.add({
        ...producto,
        'cantidad': nuevoStock,
        'sync_status': SyncStatus.updated,
        'updated_at': now,
      });
    }

    return actualizados;
  }

  Future<void> renombrarCliente({
    required int negocioId,
    required String nombreAnterior,
    required String nombreNuevo,
  }) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.movimientosTable,
      where: 'negocio_id = ? AND cliente_id IS NULL AND cliente_nombre = ?',
      whereArgs: [negocioId, nombreAnterior],
    );
    await db.update(
      DatabaseSchema.movimientosTable,
      {'cliente_nombre': nombreNuevo, 'sync_status': SyncStatus.updated},
      where: 'negocio_id = ? AND cliente_id IS NULL AND cliente_nombre = ?',
      whereArgs: [negocioId, nombreAnterior],
    );
    for (final row in rows) {
      await syncQueueRepository.enqueueUpdate(
        entityType: DatabaseSchema.movimientosTable,
        entityId: row['id'] as int,
        payload: {
          ...row,
          'cliente_nombre': nombreNuevo,
          'sync_status': SyncStatus.updated,
        },
      );
    }
  }

  Future<void> eliminarPorCliente(
    String nombreCliente, {
    required int negocioId,
    int? clienteId,
    String? clienteTelefono,
  }) async {
    final db = await databaseHelper.database;
    final where = clienteId != null
        ? 'negocio_id = ? AND (cliente_id = ? OR (cliente_id IS NULL AND cliente_nombre = ?))'
        : clienteTelefono == null || clienteTelefono.trim().isEmpty
        ? 'negocio_id = ? AND cliente_nombre = ?'
        : 'negocio_id = ? AND (cliente_telefono = ? OR cliente_nombre = ?)';
    final args = clienteId != null
        ? <Object?>[negocioId, clienteId, nombreCliente]
        : clienteTelefono == null || clienteTelefono.trim().isEmpty
        ? <Object?>[negocioId, nombreCliente]
        : <Object?>[negocioId, clienteTelefono, nombreCliente];
    final rows = await db.query(
      DatabaseSchema.movimientosTable,
      where: where,
      whereArgs: args,
    );
    await db.delete(
      DatabaseSchema.movimientosTable,
      where: where,
      whereArgs: args,
    );
    for (final row in rows) {
      await syncQueueRepository.enqueueDelete(
        entityType: DatabaseSchema.movimientosTable,
        entityId: row['id'] as int,
        payload: {
          ...row,
          'sync_status': SyncStatus.deleted,
          'deleted_at': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  Future<void> guardarMovimientos(
    List<Movimiento> movimientos, {
    required int negocioId,
  }) async {
    await databaseHelper.runInTransaction((transaction) async {
      await transaction.delete(
        DatabaseSchema.movimientosTable,
        where: 'negocio_id = ?',
        whereArgs: [negocioId],
      );
      final batch = transaction.batch();

      for (final movimiento in movimientos) {
        batch.insert(
          DatabaseSchema.movimientosTable,
          MovimientoSqliteModel.fromLegacy(
            movimiento,
            negocioId: negocioId,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });

    final db = await databaseHelper.database;
    final rows = await db.query(DatabaseSchema.movimientosTable);
    for (final row in rows) {
      await syncQueueRepository.enqueueCreate(
        entityType: DatabaseSchema.movimientosTable,
        entityId: row['id'] as int,
        payload: row,
      );
    }
  }
}
