import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database_helper.dart';
import '../../core/sync/sync_feature_flags.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/cliente_repository.dart';
import '../../data/repositories/inventory_product_metrics_repository.dart';
import '../../data/repositories/producto_repository.dart';
import '../../data/repositories/sync_outbox_repository.dart';
import '../../data/repositories/sync_diagnostics_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/sync_state_repository.dart';
import '../../data/repositories/sync_status_diagnostics_repository.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auto_sync_service.dart';
import '../../data/services/cloud_auth_service.dart';
import '../../data/services/cloud_audit_sync_service.dart';
import '../../data/services/cloud_authorization_request_sync_service.dart';
import '../../data/services/cloud_client_score_sync_service.dart';
import '../../data/services/cloud_client_sync_service.dart';
import '../../data/services/cloud_credit_cycle_sync_service.dart';
import '../../data/services/cloud_financial_sync_helpers.dart';
import '../../data/services/cloud_movement_sync_service.dart';
import '../../data/services/cloud_product_sync_service.dart';
import '../../data/services/cloud_receipt_sync_service.dart';
import '../../data/services/cloud_whatsapp_campaign_sync_service.dart';
import '../../data/services/client_sync_adapter.dart';
import '../../data/services/inventory_sync_adapter.dart';
import '../../data/services/inventory_media_sync_service.dart';
import '../../data/services/inventory_backfill_service.dart';
import '../../data/services/legacy_sync_queue_diagnostics.dart';
import '../../data/services/payment_service.dart';
import '../../data/services/subscription_billing_service.dart';
import '../../data/services/sync_device_identity_service.dart';
import '../../data/services/sync_engine.dart';
import '../../data/services/sync_scheduler.dart';
import '../../data/services/sync_service.dart';
import '../../data/models/new_sync_status.dart';
import '../../data/models/sync_user_status.dart';

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository();
});

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((ref) {
  return SyncOutboxRepository();
});

final syncStateRepositoryProvider = Provider<SyncStateRepository>((ref) {
  return SyncStateRepository();
});

final syncStatusDiagnosticsRepositoryProvider =
    Provider<SyncStatusDiagnosticsRepository>((ref) {
      return SyncStatusDiagnosticsRepository();
    });

