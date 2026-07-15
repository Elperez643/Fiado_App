import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/deuda_item_sqlite_model.dart';
import 'sync_queue_repository.dart';

class DeudaItemRepository {
  static const double _toleranciaMonto = 0.01;

  final DatabaseHelper databaseHelper;
  final SyncQueueRepository syncQueueRepository;

  DeudaItemRepository({
    DatabaseHelper? databaseHelper,
    SyncQueueRepository? syncQueueRepository,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       syncQueueRepository = syncQueueRepository ?? SyncQueueRepository();

  Future<List<DeudaItemSqliteModel>> crearItemsParaMovimiento({
    required int negocioId,
    required int movimientoId,
    required List<DeudaItemSqliteModel> items,
    Transaction? transaction,
    bool encolar = true,
  }) async {
    validarItems(items);
    final db = transaction ?? await databaseHelper.database;
    final now = DateTime.now();
    final guardados = <DeudaItemSqliteModel>[];

    for (final item in items) {
      final normalizado = item.copyWith(
        negocioId: negocioId,
        movimientoId: movimientoId,
        nombreProducto: item.nombreProducto.trim(),
        codigoReferencia: item.codigoReferencia?.trim().isEmpty ?? true
            ? null
            : item.codigoReferencia!.trim(),
        subtotal: item.cantidad * item.precioUnitario,
        createdAt: item.createdAt ?? now,
        updatedAt: item.updatedAt ?? now,
        syncStatus: item.syncStatus,
        localUuid: item.localUuid ?? newDebtItemLocalUuid(),
      );
      final id = await db.insert(
        DatabaseSchema.deudaItemsTable,
        normalizado.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      guardados.add(normalizado.copyWith(id: id));
    }

    if (encolar) {
      for (final item in guardados) {
        await syncQueueRepository.enqueueCreate(
          entityType: DatabaseSchema.deudaItemsTable,
          entityId: item.id!,
          payload: item.toMap(includeId: true),
        );
      }
    }
    debugPrint(
      '[deuda-items] items consultados/guardados movimiento_id=$movimientoId count=${guardados.length}',
    );

    return guardados;
  }

  Future<List<DeudaItemSqliteModel>> obtenerItemsPorMovimiento(
    int movimientoId, {
    int? negocioId,
  }) async {
    final db = await databaseHelper.database;
    final where = negocioId == null
        ? 'movimiento_id = ? AND sync_status != ?'
        : 'negocio_id = ? AND movimiento_id = ? AND sync_status != ?';
    final args = negocioId == null
        ? <Object?>[movimientoId, SyncStatus.deleted]
        : <Object?>[negocioId, movimientoId, SyncStatus.deleted];
    final rows = await db.query(
      DatabaseSchema.deudaItemsTable,
      where: where,
      whereArgs: args,
      orderBy: 'id ASC',
    );
    debugPrint(
      '[deuda-items] items consultados movimiento_id=$movimientoId count=${rows.length}',
    );
    return rows.map(DeudaItemSqliteModel.fromMap).toList();
  }

  Future<void> eliminarItemsPorMovimiento(int movimientoId) async {
    final db = await databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.deudaItemsTable,
      where: 'movimiento_id = ? AND sync_status != ?',
      whereArgs: [movimientoId, SyncStatus.deleted],
    );
    await db.update(
      DatabaseSchema.deudaItemsTable,
      {
        'sync_status': SyncStatus.deleted,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'movimiento_id = ? AND sync_status != ?',
      whereArgs: [movimientoId, SyncStatus.deleted],
    );

    for (final row in rows) {
      await syncQueueRepository.enqueueDelete(
        entityType: DatabaseSchema.deudaItemsTable,
        entityId: row['id'] as int,
        payload: {...row, 'sync_status': SyncStatus.deleted},
      );
    }
  }

  double calcularTotalItems(List<DeudaItemSqliteModel> items) {
    return items.fold<double>(0, (total, item) => total + item.subtotal);
  }

  void validarItems(List<DeudaItemSqliteModel> items) {
    for (final item in items) {
      if (item.nombreProducto.trim().isEmpty) {
        throw StateError('El nombre del producto es obligatorio.');
      }
      if (item.cantidad <= 0) {
        throw StateError('La cantidad debe ser mayor que 0.');
      }
      if (item.precioUnitario < 0) {
        throw StateError('El precio unitario no puede ser negativo.');
      }
      final subtotalEsperado = item.cantidad * item.precioUnitario;
      if ((item.subtotal - subtotalEsperado).abs() > _toleranciaMonto) {
        throw StateError('El subtotal no coincide con cantidad por precio.');
      }
    }
  }
}
