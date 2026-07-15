class SyncStatus {
  static const String pending = 'pending';
  static const String synced = 'synced';
  static const String retry = 'retry';
  static const String updated = 'updated';
  static const String deleted = 'deleted';
  static const String failed = 'failed';

  static const List<String> values = [
    pending,
    synced,
    retry,
    updated,
    deleted,
    failed,
  ];

  static bool isValid(String status) => values.contains(status);
}

class SyncOperationType {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';

  static const List<String> values = [create, update, delete];

  static bool isValid(String operation) => values.contains(operation);
}
