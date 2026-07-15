import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_environment.dart';

class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _cloudTokenKey = 'fiado_cloud_access_token';
  static const _cloudTokenExpiresAtKey = 'fiado_cloud_access_token_expires_at';

  const SecureTokenStorage();

  Future<String?> readManualBackendToken({
    required Future<SharedPreferences> sharedPreferences,
  }) async {
    final secureToken = await _storage.read(
      key: ApiEnvironmentConfig.manualTokenKey,
    );
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      return secureToken.trim();
    }

    final prefs = await sharedPreferences;
    final legacyToken = prefs.getString(ApiEnvironmentConfig.manualTokenKey);
    if (legacyToken == null || legacyToken.trim().isEmpty) return null;

    await writeManualBackendToken(legacyToken);
    await prefs.remove(ApiEnvironmentConfig.manualTokenKey);
    return legacyToken.trim();
  }

  Future<void> writeManualBackendToken(String token) {
    return _storage.write(
      key: ApiEnvironmentConfig.manualTokenKey,
      value: token.trim(),
    );
  }

  Future<void> clearManualBackendToken({
    required Future<SharedPreferences> sharedPreferences,
  }) async {
    await _storage.delete(key: ApiEnvironmentConfig.manualTokenKey);
    final prefs = await sharedPreferences;
    await prefs.remove(ApiEnvironmentConfig.manualTokenKey);
  }

  Future<void> writeCloudToken({
    required String token,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _cloudTokenKey, value: token.trim());
    if (expiresAt != null) {
      await _storage.write(
        key: _cloudTokenExpiresAtKey,
        value: expiresAt.toIso8601String(),
      );
    }
  }

  Future<String?> readCloudToken() async {
    final token = await _storage.read(key: _cloudTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<DateTime?> readCloudTokenExpiresAt() async {
    final value = await _storage.read(key: _cloudTokenExpiresAtKey);
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clearCloudToken() async {
    await _storage.delete(key: _cloudTokenKey);
    await _storage.delete(key: _cloudTokenExpiresAtKey);
  }
}
