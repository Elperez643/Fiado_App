import 'dart:convert';

import 'package:fiado_app/core/api/api_environment.dart';
import 'package:fiado_app/core/security/secure_token_storage.dart';
import 'package:fiado_app/data/repositories/auth_repository.dart';
import 'package:fiado_app/data/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureTokenStorage extends SecureTokenStorage {
  String? cloudToken = 'jwt-device-a';
  bool cleared = false;

  @override
  Future<String?> readCloudToken() async => cloudToken;

  @override
  Future<DateTime?> readCloudTokenExpiresAt() async => null;

  @override
  Future<void> clearCloudToken() async {
    cleared = true;
    cloudToken = null;
  }
}

class _FakeAuthRepository extends AuthRepository {
  bool sessionInvalidated = false;

  @override
  Future<String?> obtenerJwtTokenActual() async => null;

  @override
  Future<void> marcarSesionActualReemplazada() async {
    sessionInvalidated = true;
  }
}

void main() {
  test('ApiClient usa effectiveBaseUrl manual para endpoints /api', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test',
    });
    final storage = _MemorySecureTokenStorage();
    final client = ApiClient(
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://fiado.test/api/sync/clients/pull',
        );
        return http.Response('{}', 200);
      }),
      authRepository: _FakeAuthRepository(),
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: storage,
    );

    await client.post('/api/sync/clients/pull');
  });

  test('SESSION_REPLACED limpia token y marca sesion local invalida', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test/api',
    });
    final authRepository = _FakeAuthRepository();
    final storage = _MemorySecureTokenStorage();
    final client = ApiClient(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'SESSION_REPLACED',
            'message':
                'Tu cuenta se inicio en otro dispositivo. Para continuar aqui, inicia sesion nuevamente.',
          }),
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
      authRepository: authRepository,
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: storage,
    );

    await expectLater(
      client.get('/api/sync/clients/pull'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'SESSION_REPLACED',
        ),
      ),
    );
    expect(storage.cleared, isTrue);
    expect(authRepository.sessionInvalidated, isTrue);
  });
}
