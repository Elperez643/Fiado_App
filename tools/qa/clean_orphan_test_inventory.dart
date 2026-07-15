import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fiado_app/core/database/database_schema.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = await _resolveDatabasePath(args);
  final apply = _hasFlag(args, 'apply');
  final businessId = _intOption(args, 'business-id');
  final file = File(dbPath);
  if (!await file.exists()) {
    stderr.writeln('No se encontro la base SQLite: ${file.absolute.path}');
    exitCode = 1;
    return;
  }

  final db = await databaseFactory.openDatabase(file.absolute.path);
  try {
    final candidates = await _findCandidates(db, businessId: businessId);
    stdout.writeln('INVENTORY_CLEANUP_${apply ? 'APPLY' : 'DRY_RUN'}');
    stdout.writeln('database: ${file.absolute.path}');
    stdout.writeln('business_id_filter: ${businessId ?? 'none'}');
    stdout.writeln('candidatos: ${candidates.length}');
    stdout.writeln('id,negocio_id,nombre,codigo_referencia,activo,motivo');
    for (final item in candidates) {
      stdout.writeln(item.csv);
    }

    if (!apply) {
      stdout.writeln('dry_run: no se modificaron datos.');
      return;
    }

    final now = DateTime.now().toIso8601String();
    final ids = candidates.map((item) => item.id).toList(growable: false);
    if (ids.isEmpty) {
      stdout.writeln('apply: no habia candidatos.');
      return;
    }
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.transaction((txn) async {
      final imageRows = await txn.query(
        DatabaseSchema.productoImagenesTable,
        columns: ['id'],
        where:
            'producto_id IN ($placeholders) OR negocio_id IS NULL OR negocio_id = 0',
        whereArgs: ids,
      );
      final imageIds = imageRows
          .map((row) => (row['id'] as num).toInt())
          .toList(growable: false);
      await txn.update(
        DatabaseSchema.productosTable,
        {
          'activo': 0,
          'deleted_at': now,
          'updated_at': now,
          'sync_status': 'synced',
        },
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      await txn.update(
        DatabaseSchema.productoImagenesTable,
        {'deleted_at': now, 'updated_at': now, 'sync_status': 'synced'},
        where:
            'producto_id IN ($placeholders) OR negocio_id IS NULL OR negocio_id = 0',
        whereArgs: [...ids],
      );
      await txn.delete(
        DatabaseSchema.inventoryProductMetricsTable,
        where:
            'producto_id IN ($placeholders) OR negocio_id IS NULL OR negocio_id = 0',
        whereArgs: [...ids],
      );
      await txn.update(
        DatabaseSchema.syncQueueTable,
        {'status': 'synced', 'last_error': null, 'updated_at': now},
        where:
            'entity_type = ? AND entity_id IN ($placeholders) AND status IN (?, ?, ?)',
        whereArgs: [
          DatabaseSchema.productosTable,
          ...ids,
          'pending',
          'failed',
          'retry',
        ],
      );
      if (imageIds.isNotEmpty) {
        final imagePlaceholders = List.filled(imageIds.length, '?').join(', ');
        await txn.update(
          DatabaseSchema.syncQueueTable,
          {'status': 'synced', 'last_error': null, 'updated_at': now},
          where:
              'entity_type = ? AND entity_id IN ($imagePlaceholders) AND status IN (?, ?, ?)',
          whereArgs: [
            DatabaseSchema.productoImagenesTable,
            ...imageIds,
            'pending',
            'failed',
            'retry',
          ],
        );
      }
    });
    stdout.writeln('apply: productos desactivados=${ids.length}');
  } finally {
    await db.close();
  }
}

Future<List<_CleanupCandidate>> _findCandidates(
  Database db, {
  int? businessId,
}) async {
  final where = <String>[];
  final args = <Object?>[];
  if (businessId == null) {
    where.add('(negocio_id IS NULL OR negocio_id = 0)');
  } else {
    where.add('negocio_id = ?');
    args.add(businessId);
    where.add(_testPatternSql);
    args.addAll(_testPatternArgs);
  }
  final rows = await db.query(
    DatabaseSchema.productosTable,
    columns: [
      'id',
      'negocio_id',
      'nombre',
      'codigo_referencia',
      'activo',
      'created_at',
    ],
    where: where.join(' AND '),
    whereArgs: args,
    orderBy: 'id ASC',
  );
  return rows
      .map(
        (row) => _CleanupCandidate(
          id: (row['id'] as num).toInt(),
          negocioId: (row['negocio_id'] as num?)?.toInt(),
          nombre: row['nombre']?.toString() ?? '',
          codigoReferencia: row['codigo_referencia']?.toString(),
          activo: (row['activo'] as num? ?? 0).toInt(),
          motivo: businessId == null
              ? 'negocio_id null/0'
              : 'patron explicito de prueba en negocio $businessId',
        ),
      )
      .toList(growable: false);
}

const _testPatternSql = '''
(
  LOWER(nombre) LIKE ?
  OR LOWER(nombre) LIKE ?
  OR LOWER(nombre) LIKE ?
  OR LOWER(COALESCE(codigo_referencia, '')) LIKE ?
  OR LOWER(COALESCE(codigo_referencia, '')) LIKE ?
)
''';

const _testPatternArgs = ['%test%', '%prueba%', '%demo%', '%test%', '%prueba%'];

Future<String> _resolveDatabasePath(List<String> args) async {
  final explicit = _stringOption(args, 'db');
  if (explicit != null) return explicit;
  final candidates = <String>[
    'qa_data/device_fiado_app_after.db',
    'qa_data/device_fiado_app.db',
    DatabaseSchema.databaseName,
    '${await databaseFactory.getDatabasesPath()}'
        '${Platform.pathSeparator}${DatabaseSchema.databaseName}',
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return candidates.last;
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

int? _intOption(List<String> args, String name) {
  final value = _stringOption(args, name);
  return value == null ? null : int.tryParse(value);
}

bool _hasFlag(List<String> args, String name) => args.contains('--$name');

class _CleanupCandidate {
  final int id;
  final int? negocioId;
  final String nombre;
  final String? codigoReferencia;
  final int activo;
  final String motivo;

  const _CleanupCandidate({
    required this.id,
    required this.negocioId,
    required this.nombre,
    required this.codigoReferencia,
    required this.activo,
    required this.motivo,
  });

  String get csv {
    return [
      id,
      negocioId ?? '',
      _csv(nombre),
      _csv(codigoReferencia ?? ''),
      activo,
      _csv(motivo),
    ].join(',');
  }

  static String _csv(String value) => '"${value.replaceAll('"', '""')}"';
}
