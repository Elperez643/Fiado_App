import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/core/sync/sync_status.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/cliente_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:fiado_app/data/services/cloud_movement_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryLocalDatabase implements LocalDatabase {
  final Database db;

  const _MemoryLocalDatabase(this.db);

  @override
  Future<Database> get database async => db;

  @override
  Future<void> close() => db.close();

  @override
  Future<void> initialize() async {}

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

void main() {
  late Database db;
  late ClienteRepository clienteRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(DatabaseSchema.createClientesTable);
    await db.execute(DatabaseSchema.createMovimientosTable);
    await db.execute(DatabaseSchema.createDeudaItemsTable);
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.execute(DatabaseSchema.createSyncQueueTable);

    final localDatabase = _MemoryLocalDatabase(db);
    clienteRepository = ClienteRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: SyncQueueRepository(databaseHelper: localDatabase),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'clientes list derives debt from local debt and payment movements',
    () async {
      await _insertCliente(db, deudaPersistida: 0);
      await _insertMovimiento(
        db,
        id: 1,
        tipo: 'deuda',
        monto: 100,
        clienteId: 1,
      );
      await _insertMovimiento(db, id: 2, tipo: 'pago', monto: 40, clienteId: 1);

      final clientes = await clienteRepository.obtenerClientes(negocioId: 7);

      expect(clientes, hasLength(1));
      expect(clientes.single.deuda, 60);
    },
  );

  test(
    'recalcularDeudasDesdeMovimientos materializes payment-adjusted balance',
    () async {
      await _insertCliente(db, deudaPersistida: 999);
      await _insertMovimiento(
        db,
        id: 1,
        tipo: 'deuda',
        monto: 100,
        clienteId: 1,
      );
      await _insertMovimiento(
        db,
        id: 2,
        tipo: 'pago',
        monto: 100,
        clienteId: 1,
      );

      await clienteRepository.recalcularDeudasDesdeMovimientos(negocioId: 7);

      final row = (await db.query(DatabaseSchema.clientesTable)).single;
      expect(row['deuda'], 0);
    },
  );

  test(
    'legacy movements without cliente_id still count by snapshots',
    () async {
      await _insertCliente(db, deudaPersistida: 0);
      await _insertMovimiento(
        db,
        id: 1,
        tipo: 'deuda',
        monto: 75,
        clienteId: null,
      );

      final cliente = await clienteRepository.buscarPorTelefono(
        '8090000011',
        negocioId: 7,
      );

      expect(cliente, isNotNull);
      expect(cliente!.deuda, 75);
    },
  );

  test(
    'two devices keep distinct remote payments with same local id',
    () async {
      SharedPreferences.setMockInitialValues({});
      await _insertCloudSession(db);
      await _insertCliente(db, deudaPersistida: 300);
      await db.update(
        DatabaseSchema.clientesTable,
        {'remote_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'},
        where: 'id = ?',
        whereArgs: [1],
      );

      final localDatabase = _MemoryLocalDatabase(db);
      final syncQueue = SyncQueueRepository(databaseHelper: localDatabase);
      final auth = AuthRepository(
        databaseHelper: localDatabase,
        syncQueueRepository: syncQueue,
      );
      final api = _FakeMovementApiClient(
        authRepository: auth,
        sharedPreferences: SharedPreferences.getInstance(),
      );
      final service = CloudMovementSyncService(
        apiClient: api,
        authRepository: auth,
        syncQueueRepository: syncQueue,
        databaseHelper: localDatabase,
        sharedPreferences: SharedPreferences.getInstance(),
        clienteRepository: clienteRepository,
      );

      await service.pullMovements();
      await clienteRepository.recalcularDeudasDesdeMovimientos(negocioId: 7);

      final movements = await db.query(
        DatabaseSchema.movimientosTable,
        where: 'negocio_id = ? AND tipo = ?',
        whereArgs: [7, 'pago'],
        orderBy: 'monto ASC',
      );
      final cliente = await clienteRepository.buscarPorTelefono(
        '8090000011',
        negocioId: 7,
      );

      expect(movements, hasLength(2));
      expect(movements.map((row) => row['monto']), [100.0, 200.0]);
      expect(movements.map((row) => row['local_uuid']).toSet(), hasLength(2));
      expect(cliente!.deuda, 0);
    },
  );
}

