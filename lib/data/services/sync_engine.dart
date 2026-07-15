import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/diagnostics/backend_connection_diagnostics.dart';
import '../models/new_sync_status.dart';
import '../models/sync_outbox_item.dart';
import '../models/sync_state_model.dart';
import '../models/sync_user_status.dart';
import '../models/usuario_sqlite_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/sync_outbox_repository.dart';
import '../repositories/sync_state_repository.dart';
import 'api_client.dart';
import 'cloud_auth_service.dart';
import 'inventory_backfill_service.dart';
import 'inventory_image_sync_diagnostics.dart';
import 'sync_device_identity_service.dart';
import 'sync_endpoint_registry.dart';
import 'sync_module_adapter.dart';

class SyncEngineResult {
  final int pushedCount;
  final int pulledCount;
  final int pendingCount;
  final String? error;

  const SyncEngineResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.pendingCount,
    this.error,
  });

  bool get succeeded => error == null;
}

class SyncEngine {
  static const _inventoryImagesOutboxMigrationKey =
      'inventory_images_endpoint_migration_v1';

  final SyncOutboxRepository outboxRepository;
  final SyncStateRepository stateRepository;
  final SyncDeviceIdentityService deviceIdentityService;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final InventoryBackfillService? inventoryBackfillService;
  final Map<String, SyncModuleAdapter> _adapters;

  bool _running = false;
  bool _syncing = false;

  SyncEngine({
    required this.outboxRepository,
    required this.stateRepository,
    required this.deviceIdentityService,
    required this.apiClient,
    required this.authRepository,
    this.inventoryBackfillService,
    List<SyncModuleAdapter> adapters = const [],
  }) : _adapters = {for (final adapter in adapters) adapter.module: adapter};

  bool get isRunning => _running;
  bool get isSyncing => _syncing;

  Future<void> start() async {
    _running = true;
    await deviceIdentityService.getOrCreateDeviceId();
  }

  Future<void> stop() async {
    _running = false;
  }

  Future<SyncEngineResult> syncNow({String? module}) async {
    if (_syncing) {
      return SyncEngineResult(
        pushedCount: 0,
        pulledCount: 0,
        pendingCount: await outboxRepository.pendingCount(module: module),
      );
    }
    _syncing = true;
    try {
      await _prepareInventoryImagesOutbox();
      if (kDebugMode) {
        debugPrint('[Sync] baseUrl=${await apiClient.effectiveBaseUrl()}');
      }
      final authState = await _logAndValidateAuthState();
      if (!authState.tokenPresent) {
        final pending = await outboxRepository.pendingCount(module: module);
        return SyncEngineResult(
          pushedCount: 0,
          pulledCount: 0,
          pendingCount: pending,
        );
      }
      if (authState.businessId == null) {
        final pending = await outboxRepository.pendingCount(module: module);
        const error = 'No se pudo actualizar: negocio no identificado.';
        await BackendConnectionDiagnostics.recordError(
          sharedPreferences: apiClient.sharedPreferences,
          error: error,
          module: module,
        );
        return SyncEngineResult(
          pushedCount: 0,
          pulledCount: 0,
          pendingCount: pending,
          error: error,
        );
      }
      if (module == null || module == 'inventory') {
        final negocioId = int.tryParse(authState.businessId!);
        if (negocioId != null) {
          await inventoryBackfillService?.runForBusiness(negocioId: negocioId);
        }
      }
      final pushed = await pushPending(module: module);
      final pulled = await pullChanges(module: module);
      final pending = await outboxRepository.pendingCount(module: module);
      return SyncEngineResult(
        pushedCount: pushed,
        pulledCount: pulled,
        pendingCount: pending,
      );
    } catch (error) {
      final pending = await outboxRepository.pendingCount(module: module);
      debugPrint('[sync-engine] error module=${module ?? '*'} error=$error');
      return SyncEngineResult(
        pushedCount: 0,
        pulledCount: 0,
        pendingCount: pending,
        error: '$error',
      );
    } finally {
      _syncing = false;
    }
  }

