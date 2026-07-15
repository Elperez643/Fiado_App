import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/api/api_environment.dart';
import '../../core/api/api_config.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_schema.dart';
import '../../core/database/local_database.dart';
import '../../core/diagnostics/backend_connection_diagnostics.dart';
import '../../core/security/secure_token_storage.dart';
import '../../core/sync/sync_feature_flags.dart';
import '../../core/sync/sync_status.dart';
import '../models/sync_outbox_item.dart';
import '../models/sync_user_status.dart';
import 'sync_status_diagnostics_repository.dart';

class SyncDiagnosticRecord {
  final int? id;
  final String source;
  final String module;
  final String operation;
  final String status;
  final int attempts;
  final String? lastError;
  final String? createdAt;
  final String? updatedAt;
  final List<String> payloadKeys;

  const SyncDiagnosticRecord({
    required this.id,
    required this.source,
    required this.module,
    required this.operation,
    required this.status,
    required this.attempts,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
    required this.payloadKeys,
  });

  String toPlainText() =>
      'id=${id ?? '-'} module=$module operation=$operation status=$status '
      'attempts=$attempts error=${lastError ?? '-'} created=${createdAt ?? '-'} '
      'updated=${updatedAt ?? '-'} payloadKeys=${payloadKeys.join(',')}';
}

class SyncStoreDiagnosticSummary {
  final int total;
  final int pending;
  final int failed;
  final int completed;
  final int maxAttempts;
  final String? lastError;
  final Map<String, int> grouped;
  final List<SyncDiagnosticRecord> activeItems;

  const SyncStoreDiagnosticSummary({
    required this.total,
    required this.pending,
    required this.failed,
    required this.completed,
    required this.maxAttempts,
    required this.lastError,
    required this.grouped,
    required this.activeItems,
  });
}

class SyncDiagnosticsReport {
  final String effectiveBaseUrl;
  final int timeoutSeconds;
  final String? healthUrl;
  final String? healthStatus;
  final String? healthResult;
  final String? healthError;
  final String? healthAttemptAt;
  final bool isOnline;
  final bool isCloudAuthenticated;
  final bool cloudUserIdPresent;
  final bool businessIdPresent;
  final String? role;
  final bool deviceIdPresent;
  final bool sessionVersionPresent;
  final bool tokenPresent;
  final SyncUserStatus bannerStatus;
  final String? errorSource;
  final SyncStoreDiagnosticSummary outbox;
  final SyncStoreDiagnosticSummary legacyQueue;
  final bool legacyEnabled;

  const SyncDiagnosticsReport({
    required this.effectiveBaseUrl,
    required this.timeoutSeconds,
    required this.healthUrl,
    required this.healthStatus,
    required this.healthResult,
    required this.healthError,
    required this.healthAttemptAt,
    required this.isOnline,
    required this.isCloudAuthenticated,
    required this.cloudUserIdPresent,
    required this.businessIdPresent,
    required this.role,
    required this.deviceIdPresent,
    required this.sessionVersionPresent,
    required this.tokenPresent,
    required this.bannerStatus,
    required this.errorSource,
    required this.outbox,
    required this.legacyQueue,
    required this.legacyEnabled,
  });

  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln('FIADO APP - SYNC DIAGNOSTICS')
      ..writeln('generatedAt=${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('[backend]')
      ..writeln('effectiveBaseUrl=$effectiveBaseUrl')
      ..writeln('timeoutSeconds=$timeoutSeconds online=$isOnline')
      ..writeln('healthUrl=${healthUrl ?? '-'}')
      ..writeln('healthStatus=${healthStatus ?? '-'}')
      ..writeln('healthResult=${healthResult ?? '-'}')
      ..writeln('healthError=${healthError ?? '-'}')
      ..writeln('healthAttemptAt=${healthAttemptAt ?? '-'}')
      ..writeln()
      ..writeln('[auth]')
      ..writeln('isCloudAuthenticated=$isCloudAuthenticated')
      ..writeln('cloudUserIdPresent=$cloudUserIdPresent')
      ..writeln('businessIdPresent=$businessIdPresent')
      ..writeln('role=${role ?? '-'}')
      ..writeln('deviceIdPresent=$deviceIdPresent')
      ..writeln('sessionVersionPresent=$sessionVersionPresent')
      ..writeln('tokenPresent=$tokenPresent')
      ..writeln()
      ..writeln('[banner]')
      ..writeln('text=${bannerStatus.shortMessage}')
      ..writeln('isSyncing=${bannerStatus.isSyncing}')
      ..writeln('lastSyncSucceeded=${bannerStatus.lastSyncSucceeded}')
      ..writeln('lastSuccessfulSyncAt=${bannerStatus.lastSyncAt ?? '-'}')
      ..writeln('lastError=${bannerStatus.lastErrorMessage ?? '-'}')
      ..writeln('errorSource=${errorSource ?? '-'}');
    _writeStore(buffer, 'sync_outbox', outbox);
    _writeStore(buffer, 'sync_queue legacyEnabled=$legacyEnabled', legacyQueue);
    return buffer.toString();
  }

