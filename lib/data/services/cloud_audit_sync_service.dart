import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class AuditCloudSyncResult {
  final int auditsSent;
  final int auditsReceived;
  final int itemsSent;
  final int itemsReceived;
  final int errors;

  const AuditCloudSyncResult({
    required this.auditsSent,
    required this.auditsReceived,
    required this.itemsSent,
    required this.itemsReceived,
    required this.errors,
  });

  AuditCloudSyncResult combine(AuditCloudSyncResult other) {
    return AuditCloudSyncResult(
      auditsSent: auditsSent + other.auditsSent,
      auditsReceived: auditsReceived + other.auditsReceived,
      itemsSent: itemsSent + other.itemsSent,
      itemsReceived: itemsReceived + other.itemsReceived,
      errors: errors + other.errors,
    );
  }
}

class CloudAuditSyncService {
  static const _lastAuditSyncPrefix = 'fiado_audits_last_sync_';
  static const _lastAuditItemSyncPrefix = 'fiado_audit_items_last_sync_';

  final ApiClient apiClient;
  final FinancialSyncHelpers helpers;

  CloudAuditSyncService({
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

  Future<AuditCloudSyncResult> syncAuditsAndItems() async {
    final auditsPush = await pushPendingAudits();
    final auditsPull = await pullAudits();
    final itemsPush = await pushPendingAuditItems();
    final itemsPull = await pullAuditItems();
    return auditsPush.combine(auditsPull).combine(itemsPush).combine(itemsPull);
  }

  Future<AuditCloudSyncResult> pushPendingAudits() async {
    final pending = await helpers.pendingItems(DatabaseSchema.auditoriasTable);
    if (pending.isEmpty) return _empty();

    final items = <Map<String, Object?>>[];
    var preErrors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final collaboratorId = helpers.intValue(payload['colaborador_id']);
      final collaboratorRemoteId = collaboratorId == 0
          ? null
          : await helpers.remoteIdForLocalId(
              DatabaseSchema.usuariosTable,
              collaboratorId,
            );

      items.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(payload['remote_id']),
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['fecha'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'collaboratorId': collaboratorRemoteId,
          'type': payload['tipo'],
          'date': payload['fecha'],
          'status': payload['estado'],
          'totalProducts': payload['total_productos'],
          'validatedProducts': payload['productos_validados'],
          'observations': payload['observaciones'],
        },
      });
    }
    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('audits').pushPath,
      body: {'audits': items},
    );
    final push = await _applyPushResults(
      table: DatabaseSchema.auditoriasTable,
      results: (response['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      preErrors: preErrors,
    );
    return _result(auditsSent: push.sent, errors: push.errors);
  }

  Future<AuditCloudSyncResult> pullAudits() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastAuditSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('audits').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final audits = (response['audits'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var received = 0;
    for (final audit in audits) {
      await _upsertAudit(negocioId, audit);
      received++;
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastAuditSyncPrefix$negocioId', serverTime);
    }
    return _result(auditsReceived: received);
  }

  Future<AuditCloudSyncResult> pushPendingAuditItems() async {
    final negocioId = await helpers.resolveNegocioId();
    final pending = await helpers.pendingItems(
      DatabaseSchema.auditoriaItemsTable,
    );
    if (pending.isEmpty) return _empty();

    final items = <Map<String, Object?>>[];
    var preErrors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final auditRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.auditoriasTable,
        helpers.intValue(payload['auditoria_id']),
      );
      final productRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.productosTable,
        helpers.intValue(payload['producto_id']),
      );
      if (auditRemoteId == null || productRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero la auditoria y el producto asociados.',
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
            payload['created_at'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'auditId': auditRemoteId,
          'productId': productRemoteId,
          'systemStock': payload['stock_sistema'],
          'physicalStock': payload['stock_fisico'],
          'validationStatus': payload['estado_validacion'],
          'observation': payload['observacion'],
        },
      });
    }
    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('audit_items').pushPath,
      body: {'auditItems': items},
    );
    final push = await _applyPushResults(
      table: DatabaseSchema.auditoriaItemsTable,
      results: (response['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      preErrors: preErrors,
      extraValues: {'negocio_id': negocioId},
    );
    return _result(itemsSent: push.sent, errors: push.errors);
  }

  Future<AuditCloudSyncResult> pullAuditItems() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastAuditItemSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('audit_items').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final items = (response['auditItems'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var received = 0;
    for (final item in items) {
      if (await _upsertAuditItem(negocioId, item)) received++;
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastAuditItemSyncPrefix$negocioId', serverTime);
    }
    return _result(itemsReceived: received);
  }

  Future<_PushCounts> _applyPushResults({
    required String table,
    required List<Map<String, dynamic>> results,
    int preErrors = 0,
    Map<String, Object?> extraValues = const {},
  }) async {
    final pending = await helpers.pendingItems(table);
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
          table: table,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        if (extraValues.isNotEmpty) {
          final db = await helpers.databaseHelper.database;
          await db.update(
            table,
            extraValues,
            where: 'id = ?',
            whereArgs: [localId],
          );
        }
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id!);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id!,
          error ?? 'El backend no pudo sincronizar el registro.',
        );
        errors++;
      }
    }
    return _PushCounts(sent: sent, errors: errors);
  }

  Future<void> _upsertAudit(int negocioId, Map<String, dynamic> audit) async {
    final serverId = audit['id'] as String;
    final now = DateTime.now().toIso8601String();
    final collaboratorId = await helpers.localIdForRemoteId(
      DatabaseSchema.usuariosTable,
      audit['collaboratorId'] as String?,
    );
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.auditoriasTable,
      remoteId: serverId,
      values: {
        'negocio_id': negocioId,
        'remote_id': serverId,
        'colaborador_id': collaboratorId,
        'tipo': audit['type'] as String? ?? 'diaria',
        'fecha': audit['date'] as String? ?? now,
        'estado': audit['status'] as String? ?? 'pendiente',
        'total_productos': helpers.intValue(audit['totalProducts']),
        'productos_validados': helpers.intValue(audit['validatedProducts']),
        'observaciones': audit['observations'] as String?,
        'created_at': audit['createdAt'] as String? ?? now,
        'updated_at': audit['updatedAt'] as String? ?? now,
        'deleted_at': audit['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': audit['deletedAt'] == null
            ? SyncStatus.synced
            : SyncStatus.deleted,
      },
    );
  }

  Future<bool> _upsertAuditItem(
    int negocioId,
    Map<String, dynamic> item,
  ) async {
    final auditId = await helpers.localIdForRemoteId(
      DatabaseSchema.auditoriasTable,
      item['auditId'] as String?,
    );
    final productId = await helpers.localIdForRemoteId(
      DatabaseSchema.productosTable,
      item['productId'] as String?,
    );
    if (auditId == null || productId == null) return false;

    final serverId = item['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.auditoriaItemsTable,
      remoteId: serverId,
      values: {
        'negocio_id': negocioId,
        'remote_id': serverId,
        'auditoria_id': auditId,
        'producto_id': productId,
        'stock_sistema': helpers.intValue(item['systemStock']),
        'stock_fisico': item['physicalStock'],
        'estado_validacion': item['validationStatus'] as String? ?? 'pendiente',
        'observacion': item['observation'] as String?,
        'created_at': item['createdAt'] as String? ?? now,
        'updated_at': item['updatedAt'] as String? ?? now,
        'deleted_at': item['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': item['deletedAt'] == null
            ? SyncStatus.synced
            : SyncStatus.deleted,
      },
    );
    return true;
  }

  AuditCloudSyncResult _empty() => _result();

  AuditCloudSyncResult _result({
    int auditsSent = 0,
    int auditsReceived = 0,
    int itemsSent = 0,
    int itemsReceived = 0,
    int errors = 0,
  }) {
    return AuditCloudSyncResult(
      auditsSent: auditsSent,
      auditsReceived: auditsReceived,
      itemsSent: itemsSent,
      itemsReceived: itemsReceived,
      errors: errors,
    );
  }
}

class _PushCounts {
  final int sent;
  final int errors;

  const _PushCounts({required this.sent, required this.errors});
}
