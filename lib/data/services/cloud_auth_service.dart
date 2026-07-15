import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_config.dart';
import '../../core/api/api_environment.dart';
import '../../core/security/secure_token_storage.dart';
import 'sync_device_identity_service.dart';

class CloudLoginResult {
  final bool success;
  final String? userMessage;
  final CloudAuthenticatedUser? user;
  final String? token;
  final DateTime? expiresAt;
  final int? sessionVersion;
  final String? deviceId;

  const CloudLoginResult._({
    required this.success,
    this.userMessage,
    this.user,
    this.token,
    this.expiresAt,
    this.sessionVersion,
    this.deviceId,
  });

  const CloudLoginResult.success(
    CloudAuthenticatedUser user, {
    String? token,
    DateTime? expiresAt,
    int? sessionVersion,
    String? deviceId,
  }) : this._(
         success: true,
         user: user,
         token: token,
         expiresAt: expiresAt,
         sessionVersion: sessionVersion,
         deviceId: deviceId,
       );

  const CloudLoginResult.localOnly(String message)
    : this._(success: false, userMessage: message);
}

class CloudAuthenticatedUser {
  final String remoteId;
  final String name;
  final String phone;
  final String role;
  final String? businessId;
  final String? businessName;

  const CloudAuthenticatedUser({
    required this.remoteId,
    required this.name,
    required this.phone,
    required this.role,
    this.businessId,
    this.businessName,
  });

  factory CloudAuthenticatedUser.fromJson(
    Map<String, dynamic> user, {
    required String fallbackPhone,
  }) {
    final role = (user['role'] ?? user['tipoUsuario'] ?? 'negocio')
        .toString()
        .toLowerCase()
        .trim();
    final name =
        (user['name'] ??
                user['nombre'] ??
                user['businessName'] ??
                user['business_name'] ??
                'Usuario Fiado')
            .toString()
            .trim();
    final phone = (user['phone'] ?? user['telefono'] ?? fallbackPhone)
        .toString()
        .trim();
    return CloudAuthenticatedUser(
      remoteId: (user['id'] ?? user['userId'] ?? '').toString(),
      name: name.isEmpty ? 'Usuario Fiado' : name,
      phone: phone.isEmpty ? fallbackPhone.trim() : phone,
      role: _normalizeRole(role),
      businessId: (user['businessId'] ?? user['negocioId'])?.toString(),
      businessName: (user['businessName'] ?? user['business_name'])?.toString(),
    );
  }

  static String _normalizeRole(String role) {
    return switch (role) {
      'business' || 'negocio' => 'negocio',
      'personal' || 'person' => 'personal',
      'collaborator' || 'colaborador' => 'colaborador',
      _ => 'negocio',
    };
  }
}

class CloudBusinessRegistrationResult {
  final String token;
  final DateTime? expiresAt;
  final CloudAuthenticatedUser user;
  final String subscriptionStatus;
  final bool paymentMethodRequired;
  final String? message;
  final int? sessionVersion;
  final String? deviceId;

  const CloudBusinessRegistrationResult({
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.subscriptionStatus,
    required this.paymentMethodRequired,
    this.message,
    this.sessionVersion,
    this.deviceId,
  });
}

class CloudAuthService {
  static const cloudUserIdKey = 'fiado_cloud_user_id';
  static const cloudBusinessIdKey = 'fiado_cloud_business_id';
  static const cloudRoleKey = 'fiado_cloud_role';
  static const cloudBusinessNameKey = 'fiado_cloud_business_name';
  static const cloudSessionVersionKey = 'fiado_cloud_session_version';
  static const cloudDeviceIdKey = 'fiado_cloud_device_id';

  final http.Client httpClient;
  final Future<SharedPreferences> sharedPreferences;
  final SecureTokenStorage secureTokenStorage;

  const CloudAuthService({
    required this.httpClient,
    required this.sharedPreferences,
    this.secureTokenStorage = const SecureTokenStorage(),
  });

