class SyncUserStatus {
  final bool isOnline;
  final bool isCloudAuthenticated;
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncAt;
  final bool lastSyncSucceeded;
  final String? lastErrorMessage;

  const SyncUserStatus({
    required this.isOnline,
    required this.isCloudAuthenticated,
    required this.isSyncing,
    required this.pendingCount,
    this.lastSyncAt,
    this.lastSyncSucceeded = false,
    this.lastErrorMessage,
  });

  String get userFriendlyStatus {
    if (lastErrorMessage != null && lastErrorMessage!.trim().isNotEmpty) {
      if (_isLocalSavedMessage) return 'Guardado en este dispositivo';
      if (_isSessionReplaced) return 'Tu cuenta se inicio en otro dispositivo';
      return 'No se pudo actualizar';
    }
    if (isSyncing) return 'Actualizando...';
    if (pendingCount > 0) return 'Guardado en este dispositivo';
    if (isCloudAuthenticated && lastSyncSucceeded) return 'Todo actualizado';
    return 'Guardado en este dispositivo';
  }

  String get shortMessage {
    if (lastErrorMessage != null && lastErrorMessage!.trim().isNotEmpty) {
      if (_isLocalSavedMessage) return 'Guardado en este dispositivo';
      if (_isSessionReplaced) return 'Tu cuenta se inicio en otro dispositivo';
      return 'No se pudo actualizar';
    }
    if (isSyncing) return 'Actualizando...';
    if (pendingCount > 0) return 'Guardado en este dispositivo';
    if (isCloudAuthenticated && lastSyncSucceeded) return 'Todo actualizado';
    return 'Guardado en este dispositivo';
  }

  String get friendlySubtitle {
    if (lastErrorMessage != null && lastErrorMessage!.trim().isNotEmpty) {
      if (_isLocalSavedMessage) return 'Tus datos estan seguros.';
      return lastErrorMessage!;
    }
    if (isSyncing) return 'Actualizando tus datos.';
    if (pendingCount > 0) {
      return 'Se actualizaran automaticamente cuando haya conexion.';
    }
    if (isCloudAuthenticated && lastSyncSucceeded) {
      return 'Tus datos estan al dia.';
    }
    return 'Tus datos estan seguros.';
  }

  bool get _isSessionReplaced =>
      lastErrorMessage?.toLowerCase().contains('otro dispositivo') == true;

  bool get _isLocalSavedMessage =>
      lastErrorMessage?.toLowerCase().contains(
        'guardado en este dispositivo',
      ) ==
      true;

  SyncUserStatus copyWith({
    bool? isOnline,
    bool? isCloudAuthenticated,
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncAt,
    bool? lastSyncSucceeded,
    String? lastErrorMessage,
    bool clearError = false,
  }) {
    return SyncUserStatus(
      isOnline: isOnline ?? this.isOnline,
      isCloudAuthenticated: isCloudAuthenticated ?? this.isCloudAuthenticated,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncSucceeded: lastSyncSucceeded ?? this.lastSyncSucceeded,
      lastErrorMessage: clearError
          ? null
          : lastErrorMessage ?? this.lastErrorMessage,
    );
  }
}

SyncUserStatus applyLegacyQueueVisibility(
  SyncUserStatus status, {
  required int legacyPendingCount,
  required int legacyFailedCount,
}) {
  final legacyPending = legacyPendingCount < 0 ? 0 : legacyPendingCount;
  final legacyFailed = legacyFailedCount < 0 ? 0 : legacyFailedCount;
  if (legacyPending == 0 && legacyFailed == 0) return status;

  return status.copyWith(
    pendingCount: status.pendingCount + legacyPending + legacyFailed,
    lastErrorMessage: status.lastErrorMessage == null && legacyFailed > 0
        ? 'Hay cambios guardados que no se pudieron actualizar.'
        : status.lastErrorMessage,
  );
}
