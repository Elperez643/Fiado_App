import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class CloudClientScoreSyncService {
  static const _lastClientScoreSyncPrefix = 'fiado_client_scores_last_sync_';

  final ApiClient apiClient;
  final FinancialSyncHelpers helpers;

  CloudClientScoreSyncService({
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

  Future<FinancialCloudSyncResult> syncClientScores() async {
    final push = await pushPendingClientScores();
    final pull = await pullClientScores();
    return push.combine(pull);
  }

  Future<FinancialCloudSyncResult> pushPendingClientScores() async {
    final pending = await helpers.pendingItems(
      DatabaseSchema.clientScoresTable,
    );
    if (pending.isEmpty) return _result();

    final db = await helpers.databaseHelper.database;
    final items = <Map<String, Object?>>[];
    var preErrors = 0;

    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final rows = await db.query(
        DatabaseSchema.clientScoresTable,
        where: 'id = ?',
        whereArgs: [item.entityId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Score inteligente local no encontrado.',
        );
        preErrors++;
        continue;
      }

      final score = rows.first;
      final clientRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.clientesTable,
        helpers.intValue(score['cliente_id']),
      );
      if (clientRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el cliente asociado al score.',
        );
        preErrors++;
        continue;
      }

      items.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(score['remote_id']),
        'operation': item.operation,
        'updatedAt':
            score['updated_at'] ??
            score['last_calculated_at'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'remoteId': score['remote_id'],
          'clientId': clientRemoteId,
          'clientLocalId': score['cliente_id'],
          'score': score['score'],
          'riskLevel': score['risk_level'],
          'suggestedCreditLimit': score['suggested_credit_limit'],
          'paymentCompliancePercent': score['payment_compliance_percent'],
          'totalCredits': score['total_credits'],
          'totalPayments': score['total_payments'],
          'overdue30Count': score['overdue_30_count'],
          'overdue45Count': score['overdue_45_count'],
          'blocked60Count': score['blocked_60_count'],
          'lastCalculatedAt': score['last_calculated_at'],
        },
      });
    }

    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('client_scores').pushPath,
      body: {'clientScores': items},
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
          table: DatabaseSchema.clientScoresTable,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id!);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id!,
          error ?? 'El backend no pudo sincronizar el score inteligente.',
        );
        errors++;
      }
    }

    return _result(sent: sent, errors: errors);
  }

  Future<FinancialCloudSyncResult> pullClientScores() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastClientScoreSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('client_scores').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );

    var received = 0;
    for (final score
        in (response['clientScores'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()) {
      if (await _upsertScore(negocioId, score)) received++;
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString(
        '$_lastClientScoreSyncPrefix$negocioId',
        serverTime,
      );
    }
    return _result(received: received);
  }

  Future<bool> _upsertScore(int negocioId, Map<String, dynamic> score) async {
    final clientId = await helpers.localIdForRemoteId(
      DatabaseSchema.clientesTable,
      score['clientId'] as String?,
    );
    if (clientId == null) return false;

    final serverId = score['id'] as String;
    final now = DateTime.now().toIso8601String();
    final existingReasons = await _existingReasons(
      negocioId: negocioId,
      clientId: clientId,
      remoteId: serverId,
    );
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.clientScoresTable,
      remoteId: serverId,
      fallbackWhere: 'negocio_id = ? AND cliente_id = ?',
      fallbackArgs: [negocioId, clientId],
      values: {
        'remote_id': serverId,
        'negocio_id': negocioId,
        'cliente_id': clientId,
        'score': helpers.intValue(score['score']),
        'risk_level': score['riskLevel'] as String? ?? 'Riesgo medio',
        'suggested_credit_limit': helpers.doubleValue(
          score['suggestedCreditLimit'],
        ),
        'payment_compliance_percent': helpers.doubleValue(
          score['paymentCompliancePercent'],
        ),
        'total_credits': helpers.doubleValue(score['totalCredits']),
        'total_payments': helpers.doubleValue(score['totalPayments']),
        'overdue_30_count': helpers.intValue(score['overdue30Count']),
        'overdue_45_count': helpers.intValue(score['overdue45Count']),
        'blocked_60_count': helpers.intValue(score['blocked60Count']),
        'reasons_json': existingReasons,
        'last_calculated_at': score['lastCalculatedAt'] as String? ?? now,
        'created_at': score['createdAt'] as String? ?? now,
        'updated_at': score['updatedAt'] as String? ?? now,
        'deleted_at': score['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': SyncStatus.synced,
      },
    );
    return true;
  }

  Future<String?> _existingReasons({
    required int negocioId,
    required int clientId,
    required String remoteId,
  }) async {
    final db = await helpers.databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.clientScoresTable,
      columns: ['reasons_json'],
      where: 'remote_id = ? OR (negocio_id = ? AND cliente_id = ?)',
      whereArgs: [remoteId, negocioId, clientId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['reasons_json'] as String?;
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