  Future<CloudLoginResult> loginCloud({
    required String phone,
    required String password,
  }) async {
    try {
      final config = await ApiEnvironmentConfig.resolve(sharedPreferences);
      final baseUrl = ApiConfig.normalizeBaseUrl(config.baseUrl);
      debugPrint('[BackendConfig] effectiveBaseUrl=$baseUrl');
      debugPrint(
        '[cloud-auth] cloud login/link attempted action=login effectiveBaseUrl=${baseUrl.isEmpty ? 'empty' : baseUrl} phone=${phone.trim().isEmpty ? 'empty' : 'present'}',
      );
      if (baseUrl.isEmpty) {
        debugPrint('[cloud-auth] login skipped: empty baseUrl');
        return const CloudLoginResult.localOnly('Guardado en este dispositivo');
      }
      final devicePayload = await _devicePayload();
      debugPrint('[cloud-auth] deviceId enviado=${devicePayload['deviceId']}');
      debugPrint('[Auth] deviceId=${devicePayload['deviceId']}');
      final endpoint = ApiEnvironmentConfig.apiUriForBaseUrl(
        baseUrl,
        '/auth/login',
      );
      debugPrint('[Register] remoteEndpoint=$endpoint');

      final response = await httpClient
          .post(
            endpoint,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'phone': phone.trim(),
              'password': password,
              ...devicePayload,
            }),
          )
          .timeout(config.timeout);
      debugPrint('[cloud-auth] login response status=${response.statusCode}');
      debugPrint('[Register] remoteStatus=${response.statusCode}');

      if (response.statusCode == 401 || response.statusCode == 404) {
        debugPrint(
          '[cloud-auth] login auth rejected status=${response.statusCode}',
        );
        return const CloudLoginResult.localOnly('Guardado en este dispositivo');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[cloud-auth] login backend error status=${response.statusCode}',
        );
        return const CloudLoginResult.localOnly('Guardado en este dispositivo');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final token = (decoded['token'] ?? decoded['accessToken'])?.toString();
      if (token == null || token.trim().isEmpty) {
        debugPrint('[cloud-auth] login failed: missing token');
        debugPrint('[cloud-auth] cloud token saved false');
        return const CloudLoginResult.localOnly('Guardado en este dispositivo');
      }

