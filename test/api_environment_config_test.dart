import 'package:fiado_app/core/api/api_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('normalizeBaseUrl elimina slash final', () {
    expect(
      ApiEnvironmentConfig.normalizeBaseUrl('http://192.168.18.46:5000/'),
      'http://192.168.18.46:5000',
    );
    expect(
      ApiEnvironmentConfig.normalizeBaseUrl(' http://192.168.18.46:5000// '),
      'http://192.168.18.46:5000',
    );
  });

  test('healthUriForBaseUrl usa baseUrl/health', () {
    expect(
      ApiEnvironmentConfig.healthUriForBaseUrl(
        'http://192.168.18.46:5000/',
      ).toString(),
      'http://192.168.18.46:5000/health',
    );
  });

  test('healthUriForBaseUrl soporta baseUrl legacy con /api', () {
    expect(
      ApiEnvironmentConfig.healthUriForBaseUrl(
        'http://192.168.18.46:5000/api',
      ).toString(),
      'http://192.168.18.46:5000/health',
    );
  });

  test('apiUriForBaseUrl agrega /api sin duplicarlo', () {
    expect(
      ApiEnvironmentConfig.apiUriForBaseUrl(
        'http://192.168.18.46:5000',
        '/auth/login',
      ).toString(),
      'http://192.168.18.46:5000/api/auth/login',
    );
    expect(
      ApiEnvironmentConfig.apiUriForBaseUrl(
        'http://192.168.18.46:5000/api',
        '/api/auth/login',
      ).toString(),
      'http://192.168.18.46:5000/api/auth/login',
    );
  });

  test('manualBaseUrl se guarda y effectiveBaseUrl prioriza manual', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiEnvironmentConfig.environmentKey,
      ApiEnvironment.localPhysicalDevice.name,
    );
    await prefs.setString(
      ApiEnvironmentConfig.manualBaseUrlKey,
      'http://192.168.18.46:5000/',
    );

    final config = await ApiEnvironmentConfig.resolve(
      SharedPreferences.getInstance(),
    );

    expect(config.baseUrl, 'http://192.168.18.46:5000');
  });

  test('restaurar default elimina manualBaseUrl correctamente', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiEnvironmentConfig.manualBaseUrlKey,
      'http://192.168.18.46:5000',
    );

    await prefs.remove(ApiEnvironmentConfig.manualBaseUrlKey);

    expect(prefs.getString(ApiEnvironmentConfig.manualBaseUrlKey), isNull);
  });

  test('resetCloudRuntimeConfiguration no borra manualBaseUrl', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiEnvironmentConfig.manualBaseUrlKey,
      'http://192.168.18.46:5000',
    );
    await prefs.setString(ApiEnvironmentConfig.manualTokenKey, 'token');
    await prefs.setString(
      ApiEnvironmentConfig.environmentKey,
      ApiEnvironment.localPhysicalDevice.name,
    );

    await ApiEnvironmentConfig.resetCloudRuntimeConfiguration(prefs);

    expect(
      prefs.getString(ApiEnvironmentConfig.manualBaseUrlKey),
      'http://192.168.18.46:5000',
    );
    expect(prefs.getString(ApiEnvironmentConfig.manualTokenKey), isNull);
    expect(prefs.getString(ApiEnvironmentConfig.environmentKey), isNull);
  });

  test('servicio de config expone URL efectiva', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiEnvironmentConfig.manualBaseUrlKey,
      'http://192.168.18.46:5000',
    );

    final effective = await ApiEnvironmentConfig.resolve(
      SharedPreferences.getInstance(),
    );

    expect(effective.baseUrl, 'http://192.168.18.46:5000');
  });
}
