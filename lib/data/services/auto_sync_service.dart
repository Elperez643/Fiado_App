import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sync/sync_feature_flags.dart';
import '../models/sync_user_status.dart';
import '../repositories/sync_queue_repository.dart';
import 'cloud_audit_sync_service.dart';
import 'cloud_authorization_request_sync_service.dart';
import 'cloud_client_score_sync_service.dart';
import 'cloud_client_sync_service.dart';
import 'cloud_credit_cycle_sync_service.dart';
import 'cloud_movement_sync_service.dart';
import 'cloud_product_sync_service.dart';
import 'cloud_receipt_sync_service.dart';
import 'cloud_whatsapp_campaign_sync_service.dart';

class GlobalSyncStepResult {
  final String label;
  final int sent;
  final int received;
  final int errors;
  final bool skipped;
  final String? userMessage;

  const GlobalSyncStepResult({
    required this.label,
    this.sent = 0,
    this.received = 0,
    this.errors = 0,
    this.skipped = false,
    this.userMessage,
  });

  bool get succeeded => !skipped && errors == 0 && userMessage == null;
}

class GlobalSyncResult {
  final List<GlobalSyncStepResult> steps;
  final int pendingAfter;
  final DateTime completedAt;

  const GlobalSyncResult({
    required this.steps,
    required this.pendingAfter,
    required this.completedAt,
  });

  int get totalSent => steps.fold(0, (sum, step) => sum + step.sent);
  int get totalReceived => steps.fold(0, (sum, step) => sum + step.received);
  int get totalErrors => steps.fold(0, (sum, step) => sum + step.errors);
  bool get hasErrors => totalErrors > 0 || steps.any((step) => !step.succeeded);
}

class AutoSyncService {
  static const _lastSyncAtKey = 'fiado_user_last_cloud_sync_at';
  static const _lastSyncSucceededKey = 'fiado_user_last_cloud_sync_succeeded';
  static const _debounce = Duration(seconds: 3);
  static const _timeout = Duration(seconds: 45);

  final SyncQueueRepository syncQueueRepository;
  final CloudClientSyncService clientSyncService;
  final CloudProductSyncService productSyncService;
  final CloudMovementSyncService movementSyncService;
  final CloudReceiptSyncService receiptSyncService;
  final CloudCreditCycleSyncService creditCycleSyncService;
  final CloudAuditSyncService auditSyncService;
  final CloudAuthorizationRequestSyncService authorizationRequestSyncService;
  final CloudClientScoreSyncService clientScoreSyncService;
  final CloudWhatsappCampaignSyncService whatsappCampaignSyncService;
  final Future<bool> Function() isCloudAuthenticated;
  final Future<bool> Function() canSyncBusiness;
  final Future<SharedPreferences> sharedPreferences;
  final Connectivity connectivity;

  bool _isSyncing = false;
  Timer? _debounceTimer;

  AutoSyncService({
    required this.syncQueueRepository,
    required this.clientSyncService,
    required this.productSyncService,
    required this.movementSyncService,
    required this.receiptSyncService,
    required this.creditCycleSyncService,
    required this.auditSyncService,
    required this.authorizationRequestSyncService,
    required this.clientScoreSyncService,
    required this.whatsappCampaignSyncService,
    required this.isCloudAuthenticated,
    Future<bool> Function()? canSyncBusiness,
    required this.sharedPreferences,
    Connectivity? connectivity,
  }) : canSyncBusiness = canSyncBusiness ?? (() async => true),
       connectivity = connectivity ?? Connectivity();

  bool get isSyncing => _isSyncing;

  Future<bool> isOnline() async {
    final result = await connectivity.checkConnectivity();
    return result.any((item) => item != ConnectivityResult.none);
  }

  Stream<bool> onlineChanges() {
    return connectivity.onConnectivityChanged.map(
      (items) => items.any((item) => item != ConnectivityResult.none),
    );
  }

