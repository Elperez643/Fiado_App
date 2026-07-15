import 'api_environment.dart';

class ApiConfig {
  static const String defaultEmulatorBaseUrl = 'http://10.0.2.2:5193/api';
  static const String fiadoBaseUrlOverride = String.fromEnvironment(
    'FIADO_API_BASE_URL',
  );
  static const String apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String baseUrlOverride = apiBaseUrlOverride != ''
      ? apiBaseUrlOverride
      : fiadoBaseUrlOverride != ''
      ? fiadoBaseUrlOverride
      : defaultEmulatorBaseUrl;
  static const String testTokenOverride = String.fromEnvironment(
    'FIADO_API_TEST_TOKEN',
  );
  static const Duration timeout = ApiEnvironmentConfig.timeoutDefault;

  static String normalizeBaseUrl(String value) {
    return ApiEnvironmentConfig.normalizeBaseUrl(value);
  }
}
