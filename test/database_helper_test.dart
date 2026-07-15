import 'package:fiado_app/core/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'ensureClientIdentityColumns tolerates legacy movimientos without cliente_telefono',
    () async {
      await db.execute('''
CREATE TABLE clientes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  nombre TEXT NOT NULL,
  telefono TEXT NOT NULL,
  is_active INTEGER DEFAULT 1
)
''');
      await db.execute('''
CREATE TABLE movimientos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  cliente_nombre TEXT NOT NULL,
  fecha TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');

      await DatabaseHelper.instance.ensureClientIdentityColumnsForTesting(db);

      final columns = await db.rawQuery('PRAGMA table_info(movimientos)');
      final columnNames = columns.map((row) => row['name']).toSet();

      expect(columnNames, contains('cliente_id'));
      expect(columnNames, contains('cliente_nombre_snapshot'));
      expect(columnNames, contains('cliente_telefono_snapshot'));
      expect(columnNames, isNot(contains('cliente_telefono')));
    },
  );

  test(
    'ensureClientIdentityColumns backfills cliente_id from refreshed snapshot columns',
    () async {
      await db.execute('''
CREATE TABLE clientes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  nombre TEXT NOT NULL,
  telefono TEXT NOT NULL,
  is_active INTEGER DEFAULT 1
)
''');
      await db.execute('''
CREATE TABLE movimientos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  negocio_id INTEGER,
  cliente_nombre TEXT NOT NULL,
  fecha TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
      await db.insert('clientes', {
        'negocio_id': 7,
        'nombre': 'Cliente Legacy',
        'telefono': '8090000000',
        'is_active': 1,
      });
      await db.insert('movimientos', {
        'negocio_id': 7,
        'cliente_nombre': 'Cliente Legacy',
        'fecha': '2026-06-21T00:00:00.000',
        'created_at': '2026-06-21T00:00:00.000',
      });

      await DatabaseHelper.instance.ensureClientIdentityColumnsForTesting(db);

      final rows = await db.query('movimientos');
      expect(rows.single['cliente_id'], 1);
      expect(rows.single['cliente_nombre_snapshot'], 'Cliente Legacy');
      expect(rows.single['cliente_telefono_snapshot'], isNull);
    },
  );
}
