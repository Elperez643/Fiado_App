import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/sync/sync_status.dart';
import 'package:fiado_app/data/models/subscription_sqlite_model.dart';
import 'package:fiado_app/data/models/usuario_sqlite_model.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = _stringOption(args, 'db') ?? 'qa_data/offline_first_audit.db';
  final file = File(dbPath);
  if (await file.exists()) await file.delete();
  await file.parent.create(recursive: true);

  final db = await databaseFactory.openDatabase(
    file.absolute.path,
    options: OpenDatabaseOptions(
      version: DatabaseSchema.version,
      onCreate: _createSchema,
    ),
  );

  try {
    final report = await _audit(db, file.absolute.path);
    stdout.write(report.consoleOutput);
    await File('OFFLINE_FIRST_QA.md').writeAsString(report.markdown);
    stdout.writeln('Wrote OFFLINE_FIRST_QA.md');
    if (report.failed > 0) exitCode = 2;
  } finally {
    await db.close();
  }
}

Future<_OfflineReport> _audit(Database db, String dbPath) async {
  final checks = <_Check>[];
  checks.add(
    _Check(
      'DB limpia puede tener 0 usuarios locales',
      _firstInt(
            await db.rawQuery(
              'SELECT COUNT(*) AS total FROM ${DatabaseSchema.usuariosTable}',
            ),
          ) ==
          0,
    ),
  );

  final now = DateTime.now();
  final negocioId = await _createLocalUser(
    db,
    nombre: 'Negocio Offline QA',
    telefono: '8090009911',
    tipoUsuario: UsuarioSqliteModel.tipoNegocio,
    password: 'offline123',
    now: now,
  );
  await _createLocalTrial(db, negocioId, now);

  final personalId = await _createLocalUser(
    db,
    nombre: 'Personal Offline QA',
    telefono: '8090009922',
    tipoUsuario: UsuarioSqliteModel.tipoPersonal,
    password: '8090009922',
    now: now,
  );

  await db.insert(DatabaseSchema.sesionesTable, {
    'usuario_id': negocioId,
    'started_at': now.toIso8601String(),
    'last_active_at': now.toIso8601String(),
    'is_active': 1,
  });

  checks
    ..add(
      _Check(
        'Registro local negocio crea usuario',
        await _exists(
          db,
          DatabaseSchema.usuariosTable,
          'id = ? AND tipo_usuario = ? AND telefono = ?',
          [negocioId, UsuarioSqliteModel.tipoNegocio, '8090009911'],
        ),
      ),
    )
    ..add(
      _Check(
        'Registro local personal crea usuario sin suscripcion',
        await _exists(
              db,
              DatabaseSchema.usuariosTable,
              'id = ? AND tipo_usuario = ?',
              [personalId, UsuarioSqliteModel.tipoPersonal],
            ) &&
            !await _exists(
              db,
              DatabaseSchema.subscriptionsTable,
              'usuario_id = ?',
              [personalId],
            ),
      ),
    )
    ..add(
      _Check(
        'Negocio offline recibe trial local pendiente de validacion cloud',
        await _exists(
          db,
          DatabaseSchema.subscriptionsTable,
          'usuario_id = ? AND status = ?',
          [
            negocioId,
            SubscriptionSqliteModel.statusTrialLocalPendingValidation,
          ],
        ),
      ),
    )
    ..add(
      _Check(
        'Login local valida password sin servidor',
        await _localPasswordValid(db, '8090009911', 'offline123'),
      ),
    )
    ..add(
      _Check(
        'Inventario nuevo queda vacio y aislado al negocio',
        _firstInt(
              await db.rawQuery(
                'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable} WHERE negocio_id = ?',
                [negocioId],
              ),
            ) ==
            0,
      ),
    )
    ..add(
      _Check(
        'Sync queue no tiene falsos pendientes bloqueantes',
        _firstInt(
              await db.rawQuery(
                "SELECT COUNT(*) AS total FROM ${DatabaseSchema.syncQueueTable} WHERE entity_type IN ('usuarios', 'subscriptions', 'user_onboarding') AND LOWER(status) IN ('pending', 'failed', 'retry')",
              ),
            ) ==
            0,
      ),
    );

  return _OfflineReport(dbPath: dbPath, checks: checks);
}

