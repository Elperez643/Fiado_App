import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await _resolveDatabasePath(args);
  final file = File(dbPath);
  final createQaDb = !await file.exists();
  if (createQaDb) await file.parent.create(recursive: true);

  final db = await databaseFactory.openDatabase(
    file.absolute.path,
    options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onCreate: _createSchema,
    ),
  );

  try {
    final report = await _audit(db, file.absolute.path, createQaDb);
    stdout.write(report.consoleOutput);
    await File('AUTH_STARTUP_AUDIT_REPORT.md').writeAsString(report.markdown);
    stdout.writeln('Wrote AUTH_STARTUP_AUDIT_REPORT.md');
    if (report.criticalIssues.isNotEmpty) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<_AuthStartupReport> _audit(
  Database db,
  String dbPath,
  bool createdQaDb,
) async {
  final usersTable = await _tableExists(db, DatabaseSchema.usuariosTable);
  final sessionsTable = await _tableExists(db, DatabaseSchema.sesionesTable);
  final onboardingTable = await _tableExists(
    db,
    DatabaseSchema.userOnboardingTable,
  );
  final subscriptionsTable = await _tableExists(
    db,
    DatabaseSchema.subscriptionsTable,
  );
  final syncQueueTable = await _tableExists(db, DatabaseSchema.syncQueueTable);

  final totalUsers = usersTable
      ? _firstInt(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.usuariosTable}',
          ),
        )
      : 0;
  final activeSessions = sessionsTable
      ? _firstInt(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.sesionesTable} WHERE is_active = 1',
          ),
        )
      : 0;
  final usersByRole = usersTable
      ? await db.rawQuery('''
SELECT tipo_usuario, COUNT(*) AS total
FROM ${DatabaseSchema.usuariosTable}
GROUP BY tipo_usuario
ORDER BY tipo_usuario
''')
      : const <Map<String, Object?>>[];
  final activeSessionRows = sessionsTable
      ? await db.rawQuery('''
SELECT s.id, s.usuario_id, u.tipo_usuario, u.telefono, s.last_active_at,
       CASE WHEN s.jwt_token IS NULL OR s.jwt_token = '' THEN 0 ELSE 1 END AS has_jwt
FROM ${DatabaseSchema.sesionesTable} s
LEFT JOIN ${DatabaseSchema.usuariosTable} u ON u.id = s.usuario_id
WHERE s.is_active = 1
ORDER BY s.last_active_at DESC
LIMIT 10
''')
      : const <Map<String, Object?>>[];
  final queueOpen = syncQueueTable
      ? _firstInt(
          await db.rawQuery('''
SELECT COUNT(*) AS total
FROM ${DatabaseSchema.syncQueueTable}
WHERE LOWER(status) IN ('pending', 'failed', 'retry')
'''),
        )
      : 0;

  final criticalIssues = [
    if (!usersTable) 'tabla usuarios no existe',
    if (!sessionsTable) 'tabla sesiones no existe',
    if (!onboardingTable) 'tabla user_onboarding no existe',
    if (!subscriptionsTable) 'tabla subscriptions no existe',
    if (!syncQueueTable) 'tabla sync_queue no existe',
  ];

  return _AuthStartupReport(
    dbPath: dbPath,
    createdQaDb: createdQaDb,
    usersTable: usersTable,
    sessionsTable: sessionsTable,
    onboardingTable: onboardingTable,
    subscriptionsTable: subscriptionsTable,
    syncQueueTable: syncQueueTable,
    totalUsers: totalUsers,
    activeSessions: activeSessions,
    usersByRole: usersByRole,
    activeSessionRows: activeSessionRows,
    queueOpen: queueOpen,
    criticalIssues: criticalIssues,
  );
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = [
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    'qa_data/auth_startup_audit.db',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return 'qa_data/auth_startup_audit.db';
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createSesionesTable);
  await db.execute(DatabaseSchema.createSubscriptionsTable);
  await db.execute(DatabaseSchema.createUserOnboardingTable);
  await db.execute(DatabaseSchema.createSyncQueueTable);
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    [table],
  );
  return rows.isNotEmpty;
}

