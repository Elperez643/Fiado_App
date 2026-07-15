import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class CloudWhatsappCampaignSyncService {
  static const _lastWhatsappCampaignSyncPrefix =
      'fiado_whatsapp_campaigns_last_sync_';

  final ApiClient apiClient;
  final FinancialSyncHelpers helpers;

  CloudWhatsappCampaignSyncService({
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

  Future<FinancialCloudSyncResult> syncWhatsappCampaigns() async {
    final push = await pushPendingWhatsappCampaigns();
    final pull = await pullWhatsappCampaigns();
    return push.combine(pull);
  }

  Future<FinancialCloudSyncResult> pushPendingWhatsappCampaigns() async {
    final pending = await helpers.pendingItems(
      DatabaseSchema.whatsappCampaignPublicationsTable,
    );
    if (pending.isEmpty) return _result();

    final db = await helpers.databaseHelper.database;
    final items = <Map<String, Object?>>[];
    var preErrors = 0;

    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final rows = await db.query(
        DatabaseSchema.whatsappCampaignPublicationsTable,
        where: 'id = ?',
        whereArgs: [item.entityId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Campana WhatsApp local no encontrada.',
        );
        preErrors++;
        continue;
      }
      final campaign = rows.first;
      items.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(campaign['remote_id']),
        'operation': item.operation,
        'updatedAt':
            campaign['updated_at'] ??
            campaign['created_at'] ??
            item.updatedAt.toIso8601String(),
        'payload': _payloadFromRow(campaign),
      });
    }

    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('whatsapp_campaigns').pushPath,
      body: {'campaigns': items},
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
          table: DatabaseSchema.whatsappCampaignPublicationsTable,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id!);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id!,
          error ?? 'El backend no pudo sincronizar la campana WhatsApp.',
        );
        errors++;
      }
    }

    return _result(sent: sent, errors: errors);
  }

  Future<FinancialCloudSyncResult> pullWhatsappCampaigns() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString(
      '$_lastWhatsappCampaignSyncPrefix$negocioId',
    );
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('whatsapp_campaigns').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );

    var received = 0;
    for (final campaign
        in (response['campaigns'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()) {
      await _upsertCampaign(negocioId, campaign);
      received++;
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString(
        '$_lastWhatsappCampaignSyncPrefix$negocioId',
        serverTime,
      );
    }
    return _result(received: received);
  }

  Map<String, Object?> _payloadFromRow(Map<String, Object?> campaign) {
    return {
      'localUuid': campaign['local_uuid'],
      'remoteId': campaign['remote_id'],
      'dateKey': campaign['date_key'],
      'mode': campaign['mode'],
      'productIds': _jsonList(campaign['product_ids_json']),
      'renderedImagePaths': _jsonList(campaign['rendered_image_paths_json']),
      'statusTexts': _jsonList(campaign['status_texts_json']),
      'status': campaign['status'],
      'campaignStatus': campaign['campaign_status'],
      'consumesQuota': (campaign['consumes_quota'] as num? ?? 0).toInt() == 1,
      'quotaUnits': campaign['quota_units'],
      'startDate': campaign['fecha_inicio'],
      'durationDays': campaign['duracion_dias'],
      'openedWhatsappAt': campaign['opened_whatsapp_at'],
      'confirmedByUserAt': campaign['confirmed_by_user_at'],
      'canceledByUserAt': campaign['canceled_by_user_at'],
      'failedAt': campaign['failed_at'],
      'estimatedExpiresAt': campaign['estimated_expires_at'],
      'error': campaign['error'],
      'isActive': (campaign['is_active'] as num? ?? 1).toInt() == 1,
      'deletedAt': campaign['deleted_at'],
      'createdAt': campaign['created_at'],
      'updatedAt': campaign['updated_at'],
    };
  }

  Future<void> _upsertCampaign(
    int negocioId,
    Map<String, dynamic> campaign,
  ) async {
    final serverId = campaign['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.whatsappCampaignPublicationsTable,
      remoteId: serverId,
      fallbackWhere: 'negocio_id = ? AND local_uuid = ?',
      fallbackArgs: [negocioId, campaign['localUuid'] as String? ?? serverId],
      values: {
        'remote_id': serverId,
        'local_uuid': campaign['localUuid'] as String? ?? serverId,
        'negocio_id': negocioId,
        'date_key': campaign['dateKey'] as String? ?? _dateKey(DateTime.now()),
        'mode': campaign['mode'] as String? ?? 'catalogo',
        'product_ids_json': jsonEncode(
          campaign['productIds'] as List<dynamic>? ?? const [],
        ),
        'rendered_image_paths_json': jsonEncode(
          campaign['renderedImagePaths'] as List<dynamic>? ?? const [],
        ),
        'status_texts_json': jsonEncode(
          campaign['statusTexts'] as List<dynamic>? ?? const [],
        ),
        'status': campaign['status'] as String? ?? 'pendiente',
        'campaign_status': campaign['campaignStatus'] as String? ?? 'activo',
        'consumes_quota': campaign['consumesQuota'] == true ? 1 : 0,
        'quota_units': (campaign['quotaUnits'] as num?)?.toInt() ?? 1,
        'fecha_inicio': campaign['startDate'] as String? ?? now,
        'duracion_dias': (campaign['durationDays'] as num?)?.toInt() ?? 7,
        'created_at': campaign['createdAt'] as String? ?? now,
        'updated_at': campaign['updatedAt'] as String? ?? now,
        'opened_whatsapp_at': campaign['openedWhatsappAt'] as String?,
        'confirmed_by_user_at': campaign['confirmedByUserAt'] as String?,
        'canceled_by_user_at': campaign['canceledByUserAt'] as String?,
        'failed_at': campaign['failedAt'] as String?,
        'estimated_expires_at': campaign['estimatedExpiresAt'] as String?,
        'error': campaign['error'] as String?,
        'is_active': campaign['isActive'] == false ? 0 : 1,
        'deleted_at': campaign['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': SyncStatus.synced,
      },
    );
  }

  List<dynamic> _jsonList(Object? value) {
    if (value == null) return const [];
    return jsonDecode('$value') as List<dynamic>? ?? const [];
  }

  String _dateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
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
