import '../../core/database/sync_operation.dart';

abstract class ApiSyncService {
  Future<void> push(SyncOperation operation);
  Future<void> pullChanges({DateTime? since});
}

class PendingAspNetCoreSyncService implements ApiSyncService {
  const PendingAspNetCoreSyncService();

  @override
  Future<void> push(SyncOperation operation) {
    throw UnimplementedError(
      'Configurar endpoint ASP.NET Core antes de habilitar sincronizacion.',
    );
  }

  @override
  Future<void> pullChanges({DateTime? since}) {
    throw UnimplementedError(
      'Configurar endpoint ASP.NET Core antes de habilitar sincronizacion.',
    );
  }
}
