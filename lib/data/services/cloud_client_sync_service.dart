import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../../core/database/local_database.dart';
import '../../core/database/database_schema.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_queue_item_model.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_queue_repository.dart';
import 'api_client.dart';
import 'sync_endpoint_registry.dart';

class ClientCloudSyncResult {
  final int sent;
  final int received;
  final int errors;
  final String? message;

  const ClientCloudSyncResult({
    required this.sent,
    required this.received,
    required this.errors,
    this.message,
  });
}

class CloudClientSyncService {
  static const _lastSyncPrefix = 'fiado_clients_last_sync_';

  final ApiClient apiClient;
  final AuthRepository authRepository;
  final SyncQueueRepository syncQueueRepository;
  final LocalDatabase databaseHelper;
  final Future<SharedPreferences> sharedPreferences;

  const CloudClientSyncService({
    required this.apiClient,
    required this.authRepository,
    required this.syncQueueRepository,
    required this.databaseHelper,
    required this.sharedPreferences,
  });

  Future<ClientCloudSyncResult> syncClients() async {
    final push = await pushPendingClients();
    final pull = await pullClients();

    return ClientCloudSyncResult(
      sent: push.sent,
      received: pull.received,
      errors: push.errors + pull.errors,
      message: pull.message ?? push.message,
    );
  }

  Future<ClientCloudSyncResult> pushPendingClients() async {
    final negocioId = await _resolveNegocioId();
    final pending = await _pendingClientItems();
    debugPrint('[clients-sync] push count=${pending.length}');
    if (pending.isEmpty) {
      return const ClientCloudSyncResult(sent: 0, received: 0, errors: 0);
    }

    for (final item in pending) {
      await syncQueueRepository.incrementarIntento(item.id!);
    }

    final requestItems = <Map<String, Object?>>[];
    for (final item in pending) {
      final payload = item.payloadAsMap();
      requestItems.add({
        'localId': item.entityId,
        'serverId': _stringOrNull(payload['remote_id']),
        'name': payload['nombre'] ?? payload['name'] ?? '',
        'phone': payload['telefono'] ?? payload['phone'] ?? '',
        'address': payload['address'],
        'operation': item.operation,
        'updatedAt':
            payload['updated_at'] ??
            payload['updatedAt'] ??
            item.updatedAt.toIso8601String(),
      });
    }

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('clients').pushPath,
      body: {'clients': requestItems},
    );
    debugPrint('[clients-sync] response status=ok');
    final results = (response['results'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var sent = 0;
    var errors = 0;

    for (final result in results) {
      final localId = (result['localId'] as num).toInt();
      final queueItem = pending.firstWhere((item) => item.entityId == localId);
      final status = result['status'] as String? ?? 'failed';
      final error = result['error'] as String?;
      debugPrint(
        '[clients-sync] item result localId=$localId remoteId=${result['serverId']} status=$status error=${error ?? 'none'}',
      );

      if (error == null && status != 'failed') {
        await _markClientSynced(
          negocioId: negocioId,
          localId: localId,
          serverId: result['serverId'] as String?,
          serverUpdatedAt: result['serverUpdatedAt'] as String?,
        );
        await syncQueueRepository.marcarComoProcesado(queueItem.id!);
        sent++;
      } else {
        await syncQueueRepository.marcarComoFallido(
          queueItem.id!,
          error ?? 'El backend no pudo sincronizar el cliente.',
        );
        errors++;
      }
    }

    return ClientCloudSyncResult(sent: sent, received: 0, errors: errors);
  }

  Future<ClientCloudSyncResult> pullClients() async {
    final negocioId = await _resolveNegocioId();
    final prefs = await sharedPreferences;
    final lastSyncAt = prefs.getString('$_lastSyncPrefix$negocioId');

    final response = await apiClient.post(
      LegacySyncEndpointRegistry.forHandler('clients').pullPath,
      body: {'lastSyncAt': lastSyncAt},
    );
    final serverTime = response['serverTime'] as String?;
    final clients = (response['clients'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    var received = 0;
    for (final client in clients) {
      await _upsertPulledClient(negocioId, client);
      received++;
    }

    if (serverTime != null) {
      await prefs.setString('$_lastSyncPrefix$negocioId', serverTime);
    }

    return ClientCloudSyncResult(sent: 0, received: received, errors: 0);
  }

  Future<List<SyncQueueItemModel>> _pendingClientItems() async {
    final pending = await syncQueueRepository.obtenerPendientes(limit: 500);
    return pending.where((item) {
      final type = item.entityType.toLowerCase();
      return type == DatabaseSchema.clientesTable ||
          type == 'clients' ||
          type == 'cliente';
    }).toList();
  }

  Future<int> _resolveNegocioId() async {
    final user = await authRepository.obtenerUsuarioActual();
    if (user == null) {
      throw StateError('No hay una sesion local activa.');
    }
    if (user.tipoUsuario == UsuarioSqliteModel.tipoPersonal) {
      throw StateError(
        'El usuario Personal no sincroniza clientes de negocio.',
      );
    }
    final negocioId = user.tipoUsuario == UsuarioSqliteModel.tipoNegocio
        ? user.id
        : user.negocioId;
    if (negocioId == null) {
      throw StateError('El usuario actual no tiene negocio asociado.');
    }
    return negocioId;
  }

  Future<void> _markClientSynced({
    required int negocioId,
    required int localId,
    required String? serverId,
    required String? serverUpdatedAt,
  }) async {
    final db = await databaseHelper.database;
    await db.update(
      DatabaseSchema.clientesTable,
      {
        'remote_id': serverId,
        'sync_status': SyncStatus.synced,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': serverUpdatedAt,
      },
      where: 'id = ? AND negocio_id = ?',
      whereArgs: [localId, negocioId],
    );
  }

  Future<void> _upsertPulledClient(
    int negocioId,
    Map<String, dynamic> client,
  ) async {
    final db = await databaseHelper.database;
    final serverId = client['id'] as String;
    final phone = client['phone'] as String;
    final now = DateTime.now().toIso8601String();
    final isActive = (client['isActive'] as bool? ?? true) ? 1 : 0;

    final values = <String, Object?>{
      'negocio_id': negocioId,
      'uuid': client['remoteId'] as String? ?? serverId,
      'remote_id': serverId,
      'nombre': client['name'] as String? ?? '',
      'telefono': phone,
      'address': client['address'] as String?,
      'deuda': (client['debt'] as num? ?? 0).toDouble(),
      'is_active': isActive,
      'deleted_at': client['deletedAt'] as String?,
      'last_synced_at': now,
      'created_at': client['createdAt'] as String? ?? now,
      'updated_at': client['updatedAt'] as String? ?? now,
      'sync_version': 0,
      'sync_status': SyncStatus.synced,
    };

    final existing = await db.query(
      DatabaseSchema.clientesTable,
      columns: ['id'],
      where: 'negocio_id = ? AND (remote_id = ? OR telefono = ?)',
      whereArgs: [negocioId, serverId, phone],
      limit: 1,
    );

    if (existing.isEmpty) {
      await db.insert(
        DatabaseSchema.clientesTable,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } else {
      await db.update(
        DatabaseSchema.clientesTable,
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  String? _stringOrNull(Object? value) {
    final text = value?.toString();
    return text == null || text.trim().isEmpty ? null : text;
  }
}
