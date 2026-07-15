import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

const _tablesInDeleteOrder = [
  'credito_ciclo_movimientos',
  'credito_recordatorios',
  'credito_excepciones',
  'client_scores',
  'business_recommendations_cache',
  'inventory_product_metrics',
  'comprobantes',
  'deuda_items',
  'movimientos',
  'credito_ciclos',
  'auditoria_items',
  'auditorias',
  'solicitudes_autorizacion',
  'producto_imagenes',
  'productos',
  'clientes',
  'subscriptions',
  'user_onboarding',
  'sesiones',
  'sync_queue',
  'usuarios',
];

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dryRun = args.contains('--dry-run') || !args.contains('--apply');
  final apply = args.contains('--apply');
  final dbPath = await _resolveDatabasePath(args);
  final file = File(dbPath);
  if (!await file.exists()) {
    stderr.writeln('No se encontro la base SQLite: ${file.absolute.path}');
    stderr.writeln(
      'Usa: dart run tools/qa/reset_local_test_data.dart --db RUTA --dry-run',
    );
    exitCode = 1;
    return;
  }

  final db = await databaseFactory.openDatabase(file.absolute.path);
  try {
    final rows = <_ResetRow>[];
    for (final table in _tablesInDeleteOrder) {
      if (!await _tableExists(db, table)) {
        rows.add(_ResetRow(table, 0, 'skip'));
        continue;
      }
      final count = _firstInt(
        await db.rawQuery('SELECT COUNT(*) AS total FROM $table'),
      );
      rows.add(_ResetRow(table, count, dryRun ? 'dry-run' : 'deleted'));
      if (apply && count > 0) {
        await db.delete(table);
      }
    }

    stdout
      ..writeln(
        dryRun
            ? 'LOCAL_TEST_DATA_RESET_DRY_RUN'
            : 'LOCAL_TEST_DATA_RESET_APPLIED',
      )
      ..writeln('database: ${file.absolute.path}')
      ..writeln('mode: ${dryRun ? 'dry-run' : 'apply'}')
      ..writeln('table,rows,status');
    for (final row in rows) {
      stdout.writeln('${row.table},${row.rows},${row.status}');
    }
    await File(
      'LOCAL_RESET_QA.md',
    ).writeAsString(_markdown(file.path, rows, dryRun));
    stdout.writeln('Wrote LOCAL_RESET_QA.md');
  } finally {
    await db.close();
  }
}

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = [
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return candidates.last;
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

String _markdown(String dbPath, List<_ResetRow> rows, bool dryRun) {
  final buffer = StringBuffer()
    ..writeln('# Local Reset QA')
    ..writeln()
    ..writeln('- Database: `$dbPath`')
    ..writeln('- Mode: ${dryRun ? 'dry-run' : 'apply'}')
    ..writeln()
    ..writeln('| Table | Rows | Status |')
    ..writeln('| --- | ---: | --- |');
  for (final row in rows) {
    buffer.writeln('| ${row.table} | ${row.rows} | ${row.status} |');
  }
  buffer
    ..writeln()
    ..writeln('## Regla')
    ..writeln()
    ..writeln('El reset no modifica estructura, migraciones ni codigo fuente.');
  return buffer.toString();
}

class _ResetRow {
  final String table;
  final int rows;
  final String status;

  const _ResetRow(this.table, this.rows, this.status);
}
