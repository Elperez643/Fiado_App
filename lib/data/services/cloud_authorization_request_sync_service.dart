import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'cloud_financial_sync_helpers.dart';
import 'sync_endpoint_registry.dart';

class AuthorizationRequestCloudSyncResult {
  final int sent;
  final int received;
  final int errors;

  const AuthorizationRequestCloudSyncResult({
    required this.sent,
    required this.received,
    required this.errors,
  });

  AuthorizationRequestCloudSyncResult combine(
    AuthorizationRequestCloudSyncResult other,
  ) {
    return AuthorizationRequestCloudSyncResult(
      sent: sent + other.sent,
      received: received + other.received,
      errors: errors + other.errors,
    );
  }
}

class CloudAuthorizationRequestSyncService {
  static const _lastSyncPrefix = 'fiado_authorization_requests_last_sync_';

  final ApiClient apiClient;
  final AuthRepository authRepository;
  final FinancialSyncHelpers helpers;

  CloudAuthorizationRequestSyncService({
    required this.apiClient,
    required this.authRepository,
    required SyncQueueRepository syncQueueRepository,
    required DatabaseHelper databaseHelper,
    required Future<SharedPreferences> sharedPreferences,
  }) : helpers = FinancialSyncHelpers(
         authRepository: authRepository,
         syncQueueRepository: syncQueueRepository,
         databaseHelper: databaseHelper,
         sharedPreferences: sharedPreferences,
       );

  Future<AuthorizationRequestCloudSyncResult>
  syncAuthorizationRequests() async {
    final push = await pushPendingAuthorizationRequests();
    final pull = await pullAuthorizationRequests();
    return push.combine(pull);
  }

