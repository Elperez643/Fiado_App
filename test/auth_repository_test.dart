import 'package:fiado_app/core/database/database_schema.dart';
import 'package:fiado_app/core/database/local_database.dart';
import 'package:fiado_app/data/models/usuario_sqlite_model.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/repositories/subscription_repository.dart';
import 'package:fiado_app/data/services/cloud_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
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
  late AuthRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(DatabaseSchema.createUsuariosTable);
    await db.execute(DatabaseSchema.createSesionesTable);
    await db.execute(DatabaseSchema.createSubscriptionsTable);
    final localDatabase = _MemoryLocalDatabase(db);
    repository = AuthRepository(
      databaseHelper: localDatabase,
      subscriptionRepository: SubscriptionRepository(
        databaseHelper: localDatabase,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('login with missing user returns controlled message', () async {
    await expectLater(
      repository.login('8091111111', 'secret'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          AuthRepository.invalidCredentialsMessage,
        ),
      ),
    );
  });

  test('login with wrong password returns controlled message', () async {
    await repository.registrarUsuarioNegocio(
      'Negocio QA',
      'Admin QA',
      '8091111111',
      'correct',
    );

    await expectLater(
      repository.login('8091111111', 'wrong'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          AuthRepository.invalidCredentialsMessage,
        ),
      ),
    );
  });

  test('login with empty fields returns controlled message', () async {
    await expectLater(
      repository.login('', ''),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          AuthRepository.invalidCredentialsMessage,
        ),
      ),
    );
  });

  test('local personal registration works', () async {
    final user = await repository.registrarUsuarioPersonal(
      'Cliente QA',
      '8092222222',
    );

    expect(user.id, isNotNull);
    expect(user.tipoUsuario, UsuarioSqliteModel.tipoPersonal);
    final loggedIn = await repository.login('8092222222', '8092222222');
    expect(loggedIn.id, user.id);
  });

  test(
    'local business registration works without backend or internet',
    () async {
      final user = await repository.registrarUsuarioNegocio(
        'Colmado QA',
        'Admin QA',
        '8093333333',
        'secret',
      );

      expect(user.id, isNotNull);
      expect(user.tipoUsuario, UsuarioSqliteModel.tipoNegocio);
      final loggedIn = await repository.login('8093333333', 'secret');
      expect(loggedIn.id, user.id);
    },
  );

  test(
    'local collaborator registration bypasses subscription checks',
    () async {
      final negocio = await repository.registrarUsuarioNegocio(
        'Negocio QA',
        'Admin QA',
        '8094444444',
        'secret',
      );

      final colaborador = await repository.crearColaboradorDesdeNegocio(
        usuarioNegocioId: negocio.id!,
        nombre: 'Colaborador QA',
        telefono: '8095555555',
        password: 'secret',
      );

      expect(colaborador.tipoUsuario, UsuarioSqliteModel.tipoColaborador);
      expect(colaborador.negocioId, negocio.id);
    },
  );

  test('cloud link updates local remote id and session token', () async {
    final user = await repository.registrarUsuarioNegocio(
      'Negocio QA',
      'Admin QA',
      '8096666666',
      'secret',
    );
    await repository.login('8096666666', 'secret');

    final linked = await repository.vincularUsuarioCloudPorTelefono(
      telefono: user.telefono,
      cloudUser: const CloudAuthenticatedUser(
        remoteId: 'cloud-user-1',
        name: 'Negocio QA',
        phone: '8096666666',
        role: UsuarioSqliteModel.tipoNegocio,
      ),
      jwtToken: 'jwt-token',
    );

    expect(linked?.remoteId, 'cloud-user-1');
    expect(linked?.syncStatus, 'synced');
    expect(await repository.obtenerJwtTokenActual(), 'jwt-token');
  });

  test('existing local user logs in offline without calling cloud', () async {
    final created = await repository.registrarUsuarioNegocio(
      'Negocio Offline',
      'Admin QA',
      '8091010101',
      'secret',
    );

    var cloudWasCalled = false;
    final user = await repository.loginWithCloudFallback(
      telefono: '8091010101',
      password: 'secret',
      cloudLogin: () async {
        cloudWasCalled = true;
        return const CloudLoginResult.localOnly('offline');
      },
    );

    expect(user.id, created.id);
    expect(cloudWasCalled, isFalse);
  });

  test('new device cloud login creates local user session and token', () async {
    final user = await repository.loginWithCloudFallback(
      telefono: '8097777777',
      password: 'secret',
      cloudLogin: () async => const CloudLoginResult.success(
        CloudAuthenticatedUser(
          remoteId: 'cloud-user-777',
          name: 'Admin Cloud',
          phone: '8097777777',
          role: UsuarioSqliteModel.tipoNegocio,
          businessId: 'cloud-business-777',
          businessName: 'Negocio Cloud',
        ),
        token: 'cloud-jwt',
      ),
    );

    final current = await repository.obtenerUsuarioActual();

    expect(user.id, isNotNull);
    expect(user.remoteId, 'cloud-user-777');
    expect(user.tipoUsuario, UsuarioSqliteModel.tipoNegocio);
    expect(current?.id, user.id);
    expect(await repository.obtenerJwtTokenActual(), 'cloud-jwt');

    final rows = await db.query(
      DatabaseSchema.usuariosTable,
      columns: ['last_synced_at'],
      where: 'id = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    expect(rows.single['last_synced_at'], isNotNull);
  });

  test('new device cloud login failure returns controlled message', () async {
    await expectLater(
      repository.loginWithCloudFallback(
        telefono: '8098888888',
        password: 'bad',
        cloudLogin: () async =>
            const CloudLoginResult.localOnly('Usuario no encontrado'),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          AuthRepository.invalidCredentialsMessage,
        ),
      ),
    );
  });

  test('new device cloud login maps personal and collaborator roles', () async {
    final personal = await repository.loginWithCloudFallback(
      telefono: '8091212121',
      password: 'secret',
      cloudLogin: () async => const CloudLoginResult.success(
        CloudAuthenticatedUser(
          remoteId: 'cloud-personal-1',
          name: 'Cliente Cloud',
          phone: '8091212121',
          role: 'personal',
        ),
        token: 'personal-jwt',
      ),
    );

    final collaborator = await repository.loginWithCloudFallback(
      telefono: '8091313131',
      password: 'secret',
      cloudLogin: () async => const CloudLoginResult.success(
        CloudAuthenticatedUser(
          remoteId: 'cloud-collab-1',
          name: 'Colaborador Cloud',
          phone: '8091313131',
          role: 'collaborator',
          businessId: 'cloud-business-1',
        ),
        token: 'collab-jwt',
      ),
    );

    expect(personal.tipoUsuario, UsuarioSqliteModel.tipoPersonal);
    expect(collaborator.tipoUsuario, UsuarioSqliteModel.tipoColaborador);
    expect(await repository.obtenerJwtTokenActual(), 'collab-jwt');
  });
}
