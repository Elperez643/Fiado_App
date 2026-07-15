import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/core/sync/sync_status.dart';
import 'package:fiado_app/data/models/new_sync_status.dart';
import 'package:fiado_app/data/models/sync_outbox_item.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/cliente_repository.dart';
import 'package:fiado_app/data/repositories/sync_outbox_repository.dart';
import 'package:fiado_app/data/repositories/sync_queue_repository.dart';
import 'package:fiado_app/data/repositories/sync_state_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:fiado_app/data/services/client_sync_adapter.dart';
import 'package:fiado_app/data/services/sync_device_identity_service.dart';
import 'package:fiado_app/data/services/sync_engine.dart';
import 'package:fiado_app/models/cliente.dart';
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

class _ClientsApiClient extends ApiClient {
  final List<Map<String, Object?>> remoteChanges;
  final List<Map<String, Object?>> pushed = [];
  final List<String> requestedPaths = [];
  final bool tokenPresent;

  _ClientsApiClient({
    required super.authRepository,
    required super.sharedPreferences,
    this.remoteChanges = const [],
    this.tokenPresent = true,
  }) : super(httpClient: http.Client());

  @override
  Future<bool> hasUsableToken() async => tokenPresent;

  @override
  Future<Uri> requestUri(String path) async {
    return Uri.parse('http://fiado.test$path');
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) async {
    requestedPaths.add(path);
    if (path == '/api/sync/clients/push') {
      final changes = (body?['changes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();
      pushed.addAll(changes);
      return {
        'module': 'clients',
        'accepted': changes.length,
        'rejected': 0,
        'serverTime': '2026-06-22T10:00:00.000Z',
        'errors': <String>[],
      };
    }
    if (path == '/api/sync/clients/pull') {
      return {
        'module': 'clients',
        'changes': remoteChanges,
        'serverTime': '2026-06-22T10:01:00.000Z',
        'hasMore': false,
      };
    }
    return <String, dynamic>{};
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('crear cliente offline inserta sync_outbox pending', () async {
    final fixture = await _ClientFixture.open();
    addTearDown(fixture.close);

    await fixture.repository.guardarCliente(
      Cliente(nombre: 'Ana', telefono: '8091111111'),
      negocioId: 7,
    );

    final pending = await fixture.outbox.pending(module: 'clients');
    expect(pending, hasLength(1));
    expect(pending.single.status, SyncOutboxItem.statusPending);
    expect(pending.single.entityUuid, startsWith('client-'));
  });

  test('push de cliente cambia estado a synced', () async {
    final fixture = await _ClientFixture.open();
    addTearDown(fixture.close);

    await fixture.repository.guardarCliente(
      Cliente(nombre: 'Ana', telefono: '8091111111'),
      negocioId: 7,
    );
    final result = await fixture.engine.syncNow(module: 'clients');
    final pending = await fixture.outbox.pending(module: 'clients');
    final rows = await fixture.db.query(DatabaseSchema.clientesTable);

    expect(result.pushedCount, 1);
    expect(pending, isEmpty);
    expect(rows.single['sync_status'], SyncStatus.synced);
  });

  test('pull inserta cliente remoto en SQLite', () async {
    final fixture = await _ClientFixture.open(
      remoteChanges: [_remoteClient(uuid: 'client-remote-a', name: 'Remoto')],
    );
    addTearDown(fixture.close);

    await fixture.engine.pullChanges(module: 'clients');

    final rows = await fixture.db.query(DatabaseSchema.clientesTable);
    expect(rows, hasLength(1));
    expect(rows.single['uuid'], 'client-remote-a');
    expect(rows.single['nombre'], 'Remoto');
  });

  test('pull exitoso sin pendientes limpia error visible anterior', () async {
    final fixture = await _ClientFixture.open();
    addTearDown(fixture.close);
    await fixture.db.insert(DatabaseSchema.syncStateTable, {
      'business_id': '7',
      'module': 'clients',
      'last_error': 'fallo anterior',
      'pending_count': 0,
      'updated_at': '2026-06-22T09:00:00.000Z',
    });

    await fixture.engine.pullChanges(module: 'clients');

    final rows = await fixture.db.query(
      DatabaseSchema.syncStateTable,
      where: 'module = ?',
      whereArgs: ['clients'],
    );
    final status = await fixture.engine.recomputeStatus();
    expect(rows.single['last_error'], isNull);
    expect(status.state, NewSyncUiState.allUpdated);
  });

  test('pull actualiza cliente existente por uuid', () async {
    final fixture = await _ClientFixture.open(
      remoteChanges: [
        _remoteClient(uuid: 'client-shared', name: 'Nombre Nuevo'),
      ],
    );
    addTearDown(fixture.close);
    await fixture.insertClient(uuid: 'client-shared', name: 'Nombre Viejo');

    await fixture.engine.pullChanges(module: 'clients');

    final rows = await fixture.db.query(DatabaseSchema.clientesTable);
    expect(rows, hasLength(1));
    expect(rows.single['nombre'], 'Nombre Nuevo');
  });

  test('soft delete remoto oculta cliente local', () async {
    final fixture = await _ClientFixture.open(
      remoteChanges: [
        _remoteClient(
          uuid: 'client-delete',
          name: 'Borrado',
          deletedAt: '2026-06-22T10:03:00.000Z',
        ),
      ],
    );
    addTearDown(fixture.close);
    await fixture.insertClient(uuid: 'client-delete', name: 'Borrado');

    await fixture.engine.pullChanges(module: 'clients');

    final visible = await fixture.repository.obtenerClientes(negocioId: 7);
    final rows = await fixture.db.query(DatabaseSchema.clientesTable);
    expect(visible, isEmpty);
    expect(rows.single['deleted_at'], isNotNull);
  });

  test(
    'dos dispositivos conservan clientes con mismo localId y uuid diferente',
    () async {
      final changes = [
        _remoteClient(uuid: 'client-device-a', name: 'A', phone: '8090000001'),
        _remoteClient(uuid: 'client-device-b', name: 'B', phone: '8090000002'),
      ];
      final deviceA = await _ClientFixture.open(remoteChanges: changes);
      final deviceB = await _ClientFixture.open(remoteChanges: changes);
      addTearDown(deviceA.close);
      addTearDown(deviceB.close);

      await deviceA.engine.pullChanges(module: 'clients');
      await deviceB.engine.pullChanges(module: 'clients');

      expect(
        await deviceA.repository.obtenerClientes(negocioId: 7),
        hasLength(2),
      );
      expect(
        await deviceB.repository.obtenerClientes(negocioId: 7),
        hasLength(2),
      );
    },
  );

  test(
    'dos dispositivos editan el mismo cliente y converge por uuid',
    () async {
      final changes = [
        _remoteClient(uuid: 'client-shared', name: 'Ultima Edicion'),
      ];
      final fixture = await _ClientFixture.open(remoteChanges: changes);
      addTearDown(fixture.close);
      await fixture.insertClient(
        uuid: 'client-shared',
        name: 'Primera Edicion',
      );

      await fixture.engine.pullChanges(module: 'clients');

      final rows = await fixture.db.query(DatabaseSchema.clientesTable);
      expect(rows, hasLength(1));
      expect(rows.single['uuid'], 'client-shared');
      expect(rows.single['nombre'], 'Ultima Edicion');
    },
  );

  test(
    'estado no muestra Todo actualizado si clients tiene pending/error',
    () async {
      final fixture = await _ClientFixture.open();
      addTearDown(fixture.close);
      await fixture.repository.guardarCliente(
        Cliente(nombre: 'Ana', telefono: '8091111111'),
        negocioId: 7,
      );

      final pendingStatus = await fixture.engine.recomputeStatus();
      await fixture.outbox.markFailed(
        await fixture.outbox.pending(module: 'clients'),
        'fallo clients',
      );
      final failedStatus = await fixture.engine.recomputeStatus();

      expect(pendingStatus.state, NewSyncUiState.savedOnThisDevice);
      expect(pendingStatus.canShowAllUpdated, isFalse);
      expect(failedStatus.state, NewSyncUiState.error);
      expect(failedStatus.canShowAllUpdated, isFalse);
    },
  );

  test('SyncEngine no ejecuta sync clients sin token', () async {
    final fixture = await _ClientFixture.open(tokenPresent: false);
    addTearDown(fixture.close);
    await fixture.repository.guardarCliente(
      Cliente(nombre: 'Ana', telefono: '8091111111'),
      negocioId: 7,
    );

    final result = await fixture.engine.syncNow(module: 'clients');

    expect(result.pushedCount, 0);
    expect(result.pulledCount, 0);
    expect(result.pendingCount, 1);
    expect(fixture.apiClient.requestedPaths, isEmpty);
  });

  test('SyncEngine no ejecuta sync clients sin businessId', () async {
    final fixture = await _ClientFixture.open(tipoUsuario: 'personal');
    addTearDown(fixture.close);
    await fixture.repository.guardarCliente(
      Cliente(nombre: 'Ana', telefono: '8091111111'),
      negocioId: 7,
    );

    final result = await fixture.engine.syncNow(module: 'clients');

    expect(result.error, contains('negocio no identificado'));
    expect(fixture.apiClient.requestedPaths, isEmpty);
  });

  test('SyncEngine usa endpoints /api/sync/clients/push y pull', () async {
    final fixture = await _ClientFixture.open();
    addTearDown(fixture.close);
    await fixture.repository.guardarCliente(
      Cliente(nombre: 'Ana', telefono: '8091111111'),
      negocioId: 7,
    );

    await fixture.engine.syncNow(module: 'clients');

    expect(fixture.apiClient.requestedPaths, [
      '/api/sync/clients/push',
      '/api/sync/clients/pull',
    ]);
  });
}

class _ClientFixture {
  final Database db;
  final ClienteRepository repository;
  final SyncOutboxRepository outbox;
  final SyncEngine engine;
  final _ClientsApiClient apiClient;

  const _ClientFixture({
    required this.db,
    required this.repository,
    required this.outbox,
    required this.engine,
    required this.apiClient,
  });

  static Future<_ClientFixture> open({
    List<Map<String, Object?>> remoteChanges = const [],
    bool tokenPresent = true,
    String tipoUsuario = 'negocio',
  }) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.execute(DatabaseSchema.createClientesTable);
    await db.execute(DatabaseSchema.createMovimientosTable);
    await db.execute(DatabaseSchema.createSyncOutboxTable);
    await db.execute(DatabaseSchema.createSyncStateTable);
    for (final index in DatabaseSchema.initialIndexes) {
      if (index.contains('idx_sync_outbox_') ||
          index.contains('idx_sync_state_')) {
        await db.execute(index);
      }
    }
    final localDatabase = _MemoryLocalDatabase(db);
    final outbox = SyncOutboxRepository(databaseHelper: localDatabase);
    final syncQueue = SyncQueueRepository(databaseHelper: localDatabase);
    final repository = ClienteRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: syncQueue,
      syncOutboxRepository: outbox,
    );
    final auth = AuthRepository(
      databaseHelper: localDatabase,
      syncQueueRepository: syncQueue,
    );
    await _insertSession(db, tipoUsuario: tipoUsuario);
    final apiClient = _ClientsApiClient(
      authRepository: auth,
      sharedPreferences: SharedPreferences.getInstance(),
      remoteChanges: remoteChanges,
      tokenPresent: tokenPresent,
    );
    final engine = SyncEngine(
      outboxRepository: outbox,
      stateRepository: SyncStateRepository(databaseHelper: localDatabase),
      deviceIdentityService: SyncDeviceIdentityService(
        sharedPreferences: SharedPreferences.getInstance(),
      ),
      apiClient: apiClient,
      authRepository: auth,
      adapters: [
        ClientSyncAdapter(clienteRepository: repository, authRepository: auth),
      ],
    );
    return _ClientFixture(
      db: db,
      repository: repository,
      outbox: outbox,
      engine: engine,
      apiClient: apiClient,
    );
  }

  Future<void> insertClient({
    required String uuid,
    required String name,
    String phone = '8091111111',
  }) async {
    await db.insert(DatabaseSchema.clientesTable, {
      'negocio_id': 7,
      'uuid': uuid,
      'nombre': name,
      'telefono': phone,
      'deuda': 0,
      'is_active': 1,
      'created_at': '2026-06-22T09:00:00.000Z',
      'updated_at': '2026-06-22T09:00:00.000Z',
      'sync_version': 0,
      'sync_status': SyncStatus.synced,
    });
  }

  Future<void> close() => db.close();
}

Future<void> _insertSession(
  Database db, {
  String tipoUsuario = 'negocio',
}) async {
  await db.insert(DatabaseSchema.usuariosTable, {
    'id': 7,
    'remote_id': 'business-remote',
    'nombre': 'Negocio',
    'telefono': '8099999999',
    'tipo_usuario': tipoUsuario,
    'password_hash': 'hash',
    'activo': 1,
    'created_at': '2026-06-22T09:00:00.000Z',
    'updated_at': '2026-06-22T09:00:00.000Z',
    'sync_status': SyncStatus.synced,
  });
  await db.insert(DatabaseSchema.sesionesTable, {
    'usuario_id': 7,
    'started_at': '2026-06-22T09:00:00.000Z',
    'last_active_at': '2026-06-22T09:00:00.000Z',
    'is_active': 1,
  });
}

Map<String, Object?> _remoteClient({
  required String uuid,
  required String name,
  String phone = '8092222222',
  String? deletedAt,
}) {
  return {
    'uuid': uuid,
    'serverId': '$uuid-server',
    'businessId': '7',
    'nombre': name,
    'telefono': phone,
    'direccion': null,
    'deuda': 0,
    'createdAt': '2026-06-22T10:00:00.000Z',
    'updatedAt': '2026-06-22T10:02:00.000Z',
    'deletedAt': deletedAt,
    'syncVersion': 1,
  };
}
