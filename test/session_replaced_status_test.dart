import 'package:fiado_app/data/models/sync_user_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sync status con sesion reemplazada no muestra Todo actualizado', () {
    const status = SyncUserStatus(
      isOnline: true,
      isCloudAuthenticated: true,
      isSyncing: false,
      pendingCount: 0,
      lastSyncSucceeded: true,
      lastErrorMessage:
          'Tu cuenta se inicio en otro dispositivo. Para continuar aqui, inicia sesion nuevamente.',
    );

    expect(
      status.userFriendlyStatus,
      'Tu cuenta se inicio en otro dispositivo',
    );
    expect(status.shortMessage, contains('otro dispositivo'));
    expect(status.shortMessage, isNot('Todo actualizado'));
  });
}
