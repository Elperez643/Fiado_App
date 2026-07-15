import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../core/diagnostics/crash_diagnostics_service.dart';

class StartupDiagnosticsScreen extends StatefulWidget {
  const StartupDiagnosticsScreen({super.key});

  @override
  State<StartupDiagnosticsScreen> createState() =>
      _StartupDiagnosticsScreenState();
}

class _StartupDiagnosticsScreenState extends State<StartupDiagnosticsScreen> {
  late Future<_StartupDiagnostics> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostico de arranque')),
      body: FutureBuilder<_StartupDiagnostics>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows =
              data?.rows ?? {'error': snapshot.error?.toString() ?? ''};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in rows.entries)
                Card(
                  child: ListTile(
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_StartupDiagnostics> _load() async {
    var dbReady = false;
    var sessionCount = 0;
    var activeSession = false;
    var localUsersCount = 0;
    var error = '';

    try {
      final db = await DatabaseHelper.instance.database.timeout(
        const Duration(seconds: 5),
      );
      dbReady = true;
      final sessionRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM ${DatabaseSchema.sesionesTable}',
      );
      final activeRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM ${DatabaseSchema.sesionesTable} WHERE is_active = 1',
      );
      final userRows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM ${DatabaseSchema.usuariosTable}',
      );
      sessionCount = _firstInt(sessionRows);
      activeSession = _firstInt(activeRows) > 0;
      localUsersCount = _firstInt(userRows);
    } catch (err) {
      error = err.toString();
    }

    return _StartupDiagnostics({
      'dbReady': '$dbReady',
      'sessionCount': '$sessionCount',
      'activeSession': '$activeSession',
      'localUsersCount': '$localUsersCount',
      'authProviderStatus': 'local-first',
      'lastStartupStep': CrashDiagnosticsService.getLastStartupStep() ?? '',
      'lastErrorSafe': CrashDiagnosticsService.getLastStartupError() ?? error,
      'platform': defaultTargetPlatform.name,
      'isWeb': '$kIsWeb',
    });
  }

  int _firstInt(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return 0;
    return (rows.first.values.first as num? ?? 0).toInt();
  }
}

class _StartupDiagnostics {
  final Map<String, String> rows;

  const _StartupDiagnostics(this.rows);
}