class _FakeMovementApiClient extends ApiClient {
  _FakeMovementApiClient({
    required super.authRepository,
    required super.sharedPreferences,
  }) : super(httpClient: http.Client());

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (path == '/movements/sync/pull') {
      return {
        'serverTime': '2026-06-22T10:02:00.000Z',
        'movements': [
          _payment(
            id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            localUuid: 'movement-device-a',
            amount: 100,
          ),
          _payment(
            id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
            localUuid: 'movement-device-b',
            amount: 200,
          ),
        ],
      };
    }
    if (path == '/debt-items/sync/pull') {
      return {
        'serverTime': '2026-06-22T10:02:00.000Z',
        'debtItems': <Map<String, Object?>>[],
      };
    }
    return {'serverTime': '2026-06-22T10:02:00.000Z', 'results': []};
  }

  Map<String, Object?> _payment({
    required String id,
    required String localUuid,
    required double amount,
  }) {
    return {
      'id': id,
      'localId': 1,
      'remoteId': localUuid,
      'businessId': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      'clientId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'clientName': 'Cliente Pago',
      'clientPhone': '8090000011',
      'type': 'pago',
      'amount': amount,
      'concept': 'Pago multidevice',
      'date': '2026-06-22T10:01:00.000Z',
      'isActive': true,
      'createdAt': '2026-06-22T10:01:00.000Z',
      'updatedAt': '2026-06-22T10:01:00.000Z',
      'lastSyncedAt': '2026-06-22T10:01:00.000Z',
    };
  }
}

Future<void> _insertCliente(
  Database db, {
  required double deudaPersistida,
}) async {
  await db.insert(DatabaseSchema.clientesTable, {
    'id': 1,
    'negocio_id': 7,
    'uuid': 'client-payment-1',
    'nombre': 'Cliente Pago',
    'telefono': '8090000011',
    'deuda': deudaPersistida,
    'is_active': 1,
    'created_at': '2026-06-22T10:00:00.000Z',
    'updated_at': '2026-06-22T10:00:00.000Z',
    'sync_status': SyncStatus.synced,
  });
}

Future<void> _insertCloudSession(Database db) async {
  await db.insert(DatabaseSchema.usuariosTable, {
    'id': 7,
    'remote_id': 'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'nombre': 'Negocio',
    'telefono': '8099999999',
    'tipo_usuario': 'negocio',
    'password_hash': 'hash',
    'activo': 1,
    'created_at': '2026-06-22T10:00:00.000Z',
    'updated_at': '2026-06-22T10:00:00.000Z',
    'sync_status': SyncStatus.synced,
  });
  await db.insert(DatabaseSchema.sesionesTable, {
    'usuario_id': 7,
    'started_at': '2026-06-22T10:00:00.000Z',
    'last_active_at': '2026-06-22T10:00:00.000Z',
    'is_active': 1,
  });
}

Future<void> _insertMovimiento(
  Database db, {
  required int id,
  required String tipo,
  required double monto,
  required int? clienteId,
}) async {
  await db.insert(DatabaseSchema.movimientosTable, {
    'id': id,
    'negocio_id': 7,
    'cliente_id': clienteId,
    'cliente_nombre': 'Cliente Pago',
    'cliente_telefono': '8090000011',
    'cliente_nombre_snapshot': 'Cliente Pago',
    'cliente_telefono_snapshot': '8090000011',
    'tipo': tipo,
    'monto': monto,
    'fecha': '2026-06-22T10:00:00.000Z',
    'created_at': '2026-06-22T10:00:00.000Z',
    'updated_at': '2026-06-22T10:00:00.000Z',
    'is_active': 1,
    'sync_status': SyncStatus.synced,
  });
}