      final expiresAt = DateTime.tryParse(
        decoded['expiresAt']?.toString() ?? '',
      );
      final userPayload = decoded['user'];
      if (userPayload is! Map<String, dynamic>) {
        debugPrint('[cloud-auth] login failed: invalid user payload');
        debugPrint('[cloud-auth] cloud token saved false');
        return const CloudLoginResult.localOnly('No se pudo actualizar');
      }
      final cloudUser = CloudAuthenticatedUser.fromJson(
        userPayload,
        fallbackPhone: phone,
      );
      await saveCloudToken(token: token, expiresAt: expiresAt);
      await _saveCloudMetadata(userPayload);
      await _saveSessionMetadata(decoded);
      debugPrint('[cloud-auth] cloud token saved true');
      debugPrint('[Auth] tokenSaved=true');
      debugPrint(
        '[cloud-auth] sessionVersion recibido=${decoded['sessionVersion'] ?? 'null'}',
      );
      debugPrint(
        '[Auth] sessionVersion=${decoded['sessionVersion'] ?? 'null'}',
      );
      return CloudLoginResult.success(
        cloudUser,
        token: token,
        expiresAt: expiresAt,
        sessionVersion: _sessionVersionFrom(decoded),
        deviceId: decoded['deviceId']?.toString(),
      );
    } on TimeoutException {
      debugPrint('[cloud-auth] login timeout');
      debugPrint('[Register] remoteError=timeout');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    } on http.ClientException catch (error) {
      debugPrint('[cloud-auth] login network/client error: ${error.message}');
      debugPrint('[Register] remoteError=${error.message}');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    } catch (error) {
      debugPrint('[cloud-auth] login unexpected error: $error');
      debugPrint('[Register] remoteError=$error');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    }
  }

  Future<CloudBusinessRegistrationResult> startBusinessRegistration({
    required String ownerName,
    required String businessName,
    required String phone,
    required String password,
  }) async {
    final config = await ApiEnvironmentConfig.resolve(sharedPreferences);
    final baseUrl = ApiConfig.normalizeBaseUrl(config.baseUrl);
    debugPrint('[BackendConfig] effectiveBaseUrl=$baseUrl');
    debugPrint(
      '[cloud-auth] register remote attempted action=register-business effectiveBaseUrl=${baseUrl.isEmpty ? 'empty' : baseUrl}',
    );
    if (baseUrl.isEmpty) {
      throw StateError(
        'No se pudo crear la cuenta. Revisa la conexion e intentalo nuevamente.',
      );
    }

    try {
      final devicePayload = await _devicePayload();
      debugPrint('[cloud-auth] deviceId enviado=${devicePayload['deviceId']}');
      debugPrint('[Auth] deviceId=${devicePayload['deviceId']}');
      final endpoint = ApiEnvironmentConfig.apiUriForBaseUrl(
        baseUrl,
        '/auth/register/business/start',
      );
      debugPrint('[Register] remoteEndpoint=$endpoint');
      final response = await httpClient
          .post(
            endpoint,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'ownerName': ownerName.trim(),
              'businessName': businessName.trim(),
              'phone': phone.trim(),
              'password': password,
              ...devicePayload,
            }),
          )
          .timeout(config.timeout);
      debugPrint('[Register] remoteStatus=${response.statusCode}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('No se pudo crear la cuenta.');
      }

      final token = (decoded['token'] ?? decoded['accessToken'])?.toString();
      final userPayload = decoded['user'];
      if (token == null ||
          token.trim().isEmpty ||
          userPayload is! Map<String, dynamic>) {
        debugPrint('[cloud-auth] cloud token saved false');
        debugPrint('[Auth] tokenSaved=false');
        throw StateError('No se pudo iniciar la sesion.');
      }

      final expiresAt = DateTime.tryParse(
        decoded['expiresAt']?.toString() ?? '',
      );
      final user = CloudAuthenticatedUser.fromJson(
        userPayload,
        fallbackPhone: phone,
      );
      await saveCloudToken(token: token, expiresAt: expiresAt);
      await _saveCloudMetadata(userPayload);
      await _saveSessionMetadata(decoded);
      debugPrint('[cloud-auth] cloud token saved true');
      debugPrint('[Auth] tokenSaved=true');
      debugPrint(
        '[cloud-auth] sessionVersion recibido=${decoded['sessionVersion'] ?? 'null'}',
      );
      debugPrint(
        '[Auth] sessionVersion=${decoded['sessionVersion'] ?? 'null'}',
      );
      return CloudBusinessRegistrationResult(
        token: token,
        expiresAt: expiresAt,
        user: user,
        subscriptionStatus:
            decoded['subscriptionStatus']?.toString() ??
            'payment_method_required',
        paymentMethodRequired:
            decoded['paymentMethodRequired'] as bool? ?? true,
        message: decoded['message']?.toString(),
        sessionVersion: _sessionVersionFrom(decoded),
        deviceId: decoded['deviceId']?.toString(),
      );
    } on TimeoutException {
      debugPrint('[Register] remoteError=timeout');
      throw StateError(
        'No se pudo crear la cuenta. Revisa la conexion e intentalo nuevamente.',
      );
    } on http.ClientException {
      debugPrint('[Register] remoteError=client');
      throw StateError(
        'No se pudo crear la cuenta. Revisa la conexion e intentalo nuevamente.',
      );
    }
  }

  Future<CloudBusinessRegistrationResult> registerPersonal({
    required String name,
    required String phone,
    required String password,
  }) async {
    final config = await ApiEnvironmentConfig.resolve(sharedPreferences);
    final baseUrl = ApiConfig.normalizeBaseUrl(config.baseUrl);
    debugPrint('[BackendConfig] effectiveBaseUrl=$baseUrl');
    debugPrint(
      '[cloud-auth] register remote attempted action=register-personal effectiveBaseUrl=${baseUrl.isEmpty ? 'empty' : baseUrl}',
    );
    if (baseUrl.isEmpty) {
      throw StateError('Configura el servidor para crear la cuenta.');
    }

    final devicePayload = await _devicePayload();
    debugPrint('[cloud-auth] deviceId enviado=${devicePayload['deviceId']}');
    debugPrint('[Auth] deviceId=${devicePayload['deviceId']}');
    final endpoint = ApiEnvironmentConfig.apiUriForBaseUrl(
      baseUrl,
      '/auth/register/personal',
    );
    debugPrint('[Register] remoteEndpoint=$endpoint');
    final response = await httpClient
        .post(
          endpoint,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': name.trim(),
            'phone': phone.trim(),
            'password': password,
            ...devicePayload,
          }),
        )
        .timeout(config.timeout);
    debugPrint('[Register] remoteStatus=${response.statusCode}');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('No se pudo crear la cuenta.');
    }

    final token = (decoded['token'] ?? decoded['accessToken'])?.toString();
    final userPayload = decoded['user'];
    if (token == null ||
        token.trim().isEmpty ||
        userPayload is! Map<String, dynamic>) {
      debugPrint('[cloud-auth] cloud token saved false');
      debugPrint('[Auth] tokenSaved=false');
      throw StateError('No se pudo iniciar la sesion.');
    }

    final expiresAt = DateTime.tryParse(decoded['expiresAt']?.toString() ?? '');
    final user = CloudAuthenticatedUser.fromJson(
      userPayload,
      fallbackPhone: phone,
    );
    await saveCloudToken(token: token, expiresAt: expiresAt);
    await _saveCloudMetadata(userPayload);
    await _saveSessionMetadata(decoded);
    debugPrint('[cloud-auth] cloud token saved true');
    debugPrint('[Auth] tokenSaved=true');
    debugPrint(
      '[cloud-auth] sessionVersion recibido=${decoded['sessionVersion'] ?? 'null'}',
    );
    debugPrint('[Auth] sessionVersion=${decoded['sessionVersion'] ?? 'null'}');
    return CloudBusinessRegistrationResult(
      token: token,
      expiresAt: expiresAt,
      user: user,
      subscriptionStatus: decoded['subscriptionStatus']?.toString() ?? 'active',
      paymentMethodRequired: decoded['paymentMethodRequired'] as bool? ?? false,
      message: decoded['message']?.toString(),
      sessionVersion: _sessionVersionFrom(decoded),
      deviceId: decoded['deviceId']?.toString(),
    );
  }

  Future<CloudLoginResult> linkLocalUserToCloud({
    required String phone,
    required String password,
    required String name,
    required String role,
    String? businessName,
  }) async {
    try {
      final config = await ApiEnvironmentConfig.resolve(sharedPreferences);
      final baseUrl = ApiConfig.normalizeBaseUrl(config.baseUrl);
      debugPrint('[BackendConfig] effectiveBaseUrl=$baseUrl');
      debugPrint(
        '[cloud-auth] cloud login/link attempted action=link-local-user effectiveBaseUrl=${baseUrl.isEmpty ? 'empty' : baseUrl} phone=${phone.trim().isEmpty ? 'empty' : 'present'}',
      );
      if (baseUrl.isEmpty) {
        return const CloudLoginResult.localOnly('Guardado en este dispositivo');
      }
      final devicePayload = await _devicePayload();
      debugPrint('[cloud-auth] deviceId enviado=${devicePayload['deviceId']}');
      debugPrint('[Auth] deviceId=${devicePayload['deviceId']}');
      final endpoint = ApiEnvironmentConfig.apiUriForBaseUrl(
        baseUrl,
        '/auth/link-local-user',
      );
      debugPrint('[Register] remoteEndpoint=$endpoint');

      final response = await httpClient
          .post(
            endpoint,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'phone': phone.trim(),
              'password': password,
              'name': name.trim(),
              'role': role.trim(),
              if (businessName != null && businessName.trim().isNotEmpty)
                'businessName': businessName.trim(),
              ...devicePayload,
            }),
          )
          .timeout(config.timeout);
      debugPrint('[Register] remoteStatus=${response.statusCode}');

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 401 || response.statusCode == 404) {
        return const CloudLoginResult.localOnly('No se pudo actualizar');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const CloudLoginResult.localOnly('No se pudo actualizar');
      }

      return _cloudLoginResultFromResponse(decoded, fallbackPhone: phone);
    } on TimeoutException {
      debugPrint('[Register] remoteError=timeout');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    } on http.ClientException {
      debugPrint('[Register] remoteError=client');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    } catch (error) {
      debugPrint('[Register] remoteError=$error');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    }
  }

  Future<void> saveCloudToken({required String token, DateTime? expiresAt}) {
    return secureTokenStorage.writeCloudToken(
      token: token,
      expiresAt: expiresAt,
    );
  }

  Future<String?> getCloudToken() async {
    if (await isTokenExpired()) {
      await clearCloudToken();
      return null;
    }
    return secureTokenStorage.readCloudToken();
  }

  Future<void> clearCloudToken() async {
    await secureTokenStorage.clearCloudToken();
    final prefs = await sharedPreferences;
    await prefs.remove(cloudUserIdKey);
    await prefs.remove(cloudBusinessIdKey);
    await prefs.remove(cloudRoleKey);
    await prefs.remove(cloudBusinessNameKey);
    await prefs.remove(cloudSessionVersionKey);
    await prefs.remove(cloudDeviceIdKey);
  }

  Future<bool> isCloudAuthenticated() async {
    return await getCloudToken() != null;
  }

  Future<bool> isTokenExpired() async {
    final expiresAt = await secureTokenStorage.readCloudTokenExpiresAt();
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  }

  Future<void> _saveCloudMetadata(Object? user) async {
    if (user is! Map<String, dynamic>) return;
    final prefs = await sharedPreferences;
    await prefs.setString(
      cloudUserIdKey,
      (user['id'] ?? user['userId'])?.toString() ?? '',
    );
    await prefs.setString(
      cloudBusinessIdKey,
      user['businessId']?.toString() ?? '',
    );
    await prefs.setString(cloudRoleKey, user['role']?.toString() ?? '');
    await prefs.setString(
      cloudBusinessNameKey,
      user['businessName']?.toString() ?? '',
    );
  }

  Future<void> _saveSessionMetadata(Map<String, dynamic> decoded) async {
    final prefs = await sharedPreferences;
    final sessionVersion = _sessionVersionFrom(decoded);
    final deviceId = decoded['deviceId']?.toString();
    if (sessionVersion != null) {
      await prefs.setInt(cloudSessionVersionKey, sessionVersion);
    }
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      await prefs.setString(cloudDeviceIdKey, deviceId.trim());
    }
  }

  int? _sessionVersionFrom(Map<String, dynamic> decoded) {
    final raw = decoded['sessionVersion'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<Map<String, String>> _devicePayload() async {
    final deviceId = await SyncDeviceIdentityService(
      sharedPreferences: sharedPreferences,
    ).getOrCreateDeviceId();
    return {
      'deviceId': deviceId,
      'deviceInfo': kIsWeb ? 'web' : defaultTargetPlatform.name,
    };
  }

  Future<CloudLoginResult> _cloudLoginResultFromResponse(
    Map<String, dynamic> decoded, {
    required String fallbackPhone,
  }) async {
    final token = (decoded['token'] ?? decoded['accessToken'])?.toString();
    if (token == null || token.trim().isEmpty) {
      debugPrint('[cloud-auth] cloud token saved false');
      debugPrint('[Auth] tokenSaved=false');
      return const CloudLoginResult.localOnly('Guardado en este dispositivo');
    }

    final userPayload = decoded['user'];
    if (userPayload is! Map<String, dynamic>) {
      debugPrint('[cloud-auth] cloud token saved false');
      debugPrint('[Auth] tokenSaved=false');
      return const CloudLoginResult.localOnly('No se pudo actualizar');
    }

    final expiresAt = DateTime.tryParse(decoded['expiresAt']?.toString() ?? '');
    final cloudUser = CloudAuthenticatedUser.fromJson(
      userPayload,
      fallbackPhone: fallbackPhone,
    );
    await saveCloudToken(token: token, expiresAt: expiresAt);
    await _saveCloudMetadata(userPayload);
    await _saveSessionMetadata(decoded);
    debugPrint('[cloud-auth] cloud token saved true');
    debugPrint('[Auth] tokenSaved=true');
    debugPrint(
      '[cloud-auth] sessionVersion recibido=${decoded['sessionVersion'] ?? 'null'}',
    );
    debugPrint('[Auth] sessionVersion=${decoded['sessionVersion'] ?? 'null'}');
    return CloudLoginResult.success(
      cloudUser,
      token: token,
      expiresAt: expiresAt,
      sessionVersion: _sessionVersionFrom(decoded),
      deviceId: decoded['deviceId']?.toString(),
    );
  }
}