  Future<AuthorizationRequestCloudSyncResult>
  pushPendingAuthorizationRequests() async {
    final pending = await helpers.pendingItems(
      DatabaseSchema.solicitudesAutorizacionTable,
    );
    if (pending.isEmpty) return _empty();

    final items = <Map<String, Object?>>[];
    var preErrors = 0;
    final user = await authRepository.obtenerUsuarioActual();
    for (final item in pending) {
      await helpers.syncQueueRepository.incrementarIntento(item.id!);
      final payload = item.payloadAsMap();
      final collaboratorRemoteId = await helpers.remoteIdForLocalId(
        DatabaseSchema.usuariosTable,
        helpers.intValue(payload['colaborador_id']),
      );
      final canResolveCollaboratorFromJwt =
          user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador;
      if (collaboratorRemoteId == null && !canResolveCollaboratorFromJwt) {
        await helpers.syncQueueRepository.marcarComoFallido(
          item.id!,
          'Sincroniza primero el colaborador asociado a la solicitud.',
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
            payload['resolved_at'] ??
            item.updatedAt.toIso8601String(),
        'payload': {
          'collaboratorId': collaboratorRemoteId,
          'requestType': payload['tipo_solicitud'],
          'entity': payload['entidad'],
          'entityId': await _resolveEntityRemoteId(payload),
          'dataBeforeJson': payload['datos_antes'],
          'dataAfterJson': payload['datos_despues'] ?? '{}',
          'status': payload['estado'],
          'businessComment': payload['comentario_negocio'],
          'decidedAt': payload['resolved_at'],
        },
      });
    }
    if (items.isEmpty) return _result(errors: preErrors);

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('authorization_requests').pushPath,
      body: {'authorizationRequests': items},
    );
    return _applyPushResults(
      (response['results'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>(),
      preErrors,
    );
  }

  Future<AuthorizationRequestCloudSyncResult>
  pullAuthorizationRequests() async {
    final negocioId = await helpers.resolveNegocioId();
    final prefs = await helpers.sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastSyncPrefix$negocioId');
    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('authorization_requests').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final requests =
        (response['authorizationRequests'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    var received = 0;
    for (final request in requests) {
      if (await _upsertAuthorizationRequest(negocioId, request)) received++;
    }

    final serverTime = response['serverTime'] as String?;
    if (serverTime != null) {
      await prefs.setString('$_lastSyncPrefix$negocioId', serverTime);
    }
    return _result(received: received);
  }

  Future<void> approveRemoteRequest(int localRequestId, {String? comment}) {
    return _decideRemoteRequest(localRequestId, true, comment);
  }

  Future<void> rejectRemoteRequest(int localRequestId, {String? comment}) {
    return _decideRemoteRequest(localRequestId, false, comment);
  }

  Future<void> _decideRemoteRequest(
    int localRequestId,
    bool approve,
    String? comment,
  ) async {
    final db = await helpers.databaseHelper.database;
    final rows = await db.query(
      DatabaseSchema.solicitudesAutorizacionTable,
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [localRequestId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['remote_id'] == null) {
      throw StateError('La solicitud aun no tiene remote_id.');
    }
    final remoteId = rows.first['remote_id'] as String;
    final action = approve ? 'approve' : 'reject';
    final response = await apiClient.post(
      '/authorization-requests/$remoteId/$action',
      body: {'comment': comment},
    );
    await _upsertAuthorizationRequest(
      await helpers.resolveNegocioId(),
      response,
    );
  }

  Future<String?> _resolveEntityRemoteId(Map<String, Object?> payload) async {
    final entity = helpers.stringOrNull(payload['entidad']);
    final localId = helpers.intValue(payload['entidad_id']);
    if (localId == 0) return null;
    if (entity == 'producto') {
      return helpers.remoteIdForLocalId(DatabaseSchema.productosTable, localId);
    }
    if (entity == 'cliente') {
      return helpers.remoteIdForLocalId(DatabaseSchema.clientesTable, localId);
    }
    return null;
  }

  Future<AuthorizationRequestCloudSyncResult> _applyPushResults(
    List<Map<String, dynamic>> results,
    int preErrors,
  ) async {
    final pending = await helpers.pendingItems(
      DatabaseSchema.solicitudesAutorizacionTable,
    );
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
          table: DatabaseSchema.solicitudesAutorizacionTable,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await helpers.syncQueueRepository.marcarComoProcesado(queue.id!);
        sent++;
      } else {
        await helpers.syncQueueRepository.marcarComoFallido(
          queue.id!,
          error ?? 'El backend no pudo sincronizar la solicitud.',
        );
        errors++;
      }
    }
    return _result(sent: sent, errors: errors);
  }

  Future<bool> _upsertAuthorizationRequest(
    int negocioId,
    Map<String, dynamic> request,
  ) async {
    final user = await authRepository.obtenerUsuarioActual();
    final collaboratorId = await helpers.localIdForRemoteId(
      DatabaseSchema.usuariosTable,
      request['collaboratorId'] as String?,
    );
    final fallbackCollaboratorId =
        user?.tipoUsuario == UsuarioSqliteModel.tipoColaborador
        ? user?.id
        : null;
    final localCollaboratorId = collaboratorId ?? fallbackCollaboratorId;
    if (localCollaboratorId == null) return false;

    final serverId = request['id'] as String;
    final now = DateTime.now().toIso8601String();
    await helpers.upsertByRemoteId(
      table: DatabaseSchema.solicitudesAutorizacionTable,
      remoteId: serverId,
      values: {
        'negocio_id': negocioId,
        'remote_id': serverId,
        'colaborador_id': localCollaboratorId,
        'tipo_solicitud': request['requestType'] as String? ?? '',
        'entidad': request['entity'] as String? ?? '',
        'entidad_id': await _resolveEntityLocalId(request),
        'datos_antes': request['dataBeforeJson'] as String?,
        'datos_despues': request['dataAfterJson'] as String? ?? '{}',
        'estado': _localStatus(request['status'] as String?),
        'comentario_negocio': request['businessComment'] as String?,
        'resolved_at': request['decidedAt'] as String?,
        'created_at': request['createdAt'] as String? ?? now,
        'updated_at': request['updatedAt'] as String? ?? now,
        'deleted_at': request['deletedAt'] as String?,
        'last_synced_at': now,
        'sync_status': request['deletedAt'] == null
            ? SyncStatus.synced
            : SyncStatus.deleted,
      },
    );
    return true;
  }

  Future<int?> _resolveEntityLocalId(Map<String, dynamic> request) async {
    final entity = request['entity'] as String?;
    final remoteId = request['entityId'] as String?;
    if (entity == 'producto' || entity == 'product') {
      return helpers.localIdForRemoteId(
        DatabaseSchema.productosTable,
        remoteId,
      );
    }
    if (entity == 'cliente' || entity == 'client') {
      return helpers.localIdForRemoteId(DatabaseSchema.clientesTable, remoteId);
    }
    return null;
  }

  String _localStatus(String? status) {
    return switch (status) {
      'aprobada' => 'aprobado',
      'rechazada' => 'rechazado',
      _ => status ?? 'pendiente',
    };
  }

  AuthorizationRequestCloudSyncResult _empty() => _result();

  AuthorizationRequestCloudSyncResult _result({
    int sent = 0,
    int received = 0,
    int errors = 0,
  }) {
    return AuthorizationRequestCloudSyncResult(
      sent: sent,
      received: received,
      errors: errors,
    );
  }
}