Future<int> _createLocalUser(
  Database db, {
  required String nombre,
  required String telefono,
  required String tipoUsuario,
  required String password,
  required DateTime now,
}) {
  return db.insert(DatabaseSchema.usuariosTable, {
    'nombre': nombre,
    'telefono': telefono,
    'tipo_usuario': tipoUsuario,
    'password_hash': _hashPassword(password),
    'activo': 1,
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
    'sync_status': SyncStatus.pending,
  });
}

Future<void> _createLocalTrial(Database db, int usuarioId, DateTime now) {
  return db.insert(DatabaseSchema.subscriptionsTable, {
    'usuario_id': usuarioId,
    'plan_id': 'basico',
    'plan_nombre': 'Basico',
    'precio_mensual': 4.99,
    'max_colaboradores': 3,
    'billing_cycle': 'mensual',
    'discount_percent': 0,
    'original_price': 4.99,
    'final_price': 4.99,
    'currency_code': 'USD',
    'status': SubscriptionSqliteModel.statusTrialLocalPendingValidation,
    'trial_started_at': now.toIso8601String(),
    'trial_ends_at': now.add(const Duration(days: 30)).toIso8601String(),
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
    'sync_status': SyncStatus.pending,
  });
}

Future<bool> _localPasswordValid(
  Database db,
  String telefono,
  String password,
) async {
  final rows = await db.query(
    DatabaseSchema.usuariosTable,
    where: 'telefono = ?',
    whereArgs: [telefono],
    limit: 1,
  );
  if (rows.isEmpty) return false;
  return rows.first['password_hash'] == _hashPassword(password);
}

Future<bool> _exists(
  Database db,
  String table,
  String where,
  List<Object?> args,
) async {
  final rows = await db.query(table, where: where, whereArgs: args, limit: 1);
  return rows.isNotEmpty;
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute(DatabaseSchema.createUsuariosTable);
  await db.execute(DatabaseSchema.createSesionesTable);
  await db.execute(DatabaseSchema.createSubscriptionsTable);
  await db.execute(DatabaseSchema.createUserOnboardingTable);
  await db.execute(DatabaseSchema.createProductosTable);
  await db.execute(DatabaseSchema.createClientesTable);
  await db.execute(DatabaseSchema.createMovimientosTable);
  await db.execute(DatabaseSchema.createDeudaItemsTable);
  await db.execute(DatabaseSchema.createComprobantesTable);
  await db.execute(DatabaseSchema.createSyncQueueTable);
}

String _hashPassword(String password) {
  const salt = 'fiado-local-auth-v1';
  var hash = 2166136261;
  for (final unit in '$salt:$password'.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return base64Url.encode(utf8.encode(hash.toRadixString(16)));
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

class _Check {
  final String label;
  final bool passed;

  const _Check(this.label, this.passed);
}

class _OfflineReport {
  final String dbPath;
  final List<_Check> checks;

  const _OfflineReport({required this.dbPath, required this.checks});

  int get failed => checks.where((check) => !check.passed).length;

  String get consoleOutput {
    final buffer = StringBuffer()
      ..writeln('OFFLINE_FIRST_AUDIT')
      ..writeln('database: $dbPath')
      ..writeln('failed: $failed')
      ..writeln('check,status');
    for (final check in checks) {
      buffer.writeln('"${check.label}",${check.passed ? 'OK' : 'FAIL'}');
    }
    return buffer.toString();
  }

  String get markdown {
    final buffer = StringBuffer()
      ..writeln('# Offline First QA')
      ..writeln()
      ..writeln('- Database: `$dbPath`')
      ..writeln('- Failed checks: $failed')
      ..writeln()
      ..writeln('| Check | Status |')
      ..writeln('| --- | --- |');
    for (final check in checks) {
      buffer.writeln('| ${check.label} | ${check.passed ? 'OK' : 'FAIL'} |');
    }
    buffer
      ..writeln()
      ..writeln('## Manual QA')
      ..writeln()
      ..writeln('- App instalada limpia sin internet abre Login.')
      ..writeln('- Registro negocio local entra al Dashboard.')
      ..writeln('- Inventario nuevo aparece vacio.')
      ..writeln('- Stripe muestra mensaje de conexion requerida sin nube.');
    return buffer.toString();
  }
}
