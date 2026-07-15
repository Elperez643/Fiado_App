import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class CloudReceiptSyncService {
  static const _lastReceiptSyncPrefix = 'fiado_receipts_last_sync_';

  final ApiClient apiClient;
  final FinancialSyncHelpers helpers;

  CloudReceiptSyncService({
    required this.apiClient,
    required AuthRepository authRepository,
    required SyncQueueRepository syncQueueRepository,
    required DatabaseHelper databaseHelper,
    required Future<SharedPreferences> sharedPreferences,
  }) : helpers = FinancialSyncHelpers(
         authRepository: authRepository,
         syncQueueRepository: syncQueueRepository,
         databaseHelper: databaseHelper,
         sharedPreferences: sharedPreferences,
       );

  Future<FinancialCloudSyncResult> syncReceipts() async {
    final push = await pushPendingReceipts();
    final pull = await pullReceipts();
    return push.combine(pull);
  }

  Future<FinancialCloudSyncResult> pushPendingReceipts() async {
    final pending = await helpers.pendingItems(
      DatabaseSchema.comprobantesTable,
    );
    if (pending.isEmpty) return _result();

    final items = <Map<String, Object?>>[];
    var preErrors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final movementRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.movimientosTable,
        helpers.intValue(payload['movimiento_id']),
      );
      if (movementRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el movimiento asociado al comprobante.',
        );
        preErrors++;
        continue;
      }
      final negocioId = await helpers.resolveNegocioId();
      final db = await helpers.databaseHelper.database;
      final movementRows = await db.query(
        DatabaseSchema.movimientosTable,
        columns: ['cliente_id'],
        where: 'id = ? AND negocio_id = ?',
        whereArgs: [helpers.intValue(payload['movimiento_id']), negocioId],
        limit: 1,
      );
      final client =
          await helpers.resolveClientByLocalId(
            negocioId: negocioId,
            clientId: movementRows.isEmpty
                ? null
                : helpers.intValueOrNull(movementRows.first['cliente_id']),
          ) ??
          await helpers.resolveClientByNamePhone(
            negocioId: negocioId,
            name: helpers.stringOrNull(payload['cliente_nombre']),
            phone: helpers.stringOrNull(payload['cliente_telefono']),
          );
      final clientRemoteId = client?['remote_id'] as String?;
      if (clientRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el cliente asociado al comprobante.',
        );
        preErrors++;
        continue;
      }
      items.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(payload['remote_id']),
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['fecha'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'movementId': movementRemoteId,
          'clientId': clientRemoteId,
          'receiptCode': payload['codigo_comprobante'],
          'type': payload['tipo'],
          'payloadJson': payload['payload_json'],
          'total': payload['total'],
          'previousBalance': payload['saldo_anterior'],
          'newBalance': payload['saldo_nuevo'],
          'date': payload['fecha'],
        },
      });
    }
    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('receipts').pushPath,
      body: {'receipts': items},
    );
    final results = (response['results'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    var sent = 0;
    var errors = preErrors;
    for (final result in results) {
      final localId = (result['localId'] as num).toInt();
      final queue = pending
          .where((item) => item.entityId == localId)
          .firstOrNull;
      if (queue == null) continue;
      final status = result['status'] as String? ?? 'failed';
      final error = result['error'] as String?;
      if (error == null && status != 'failed') {
        await helpers.markSynced(
          table: DatabaseSchema.comprobantesTable,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id!);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id!,
          error ?? 'El backend no pudo sincronizar el comprobante.',
        );
        errors++;
      }
    }
    return _result(sent: sent, errors: errors);
  }

  Future<FinancialCloudSyncResult> pullReceipts() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastReceiptSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('receipts').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final receipts = (response['receipts'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    var received = 0;
    for (final receipt in receipts) {
      if (await _upsertReceipt(negocioId, receipt)) received++;
    }
    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastReceiptSyncPrefix$negocioId', serverTime);
    }
    return _result(received: received);
  }

  Future<bool> _upsertReceipt(
    int negocioId,
    Map<String, dynamic> receipt,
  ) async {
    final movementId = await helpers.localIdForRemoteId(
      DatabaseSchema.movimientosTable,
      receipt['movementId'] as String?,
    );
    if (movementId == null) return false;
    final serverId = receipt['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.comprobantesTable,
      remoteId: serverId,
      fallbackWhere: 'codigo_comprobante = ?',
      fallbackArgs: [receipt['receiptCode'] as String? ?? ''],
      values: {
        'negocio_id': negocioId,
        'remote_id': serverId,
        'tipo': receipt['type'] as String? ?? 'deuda',
        'movimiento_id': movementId,
        'cliente_nombre': receipt['clientName'] as String? ?? '',
        'cliente_telefono': receipt['clientPhone'] as String?,
        'negocio_nombre': receipt['businessName'] as String?,
        'codigo_comprobante': receipt['receiptCode'] as String? ?? '',
        'fecha': receipt['date'] as String? ?? now,
        'subtotal': helpers.doubleValue(receipt['total']),
        'total': helpers.doubleValue(receipt['total']),
        'saldo_anterior': receipt['previousBalance'],
        'saldo_nuevo': receipt['newBalance'],
        'payload_json': receipt['payloadJson'] as String? ?? '{}',
        'created_at': receipt['createdAt'] as String? ?? now,
        'updated_at': receipt['updatedAt'] as String? ?? now,
        'deleted_at': receipt['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': receipt['deletedAt'] == null
            ? SyncStatus.synced
            : SyncStatus.deleted,
      },
    );
    return true;
  }

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
