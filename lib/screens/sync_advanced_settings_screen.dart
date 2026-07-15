import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/cloud_audit_sync_service.dart';
import '../data/services/cloud_authorization_request_sync_service.dart';
import '../data/services/cloud_client_sync_service.dart';
import '../data/services/cloud_financial_sync_helpers.dart';
import '../data/services/cloud_product_sync_service.dart';
import '../presentation/providers/sync_providers.dart';
import 'backend_settings_screen.dart';

class SyncAdvancedSettingsScreen extends ConsumerWidget {
  const SyncAdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion avanzada de nube')),
      body: statusAsync.when(
        data: (summary) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _MetricTile(
                icon: Icons.cloud_upload_outlined,
                label: 'Pendientes por sincronizar',
                value: '${summary.pendingCount}',
              ),
              const SizedBox(height: 12),
              _MetricTile(
                icon: Icons.error_outline,
                label: 'Fallidos',
                value: '${summary.failedCount}',
              ),
              const SizedBox(height: 12),
              _MetricTile(
                icon: Icons.schedule_outlined,
                label: 'Ultimo intento',
                value: _formatDate(summary.lastAttemptAt),
              ),
              const SizedBox(height: 12),
              _MetricTile(
                icon: Icons.done_all_outlined,
                label: 'Sincronizados en cola',
                value: '${summary.processedCount}',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _simulateSync(context, ref),
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Simular sincronizacion'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _syncEverythingWithBackend(context, ref),
                icon: const Icon(Icons.cloud_done_outlined),
                label: const Text('Sincronizar todo con backend'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncClientsWithBackend(context, ref),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('Sincronizar clientes con backend'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncProductsWithBackend(context, ref),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Sincronizar productos e imagenes'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncMovementsWithBackend(context, ref),
                icon: const Icon(Icons.swap_horiz_outlined),
                label: const Text('Sincronizar movimientos/deudas'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncReceiptsWithBackend(context, ref),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Sincronizar comprobantes'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncCreditCyclesWithBackend(context, ref),
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('Sincronizar ciclos de credito'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncClientScoresWithBackend(context, ref),
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Sincronizar score inteligente'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _syncAllFinancialWithBackend(context, ref),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Sincronizar todo lo financiero'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _syncAuditsWithBackend(context, ref),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Sincronizar auditorias'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _syncAuthorizationRequestsWithBackend(context, ref),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Sincronizar solicitudes'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _syncAllOperationalWithBackend(context, ref),
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Sincronizar todo operativo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _showBackendConfig(context, ref),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Configuracion avanzada de nube'),
              ),
              const SizedBox(height: 12),
              if (ref.watch(clientCloudSyncStatusProvider) != null)
                _ClientCloudSyncTile(
                  result: ref.watch(clientCloudSyncStatusProvider)!,
                ),
              if (ref.watch(clientCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(productCloudSyncStatusProvider) != null)
                _ProductCloudSyncTile(
                  result: ref.watch(productCloudSyncStatusProvider)!,
                ),
              if (ref.watch(productCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(movementCloudSyncStatusProvider) != null)
                _FinancialCloudSyncTile(
                  title: 'Movimientos/deudas backend',
                  icon: Icons.swap_horiz_outlined,
                  result: ref.watch(movementCloudSyncStatusProvider)!,
                ),
              if (ref.watch(movementCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(receiptCloudSyncStatusProvider) != null)
                _FinancialCloudSyncTile(
                  title: 'Comprobantes backend',
                  icon: Icons.receipt_long_outlined,
                  result: ref.watch(receiptCloudSyncStatusProvider)!,
                ),
              if (ref.watch(receiptCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(creditCycleCloudSyncStatusProvider) != null)
                _FinancialCloudSyncTile(
                  title: 'Ciclos de credito backend',
                  icon: Icons.event_repeat_outlined,
                  result: ref.watch(creditCycleCloudSyncStatusProvider)!,
                ),
              if (ref.watch(creditCycleCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(clientScoreCloudSyncStatusProvider) != null)
                _FinancialCloudSyncTile(
                  title: 'Score inteligente backend',
                  icon: Icons.insights_outlined,
                  result: ref.watch(clientScoreCloudSyncStatusProvider)!,
                ),
              if (ref.watch(clientScoreCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(auditCloudSyncStatusProvider) != null)
                _AuditCloudSyncTile(
                  result: ref.watch(auditCloudSyncStatusProvider)!,
                ),
              if (ref.watch(auditCloudSyncStatusProvider) != null)
                const SizedBox(height: 12),
              if (ref.watch(authorizationRequestCloudSyncStatusProvider) !=
                  null)
                _AuthorizationRequestCloudSyncTile(
                  result: ref.watch(
                    authorizationRequestCloudSyncStatusProvider,
                  )!,
                ),
              if (ref.watch(authorizationRequestCloudSyncStatusProvider) !=
                  null)
                const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _clearProcessed(context, ref),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Limpiar sincronizados'),
              ),
            ],
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar el estado: $error'),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _showBackendConfig(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BackendSettingsScreen()),
    );
  }

  Future<void> _syncClientsWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudClientSyncServiceProvider)
          .syncClients();
      ref.read(clientCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Clientes sincronizados: ${result.sent} enviados, ${result.received} recibidos, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar clientes: $error')),
      );
    }
  }

  Future<void> _syncProductsWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudProductSyncServiceProvider)
          .syncProductsAndImages();
      ref.read(productCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Productos sincronizados: ${result.productsSent} enviados, ${result.productsReceived} recibidos, ${result.imagesSent} imagenes enviadas, ${result.imagesReceived} imagenes recibidas, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo sincronizar productos e imagenes: $error'),
        ),
      );
    }
  }

