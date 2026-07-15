import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_config.dart';
import '../../core/api/api_environment.dart';
import '../../core/diagnostics/backend_connection_diagnostics.dart';
import '../../core/security/secure_token_storage.dart';
import '../repositories/auth_repository.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;

  const ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

class ApiClient {
  static const manualTokenKey = ApiEnvironmentConfig.manualTokenKey;
  static const manualBaseUrlKey = ApiEnvironmentConfig.manualBaseUrlKey;

  final http.Client httpClient;
  final AuthRepository authRepository;
  final Future<SharedPreferences> sharedPreferences;
  final SecureTokenStorage secureTokenStorage;

  const ApiClient({
    required this.httpClient,
    required this.authRepository,
    required this.sharedPreferences,
    this.secureTokenStorage = const SecureTokenStorage(),
  });

  Future<Map<String, dynamic>> get(String path) {
    return _send('GET', path);
  }

  Future<List<dynamic>> getList(String path) async {
    final decoded = await _sendDecoded('GET', path);
    return decoded as List<dynamic>? ?? const [];
  }

  Future<String> effectiveBaseUrl() async {
    final config = await ApiEnvironmentConfig.resolve(sharedPreferences);
    return ApiConfig.normalizeBaseUrl(config.baseUrl);
  }

  Future<Uri> requestUri(String path) => _uri(path);

  Future<bool> hasUsableToken() async => (await _resolveToken()) != null;

  Future<Map<String, dynamic>> post(String path, {Map<String, Object?>? body}) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, Object?>? body}) {
    return _send('PUT', path, body: body);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final decoded = await _sendDecoded(method, path, body: body);
    return decoded as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  Future<dynamic> _sendDecoded(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final uri = await _uri(path);
    final token = await _resolveToken();
    if (token == null) {
      await BackendConnectionDiagnostics.recordRequest(
        sharedPreferences: sharedPreferences,
        endpoint: uri,
      );
      await BackendConnectionDiagnostics.recordError(
        sharedPreferences: sharedPreferences,
        error: 'missing token',
      );
      throw const ApiException('Guardado en este dispositivo', statusCode: 401);
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      await BackendConnectionDiagnostics.recordRequest(
        sharedPreferences: sharedPreferences,
        endpoint: uri,
      );
      final response =
          await (switch (method) {
            'GET' => httpClient.get(uri, headers: headers),
            'POST' => httpClient.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, Object?>{}),
            ),
            'PUT' => httpClient.put(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, Object?>{}),
            ),
            _ => throw ApiException('Metodo HTTP no soportado: $method'),
          }).timeout(
            (await ApiEnvironmentConfig.resolve(sharedPreferences)).timeout,
          );

      await BackendConnectionDiagnostics.recordResponse(
        sharedPreferences: sharedPreferences,
        statusCode: response.statusCode,
        body: response.body,
      );
      if (kDebugMode &&
          response.statusCode == 400 &&
          (uri.path == '/api/sync/inventory/images/push' ||
              uri.path == '/api/sync/inventory_images/push')) {
        debugPrint(
          '[inventory-images-http-400] endpoint=$uri statusCode=${response.statusCode} body=${response.body}',
        );
      }
      return await _decodeResponse(response);
    } on TimeoutException {
      await BackendConnectionDiagnostics.recordError(
        sharedPreferences: sharedPreferences,
        error: 'timeout',
      );
      throw const ApiException(
        'Tiempo de espera agotado conectando al backend.',
      );
    } on http.ClientException catch (error) {
      await BackendConnectionDiagnostics.recordError(
        sharedPreferences: sharedPreferences,
        error: error.message,
      );
      throw ApiException('No se pudo conectar al backend: ${error.message}');
    } on ApiException catch (error) {
      await BackendConnectionDiagnostics.recordError(
        sharedPreferences: sharedPreferences,
        error: error,
      );
      rethrow;
    }
  }

  Future<Uri> _uri(String path) async {
    final baseUrl = await effectiveBaseUrl();
    if (baseUrl.isEmpty) {
      throw const ApiException('Configura una baseUrl del backend.');
    }
    return ApiEnvironmentConfig.apiUriForBaseUrl(baseUrl, path);
  }

  Future<String?> _resolveToken() async {
    final cloudToken = await secureTokenStorage.readCloudToken();
    final cloudExpiresAt = await secureTokenStorage.readCloudTokenExpiresAt();
    if (cloudToken != null &&
        (cloudExpiresAt == null ||
            DateTime.now().toUtc().isBefore(cloudExpiresAt.toUtc()))) {
      return cloudToken;
    }
    if (cloudToken != null && cloudExpiresAt != null) {
      await secureTokenStorage.clearCloudToken();
    }

    final sessionToken = await authRepository.obtenerJwtTokenActual();
    if (sessionToken != null) return sessionToken;

    final manualToken = await secureTokenStorage.readManualBackendToken(
      sharedPreferences: sharedPreferences,
    );
    if (manualToken != null && manualToken.trim().isNotEmpty) {
      return manualToken.trim();
    }

    if (ApiConfig.testTokenOverride.trim().isNotEmpty) {
      return ApiConfig.testTokenOverride.trim();
    }

    return null;
  }

  Future<dynamic> _decodeResponse(http.Response response) async {
    final content = response.body.trim();
    Object decoded = const <String, dynamic>{};
    if (content.isNotEmpty) {
      try {
        decoded = jsonDecode(content);
      } catch (_) {
        decoded = <String, dynamic>{'message': content};
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final code = map['code']?.toString();
      if ((response.statusCode == 401 || response.statusCode == 409) &&
          code == 'SESSION_REPLACED') {
        await secureTokenStorage.clearCloudToken();
        await authRepository.marcarSesionActualReemplazada();
        throw const ApiException(
          'Tu cuenta se inicio en otro dispositivo. Para continuar aqui, inicia sesion nuevamente.',
          statusCode: 401,
          code: 'SESSION_REPLACED',
        );
      }
      if (response.statusCode == 401) {
        await secureTokenStorage.clearCloudToken();
        throw const ApiException('No se pudo actualizar', statusCode: 401);
      }
      final message =
          map['message'] as String? ??
          map['error']?.toString() ??
          'Error HTTP ${response.statusCode}';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return decoded;
  }
}
