import '../models/sync_outbox_item.dart';

abstract class SyncModuleAdapter {
  String get module;

  Future<void> onPushAccepted({
    required List<SyncOutboxItem> items,
    required DateTime serverTime,
  }) async {}

  Future<int> applyPullChanges(List<Map<String, Object?>> changes);
}
