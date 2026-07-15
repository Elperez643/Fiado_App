import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/sync/sync_status.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import '../models/sync_queue_item_model.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class CloudCreditCycleSyncService {
  static const _lastCreditCycleSyncPrefix = 'fiado_credit_cycles_last_sync_';

  final ApiClient apiClient;
  final FinancialSyncHelpers helpers;

  CloudCreditCycleSyncService({
    required this.apiClient,
    required AuthRepository authRepository,
    required SyncQueueRepository syncQueueRepository,
    required LocalDatabase databaseHelper,
    required Future<SharedPreferences> sharedPreferences,
  }) : helpers = FinancialSyncHelpers(
         authRepository: authRepository,
         syncQueueRepository: syncQueueRepository,
         databaseHelper: databaseHelper,
         sharedPreferences: sharedPreferences,
       );

  Future<FinancialCloudSyncResult> syncCreditCycles() async {
    final push = await pushPendingCreditCycles();
    final pull = await pullCreditCycles();
    return push.combine(pull);
  }

  Future<FinancialCloudSyncResult> pushPendingCreditCycles() async {
    final pendingCycles = await helpers.pendingItems(
      DatabaseSchema.creditoCiclosTable,
    );
    final pendingReminders = await helpers.pendingItems(
      DatabaseSchema.creditoRecordatoriosTable,
    );
    final pendingExceptions = await helpers.pendingItems(
      DatabaseSchema.creditoExcepcionesTable,
    );
    if (pendingCycles.isEmpty &&
        pendingReminders.isEmpty &&
        pendingExceptions.isEmpty) {
      return _result();
    }

    final cycleItems = <Map<String, Object?>>[];
    final reminderItems = <Map<String, Object?>>[];
    final exceptionItems = <Map<String, Object?>>[];
    var preErrors = 0;
    for (final item in pendingCycles) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final clientRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.clientesTable,
        helpers.intValue(payload['cliente_id']),
      );
      if (clientRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el cliente asociado al ciclo.',
        );
        preErrors++;
        continue;
      }
      cycleItems.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(payload['remote_id']),
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['fecha_inicio'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'clientId': clientRemoteId,
          'startDate': payload['fecha_inicio'],
          'dueDate30': payload['fecha_limite_30'],
          'dueDate45': payload['fecha_limite_45'],
          'blockDate60': payload['fecha_bloqueo_60'],
          'status': payload['estado'],
          'totalAmount': payload['monto_total'],
          'paidAmount': payload['monto_pagado'],
          'pendingBalance': payload['saldo_pendiente'],
          'isBlocked': (payload['bloqueado'] as num? ?? 0).toInt() == 1,
          'settledAt': payload['fecha_saldado'],
        },
      });
    }

    preErrors += await _collectReminderPushItems(
      pendingReminders,
      reminderItems,
    );
    preErrors += await _collectExceptionPushItems(
      pendingExceptions,
      exceptionItems,
    );

    if (cycleItems.isEmpty && reminderItems.isEmpty && exceptionItems.isEmpty) {
      return _result(errors: preErrors);
    }

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('credit_cycles').pushPath,
      body: {
        'creditCycles': cycleItems,
        'creditReminders': reminderItems,
        'creditExceptions': exceptionItems,
      },
    );
    final cycleResult = await _applyPushResults(
      table: DatabaseSchema.creditoCiclosTable,
      pending: pendingCycles,
      results: (response['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      fallbackError: 'El backend no pudo sincronizar el ciclo.',
    );
    final reminderResult = await _applyPushResults(
      table: DatabaseSchema.creditoRecordatoriosTable,
      pending: pendingReminders,
      results: (response['creditReminderResults'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      fallbackError: 'El backend no pudo sincronizar el recordatorio.',
    );
    final exceptionResult = await _applyPushResults(
      table: DatabaseSchema.creditoExcepcionesTable,
      pending: pendingExceptions,
      results:
          (response['creditExceptionResults'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>(),
      fallbackError: 'El backend no pudo sincronizar la excepcion de credito.',
    );
    final sent = cycleResult.sent + reminderResult.sent + exceptionResult.sent;
    final errors =
        preErrors +
        cycleResult.errors +
        reminderResult.errors +
        exceptionResult.errors;
    return _result(sent: sent, errors: errors);
  }

  Future<int> _collectReminderPushItems(
    List<SyncQueueItemModel> pending,
    List<Map<String, Object?>> items,
  ) async {
    final db = await helpers.databaseHelper.database;
    var errors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final rows = await db.query(
        DatabaseSchema.creditoRecordatoriosTable,
        where: 'id = ?',
        whereArgs: [item.entityId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Recordatorio de credito local no encontrado.',
        );
        errors++;
        continue;
      }
      final reminder = rows.first;
      final cycleRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.creditoCiclosTable,
        helpers.intValue(reminder['ciclo_id']),
      );
      final clientRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.clientesTable,
        helpers.intValue(reminder['cliente_id']),
      );
      if (cycleRemoteId == null || clientRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el ciclo y cliente asociados al recordatorio.',
        );
        errors++;
        continue;
      }
      items.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(reminder['remote_id']),
        'operation': item.operation,
        'updatedAt':
            reminder['updated_at'] ??
            reminder['fecha_generado'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'creditCycleId': cycleRemoteId,
          'clientId': clientRemoteId,
          'type': reminder['tipo'],
          'message': reminder['mensaje'],
          'channel': reminder['canal'],
          'status': reminder['estado'],
          'generatedAt': reminder['fecha_generado'],
          'sentAt': reminder['fecha_enviado'],
        },
      });
    }
    return errors;
  }

  Future<int> _collectExceptionPushItems(
    List<SyncQueueItemModel> pending,
    List<Map<String, Object?>> items,
  ) async {
    final db = await helpers.databaseHelper.database;
    var errors = 0;
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final rows = await db.query(
        DatabaseSchema.creditoExcepcionesTable,
        where: 'id = ?',
        whereArgs: [item.entityId],
        limit: 1,
      );
      if (rows.isEmpty) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Excepcion de credito local no encontrada.',
        );
        errors++;
        continue;
      }
      final exception = rows.first;
      final cycleRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.creditoCiclosTable,
        helpers.intValue(exception['ciclo_id']),
      );
      final clientRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.clientesTable,
        helpers.intValue(exception['cliente_id']),
      );
      final movementRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.movimientosTable,
        helpers.intValueOrNull(exception['movimiento_id']),
      );
      if (cycleRemoteId == null || clientRemoteId == null) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el ciclo y cliente asociados a la excepcion.',
        );
        errors++;
        continue;
      }
      items.add({
        'localId': item.entityId,
        'serverId': helpers.stringOrNull(exception['remote_id']),
        'operation': item.operation,
        'updatedAt':
            exception['updated_at'] ??
            exception['fecha'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'creditCycleId': cycleRemoteId,
          'clientId': clientRemoteId,
          'movementId': movementRemoteId,
          'reason': exception['motivo'],
          'amount': exception['monto_fiado'],
          'date': exception['fecha'],
        },
      });
    }
    return errors;
  }

  Future<({int sent, int errors})> _applyPushResults({
    required String table,
    required List<SyncQueueItemModel> pending,
    required List<Map<String, dynamic>> results,
    required String fallbackError,
  }) async {
    var sent = 0;
    var errors = 0;
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
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id!);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id!,
          error ?? fallbackError,
        );
        errors++;
      }
    }
    return (sent: sent, errors: errors);
  }

  Future<FinancialCloudSyncResult> pullCreditCycles() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastCreditCycleSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('credit_cycles').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    var received = 0;
    for (final cycle
        in (response['creditCycles'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()) {
      if (await _upsertCycle(negocioId, cycle)) received++;
    }
    for (final reminder
        in (response['creditReminders'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()) {
      if (await _upsertReminder(negocioId, reminder)) received++;
    }
    for (final exception
        in (response['creditExceptions'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()) {
      if (await _upsertException(negocioId, exception)) received++;
    }
    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString(
        '$_lastCreditCycleSyncPrefix$negocioId',
        serverTime,
      );
    }
    return _result(received: received);
  }

  Future<bool> _upsertCycle(int negocioId, Map<String, dynamic> cycle) async {
    final clientId = await helpers.localIdForRemoteId(
      DatabaseSchema.clientesTable,
      cycle['clientId'] as String?,
    );
    if (clientId == null) return false;
    final serverId = cycle['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.creditoCiclosTable,
      remoteId: serverId,
      values: {
        'remote_id': serverId,
        'negocio_id': negocioId,
        'cliente_id': clientId,
        'fecha_inicio': cycle['startDate'] as String? ?? now,
        'fecha_limite_30': cycle['dueDate30'] as String? ?? now,
        'fecha_limite_45': cycle['dueDate45'] as String? ?? now,
        'fecha_bloqueo_60': cycle['blockDate60'] as String? ?? now,
        'estado': cycle['status'] as String? ?? 'activo',
        'monto_total': helpers.doubleValue(cycle['totalAmount']),
        'monto_pagado': helpers.doubleValue(cycle['paidAmount']),
        'saldo_pendiente': helpers.doubleValue(cycle['pendingBalance']),
        'bloqueado': (cycle['isBlocked'] as bool? ?? false) ? 1 : 0,
        'fecha_saldado': cycle['settledAt'] as String?,
        'created_at': cycle['createdAt'] as String? ?? now,
        'updated_at': cycle['updatedAt'] as String? ?? now,
        'last_synced_at': now,
        'sync_status': SyncStatus.synced,
      },
    );
    return true;
  }

  Future<bool> _upsertReminder(
    int negocioId,
    Map<String, dynamic> reminder,
  ) async {
    final cycleId = await helpers.localIdForRemoteId(
      DatabaseSchema.creditoCiclosTable,
      reminder['creditCycleId'] as String?,
    );
    final clientId = await helpers.localIdForRemoteId(
      DatabaseSchema.clientesTable,
      reminder['clientId'] as String?,
    );
    if (cycleId == null || clientId == null) return false;
    final serverId = reminder['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.creditoRecordatoriosTable,
      remoteId: serverId,
      values: {
        'remote_id': serverId,
        'ciclo_id': cycleId,
        'negocio_id': negocioId,
        'cliente_id': clientId,
        'tipo': reminder['type'] as String? ?? 'toque_manual',
        'mensaje': reminder['message'] as String? ?? '',
        'canal': reminder['channel'] as String? ?? 'interno',
        'estado': reminder['status'] as String? ?? 'pendiente',
        'fecha_generado': reminder['generatedAt'] as String? ?? now,
        'fecha_enviado': reminder['sentAt'] as String?,
        'created_at': reminder['createdAt'] as String? ?? now,
        'updated_at': reminder['updatedAt'] as String? ?? now,
        'last_synced_at': now,
        'sync_status': SyncStatus.synced,
      },
    );
    return true;
  }

  Future<bool> _upsertException(
    int negocioId,
    Map<String, dynamic> exception,
  ) async {
    final cycleId = await helpers.localIdForRemoteId(
      DatabaseSchema.creditoCiclosTable,
      exception['creditCycleId'] as String?,
    );
    final clientId = await helpers.localIdForRemoteId(
      DatabaseSchema.clientesTable,
      exception['clientId'] as String?,
    );
    final movementId = await helpers.localIdForRemoteId(
      DatabaseSchema.movimientosTable,
      exception['movementId'] as String?,
    );
    if (cycleId == null || clientId == null) return false;
    final serverId = exception['id'] as String;
    final now = DateTime.now().toIso8601String();
    final user = await helpers.authRepository.obtenerUsuarioActual();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.creditoExcepcionesTable,
      remoteId: serverId,
      values: {
        'remote_id': serverId,
        'ciclo_id': cycleId,
        'negocio_id': negocioId,
        'cliente_id': clientId,
        'usuario_id': user?.id ?? negocioId,
        'motivo': exception['reason'] as String?,
        'monto_fiado': helpers.doubleValue(exception['amount']),
        'movimiento_id': movementId,
        'fecha': exception['date'] as String? ?? now,
        'created_at': exception['createdAt'] as String? ?? now,
        'updated_at': exception['updatedAt'] as String? ?? now,
        'last_synced_at': now,
        'sync_status': SyncStatus.synced,
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
