enum NewSyncUiState { updating, savedOnThisDevice, allSaved, allUpdated, error }

class NewSyncStatus {
  final NewSyncUiState state;
  final int pendingCount;
  final DateTime? lastSuccessAt;
  final String? lastError;

  const NewSyncStatus({
    required this.state,
    required this.pendingCount,
    this.lastSuccessAt,
    this.lastError,
  });

  bool get isUpdating => state == NewSyncUiState.updating;

  bool get canShowAllUpdated => state == NewSyncUiState.allUpdated;
}