String? _stringOption(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  final index = args.indexOf('--$name');
  if (index >= 0 && index + 1 < args.length) return args[index + 1];
  return null;
}

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  return (rows.first.values.first as num? ?? 0).toInt();
}

class _AuthStartupReport {
  final String dbPath;
  final bool createdQaDb;
  final bool usersTable;
  final bool sessionsTable;
  final bool onboardingTable;
  final bool subscriptionsTable;
  final bool syncQueueTable;
  final int totalUsers;
  final int activeSessions;
  final List<Map<String, Object?>> usersByRole;
  final List<Map<String, Object?>> activeSessionRows;
  final int queueOpen;
  final List<String> criticalIssues;

  const _AuthStartupReport({
    required this.dbPath,
    required this.createdQaDb,
    required this.usersTable,
    required this.sessionsTable,
    required this.onboardingTable,
    required this.subscriptionsTable,
    required this.syncQueueTable,
    required this.totalUsers,
    required this.activeSessions,
    required this.usersByRole,
    required this.activeSessionRows,
    required this.queueOpen,
    required this.criticalIssues,
  });

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('AUTH_STARTUP_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('created_qa_db: $createdQaDb')
      ..writeln('critical_issues: ${criticalIssues.length}')
      ..writeln('usuarios_table: $usersTable')
      ..writeln('sesiones_table: $sessionsTable')
      ..writeln('user_onboarding_table: $onboardingTable')
      ..writeln('subscriptions_table: $subscriptionsTable')
      ..writeln('sync_queue_table: $syncQueueTable')
      ..writeln('usuarios_locales: $totalUsers')
      ..writeln('sesiones_activas: $activeSessions')
      ..writeln('sync_queue_abierta: $queueOpen')
      ..writeln()
      ..writeln('usuarios_por_rol');
    for (final row in usersByRole) {
      buffer.writeln('${row['tipo_usuario']}: ${row['total']}');
    }
    buffer
      ..writeln()
      ..writeln('sesiones_activas_detalle')
      ..writeln('session_id,usuario_id,rol,telefono,last_active_at,has_jwt');
    for (final row in activeSessionRows) {
      buffer.writeln(
        '${row['id']},${row['usuario_id']},${row['tipo_usuario']},'
        '${row['telefono']},${row['last_active_at']},${row['has_jwt']}',
      );
    }
    for (final issue in criticalIssues) {
      buffer.writeln('critical: $issue');
    }
    return buffer.toString();
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# Auth Startup Audit Report')
      ..writeln()
      ..writeln('- Database: `$dbPath`')
      ..writeln('- Created QA DB: $createdQaDb')
      ..writeln('- Critical issues: ${criticalIssues.length}')
      ..writeln('- Usuarios locales: $totalUsers')
      ..writeln('- Sesiones activas: $activeSessions')
      ..writeln('- Sync queue abierta: $queueOpen')
      ..writeln()
      ..writeln('## Tablas')
      ..writeln()
      ..writeln('| Tabla | Existe |')
      ..writeln('| --- | --- |')
      ..writeln('| usuarios | $usersTable |')
      ..writeln('| sesiones | $sessionsTable |')
      ..writeln('| user_onboarding | $onboardingTable |')
      ..writeln('| subscriptions | $subscriptionsTable |')
      ..writeln('| sync_queue | $syncQueueTable |')
      ..writeln()
      ..writeln('## Usuarios Por Rol')
      ..writeln()
      ..writeln('| Rol | Total |')
      ..writeln('| --- | ---: |');
    for (final row in usersByRole) {
      buffer.writeln('| ${row['tipo_usuario']} | ${row['total']} |');
    }
    if (criticalIssues.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Critical Issues');
      for (final issue in criticalIssues) {
        buffer.writeln('- $issue');
      }
    }
    return buffer.toString();
  }
}
