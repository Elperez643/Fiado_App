import '../../core/database/sync_operation.dart';

abstract class SyncQueueService {
  Future<void> enqueue(SyncOperation operation);
  Future<List<SyncOperation>> pending({int limit = 100});
  Future<void> markSynced(String operationId);
}

class NoopSyncQueueService implements SyncQueueService {
  const NoopSyncQueueService();

  @override
  Future<void> enqueue(SyncOperation operation) async {}

  @override
  Future<List<SyncOperation>> pending({int limit = 100}) async {
    return const [];
  }

  @override
  Future<void> markSynced(String operationId) async {}
}