  Future<SyncUserStatus> loadUserStatus({String? lastErrorMessage}) async {
    await syncQueueRepository.marcarLocalesNoSoportadosComoProcesados();
    final summary = await syncQueueRepository.obtenerResumen();
    final prefs = await sharedPreferences;
    final lastSyncRaw = prefs.getString(_lastSyncAtKey);
    final cloudAuthenticated = await isCloudAuthenticated();
    return SyncUserStatus(
      isOnline: await isOnline(),
      isCloudAuthenticated: cloudAuthenticated,
      isSyncing: _isSyncing,
      pendingCount: summary.pendingCount + summary.failedCount,
      lastSyncAt: lastSyncRaw == null ? null : DateTime.tryParse(lastSyncRaw),
      lastSyncSucceeded:
          cloudAuthenticated &&
          prefs.getBool(_lastSyncSucceededKey) == true &&
          summary.pendingCount + summary.failedCount == 0,
      lastErrorMessage: lastErrorMessage,
    );
  }

  Future<void> scheduleAutoSync({
    required Future<void> Function() onRun,
  }) async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(onRun()));
  }

  Future<GlobalSyncResult?> autoSyncIfNeeded({
    void Function(String step)? onProgress,
  }) async {
    if (!SyncFeatureFlags.enableLegacySync) return null;
    if (_isSyncing) return null;
    if (!await isOnline()) return null;
    if (!await isCloudAuthenticated()) return null;
    if (!await canSyncBusiness()) return null;
    await syncQueueRepository.marcarLocalesNoSoportadosComoProcesados();
    final summary = await syncQueueRepository.obtenerResumen();
    debugPrint(
      '[autosync] pending before=${summary.pendingCount} failed before=${summary.failedCount}',
    );
    // Even with an empty local queue, run push+pull. Another device may have
    // changed business data since this device's last successful sync.
    return syncNow(onProgress: onProgress);
  }

  Future<GlobalSyncResult> syncNow({
    void Function(String step)? onProgress,
  }) async {
    if (!SyncFeatureFlags.enableLegacySync) {
      throw StateError('La sincronizacion legacy esta aislada.');
    }
    if (_isSyncing) {
      throw StateError('Ya hay una sincronizacion en curso.');
    }

    if (!await isOnline()) {
      throw StateError(
        'Tu informacion esta guardada en este dispositivo y se sincronizara cuando tengas internet.',
      );
    }
    if (!await isCloudAuthenticated()) {
      throw StateError(
        'Guardado en este dispositivo. Se actualizara automaticamente cuando haya conexion.',
      );
    }
    if (!await canSyncBusiness()) {
      throw StateError('Agrega una tarjeta para activar tu prueba.');
    }
    await syncQueueRepository.marcarLocalesNoSoportadosComoProcesados();

    _isSyncing = true;
    final steps = <GlobalSyncStepResult>[];
    try {
      debugPrint('[autosync] processing entity=clientes');
      final clients = await _runStep(
        'Sincronizando clientes...',
        onProgress,
        () async {
          final result = await clientSyncService.syncClients().timeout(
            _timeout,
          );
          return GlobalSyncStepResult(
            label: 'Clientes',
            sent: result.sent,
            received: result.received,
            errors: result.errors,
          );
        },
      );
      steps.add(clients);

      debugPrint('[autosync] processing entity=productos');
      final products = await _runStep(
        'Sincronizando inventario...',
        onProgress,
        () async {
          final result = await productSyncService.syncProducts().timeout(
            _timeout,
          );
          return GlobalSyncStepResult(
            label: 'Inventario',
            sent: result.productsSent,
            received: result.productsReceived,
            errors: result.errors,
          );
        },
      );
      steps.add(products);

      if (products.succeeded) {
        debugPrint('[autosync] processing entity=producto_imagenes');
        steps.add(
          await _runStep('Sincronizando imagenes...', onProgress, () async {
            final result = await productSyncService.syncProductImages().timeout(
              _timeout,
            );
            return GlobalSyncStepResult(
              label: 'Imagenes',
              sent: result.imagesSent,
              received: result.imagesReceived,
              errors: result.errors,
            );
          }),
        );
      }

      if (clients.succeeded) {
        debugPrint('[autosync] processing entity=movimientos/deuda_items');
        final movements = await _runStep(
          'Sincronizando deudas...',
          onProgress,
          () async {
            final result = await movementSyncService
                .syncMovementsAndDebtItems()
                .timeout(_timeout);
            return GlobalSyncStepResult(
              label: 'Deudas y pagos',
              sent: result.sent,
              received: result.received,
              errors: result.errors,
            );
          },
        );
        steps.add(movements);

        if (movements.succeeded) {
          debugPrint('[autosync] processing entity=comprobantes');
          steps.add(
            await _runStep(
              'Sincronizando comprobantes...',
              onProgress,
              () async {
                final result = await receiptSyncService.syncReceipts().timeout(
                  _timeout,
                );
                return GlobalSyncStepResult(
                  label: 'Comprobantes',
                  sent: result.sent,
                  received: result.received,
                  errors: result.errors,
                );
              },
            ),
          );

          debugPrint('[autosync] processing entity=credito_ciclos');
          steps.add(
            await _runStep(
              'Sincronizando ciclos de credito...',
              onProgress,
              () async {
                final result = await creditCycleSyncService
                    .syncCreditCycles()
                    .timeout(_timeout);
                return GlobalSyncStepResult(
                  label: 'Ciclos de credito',
                  sent: result.sent,
                  received: result.received,
                  errors: result.errors,
                );
              },
            ),
          );

          debugPrint('[autosync] processing entity=client_scores');
          steps.add(
            await _runStep(
              'Sincronizando score inteligente...',
              onProgress,
              () async {
                final result = await clientScoreSyncService
                    .syncClientScores()
                    .timeout(_timeout);
                return GlobalSyncStepResult(
                  label: 'Score inteligente',
                  sent: result.sent,
                  received: result.received,
                  errors: result.errors,
                );
              },
            ),
          );
        }
      }

      if (products.succeeded) {
        debugPrint('[autosync] processing entity=auditorias');
        steps.add(
          await _runStep('Sincronizando auditorias...', onProgress, () async {
            final result = await auditSyncService.syncAuditsAndItems().timeout(
              _timeout,
            );
            return GlobalSyncStepResult(
              label: 'Auditorias',
              sent: result.auditsSent + result.itemsSent,
              received: result.auditsReceived + result.itemsReceived,
              errors: result.errors,
            );
          }),
        );
      }

      debugPrint('[autosync] processing entity=solicitudes_autorizacion');
      steps.add(
        await _runStep('Sincronizando solicitudes...', onProgress, () async {
          final result = await authorizationRequestSyncService
              .syncAuthorizationRequests()
              .timeout(_timeout);
          return GlobalSyncStepResult(
            label: 'Solicitudes',
            sent: result.sent,
            received: result.received,
            errors: result.errors,
          );
        }),
      );

      debugPrint('[autosync] processing entity=whatsapp_campaign_publications');
      steps.add(
        await _runStep(
          'Sincronizando campanas WhatsApp...',
          onProgress,
          () async {
            final result = await whatsappCampaignSyncService
                .syncWhatsappCampaigns()
                .timeout(_timeout);
            return GlobalSyncStepResult(
              label: 'Campanas WhatsApp',
              sent: result.sent,
              received: result.received,
              errors: result.errors,
            );
          },
        ),
      );

      final summary = await syncQueueRepository.obtenerResumen();
      final completedAt = DateTime.now();
      final pendingAfter = summary.pendingCount + summary.failedCount;
      final succeeded =
          steps.every((step) => step.succeeded) && pendingAfter == 0;
      debugPrint(
        '[autosync] pending after=${summary.pendingCount} failed after=${summary.failedCount}',
      );
      debugPrint(
        '[autosync] lastSyncSucceeded=$succeeded reason=${succeeded ? 'all steps succeeded and no pending items' : 'hasErrors=${steps.any((step) => !step.succeeded)} pendingAfter=$pendingAfter'}',
      );
      final prefs = await sharedPreferences;
      await prefs.setString(_lastSyncAtKey, completedAt.toIso8601String());
      await prefs.setBool(_lastSyncSucceededKey, succeeded);
      onProgress?.call('Listo');
      return GlobalSyncResult(
        steps: steps,
        pendingAfter: pendingAfter,
        completedAt: completedAt,
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<GlobalSyncStepResult> _runStep(
    String progress,
    void Function(String step)? onProgress,
    Future<GlobalSyncStepResult> Function() action,
  ) async {
    onProgress?.call(progress);
    try {
      return await action();
    } catch (_) {
      return GlobalSyncStepResult(
        label: progress.replaceAll('Sincronizando ', '').replaceAll('...', ''),
        errors: 1,
        userMessage:
            'No pudimos sincronizar esta parte ahora. Se intentara nuevamente cuando tengas internet.',
      );
    }
  }
}
