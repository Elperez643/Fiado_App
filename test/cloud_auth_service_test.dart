import 'dart:convert';

import 'package:fiado_app/core/api/api_environment.dart';
import 'package:fiado_app/core/security/secure_token_storage.dart';
import 'package:fiado_app/data/services/cloud_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureTokenStorage extends SecureTokenStorage {
  String? token;
  DateTime? expiresAt;

  @override
  Future<void> writeCloudToken({
    required String token,
    DateTime? expiresAt,
  }) async {
    this.token = token;
    this.expiresAt = expiresAt;
  }

  @override
  Future<String?> readCloudToken() async => token;

  @override
  Future<DateTime?> readCloudTokenExpiresAt() async => expiresAt;

  @override
  Future<void> clearCloudToken() async {
    token = null;
    expiresAt = null;
  }
}

void main() {
  test('cloud login uses configured API_BASE_URL style base url', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test/api',
    });
    final storage = _MemorySecureTokenStorage();
    final service = CloudAuthService(
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: storage,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://fiado.test/api/auth/login');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['phone'], '8091234567');
        expect(body.containsKey('password'), isTrue);
        expect(body['deviceId'], isA<String>());
        expect((body['deviceId'] as String), startsWith('device-'));
        expect(body['deviceInfo'], isA<String>());
        return http.Response(
          jsonEncode({
            'token': 'jwt-web',
            'expiresAt': '2026-06-23T00:00:00Z',
            'user': {
              'userId': 'cloud-user-web',
              'name': 'Admin Web',
              'phone': '8091234567',
              'role': 'Negocio',
              'businessId': 'cloud-business-web',
              'businessName': 'Negocio Web',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.loginCloud(
      phone: '8091234567',
      password: 'secret',
    );

    expect(result.success, isTrue);
    expect(result.user?.remoteId, 'cloud-user-web');
    expect(result.user?.role, 'negocio');
    expect(storage.token, 'jwt-web');
  });

  test('cloud login failure returns local-only controlled result', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test/api',
    });
    final service = CloudAuthService(
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: _MemorySecureTokenStorage(),
      httpClient: MockClient((_) async => http.Response('', 401)),
    );

    final result = await service.loginCloud(
      phone: '8091234567',
      password: 'bad',
    );

    expect(result.success, isFalse);
    expect(result.user, isNull);
    expect(result.userMessage, isNotNull);
  });

  test('registro personal con backend accesible guarda token', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test',
    });
    final storage = _MemorySecureTokenStorage();
    final service = CloudAuthService(
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: storage,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'http://fiado.test/api/auth/register/personal',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['phone'], '8095551212');
        expect(body['deviceId'], isA<String>());
        return http.Response(
          jsonEncode({
            'token': 'jwt-register',
            'sessionVersion': 1,
            'expiresAt': '2026-06-23T00:00:00Z',
            'user': {
              'userId': 'cloud-user-register',
              'name': 'Cliente Nuevo',
              'phone': '8095551212',
              'role': 'Personal',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.registerPersonal(
      name: 'Cliente Nuevo',
      phone: '8095551212',
      password: 'secret123',
    );

    expect(result.user.remoteId, 'cloud-user-register');
    expect(result.sessionVersion, 1);
    expect(storage.token, 'jwt-register');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(CloudAuthService.cloudSessionVersionKey), 1);
  });

  test('cloud login usa effectiveBaseUrl manual sin duplicar /api', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test',
    });
    final service = CloudAuthService(
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: _MemorySecureTokenStorage(),
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'http://fiado.test/api/auth/login');
        return http.Response('', 401);
      }),
    );

    await service.loginCloud(phone: '8091234567', password: 'bad');
  });

  test('link-local-user fallido expone error controlado', () async {
    SharedPreferences.setMockInitialValues({
      ApiEnvironmentConfig.manualBaseUrlKey: 'http://fiado.test',
    });
    final service = CloudAuthService(
      sharedPreferences: SharedPreferences.getInstance(),
      secureTokenStorage: _MemorySecureTokenStorage(),
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'http://fiado.test/api/auth/link-local-user',
        );
        return http.Response('{"message":"backend details"}', 400);
      }),
    );

    final result = await service.linkLocalUserToCloud(
      phone: '8091234567',
      password: 'secret123',
      name: 'Negocio',
      role: 'negocio',
      businessName: 'Negocio',
    );

    expect(result.success, isFalse);
    expect(result.userMessage, 'No se pudo actualizar');
  });
}