  Future<void> _syncMovementsWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudMovementSyncServiceProvider)
          .syncMovementsAndDebtItems();
      ref.read(movementCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Movimientos/deudas: ${result.sent} enviados, ${result.received} recibidos, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar movimientos: $error')),
      );
    }
  }

  Future<void> _syncReceiptsWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudReceiptSyncServiceProvider)
          .syncReceipts();
      ref.read(receiptCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Comprobantes: ${result.sent} enviados, ${result.received} recibidos, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar comprobantes: $error')),
      );
    }
  }

  Future<void> _syncCreditCyclesWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudCreditCycleSyncServiceProvider)
          .syncCreditCycles();
      ref.read(creditCycleCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ciclos: ${result.sent} enviados, ${result.received} recibidos, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar ciclos: $error')),
      );
    }
  }

  Future<void> _syncClientScoresWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudClientScoreSyncServiceProvider)
          .syncClientScores();
      ref.read(clientScoreCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Score inteligente: ${result.sent} enviados, ${result.received} recibidos, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo sincronizar score inteligente: $error'),
        ),
      );
    }
  }

  Future<void> _syncAllFinancialWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _syncMovementsWithBackend(context, ref);
    if (!context.mounted) return;
    await _syncReceiptsWithBackend(context, ref);
    if (!context.mounted) return;
    await _syncCreditCyclesWithBackend(context, ref);
  }

  Future<void> _syncAuditsWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudAuditSyncServiceProvider)
          .syncAuditsAndItems();
      ref.read(auditCloudSyncStatusProvider.notifier).state = result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Auditorias: ${result.auditsSent} enviadas, ${result.auditsReceived} recibidas, ${result.itemsSent} items enviados, ${result.itemsReceived} items recibidos, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar auditorias: $error')),
      );
    }
  }

  Future<void> _syncAuthorizationRequestsWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(cloudAuthorizationRequestSyncServiceProvider)
          .syncAuthorizationRequests();
      ref.read(authorizationRequestCloudSyncStatusProvider.notifier).state =
          result;
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Solicitudes: ${result.sent} enviadas, ${result.received} recibidas, ${result.errors} errores.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo sincronizar solicitudes: $error')),
      );
    }
  }

  Future<void> _syncAllOperationalWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _syncAuditsWithBackend(context, ref);
    if (!context.mounted) return;
    await _syncAuthorizationRequestsWithBackend(context, ref);
  }

  Future<void> _syncEverythingWithBackend(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final stepResults = <_FullSyncStepResult>[];

    final clients = await _runFullSyncStep('Clientes', () async {
      final result = await ref
          .read(cloudClientSyncServiceProvider)
          .syncClients();
      ref.read(clientCloudSyncStatusProvider.notifier).state = result;
      return _FullSyncStepResult(
        label: 'Clientes',
        sent: result.sent,
        received: result.received,
        errors: result.errors,
      );
    });
    stepResults.add(clients);

    final products = await _runFullSyncStep('Productos', () async {
      final result = await ref
          .read(cloudProductSyncServiceProvider)
          .syncProducts();
      ref.read(productCloudSyncStatusProvider.notifier).state = result;
      return _FullSyncStepResult(
        label: 'Productos',
        sent: result.productsSent,
        received: result.productsReceived,
        errors: result.errors,
      );
    });
    stepResults.add(products);

    if (products.succeeded) {
      final images = await _runFullSyncStep('Imagenes', () async {
        final result = await ref
            .read(cloudProductSyncServiceProvider)
            .syncProductImages();
        final previous = ref.read(productCloudSyncStatusProvider);
        ref.read(productCloudSyncStatusProvider.notifier).state =
            previous == null ? result : previous.combine(result);
        return _FullSyncStepResult(
          label: 'Imagenes',
          sent: result.imagesSent,
          received: result.imagesReceived,
          errors: result.errors,
        );
      });
      stepResults.add(images);
    } else {
      stepResults.add(
        const _FullSyncStepResult(
          label: 'Imagenes',
          skipped: true,
          errorMessage: 'omitido por error en productos',
        ),
      );
    }

    if (clients.succeeded) {
      final movements = await _runFullSyncStep(
        'Movimientos/deuda_items',
        () async {
          final result = await ref
              .read(cloudMovementSyncServiceProvider)
              .syncMovementsAndDebtItems();
          ref.read(movementCloudSyncStatusProvider.notifier).state = result;
          return _FullSyncStepResult(
            label: 'Movimientos/deuda_items',
            sent: result.sent,
            received: result.received,
            errors: result.errors,
          );
        },
      );
      stepResults.add(movements);

      if (movements.succeeded) {
        final receipts = await _runFullSyncStep('Comprobantes', () async {
          final result = await ref
              .read(cloudReceiptSyncServiceProvider)
              .syncReceipts();
          ref.read(receiptCloudSyncStatusProvider.notifier).state = result;
          return _FullSyncStepResult(
            label: 'Comprobantes',
            sent: result.sent,
            received: result.received,
            errors: result.errors,
          );
        });
        stepResults.add(receipts);

        final cycles = await _runFullSyncStep('Ciclos de credito', () async {
          final result = await ref
              .read(cloudCreditCycleSyncServiceProvider)
              .syncCreditCycles();
          ref.read(creditCycleCloudSyncStatusProvider.notifier).state = result;
          return _FullSyncStepResult(
            label: 'Ciclos de credito',
            sent: result.sent,
            received: result.received,
            errors: result.errors,
          );
        });
        stepResults.add(cycles);

        if (cycles.succeeded) {
          final scores = await _runFullSyncStep('Score inteligente', () async {
            final result = await ref
                .read(cloudClientScoreSyncServiceProvider)
                .syncClientScores();
            ref.read(clientScoreCloudSyncStatusProvider.notifier).state =
                result;
            return _FullSyncStepResult(
              label: 'Score inteligente',
              sent: result.sent,
              received: result.received,
              errors: result.errors,
            );
          });
          stepResults.add(scores);
        } else {
          stepResults.add(
            const _FullSyncStepResult(
              label: 'Score inteligente',
              skipped: true,
              errorMessage: 'omitido por error en ciclos de credito',
            ),
          );
        }
      } else {
        stepResults.addAll(const [
          _FullSyncStepResult(
            label: 'Comprobantes',
            skipped: true,
            errorMessage: 'omitido por error en movimientos',
          ),
          _FullSyncStepResult(
            label: 'Ciclos de credito',
            skipped: true,
            errorMessage: 'omitido por error en movimientos',
          ),
          _FullSyncStepResult(
            label: 'Score inteligente',
            skipped: true,
            errorMessage: 'omitido por error en movimientos',
          ),
        ]);
      }
    } else {
      stepResults.addAll(const [
        _FullSyncStepResult(
          label: 'Movimientos/deuda_items',
          skipped: true,
          errorMessage: 'omitido por error en clientes',
        ),
        _FullSyncStepResult(
          label: 'Comprobantes',
          skipped: true,
          errorMessage: 'omitido por error en clientes',
        ),
        _FullSyncStepResult(
          label: 'Ciclos de credito',
          skipped: true,
          errorMessage: 'omitido por error en clientes',
        ),
        _FullSyncStepResult(
          label: 'Score inteligente',
          skipped: true,
          errorMessage: 'omitido por error en clientes',
        ),
      ]);
    }

    if (products.succeeded) {
      final audits = await _runFullSyncStep('Auditorias/audit_items', () async {
        final result = await ref
            .read(cloudAuditSyncServiceProvider)
            .syncAuditsAndItems();
        ref.read(auditCloudSyncStatusProvider.notifier).state = result;
        return _FullSyncStepResult(
          label: 'Auditorias/audit_items',
          sent: result.auditsSent + result.itemsSent,
          received: result.auditsReceived + result.itemsReceived,
          errors: result.errors,
        );
      });
      stepResults.add(audits);
    } else {
      stepResults.add(
        const _FullSyncStepResult(
          label: 'Auditorias/audit_items',
          skipped: true,
          errorMessage: 'omitido por error en productos',
        ),
      );
    }

    final requests = await _runFullSyncStep('Solicitudes', () async {
      final result = await ref
          .read(cloudAuthorizationRequestSyncServiceProvider)
          .syncAuthorizationRequests();
      ref.read(authorizationRequestCloudSyncStatusProvider.notifier).state =
          result;
      return _FullSyncStepResult(
        label: 'Solicitudes',
        sent: result.sent,
        received: result.received,
        errors: result.errors,
      );
    });
    stepResults.add(requests);

    ref.invalidate(syncStatusProvider);
    final errors = stepResults.fold<int>(
      0,
      (total, item) => total + item.errors,
    );
    final skipped = stepResults.where((item) => item.skipped).length;
    final sent = stepResults.fold<int>(0, (total, item) => total + item.sent);
    final received = stepResults.fold<int>(
      0,
      (total, item) => total + item.received,
    );
    final failedLabels = stepResults
        .where((item) => !item.succeeded)
        .map((item) => '${item.label}: ${item.errorMessage ?? item.errors}')
        .join(' | ');

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Sync completo: $sent enviados, $received recibidos, $errors errores, $skipped omitidos.${failedLabels.isEmpty ? '' : ' $failedLabels'}',
        ),
      ),
    );
  }

  Future<_FullSyncStepResult> _runFullSyncStep(
    String label,
    Future<_FullSyncStepResult> Function() action,
  ) async {
    try {
      return await action();
    } catch (error) {
      return _FullSyncStepResult(
        label: label,
        errors: 1,
        errorMessage: '$error',
      );
    }
  }

  Future<void> _simulateSync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(syncServiceProvider).syncPendingData();
      ref.invalidate(syncStatusProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Simulacion completada: ${result.processed} procesados, ${result.failed} fallidos.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo simular: $error')),
      );
    }
  }

  Future<void> _clearProcessed(BuildContext context, WidgetRef ref) async {
    final deleted = await ref
        .read(syncQueueRepositoryProvider)
        .limpiarProcesados();
    ref.invalidate(syncStatusProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se limpiaron $deleted registros sincronizados.')),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin intentos';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _ClientCloudSyncTile extends StatelessWidget {
  final ClientCloudSyncResult result;

  const _ClientCloudSyncTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.cloud_done_outlined),
        title: const Text('Clientes backend'),
        subtitle: Text(
          'Enviados: ${result.sent} | Recibidos: ${result.received} | Errores: ${result.errors}',
        ),
      ),
    );
  }
}

