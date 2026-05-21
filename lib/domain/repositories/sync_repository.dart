import '../../core/database/sync_operation.dart';

abstract class SyncRepository {
  Future<void> enqueue(SyncOperation operation);
  Future<List<SyncOperation>> pending({int limit = 100});
  Future<void> markSynced(String operationId);
}
