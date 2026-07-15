import 'package:fiado_app/data/models/sync_user_status.dart';
import 'package:fiado_app/data/services/auto_sync_service.dart';
import 'package:fiado_app/presentation/providers/sync_providers.dart';
import 'package:fiado_app/screens/sync_status_screen.dart';
import 'package:fiado_app/widgets/sync_cloud_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncUserStatusNotifier extends SyncUserStatusNotifier {
  final SyncUserStatus initialStatus;
  int refreshCount = 0;
  int autoSyncCount = 0;

  _FakeSyncUserStatusNotifier(super.ref, {required this.initialStatus}) {
    state = AsyncData(initialStatus);
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }

  @override
  Future<void> scheduleAutoSync() async {
    autoSyncCount++;
  }

  @override
  Future<GlobalSyncResult?> runManualSync() async {
    throw StateError('Manual sync should not be visible to final users.');
  }
}

void main() {
  const localSavedStatus = SyncUserStatus(
    isOnline: true,
    isCloudAuthenticated: false,
    isSyncing: false,
    pendingCount: 0,
  );
  const updatedStatus = SyncUserStatus(
    isOnline: true,
    isCloudAuthenticated: true,
    isSyncing: false,
    pendingCount: 0,
    lastSyncSucceeded: true,
  );
  const syncingStatus = SyncUserStatus(
    isOnline: true,
    isCloudAuthenticated: true,
    isSyncing: true,
    pendingCount: 0,
    lastSyncSucceeded: true,
  );
  const pendingStatus = SyncUserStatus(
    isOnline: true,
    isCloudAuthenticated: true,
    isSyncing: false,
    pendingCount: 2,
    lastSyncSucceeded: true,
  );
  const cloudWithoutSuccessfulPullStatus = SyncUserStatus(
    isOnline: true,
    isCloudAuthenticated: true,
    isSyncing: false,
    pendingCount: 0,
    lastSyncSucceeded: false,
  );
  const failedStatus = SyncUserStatus(
    isOnline: true,
    isCloudAuthenticated: true,
    isSyncing: false,
    pendingCount: 1,
    lastErrorMessage: 'fallo activo',
  );

  test('SyncUserStatus shortMessage uses honest save/sync wording', () {
    expect(localSavedStatus.shortMessage, 'Guardado en este dispositivo');
    expect(updatedStatus.shortMessage, 'Todo actualizado');
    expect(syncingStatus.shortMessage, 'Actualizando...');
    expect(pendingStatus.shortMessage, 'Guardado en este dispositivo');
    expect(
      cloudWithoutSuccessfulPullStatus.shortMessage,
      'Guardado en este dispositivo',
    );
  });

  test('backend accesible sin token no implica Todo actualizado', () {
    const status = SyncUserStatus(
      isOnline: true,
      isCloudAuthenticated: false,
      isSyncing: false,
      pendingCount: 0,
      lastSyncSucceeded: true,
    );

    expect(status.shortMessage, 'Guardado en este dispositivo');
    expect(status.shortMessage, isNot('Todo actualizado'));
  });

  test('si token no se guarda no puede mostrar Todo actualizado', () {
    const status = SyncUserStatus(
      isOnline: true,
      isCloudAuthenticated: false,
      isSyncing: false,
      pendingCount: 0,
      lastSyncSucceeded: false,
    );

    expect(status.shortMessage, 'Guardado en este dispositivo');
    expect(status.shortMessage, isNot('Todo actualizado'));
  });

  test('fallo real de auth se muestra como error', () {
    const status = SyncUserStatus(
      isOnline: true,
      isCloudAuthenticated: false,
      isSyncing: false,
      pendingCount: 0,
      lastErrorMessage: 'No se pudo actualizar',
    );

    expect(status.shortMessage, 'No se pudo actualizar');
  });

  test('legacy pendiente apagado impide Todo actualizado', () {
    final status = applyLegacyQueueVisibility(
      updatedStatus,
      legacyPendingCount: 1,
      legacyFailedCount: 0,
    );

    expect(status.pendingCount, 1);
    expect(status.shortMessage, 'Guardado en este dispositivo');
  });

  test('legacy fallido activo muestra No se pudo actualizar', () {
    final status = applyLegacyQueueVisibility(
      updatedStatus,
      legacyPendingCount: 0,
      legacyFailedCount: 1,
    );

    expect(status.pendingCount, 1);
    expect(status.shortMessage, 'No se pudo actualizar');
  });

  test('colas vacias con auth y sync exitoso permiten Todo actualizado', () {
    final status = applyLegacyQueueVisibility(
      updatedStatus,
      legacyPendingCount: 0,
      legacyFailedCount: 0,
    );

    expect(status.shortMessage, 'Todo actualizado');
  });

  testWidgets('SyncStatusScreen hides manual cloud controls for final users', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncUserStatusProvider.overrideWith(
            (ref) =>
                _FakeSyncUserStatusNotifier(ref, initialStatus: pendingStatus),
          ),
        ],
        child: const MaterialApp(home: SyncStatusScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estado de datos'), findsOneWidget);
    expect(find.text('Sincronizar con la nube'), findsNothing);
    expect(find.text('Conectar cuenta a la nube'), findsNothing);
    expect(find.text('No conectado a la nube'), findsNothing);
    expect(find.text('Nube'), findsNothing);
    expect(find.text('Actualizar datos'), findsNothing);
    expect(
      find.text(
        'Fiado App guarda tus datos primero en este dispositivo y los actualiza automaticamente cuando haya conexion.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('SyncCloudIndicator shows saved data wording and auto syncs', (
    tester,
  ) async {
    late _FakeSyncUserStatusNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncUserStatusProvider.overrideWith((ref) {
            notifier = _FakeSyncUserStatusNotifier(
              ref,
              initialStatus: pendingStatus,
            );
            return notifier;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncCloudIndicator())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardado en este dispositivo'), findsOneWidget);
    expect(find.text('No conectado a la nube'), findsNothing);
    expect(notifier.autoSyncCount, greaterThan(0));
  });

  testWidgets('SyncCloudIndicator shows updated only after successful sync', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncUserStatusProvider.overrideWith(
            (ref) =>
                _FakeSyncUserStatusNotifier(ref, initialStatus: updatedStatus),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncCloudIndicator())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todo actualizado'), findsOneWidget);
    expect(find.text('Guardado en este dispositivo'), findsNothing);
  });

  testWidgets('SyncCloudIndicator does not imply cloud when only local saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncUserStatusProvider.overrideWith(
            (ref) => _FakeSyncUserStatusNotifier(
              ref,
              initialStatus: localSavedStatus,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncCloudIndicator())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardado en este dispositivo'), findsOneWidget);
    final label = tester.widget<Text>(
      find.text('Guardado en este dispositivo').first,
    );
    expect(label.style?.color, isNot(Colors.green));
    expect(find.text('Todo actualizado'), findsNothing);
    expect(find.text('No conectado a la nube'), findsNothing);
  });

  testWidgets('SyncCloudIndicator shows updating while syncing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncUserStatusProvider.overrideWith(
            (ref) =>
                _FakeSyncUserStatusNotifier(ref, initialStatus: syncingStatus),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncCloudIndicator())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Actualizando...'), findsOneWidget);
  });

  testWidgets('SyncCloudIndicator shows failure for a real active error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncUserStatusProvider.overrideWith(
            (ref) =>
                _FakeSyncUserStatusNotifier(ref, initialStatus: failedStatus),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SyncCloudIndicator())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo actualizar'), findsOneWidget);
    expect(find.text('Todo actualizado'), findsNothing);
  });
}