  static void _writeStore(
    StringBuffer buffer,
    String title,
    SyncStoreDiagnosticSummary summary,
  ) {
    buffer
      ..writeln()
      ..writeln('[$title]')
      ..writeln(
        'total=${summary.total} pending=${summary.pending} '
        'failed=${summary.failed} completed=${summary.completed}',
      )
      ..writeln('maxAttempts=${summary.maxAttempts}')
      ..writeln('lastError=${summary.lastError ?? '-'}')
      ..writeln('grouped=${jsonEncode(summary.grouped)}');
    for (final item in summary.activeItems) {
      buffer.writeln('${item.source}: ${item.toPlainText()}');
    }
  }
}

class SyncDiagnosticsRepository {
  final LocalDatabase databaseHelper;
  final Future<SharedPreferences> sharedPreferences;
  final SecureTokenStorage secureTokenStorage;
  final Future<bool> Function()? tokenPresentResolver;

  SyncDiagnosticsRepository({
    LocalDatabase? databaseHelper,
    Future<SharedPreferences>? sharedPreferences,
    this.secureTokenStorage = const SecureTokenStorage(),
    this.tokenPresentResolver,
  }) : databaseHelper = databaseHelper ?? DatabaseHelper.instance,
       sharedPreferences = sharedPreferences ?? SharedPreferences.getInstance();

  Future<SyncDiagnosticsReport> load({
    required SyncUserStatus bannerStatus,
  }) async {
    final db = await databaseHelper.database;
    final prefs = await sharedPreferences;
    final config = await ApiEnvironmentConfig.resolve(Future.value(prefs));
    final storageSnapshot = await SyncStatusDiagnosticsRepository(
      databaseHelper: databaseHelper,
    ).snapshot();
    final backend = await BackendConnectionDiagnostics.read(
      Future.value(prefs),
    );
    final outbox = await _readOutbox(db);
    final legacy = await _readLegacyQueue(db);
    final tokenPresent = tokenPresentResolver != null
        ? await tokenPresentResolver!()
        : await _hasUsableToken(db);
    final visibleError = bannerStatus.lastErrorMessage;
    final errorSource = visibleError == null
        ? null
        : legacy.failed > 0
        ? 'sync_queue'
        : storageSnapshot.sourceForError(visibleError);

    return SyncDiagnosticsReport(
      effectiveBaseUrl: config.baseUrl,
      timeoutSeconds: config.timeout.inSeconds,
      healthUrl:
          prefs.getString('fiado_backend_last_health_url') ??
          backend.lastEndpoint,
      healthStatus:
          prefs.getString('fiado_backend_last_health_status') ??
          backend.lastStatusCode?.toString(),
      healthResult: prefs.getString('fiado_backend_last_health_result'),
      healthError:
          _summarize(prefs.getString('fiado_backend_last_health_error')) ??
          _summarize(backend.lastError),
      healthAttemptAt: prefs.getString('fiado_backend_last_health_attempt_at'),
      isOnline: bannerStatus.isOnline,
      isCloudAuthenticated: bannerStatus.isCloudAuthenticated,
      cloudUserIdPresent: _present(prefs.getString('fiado_cloud_user_id')),
      businessIdPresent: _present(prefs.getString('fiado_cloud_business_id')),
      role: _safeRole(prefs.getString('fiado_cloud_role')),
      deviceIdPresent:
          _present(prefs.getString('fiado_sync_device_id')) ||
          _present(prefs.getString('fiado_cloud_device_id')),
      sessionVersionPresent: prefs.containsKey('fiado_cloud_session_version'),
      tokenPresent: tokenPresent,
      bannerStatus: bannerStatus,
      errorSource: errorSource,
      outbox: outbox,
      legacyQueue: legacy,
      legacyEnabled: SyncFeatureFlags.enableLegacySync,
    );
  }

  Future<SyncStoreDiagnosticSummary> readLegacyQueue() async {
    return _readLegacyQueue(await databaseHelper.database);
  }

  Future<bool> _hasUsableToken(Database db) async {
    if ((await secureTokenStorage.readCloudToken()) != null) return true;
    final sessionRows = await db.query(
      DatabaseSchema.sesionesTable,
      columns: ['jwt_token'],
      where: 'is_active = ? AND jwt_token IS NOT NULL',
      whereArgs: [1],
      limit: 1,
    );
    if (sessionRows.isNotEmpty &&
        _present(sessionRows.first['jwt_token']?.toString())) {
      return true;
    }
    return ApiConfig.testTokenOverride.trim().isNotEmpty;
  }

