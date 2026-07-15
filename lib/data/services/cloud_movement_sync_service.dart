import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/cliente_repository.dart';
import '../repositories/inventory_product_metrics_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class CloudMovementSyncService {
  static const _lastMovementSyncPrefix = 'fiado_movements_last_sync_';
  static const _lastDebtItemSyncPrefix = 'fiado_debt_items_last_sync_';

  final ApiClient apiClient;
  final FinancialSyncHelpers helpers;
  final ClienteRepository clienteRepository;
  final InventoryProductMetricsRepository inventoryMetricsRepository;

  CloudMovementSyncService({
    required this.apiClient,
    required AuthRepository authRepository,
    required SyncQueueRepository syncQueueRepository,
    required LocalDatabase databaseHelper,
    required Future<SharedPreferences> sharedPreferences,
    ClienteRepository? clienteRepository,
    InventoryProductMetricsRepository? inventoryMetricsRepository,
  }) : helpers = FinancialSyncHelpers(
         authRepository: authRepository,
         syncQueueRepository: syncQueueRepository,
         databaseHelper: databaseHelper,
         sharedPreferences: sharedPreferences,
       ),
       clienteRepository =
           clienteRepository ??
           ClienteRepository(
             databaseHelper: databaseHelper,
             syncQueueRepository: syncQueueRepository,
           ),
       inventoryMetricsRepository =
           inventoryMetricsRepository ?? InventoryProductMetricsRepository();

  Future<FinancialCloudSyncResult> syncMovementsAndDebtItems() async {
    final stopwatch = Stopwatch()..start();
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastMovementSyncPrefix$negocioId');
    final movements = await pushPendingMovements();
    final pulledMovements = await pullMovements();
    final debtItems = await pushPendingDebtItems();
    final pulledDebtItems = await pullDebtItems();
    await clienteRepository.recalcularDeudasDesdeMovimientos(
      negocioId: negocioId,
    );
    final result = movements
        .combine(pulledMovements)
        .combine(debtItems)
        .combine(pulledDebtItems);
    final pendingCount =
        (await helpers.syncQueueRepository.obtenerResumen()).pendingCount;
    debugPrint(
      '[sync-contable] businessId=$negocioId uploaded=${result.sent} downloaded=${result.received} '
      'pendingCount=$pendingCount lastSyncAt=$lastSyncAt elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return result;
  }

  Future<FinancialCloudSyncResult> pushPendingMovements() async {
    final negocioId = await helpers.resolveNegocioId();
    final stopwatch = Stopwatch()..start();
    final pending = await helpers.pendingItems(DatabaseSchema.movimientosTable);
    if (pending.isEmpty) return _empty();

    final items = <Map<String, Object?>>[];
    var preErrors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final localUuid = await _ensureLocalUuid(
        table: DatabaseSchema.movimientosTable,
        localId: item.entityId,
        payload: payload,
        prefix: 'movement',
      );
      final client =
          await helpers.resolveClientByLocalId(
            negocioId: negocioId,
            clientId: helpers.intValueOrNull(payload['cliente_id']),
          ) ??
          await helpers.resolveClientByNamePhone(
            negocioId: negocioId,
            name:
                helpers.stringOrNull(payload['cliente_nombre_snapshot']) ??
                helpers.stringOrNull(payload['cliente_nombre']),
            phone:
                helpers.stringOrNull(payload['cliente_telefono_snapshot']) ??
                helpers.stringOrNull(payload['cliente_telefono']),
          );
      final clientRemoteId = client?['remote_id'] as String?;
      if (clientRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el cliente asociado al movimiento.',
        );
        preErrors++;
        continue;
      }
      items.add({
        'localId': item.entityId,
        if (_isGuid(helpers.stringOrNull(payload['remote_id'])))
          'serverId': helpers.stringOrNull(payload['remote_id']),
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['fecha'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'clientId': clientRemoteId,
          'type': payload['tipo'],
          'amount': payload['monto'],
          'concept': payload['concepto'],
          'date': payload['fecha'],
          'isActive': (payload['is_active'] as num? ?? 1).toInt() == 1,
          'localUuid': localUuid,
        },
      });
    }
    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('movements').pushPath,
      body: {'movements': items},
    );
    final result = await _applyPushResults(
      table: DatabaseSchema.movimientosTable,
      pendingEntityIds: pending.map((item) => item.entityId).toSet(),
      results: (response['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      preErrors: preErrors,
    );
    debugPrint(
      '[sync-contable] movimientos push businessId=$negocioId uploaded=${result.sent} '
      'errors=${result.errors} pendingCount=${pending.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return result;
  }

  Future<FinancialCloudSyncResult> pullMovements() async {
    final negocioId = await helpers.resolveNegocioId();
    final stopwatch = Stopwatch()..start();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastMovementSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('movements').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final movements = (response['movements'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    var received = 0;
    for (final movement in movements) {
      await _upsertMovement(negocioId, movement);
      received++;
    }
    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastMovementSyncPrefix$negocioId', serverTime);
    }
    debugPrint(
      '[sync-contable] movimientos pull businessId=$negocioId downloaded=$received '
      'lastSyncAt=$lastSyncAt elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return _result(received: received);
  }

  Future<FinancialCloudSyncResult> pushPendingDebtItems() async {
    final negocioId = await helpers.resolveNegocioId();
    final stopwatch = Stopwatch()..start();
    final pending = await helpers.pendingItems(DatabaseSchema.deudaItemsTable);
    if (pending.isEmpty) return _empty();

    final items = <Map<String, Object?>>[];
    var preErrors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final localUuid = await _ensureLocalUuid(
        table: DatabaseSchema.deudaItemsTable,
        localId: item.entityId,
        payload: payload,
        prefix: 'debt-item',
      );
      final movementRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.movimientosTable,
        helpers.intValue(payload['movimiento_id']),
      );
      if (movementRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el movimiento asociado al detalle.',
        );
        preErrors++;
        continue;
      }
      final productRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.productosTable,
        helpers.intValue(payload['producto_id']),
      );
      items.add({
        'localId': item.entityId,
        if (_isGuid(helpers.stringOrNull(payload['remote_id'])))
          'serverId': helpers.stringOrNull(payload['remote_id']),
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['created_at'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'movementId': movementRemoteId,
          'productId': productRemoteId,
          'productName': payload['nombre_producto'],
          'codeReference': payload['codigo_referencia'],
          'quantity': payload['cantidad'],
          'unitPrice': payload['precio_unitario'],
          'subtotal': payload['subtotal'],
          'localUuid': localUuid,
        },
      });
    }
    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('debt_items').pushPath,
      body: {'debtItems': items},
    );
    final result = await _applyPushResults(
      table: DatabaseSchema.deudaItemsTable,
      pendingEntityIds: pending.map((item) => item.entityId).toSet(),
      results: (response['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      preErrors: preErrors,
    );
    debugPrint(
      '[sync-contable] deuda_items push businessId=$negocioId uploaded=${result.sent} '
      'errors=${result.errors} pendingCount=${pending.length} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return result;
  }

  Future<FinancialCloudSyncResult> pullDebtItems() async {
    final negocioId = await helpers.resolveNegocioId();
    final stopwatch = Stopwatch()..start();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastDebtItemSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('debt_items').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final debtItems = (response['debtItems'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    var received = 0;
    for (final debtItem in debtItems) {
      if (await _upsertDebtItem(negocioId, debtItem)) received++;
    }
    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastDebtItemSyncPrefix$negocioId', serverTime);
    }
    debugPrint(
      '[sync-contable] deuda_items pull businessId=$negocioId downloaded=$received '
      'lastSyncAt=$lastSyncAt elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    return _result(received: received);
  }

  Future<FinancialCloudSyncResult> _applyPushResults({
    required String table,
    required Set<int> pendingEntityIds,
    required List<Map<String, dynamic>> results,
    int preErrors = 0,
  }) async {
    final pending = await helpers.pendingItems(table);
    var sent = 0;
    var errors = preErrors;
    for (final result in results) {
      final localId = (result['localId'] as num).toInt();
      final queue = pending
          .where((item) => item.entityId == localId)
          .cast<dynamic>()
          .firstOrNull;
      if (queue == null || !pendingEntityIds.contains(localId)) continue;
      final status = result['status'] as String? ?? 'failed';
      final error = result['error'] as String?;
      if (error == null && status != 'failed') {
        await helpers.markSynced(
          table: table,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id! as int);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id! as int,
          error ?? 'El backend no pudo sincronizar el registro.',
        );
        errors++;
      }
    }
    return _result(sent: sent, errors: errors);
  }

  Future<void> _upsertMovement(
    int negocioId,
    Map<String, dynamic> movement,
  ) async {
    final serverId = movement['id'] as String;
    final now = DateTime.now().toIso8601String();
    final clientLocalId = await helpers.localIdForRemoteId(
      DatabaseSchema.clientesTable,
      movement['clientId'] as String?,
    );
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.movimientosTable,
      remoteId: serverId,
      values: {
        'negocio_id': negocioId,
        'remote_id': serverId,
        'cliente_id': clientLocalId,
        'cliente_nombre': movement['clientName'] as String? ?? '',
        'cliente_telefono': movement['clientPhone'] as String?,
        'cliente_nombre_snapshot': movement['clientName'] as String? ?? '',
        'cliente_telefono_snapshot': movement['clientPhone'] as String?,
        'tipo': movement['type'] as String? ?? 'deuda',
        'monto': helpers.doubleValue(movement['amount']),
        'concepto': movement['concept'] as String?,
        'fecha': movement['date'] as String? ?? now,
        'created_at': movement['createdAt'] as String? ?? now,
        'updated_at': movement['updatedAt'] as String? ?? now,
        'is_active': (movement['isActive'] as bool? ?? true) ? 1 : 0,
        'deleted_at': movement['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': SyncStatus.synced,
        'local_uuid': movement['remoteId'] as String?,
      },
      fallbackWhere: 'negocio_id = ? AND local_uuid = ?',
      fallbackArgs: [negocioId, movement['remoteId'] as String?],
    );
  }

  Future<bool> _upsertDebtItem(int negocioId, Map<String, dynamic> item) async {
    final movementId = await helpers.localIdForRemoteId(
      DatabaseSchema.movimientosTable,
      item['movementId'] as String?,
    );
    if (movementId == null) return false;
    final productId = await helpers.localIdForRemoteId(
      DatabaseSchema.productosTable,
      item['productId'] as String?,
    );
    final serverId = item['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.deudaItemsTable,
      remoteId: serverId,
      values: {
        'negocio_id': negocioId,
        'remote_id': serverId,
        'movimiento_id': movementId,
        'producto_id': productId,
        'nombre_producto': item['productName'] as String? ?? '',
        'codigo_referencia': item['codeReference'] as String?,
        'cantidad': helpers.intValue(item['quantity']),
        'precio_unitario': helpers.doubleValue(item['unitPrice']),
        'subtotal': helpers.doubleValue(item['subtotal']),
        'created_at': item['createdAt'] as String? ?? now,
        'updated_at': item['updatedAt'] as String? ?? now,
        'deleted_at': item['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': item['deletedAt'] == null
            ? SyncStatus.synced
            : SyncStatus.deleted,
        'local_uuid': item['remoteId'] as String?,
      },
      fallbackWhere: 'negocio_id = ? AND local_uuid = ?',
      fallbackArgs: [negocioId, item['remoteId'] as String?],
    );
    if (productId != null) {
      await inventoryMetricsRepository.markProductDirty(
        negocioId: negocioId,
        productoId: productId,
      );
    }
    return true;
  }

  Future<String> _ensureLocalUuid({
    required String table,
    required int localId,
    required Map<String, Object?> payload,
    required String prefix,
  }) async {
    final fromPayload = helpers.stringOrNull(payload['local_uuid']);
    if (fromPayload != null) return fromPayload;

    final db = await helpers.databaseHelper.database;
    final rows = await db.query(
      table,
      columns: ['local_uuid'],
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    final existing = rows.isEmpty
        ? null
        : helpers.stringOrNull(rows.first['local_uuid']);
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final generated = '$prefix-${hex.join()}';
    await db.update(
      table,
      {'local_uuid': generated},
      where: 'id = ?',
      whereArgs: [localId],
    );
    return generated;
  }

  bool _isGuid(String? value) {
    if (value == null) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  FinancialCloudSyncResult _empty() => _result();

  FinancialCloudSyncResult _result({
    int sent = 0,
    int received = 0,
    int errors = 0,
  }) {
    return FinancialCloudSyncResult(
      sent: sent,
      received: received,
      errors: errors,
    );
  }
}