  Future<int> pushPending({String? module}) async {
    await _prepareInventoryImagesOutbox();
    final deviceId = await deviceIdentityService.getOrCreateDeviceId();
    final businessId = await _businessId();
    final tokenPresent = await apiClient.hasUsableToken();
    final items = await outboxRepository.pending(module: module);
    if (items.isEmpty || !tokenPresent || businessId == null) return 0;
    await outboxRepository.markSyncing(items);

    final modules = <String, List<SyncOutboxItem>>{};
    for (final item in items) {
      modules.putIfAbsent(item.module, () => <SyncOutboxItem>[]).add(item);
    }

    var pushed = 0;
    for (final entry in modules.entries) {
      final moduleName = entry.key;
      final moduleItems = entry.value;
      final endpoint = SyncEndpointRegistry.forModule(moduleName);
      final stopwatch = Stopwatch()..start();
      try {
        final uri = await apiClient.requestUri(endpoint.pushPath);
        await BackendConnectionDiagnostics.recordRequest(
          sharedPreferences: apiClient.sharedPreferences,
          endpoint: uri,
          module: moduleName,
          operation: 'push',
        );
        if (kDebugMode) {
          debugPrint(
            '[SyncRequest] module=$moduleName operation=push url=$uri businessId=$businessId deviceId=$deviceId tokenPresent=$tokenPresent',
          );
        }
        final requestBody =
            endpoint.pushPayloadShape ==
                SyncPushPayloadShape.inventoryImageMetadata
            ? <String, Object?>{
                'images': moduleItems
                    .map((item) => item.payloadAsMap())
                    .toList(growable: false),
              }
            : <String, Object?>{
                'deviceId': deviceId,
                'changes': moduleItems
                    .map(
                      (item) => {
                        'uuid': item.uuid,
                        'businessId': item.businessId,
                        'entityType': item.entityType,
                        'entityUuid': item.entityUuid,
                        'operation': item.operation,
                        'payload': item.payloadAsMap(),
                        'updatedAt': item.updatedAt.toIso8601String(),
                      },
                    )
                    .toList(growable: false),
              };
        if (kDebugMode &&
            endpoint.pushPayloadShape ==
                SyncPushPayloadShape.inventoryImageMetadata) {
          debugPrint(
            '[inventory-images-push-request] ${InventoryImageSyncDiagnostics.pushRequestLog(endpoint: uri, module: moduleName, body: requestBody, items: moduleItems)}',
          );
        }
        final response = await apiClient.post(
          endpoint.pushPath,
          body: requestBody,
        );
        final diagnostic = await BackendConnectionDiagnostics.read(
          apiClient.sharedPreferences,
        );
        if (kDebugMode) {
          debugPrint(
            '[SyncResponse] module=$moduleName operation=push status=${diagnostic.lastStatusCode ?? 'ok'} body=${diagnostic.lastResponseBody ?? response}',
          );
        }
        final rejected = (response['rejected'] as num? ?? 0).toInt();
        if (rejected > 0) {
          final errors = (response['errors'] as List<dynamic>? ?? const [])
              .map((error) => error.toString())
              .where((error) => error.trim().isNotEmpty)
              .join('; ');
          throw StateError(
            errors.isEmpty
                ? 'El backend rechazo $rejected cambios.'
                : 'El backend rechazo $rejected cambios: $errors',
          );
        }
        await outboxRepository.markSynced(moduleItems);
        await _adapters[moduleName]?.onPushAccepted(
          items: moduleItems,
          serverTime:
              DateTime.tryParse(response['serverTime']?.toString() ?? '') ??
              DateTime.now(),
        );
        pushed += moduleItems.length;
        await _updateModuleState(
          moduleName,
          lastPushAt: DateTime.now(),
          lastSuccessAt: DateTime.now(),
          clearError: true,
        );
        stopwatch.stop();
        if (kDebugMode) {
          debugPrint(
            '[Sync] module=$moduleName operation=push status=ok elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
        }
      } catch (error) {
        stopwatch.stop();
        if (kDebugMode &&
            moduleName == SyncEndpointRegistry.inventoryImages.localModule &&
            error is ApiException &&
            error.statusCode == 400) {
          final diagnostic = await BackendConnectionDiagnostics.read(
            apiClient.sharedPreferences,
          );
          debugPrint(
            '[inventory-images-push-400] endpoint=${endpoint.pushPath} module=$moduleName statusCode=400 body=${diagnostic.lastResponseBody ?? 'unavailable'} events=${InventoryImageSyncDiagnostics.failedEventsLog(moduleItems)}',
          );
        }
        await BackendConnectionDiagnostics.recordError(
          sharedPreferences: apiClient.sharedPreferences,
          error: error,
          module: moduleName,
          operation: 'push',
        );
        if (error is! ApiException || error.code != 'SESSION_REPLACED') {
          await outboxRepository.markFailed(moduleItems, '$error');
        }
        await _updateModuleState(moduleName, lastError: '$error');
        if (kDebugMode) {
          debugPrint(
            '[Sync] module=$moduleName operation=push status=error elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
          debugPrint('[SyncError] module=$moduleName error=$error');
        }
        rethrow;
      }
    }
    return pushed;
  }

  Future<int> pullChanges({String? module}) async {
    final deviceId = await deviceIdentityService.getOrCreateDeviceId();
    final businessId = await _businessId();
    final tokenPresent = await apiClient.hasUsableToken();
    if (!tokenPresent || businessId == null) return 0;
    final modules = module == null
        ? await _modulesKnownLocally()
        : <String>{module};
    if (modules.isEmpty) return 0;
    var pulled = 0;
    for (final moduleName in modules) {
      final endpoint = SyncEndpointRegistry.forModule(moduleName);
      if (!endpoint.supportsGlobalPull) {
        final pendingForModule = await outboxRepository.pendingCount(
          module: moduleName,
        );
        final failedForModule = await outboxRepository.failedCount(
          module: moduleName,
        );
        if (pendingForModule == 0 && failedForModule == 0) {
          await _updateModuleState(moduleName, clearError: true);
        }
        if (kDebugMode) {
          debugPrint(
            '[InventoryMediaSync] pull skipped mode=lazy module=$moduleName pending=$pendingForModule failed=$failedForModule staleErrorCleared=${pendingForModule == 0 && failedForModule == 0}',
          );
        }
        continue;
      }
      final stopwatch = Stopwatch()..start();
      final state = await _stateForModule(moduleName);
      try {
        final uri = await apiClient.requestUri(endpoint.pullPath);
        await BackendConnectionDiagnostics.recordRequest(
          sharedPreferences: apiClient.sharedPreferences,
          endpoint: uri,
          module: moduleName,
          operation: 'pull',
        );
        if (kDebugMode) {
          debugPrint(
            '[SyncRequest] module=$moduleName operation=pull url=$uri businessId=$businessId deviceId=$deviceId tokenPresent=$tokenPresent',
          );
        }
        final response = await apiClient.post(
          endpoint.pullPath,
          body: {
            'deviceId': deviceId,
            'lastPullAt': state?.lastPullAt?.toIso8601String(),
          },
        );
        final diagnostic = await BackendConnectionDiagnostics.read(
          apiClient.sharedPreferences,
        );
        if (kDebugMode) {
          debugPrint(
            '[SyncResponse] module=$moduleName operation=pull status=${diagnostic.lastStatusCode ?? 'ok'} body=${diagnostic.lastResponseBody ?? response}',
          );
        }
        final changes = response['changes'] as List<dynamic>? ?? const [];
        final mappedChanges = changes
            .whereType<Map<String, dynamic>>()
            .map((change) => Map<String, Object?>.from(change))
            .toList(growable: false);
        pulled +=
            await (_adapters[moduleName]?.applyPullChanges(mappedChanges) ??
                Future.value(changes.length));
        await _updateModuleState(
          moduleName,
          lastPullAt: DateTime.now(),
          lastSuccessAt: DateTime.now(),
          clearError: true,
        );
        stopwatch.stop();
        if (kDebugMode) {
          debugPrint(
            '[Sync] module=$moduleName operation=pull status=ok elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
        }
      } catch (error) {
        stopwatch.stop();
        await BackendConnectionDiagnostics.recordError(
          sharedPreferences: apiClient.sharedPreferences,
          error: error,
          module: moduleName,
          operation: 'pull',
        );
        await _updateModuleState(moduleName, lastError: '$error');
        if (kDebugMode) {
          debugPrint(
            '[Sync] module=$moduleName operation=pull status=error elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
          debugPrint('[SyncError] module=$moduleName error=$error');
        }
        rethrow;
      }
    }
    return pulled;
  }

  Future<NewSyncStatus> recomputeStatus() async {
    final pending = await outboxRepository.pendingCount();
    final outboxError = await outboxRepository.lastError();
    final stateError = await stateRepository.lastErrorWithPendingWork();
    final lastSuccess = await stateRepository.lastSuccessAt();
    if (_syncing) {
      return NewSyncStatus(
        state: NewSyncUiState.updating,
        pendingCount: pending,
        lastSuccessAt: lastSuccess,
      );
    }
    final error = outboxError ?? stateError;
    if (error != null) {
      return NewSyncStatus(
        state: NewSyncUiState.error,
        pendingCount: pending,
        lastSuccessAt: lastSuccess,
        lastError: error,
      );
    }
    if (pending > 0) {
      return NewSyncStatus(
        state: NewSyncUiState.savedOnThisDevice,
        pendingCount: pending,
        lastSuccessAt: lastSuccess,
      );
    }
    if (lastSuccess != null) {
      return NewSyncStatus(
        state: NewSyncUiState.allUpdated,
        pendingCount: 0,
        lastSuccessAt: lastSuccess,
      );
    }
    return const NewSyncStatus(state: NewSyncUiState.allSaved, pendingCount: 0);
  }

  Future<SyncUserStatus> recomputeUserStatus({
    required bool isOnline,
    required bool isCloudAuthenticated,
  }) async {
    final status = await recomputeStatus();
    return SyncUserStatus(
      isOnline: isOnline,
      isCloudAuthenticated: isCloudAuthenticated,
      isSyncing: status.state == NewSyncUiState.updating,
      pendingCount: status.pendingCount,
      lastSyncAt: status.lastSuccessAt,
      lastSyncSucceeded:
          isCloudAuthenticated && status.state == NewSyncUiState.allUpdated,
      lastErrorMessage: status.lastError,
    );
  }

  Future<Set<String>> _modulesKnownLocally() async {
    final items = await outboxRepository.pending(limit: 500);
    final states = await stateRepository.allStates();
    return {
      ...items.map((item) => item.module),
      ...states.map((state) => state.module),
      ..._adapters.keys,
    };
  }

  Future<void> _prepareInventoryImagesOutbox() async {
    final preferences = await apiClient.sharedPreferences;
    if (preferences.getBool(_inventoryImagesOutboxMigrationKey) ?? false) {
      return;
    }
    final reactivated = await outboxRepository
        .reactivateLegacyInventoryImageEvents();
    await preferences.setBool(_inventoryImagesOutboxMigrationKey, true);
    if (kDebugMode) {
      debugPrint(
        '[InventoryMediaSync] legacyOutboxReactivated count=$reactivated',
      );
    }
  }

  Future<void> _updateModuleState(
    String module, {
    DateTime? lastPullAt,
    DateTime? lastPushAt,
    DateTime? lastSuccessAt,
    String? lastError,
    bool clearError = false,
  }) async {
    final businessId = await _businessId();
    if (businessId == null) return;
    final current = await stateRepository.getState(
      businessId: businessId,
      module: module,
    );
    await stateRepository.upsert(
      businessId: businessId,
      module: module,
      lastPullAt: lastPullAt ?? current?.lastPullAt,
      lastPushAt: lastPushAt ?? current?.lastPushAt,
      lastSuccessAt: lastSuccessAt ?? current?.lastSuccessAt,
      lastError: clearError ? null : lastError ?? current?.lastError,
      pendingCount: await outboxRepository.pendingCount(module: module),
    );
  }

  Future<SyncStateModel?> _stateForModule(String module) async {
    final businessId = await _businessId();
    if (businessId == null) return null;
    return stateRepository.getState(businessId: businessId, module: module);
  }

  Future<String?> _businessId() async {
    final user = await authRepository.obtenerUsuarioActual();
    final id = switch (user?.tipoUsuario) {
      UsuarioSqliteModel.tipoNegocio => user?.id,
      UsuarioSqliteModel.tipoColaborador => user?.negocioId,
      _ => null,
    };
    return id?.toString();
  }

  Future<_SyncAuthState> _logAndValidateAuthState() async {
    final user = await authRepository.obtenerUsuarioActual();
    final businessId = await _businessId();
    final tokenPresent = await apiClient.hasUsableToken();
    final deviceId = await deviceIdentityService.getOrCreateDeviceId();
    final prefs = await apiClient.sharedPreferences;
    final sessionVersion = prefs.getInt(
      CloudAuthService.cloudSessionVersionKey,
    );
    if (kDebugMode) {
      debugPrint('[AuthState] tokenPresent=$tokenPresent');
      debugPrint('[AuthState] userId=${user?.id ?? 'null'}');
      debugPrint('[AuthState] businessId=${businessId ?? 'null'}');
      debugPrint('[AuthState] role=${user?.tipoUsuario ?? 'null'}');
      debugPrint('[AuthState] deviceId=$deviceId');
      debugPrint('[AuthState] sessionVersion=${sessionVersion ?? 'null'}');
    }
    return _SyncAuthState(tokenPresent: tokenPresent, businessId: businessId);
  }
}

class _SyncAuthState {
  final bool tokenPresent;
  final String? businessId;

  const _SyncAuthState({required this.tokenPresent, required this.businessId});
}