final syncDiagnosticsRepositoryProvider = Provider<SyncDiagnosticsRepository>((
  ref,
) {
  return SyncDiagnosticsRepository(
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final syncDeviceIdentityServiceProvider = Provider<SyncDeviceIdentityService>((
  ref,
) {
  return SyncDeviceIdentityService(
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    outboxRepository: ref.read(syncOutboxRepositoryProvider),
    stateRepository: ref.read(syncStateRepositoryProvider),
    deviceIdentityService: ref.read(syncDeviceIdentityServiceProvider),
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryForSyncProvider),
    inventoryBackfillService: ref.read(inventoryBackfillServiceProvider),
    adapters: [
      ClientSyncAdapter(
        clienteRepository: ClienteRepository(
          syncQueueRepository: ref.read(syncQueueRepositoryProvider),
          syncOutboxRepository: ref.read(syncOutboxRepositoryProvider),
        ),
        authRepository: ref.read(authRepositoryForSyncProvider),
      ),
      InventorySyncAdapter(
        productoRepository: ProductoRepository(
          syncQueueRepository: ref.read(syncQueueRepositoryProvider),
          syncOutboxRepository: ref.read(syncOutboxRepositoryProvider),
        ),
        authRepository: ref.read(authRepositoryForSyncProvider),
      ),
    ],
  );
});

final inventoryBackfillServiceProvider = Provider<InventoryBackfillService>((
  ref,
) {
  return InventoryBackfillService(
    syncOutboxRepository: ref.read(syncOutboxRepositoryProvider),
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final inventoryMediaSyncServiceProvider = Provider<InventoryMediaSyncService>((
  ref,
) {
  return InventoryMediaSyncService(
    apiClient: ref.read(apiClientProvider),
    syncOutboxRepository: ref.read(syncOutboxRepositoryProvider),
  );
});

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(syncEngine: ref.read(syncEngineProvider));
  ref.onDispose(() {
    scheduler.stop();
  });
  return scheduler;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final syncStatusProvider = FutureProvider<SyncQueueSummary>((ref) {
  return ref.read(syncQueueRepositoryProvider).obtenerResumen();
});

final newSyncStatusProvider = FutureProvider<NewSyncStatus>((ref) {
  return ref.read(syncEngineProvider).recomputeStatus();
});

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  return AutoSyncService(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    clientSyncService: ref.read(cloudClientSyncServiceProvider),
    productSyncService: ref.read(cloudProductSyncServiceProvider),
    movementSyncService: ref.read(cloudMovementSyncServiceProvider),
    receiptSyncService: ref.read(cloudReceiptSyncServiceProvider),
    creditCycleSyncService: ref.read(cloudCreditCycleSyncServiceProvider),
    auditSyncService: ref.read(cloudAuditSyncServiceProvider),
    authorizationRequestSyncService: ref.read(
      cloudAuthorizationRequestSyncServiceProvider,
    ),
    clientScoreSyncService: ref.read(cloudClientScoreSyncServiceProvider),
    whatsappCampaignSyncService: ref.read(
      cloudWhatsappCampaignSyncServiceProvider,
    ),
    isCloudAuthenticated: () =>
        ref.read(cloudAuthServiceProvider).isCloudAuthenticated(),
    canSyncBusiness: () async {
      // TODO: Reactivate commercial access checks after stabilization.
      // Sync protects user data and should not be blocked by subscription,
      // backend rollout, or payment-method state while local-first is settling.
      return true;
    },
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final syncUserStatusProvider =
    StateNotifierProvider<SyncUserStatusNotifier, AsyncValue<SyncUserStatus>>((
      ref,
    ) {
      return SyncUserStatusNotifier(ref);
    });

final sharedPreferencesProvider = Provider<Future<SharedPreferences>>((ref) {
  return SharedPreferences.getInstance();
});

final authRepositoryForSyncProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    httpClient: http.Client(),
    authRepository: ref.read(authRepositoryForSyncProvider),
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final cloudAuthServiceProvider = Provider<CloudAuthService>((ref) {
  return CloudAuthService(
    httpClient: http.Client(),
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final cloudClientSyncServiceProvider = Provider<CloudClientSyncService>((ref) {
  return CloudClientSyncService(
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryForSyncProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    databaseHelper: DatabaseHelper.instance,
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final clientCloudSyncStatusProvider = StateProvider<ClientCloudSyncResult?>(
  (ref) => null,
);

final cloudProductSyncServiceProvider = Provider<CloudProductSyncService>((
  ref,
) {
  return CloudProductSyncService(
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryForSyncProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    databaseHelper: DatabaseHelper.instance,
    sharedPreferences: ref.read(sharedPreferencesProvider),
    inventoryMetricsRepository: InventoryProductMetricsRepository(),
  );
});

final productCloudSyncStatusProvider = StateProvider<ProductCloudSyncResult?>(
  (ref) => null,
);

final cloudMovementSyncServiceProvider = Provider<CloudMovementSyncService>((
  ref,
) {
  return CloudMovementSyncService(
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryForSyncProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    databaseHelper: DatabaseHelper.instance,
    sharedPreferences: ref.read(sharedPreferencesProvider),
    inventoryMetricsRepository: InventoryProductMetricsRepository(),
  );
});

final cloudReceiptSyncServiceProvider = Provider<CloudReceiptSyncService>((
  ref,
) {
  return CloudReceiptSyncService(
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryForSyncProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    databaseHelper: DatabaseHelper.instance,
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final cloudCreditCycleSyncServiceProvider =
    Provider<CloudCreditCycleSyncService>((ref) {
      return CloudCreditCycleSyncService(
        apiClient: ref.read(apiClientProvider),
        authRepository: ref.read(authRepositoryForSyncProvider),
        syncQueueRepository: ref.read(syncQueueRepositoryProvider),
        databaseHelper: DatabaseHelper.instance,
        sharedPreferences: ref.read(sharedPreferencesProvider),
      );
    });

final movementCloudSyncStatusProvider =
    StateProvider<FinancialCloudSyncResult?>((ref) => null);

final receiptCloudSyncStatusProvider = StateProvider<FinancialCloudSyncResult?>(
  (ref) => null,
);

final creditCycleCloudSyncStatusProvider =
    StateProvider<FinancialCloudSyncResult?>((ref) => null);

final cloudAuditSyncServiceProvider = Provider<CloudAuditSyncService>((ref) {
  return CloudAuditSyncService(
    apiClient: ref.read(apiClientProvider),
    authRepository: ref.read(authRepositoryForSyncProvider),
    syncQueueRepository: ref.read(syncQueueRepositoryProvider),
    databaseHelper: DatabaseHelper.instance,
    sharedPreferences: ref.read(sharedPreferencesProvider),
  );
});

final cloudAuthorizationRequestSyncServiceProvider =
    Provider<CloudAuthorizationRequestSyncService>((ref) {
      return CloudAuthorizationRequestSyncService(
        apiClient: ref.read(apiClientProvider),
        authRepository: ref.read(authRepositoryForSyncProvider),
        syncQueueRepository: ref.read(syncQueueRepositoryProvider),
        databaseHelper: DatabaseHelper.instance,
        sharedPreferences: ref.read(sharedPreferencesProvider),
      );
    });

final auditCloudSyncStatusProvider = StateProvider<AuditCloudSyncResult?>(
  (ref) => null,
);

final authorizationRequestCloudSyncStatusProvider =
    StateProvider<AuthorizationRequestCloudSyncResult?>((ref) => null);

final cloudClientScoreSyncServiceProvider =
    Provider<CloudClientScoreSyncService>((ref) {
      return CloudClientScoreSyncService(
        apiClient: ref.read(apiClientProvider),
        authRepository: ref.read(authRepositoryForSyncProvider),
        syncQueueRepository: ref.read(syncQueueRepositoryProvider),
        databaseHelper: DatabaseHelper.instance,
        sharedPreferences: ref.read(sharedPreferencesProvider),
      );
    });

final cloudWhatsappCampaignSyncServiceProvider =
    Provider<CloudWhatsappCampaignSyncService>((ref) {
      return CloudWhatsappCampaignSyncService(
        apiClient: ref.read(apiClientProvider),
        authRepository: ref.read(authRepositoryForSyncProvider),
        syncQueueRepository: ref.read(syncQueueRepositoryProvider),
        databaseHelper: DatabaseHelper.instance,
        sharedPreferences: ref.read(sharedPreferencesProvider),
      );
    });

final clientScoreCloudSyncStatusProvider =
    StateProvider<FinancialCloudSyncResult?>((ref) => null);

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService(apiClient: ref.read(apiClientProvider));
});

final subscriptionBillingServiceProvider = Provider<SubscriptionBillingService>(
  (ref) {
    return SubscriptionBillingService(
      paymentService: ref.read(paymentServiceProvider),
    );
  },
);

class SyncUserStatusNotifier extends StateNotifier<AsyncValue<SyncUserStatus>> {
  final Ref ref;
  String? _lastFriendlyError;
  String? _lastStorageDiagnosticSignature;
  String? _lastLegacyQueueDiagnosticSignature;
  String? currentProgress;

  SyncUserStatusNotifier(this.ref) : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      if (SyncFeatureFlags.useNewSyncEngine) {
        final status = await ref
            .read(syncEngineProvider)
            .recomputeUserStatus(
              isOnline: await ref.read(autoSyncServiceProvider).isOnline(),
              isCloudAuthenticated: await ref
                  .read(cloudAuthServiceProvider)
                  .isCloudAuthenticated(),
            );
        final isProvenHealthy =
            status.isCloudAuthenticated &&
            status.lastSyncSucceeded &&
            status.pendingCount == 0 &&
            status.lastErrorMessage == null;
        if (isProvenHealthy) _lastFriendlyError = null;
        await _publishAndLog(
          _lastFriendlyError == null
              ? status
              : status.copyWith(lastErrorMessage: _lastFriendlyError),
        );
        return;
      }
      await _publishAndLog(
        await ref
            .read(autoSyncServiceProvider)
            .loadUserStatus(lastErrorMessage: _lastFriendlyError),
      );
    } catch (error) {
      await _publishAndLog(
        const SyncUserStatus(
          isOnline: false,
          isCloudAuthenticated: false,
          isSyncing: false,
          pendingCount: 0,
          lastSyncSucceeded: false,
          lastErrorMessage:
              'No pudimos revisar la sincronizacion ahora. Tus datos locales siguen guardados.',
        ),
        calculationError: error,
      );
    }
  }

  Future<GlobalSyncResult?> runAutoSyncIfNeeded() async {
    if (SyncFeatureFlags.useNewSyncEngine) {
      try {
        await _setSyncing(true);
        debugPrint('[SyncAfterAuth] started=true');
        final result = await ref.read(syncEngineProvider).syncNow();
        _lastFriendlyError = result.succeeded
            ? null
            : _humanizeError(result.error ?? _friendlySyncError);
        debugPrint(
          '[SyncAfterAuth] pushStatus=${result.error == null ? 'ok pushed=${result.pushedCount}' : 'error ${result.error}'}',
        );
        debugPrint(
          '[SyncAfterAuth] pullStatus=${result.error == null ? 'ok pulled=${result.pulledCount}' : 'error ${result.error}'}',
        );
        await _setSyncing(false);
        return null;
      } catch (_) {
        _lastFriendlyError = _friendlySyncError;
        debugPrint('[SyncAfterAuth] pushStatus=error');
        debugPrint('[SyncAfterAuth] pullStatus=error');
        await _setSyncing(false);
        return null;
      } finally {
        currentProgress = null;
        await refresh();
        debugPrint(
          '[SyncAfterAuth] finalStatus=${state.valueOrNull?.shortMessage ?? 'unknown'}',
        );
      }
    }
    final service = ref.read(autoSyncServiceProvider);
    try {
      await _setSyncing(true);
      final result = await service.autoSyncIfNeeded(onProgress: _setProgress);
      if (result != null) {
        _lastFriendlyError = result.hasErrors ? _friendlyPartialError : null;
      }
      ref.invalidate(syncStatusProvider);
      await _setSyncing(false);
      return result;
    } catch (_) {
      _lastFriendlyError = _friendlySyncError;
      await _setSyncing(false);
      return null;
    } finally {
      currentProgress = null;
      await refresh();
    }
  }

  Future<GlobalSyncResult?> runAutoSyncNow() {
    return runAutoSyncIfNeeded();
  }

  Future<GlobalSyncResult?> runInitialRestore() async {
    if (SyncFeatureFlags.useNewSyncEngine) {
      return runAutoSyncIfNeeded();
    }
    final service = ref.read(autoSyncServiceProvider);
    try {
      await _setSyncing(true);
      final result = await service.syncNow(onProgress: _setProgress);
      _lastFriendlyError = result.hasErrors ? _friendlyPartialError : null;
      ref.invalidate(syncStatusProvider);
      await _setSyncing(false);
      return result;
    } catch (_) {
      _lastFriendlyError = _friendlySyncError;
      await _setSyncing(false);
      return null;
    } finally {
      currentProgress = null;
      await refresh();
    }
  }

  Future<GlobalSyncResult?> runManualSync() async {
    if (SyncFeatureFlags.useNewSyncEngine) {
      return runAutoSyncIfNeeded();
    }
    final service = ref.read(autoSyncServiceProvider);
    try {
      await _setSyncing(true);
      final result = await service.syncNow(onProgress: _setProgress);
      _lastFriendlyError = result.hasErrors ? _friendlyPartialError : null;
      ref.invalidate(syncStatusProvider);
      await _setSyncing(false);
      return result;
    } catch (error) {
      _lastFriendlyError = _humanizeError(error);
      await _setSyncing(false);
      return null;
    } finally {
      currentProgress = null;
      await refresh();
    }
  }

  Future<void> scheduleAutoSync() async {
    if (SyncFeatureFlags.useNewSyncEngine) {
      await ref.read(syncSchedulerProvider).start();
      return;
    }
    await ref
        .read(autoSyncServiceProvider)
        .scheduleAutoSync(
          onRun: () async {
            await runAutoSyncIfNeeded();
          },
        );
  }

  Future<void> setAuthConnectionError(String message) async {
    _lastFriendlyError = _humanizeError(message);
    await refresh();
  }

  Future<void> _setSyncing(bool syncing) async {
    final current = state.valueOrNull;
    if (current == null) {
      state = const AsyncLoading();
      return;
    }
    await _publishAndLog(current.copyWith(isSyncing: syncing));
  }

  void _setProgress(String progress) {
    currentProgress = progress;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isSyncing: true, clearError: true));
    }
  }

  Future<void> _publishAndLog(
    SyncUserStatus status, {
    Object? calculationError,
  }) async {
    try {
      final diagnostics = ref.read(syncStatusDiagnosticsRepositoryProvider);
      final snapshot = await diagnostics.snapshot();
      final visibleStatus = applyLegacyQueueVisibility(
        status,
        legacyPendingCount: snapshot.pendingLegacyQueueCount,
        legacyFailedCount: snapshot.failedLegacyQueueCount,
      );
      state = AsyncData(visibleStatus);
      debugPrint(
        '[sync-status] sync status final=${visibleStatus.shortMessage}',
      );
      final visibleErrorSource = snapshot.sourceForError(
        visibleStatus.lastErrorMessage,
      );
      final log = {
        'selectedText': visibleStatus.shortMessage,
        'isSyncing': visibleStatus.isSyncing,
        'pendingCountTotal': visibleStatus.pendingCount,
        'pendingOutboxCount': snapshot.pendingOutboxCount,
        'pendingLegacyQueueCount': snapshot.pendingLegacyQueueCount,
        'activePendingLegacyQueueCount': snapshot.activePendingLegacyQueueCount,
        'failedOutboxCount': snapshot.failedOutboxCount,
        'failedLegacyQueueCount': snapshot.failedLegacyQueueCount,
        'activeFailedLegacyQueueCount': snapshot.activeFailedLegacyQueueCount,
        'lastErrorVisible': visibleStatus.lastErrorMessage,
        'lastErrorSource': visibleErrorSource,
        'lastSuccessfulSyncAt':
            (visibleStatus.lastSyncAt ?? snapshot.lastSuccessfulSyncAt)
                ?.toIso8601String(),
        'lastSyncSucceeded': visibleStatus.lastSyncSucceeded,
        'isCloudAuthenticated': visibleStatus.isCloudAuthenticated,
        'pendingModules': snapshot.pendingModules,
        'failedModules': snapshot.failedModules,
        'legacySyncEnabled': SyncFeatureFlags.enableLegacySync,
        if (calculationError != null)
          'calculationError': calculationError.toString(),
      };
      debugPrint('[sync-status-banner-state] ${jsonEncode(log)}');
      debugPrint(
        '[sync-global-status] outboxPending=${snapshot.pendingOutboxCount} '
        'legacyPending=${snapshot.pendingLegacyQueueCount} '
        'outboxFailed=${snapshot.failedOutboxCount} '
        'legacyFailed=${snapshot.failedLegacyQueueCount} '
        'legacyEnabled=${SyncFeatureFlags.enableLegacySync} '
        'visibleText=${visibleStatus.shortMessage}',
      );
      final legacyDiagnosticSignature =
          '${snapshot.pendingLegacyQueueCount}|${snapshot.failedLegacyQueueCount}';
      if (kDebugMode &&
          snapshot.pendingLegacyQueueCount + snapshot.failedLegacyQueueCount >
              0 &&
          _lastLegacyQueueDiagnosticSignature != legacyDiagnosticSignature) {
        _lastLegacyQueueDiagnosticSignature = legacyDiagnosticSignature;
        await LegacySyncQueueDiagnostics().debugPrintSummary();
      } else if (snapshot.pendingLegacyQueueCount == 0 &&
          snapshot.failedLegacyQueueCount == 0) {
        _lastLegacyQueueDiagnosticSignature = null;
      }

      if (visibleStatus.lastErrorMessage != null) {
        final signature =
            '${visibleStatus.lastErrorMessage}|$visibleErrorSource|'
            '${snapshot.pendingOutboxCount}|${snapshot.failedOutboxCount}|'
            '${snapshot.pendingLegacyQueueCount}|${snapshot.failedLegacyQueueCount}';
        if (_lastStorageDiagnosticSignature != signature) {
          _lastStorageDiagnosticSignature = signature;
          await diagnostics.debugPrintSummary();
        }
      } else {
        _lastStorageDiagnosticSignature = null;
      }
    } catch (diagnosticError) {
      state = AsyncData(status);
      debugPrint('[sync-status] sync status final=${status.shortMessage}');
      debugPrint(
        '[sync-status-banner-state] ${jsonEncode({'selectedText': status.shortMessage, 'isSyncing': status.isSyncing, 'pendingCountTotal': status.pendingCount, 'lastErrorVisible': status.lastErrorMessage, 'lastSyncSucceeded': status.lastSyncSucceeded, 'isCloudAuthenticated': status.isCloudAuthenticated, 'diagnosticError': diagnosticError.toString()})}',
      );
    }
  }

  String _humanizeError(Object error) {
    final text = '$error'.toLowerCase();
    if (text.contains('session_replaced') ||
        text.contains('otro dispositivo')) {
      return 'Tu cuenta se inicio en otro dispositivo. Para continuar aqui, inicia sesion nuevamente.';
    }
    if (text.contains('cuenta') && text.contains('nube')) {
      return 'Guardado en este dispositivo';
    }
    if (text.contains('token') ||
        text.contains('jwt') ||
        text.contains('401')) {
      return 'Guardado en este dispositivo';
    }
    if (text.contains('internet') || text.contains('conexion')) {
      return 'Guardado en este dispositivo';
    }
    return _friendlySyncError;
  }

  static const _friendlySyncError = 'No se pudo actualizar';
  static const _friendlyPartialError = 'No se pudo actualizar';
}
