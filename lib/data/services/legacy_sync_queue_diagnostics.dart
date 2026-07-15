import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/database/local_database.dart';
import '../repositories/sync_diagnostics_repository.dart';

class LegacySyncQueueDiagnostics {
  final SyncDiagnosticsRepository diagnosticsRepository;

  LegacySyncQueueDiagnostics({LocalDatabase? databaseHelper})
    : diagnosticsRepository = SyncDiagnosticsRepository(
        databaseHelper: databaseHelper,
      );

  Future<void> debugPrintSummary() async {
    if (!kDebugMode) return;
    final summary = await diagnosticsRepository.readLegacyQueue();

    debugPrint(
      '[sync-legacy-queue-summary] ${jsonEncode({'total': summary.total, 'pending': summary.pending, 'failed': summary.failed, 'completed': summary.completed, 'entities': summary.grouped, 'maxAttempts': summary.maxAttempts, 'lastError': summary.lastError})}',
    );

    for (final item in summary.activeItems) {
      debugPrint(
        '[sync-legacy-queue-item] ${jsonEncode({'id': item.id, 'entityType': item.module, 'operation': item.operation, 'status': item.status, 'attempts': item.attempts, 'lastError': item.lastError, 'createdAt': item.createdAt, 'updatedAt': item.updatedAt, 'payloadKeys': item.payloadKeys})}',
      );
    }
  }
}
