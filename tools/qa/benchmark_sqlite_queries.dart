import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  final dbPath = _stringOption(args, 'db', 'qa_data/fiado_stress_test.db');
  final file = File(dbPath);
  final absolutePath = file.absolute.path;
  if (!await file.exists()) {
    stderr.writeln('Database not found: $absolutePath');
    stderr.writeln('Run tools/qa/generate_stress_sqlite_data.dart first.');
    exitCode = 66;
    return;
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await databaseFactory.openDatabase(absolutePath);
  try {
    final results = <_Metric>[];
    results.add(
      await _measure('clientes_count', () {
        return db.rawQuery(
          'SELECT COUNT(*) AS total FROM ${DatabaseSchema.clientesTable} '
          'WHERE negocio_id = ? AND COALESCE(is_active, 1) = 1',
          [1],
        );
      }),
    );
    results.add(
      await _measure('clientes_page_50', () {
        return db.query(
          DatabaseSchema.clientesTable,
          where: 'negocio_id = ? AND COALESCE(is_active, 1) = 1',
          whereArgs: [1],
          orderBy: 'nombre COLLATE NOCASE ASC',
          limit: 50,
        );
      }),
    );
    results.add(
      await _measure('clientes_page_100', () {
        return db.query(
          DatabaseSchema.clientesTable,
          where: 'negocio_id = ? AND COALESCE(is_active, 1) = 1',
          whereArgs: [1],
          orderBy: 'nombre COLLATE NOCASE ASC',
          limit: 100,
        );
      }),
    );
    results.add(
      await _measure('clientes_search_name_limit_50', () {
        return db.query(
          DatabaseSchema.clientesTable,
          where:
              'negocio_id = ? AND (nombre LIKE ? OR telefono LIKE ?) AND COALESCE(is_active, 1) = 1',
          whereArgs: [1, '%Cliente QA 0009%', '%0009%'],
          orderBy: 'nombre COLLATE NOCASE ASC',
          limit: 50,
        );
      }),
    );
    results.add(
      await _measure('clientes_search_phone_limit_50', () {
        return db.query(
          DatabaseSchema.clientesTable,
          where:
              'negocio_id = ? AND telefono LIKE ? AND COALESCE(is_active, 1) = 1',
          whereArgs: [1, '%0009%'],
          orderBy: 'nombre COLLATE NOCASE ASC',
          limit: 50,
        );
      }),
    );
    results.add(
      await _measure('productos_page_50', () {
        return db.query(
          DatabaseSchema.productosTable,
          where: 'negocio_id = ? AND activo = ?',
          whereArgs: [1, 1],
          orderBy: 'nombre COLLATE NOCASE ASC',
          limit: 50,
        );
      }),
    );
    results.add(
      await _measure('productos_code_lookup', () {
        return db.query(
          DatabaseSchema.productosTable,
          where: 'negocio_id = ? AND codigo_referencia = ? AND activo = ?',
          whereArgs: [1, 'QA-P-000001', 1],
          limit: 1,
        );
      }),
    );
    results.add(
      await _measure('movimientos_latest_100', () {
        return db.query(
          DatabaseSchema.movimientosTable,
          where: 'negocio_id = ?',
          whereArgs: [1],
          orderBy: 'fecha DESC',
          limit: 100,
        );
      }),
    );
    results.add(
      await _measure('movimientos_by_client_100', () {
        return db.query(
          DatabaseSchema.movimientosTable,
          where: 'negocio_id = ? AND cliente_telefono = ?',
          whereArgs: [1, '8090000001'],
          orderBy: 'fecha DESC',
          limit: 100,
        );
      }),
    );
    results.add(
      await _measure('deuda_items_by_movement', () {
        return db.query(
          DatabaseSchema.deudaItemsTable,
          where: 'negocio_id = ? AND movimiento_id = ?',
          whereArgs: [1, 1],
        );
      }),
    );
    results.add(
      await _measure('cuentas_por_cobrar_count', () {
        return db.rawQuery(
          'SELECT COUNT(*) AS total FROM ${DatabaseSchema.creditoCiclosTable} '
          'WHERE negocio_id = ? AND saldo_pendiente > 0',
          [1],
        );
      }),
    );
    results.add(
      await _measure('ciclos_vencidos_count', () {
        return db.rawQuery(
          'SELECT COUNT(*) AS total FROM ${DatabaseSchema.creditoCiclosTable} '
          'WHERE negocio_id = ? AND estado IN (?, ?) AND saldo_pendiente > 0',
          [1, 'mora', 'bloqueado'],
        );
      }),
    );
    results.add(
      await _measure('sync_queue_pending_count', () {
        return db.rawQuery(
          'SELECT COUNT(*) AS total FROM ${DatabaseSchema.syncQueueTable} '
          'WHERE status = ?',
          ['pending'],
        );
      }),
    );
    results.add(
      await _measure('audits_report_100', () {
        return db.rawQuery(
          '''
SELECT a.*, (
  SELECT COUNT(*)
  FROM ${DatabaseSchema.auditoriaItemsTable} i
  WHERE i.auditoria_id = a.id
    AND i.estado_validacion = ?
) AS diferencias
FROM ${DatabaseSchema.auditoriasTable} a
WHERE a.negocio_id = ?
ORDER BY a.fecha DESC
LIMIT 100
''',
          ['diferencia', 1],
        );
      }),
    );
    results.add(
      await _measure('dashboard_read', () async {
        final rows = <Map<String, Object?>>[];
        rows.addAll(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.clientesTable} '
            'WHERE negocio_id = ? AND COALESCE(is_active, 1) = 1',
            [1],
          ),
        );
        rows.addAll(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.productosTable} '
            'WHERE negocio_id = ? AND activo = ?',
            [1, 1],
          ),
        );
        rows.addAll(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.movimientosTable} '
            'WHERE negocio_id = ?',
            [1],
          ),
        );
        rows.addAll(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.creditoCiclosTable} '
            'WHERE negocio_id = ? AND saldo_pendiente > 0',
            [1],
          ),
        );
        rows.addAll(
          await db.rawQuery(
            'SELECT COUNT(*) AS total FROM ${DatabaseSchema.syncQueueTable} '
            'WHERE status = ?',
            ['pending'],
          ),
        );
        return rows;
      }),
    );

    final dbSizeMb = (await file.length()) / (1024 * 1024);
    stdout.writeln('metric,elapsed_ms,rows');
    for (final result in results) {
      stdout.writeln('${result.name},${result.elapsedMs},${result.rows}');
    }
    stdout.writeln('database_size_mb,${dbSizeMb.toStringAsFixed(2)},');
    stdout.writeln(
      'process_rss_mb,${(ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(2)},',
    );
  } finally {
    await db.close();
  }
}

Future<_Metric> _measure(
  String name,
  Future<List<Map<String, Object?>>> Function() action,
) async {
  final stopwatch = Stopwatch()..start();
  final rows = await action();
  stopwatch.stop();
  return _Metric(name, stopwatch.elapsedMilliseconds, rows.length);
}

String _stringOption(List<String> args, String name, String fallback) {
  final prefix = '--$name=';
  return args
          .where((arg) => arg.startsWith(prefix))
          .map((arg) => arg.substring(prefix.length))
          .firstOrNull ??
      fallback;
}

class _Metric {
  final String name;
  final int elapsedMs;
  final int rows;

  const _Metric(this.name, this.elapsedMs, this.rows);
}