class _ProductCloudSyncTile extends StatelessWidget {
  final ProductCloudSyncResult result;

  const _ProductCloudSyncTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Productos e imagenes backend'),
        subtitle: Text(
          'Productos enviados: ${result.productsSent} | Productos recibidos: ${result.productsReceived} | Imagenes enviadas: ${result.imagesSent} | Imagenes recibidas: ${result.imagesReceived} | Errores: ${result.errors}',
        ),
      ),
    );
  }
}

class _FinancialCloudSyncTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final FinancialCloudSyncResult result;

  const _FinancialCloudSyncTile({
    required this.title,
    required this.icon,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          'Enviados: ${result.sent} | Recibidos: ${result.received} | Errores: ${result.errors}',
        ),
      ),
    );
  }
}

class _AuditCloudSyncTile extends StatelessWidget {
  final AuditCloudSyncResult result;

  const _AuditCloudSyncTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Auditorias backend'),
        subtitle: Text(
          'Auditorias enviadas: ${result.auditsSent} | Auditorias recibidas: ${result.auditsReceived} | Items enviados: ${result.itemsSent} | Items recibidos: ${result.itemsReceived} | Errores: ${result.errors}',
        ),
      ),
    );
  }
}

class _AuthorizationRequestCloudSyncTile extends StatelessWidget {
  final AuthorizationRequestCloudSyncResult result;

  const _AuthorizationRequestCloudSyncTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Solicitudes backend'),
        subtitle: Text(
          'Enviadas: ${result.sent} | Recibidas: ${result.received} | Errores: ${result.errors}',
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _FullSyncStepResult {
  final String label;
  final int sent;
  final int received;
  final int errors;
  final bool skipped;
  final String? errorMessage;

  const _FullSyncStepResult({
    required this.label,
    this.sent = 0,
    this.received = 0,
    this.errors = 0,
    this.skipped = false,
    this.errorMessage,
  });

  bool get succeeded => !skipped && errors == 0 && errorMessage == null;
}