  Future<SyncStoreDiagnosticSummary> _readOutbox(Database db) async {
    return _readStore(
      db,
      table: DatabaseSchema.syncOutboxTable,
      groupColumn: 'module',
      attemptsColumn: 'attempt_count',
      payloadColumn: 'payload_json',
      source: 'outbox',
      pendingStatuses: const [
        SyncOutboxItem.statusPending,
        SyncOutboxItem.statusSyncing,
      ],
      failedStatus: SyncOutboxItem.statusFailed,
      completedStatus: SyncOutboxItem.statusSynced,
    );
  }

  Future<SyncStoreDiagnosticSummary> _readLegacyQueue(Database db) async {
    return _readStore(
      db,
      table: DatabaseSchema.syncQueueTable,
      groupColumn: 'entity_type',
      attemptsColumn: 'attempts',
      payloadColumn: 'payload',
      source: 'legacy',
      pendingStatuses: const [SyncStatus.pending, SyncStatus.retry],
      failedStatus: SyncStatus.failed,
      completedStatus: SyncStatus.synced,
    );
  }

  Future<SyncStoreDiagnosticSummary> _readStore(
    Database db, {
    required String table,
    required String groupColumn,
    required String attemptsColumn,
    required String payloadColumn,
    required String source,
    required List<String> pendingStatuses,
    required String failedStatus,
    required String completedStatus,
  }) async {
    final pendingPlaceholders = List.filled(
      pendingStatuses.length,
      '?',
    ).join(', ');
    final aggregate = (await db.rawQuery(
      '''
SELECT COUNT(*) AS total,
  SUM(CASE WHEN status IN ($pendingPlaceholders) THEN 1 ELSE 0 END) AS pending,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS failed,
  SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS completed,
  MAX(COALESCE($attemptsColumn, 0)) AS max_attempts
FROM $table
''',
      [...pendingStatuses, failedStatus, completedStatus],
    )).first;
    final groupedRows = await db.rawQuery(
      'SELECT $groupColumn, COUNT(*) AS total FROM $table '
      'GROUP BY $groupColumn ORDER BY $groupColumn ASC',
    );
    final rows = await db.query(
      table,
      columns: [
        'id',
        groupColumn,
        'operation',
        'status',
        attemptsColumn,
        'last_error',
        'created_at',
        'updated_at',
        payloadColumn,
      ],
      where: 'status IN ($pendingPlaceholders, ?)',
      whereArgs: [...pendingStatuses, failedStatus],
      orderBy:
          "CASE WHEN status = '$failedStatus' THEN 0 ELSE 1 END, "
          'updated_at DESC, id ASC',
      limit: 20,
    );
    String? lastError;
    for (final row in rows) {
      lastError = _summarize(row['last_error']?.toString());
      if (lastError != null) break;
    }
    return SyncStoreDiagnosticSummary(
      total: _int(aggregate['total']),
      pending: _int(aggregate['pending']),
      failed: _int(aggregate['failed']),
      completed: _int(aggregate['completed']),
      maxAttempts: _int(aggregate['max_attempts']),
      lastError: lastError,
      grouped: {
        for (final row in groupedRows)
          row[groupColumn].toString(): _int(row['total']),
      },
      activeItems: rows
          .map(
            (row) => SyncDiagnosticRecord(
              id: (row['id'] as num?)?.toInt(),
              source: source,
              module: row[groupColumn]?.toString() ?? '-',
              operation: row['operation']?.toString() ?? '-',
              status: row['status']?.toString() ?? '-',
              attempts: _int(row[attemptsColumn]),
              lastError: _summarize(row['last_error']?.toString()),
              createdAt: row['created_at']?.toString(),
              updatedAt: row['updated_at']?.toString(),
              payloadKeys: _payloadKeys(row[payloadColumn]?.toString()),
            ),
          )
          .toList(growable: false),
    );
  }

  static int _int(Object? value) => (value as num? ?? 0).toInt();
  static bool _present(String? value) => value?.trim().isNotEmpty == true;
  static String? _safeRole(String? role) =>
      _present(role) ? role!.trim() : null;

  static List<String> _payloadKeys(String? payload) {
    if (!_present(payload)) return const [];
    try {
      final decoded = jsonDecode(payload!);
      if (decoded is! Map<String, dynamic>) return const [];
      return decoded.keys.toList(growable: false)..sort();
    } catch (_) {
      return const [];
    }
  }

  static String? _summarize(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!_present(normalized)) return null;
    final redacted = normalized!
        .replaceAll(
          RegExp(r'Bearer\s+\S+', caseSensitive: false),
          'Bearer [redacted]',
        )
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[token redacted]',
        )
        .replaceAll(
          RegExp(
            r'"(?:password|token|imageData|contentBase64)"\s*:\s*"[^"]*"',
            caseSensitive: false,
          ),
          '"sensitive":"[redacted]"',
        );
    return redacted.length <= 240
        ? redacted
        : '${redacted.substring(0, 240)}...';
  }
}
