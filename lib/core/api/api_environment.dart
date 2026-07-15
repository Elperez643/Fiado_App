import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiEnvironment {
  localEmulator,
  localPhysicalDevice,
  localDesktop,
  localWeb,
  production,
}

class ApiEnvironmentConfig {
  static const environmentKey = 'fiado_api_environment';
  static const manualBaseUrlKey = 'fiado_api_base_url';
  static const manualTokenKey = 'fiado_api_test_token';

  final ApiEnvironment environment;
  final String name;
  final String baseUrl;
  final Duration timeout;
  final bool isProduction;
  final bool allowManualOverride;

  const ApiEnvironmentConfig({
    required this.environment,
    required this.name,
    required this.baseUrl,
    required this.timeout,
    required this.isProduction,
    required this.allowManualOverride,
  });

  static const timeoutDefault = Duration(seconds: 20);
  static const compileTimeBaseUrlOverride = String.fromEnvironment(
    'FIADO_API_BASE_URL',
  );
  static const compileTimeApiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const physicalDevicePlaceholder = 'http://TU_IP_LOCAL:5000/api';
  static const productionBaseUrl = 'https://api.fiadoapp.com/api';
  static const defaultLocalPhysicalDeviceBaseUrl = 'http://192.168.18.46:5000';

  static const configs = <ApiEnvironment, ApiEnvironmentConfig>{
    ApiEnvironment.localEmulator: ApiEnvironmentConfig(
      environment: ApiEnvironment.localEmulator,
      name: 'Android emulador',
      baseUrl: 'http://10.0.2.2:5193/api',
      timeout: timeoutDefault,
      isProduction: false,
      allowManualOverride: true,
    ),
    ApiEnvironment.localPhysicalDevice: ApiEnvironmentConfig(
      environment: ApiEnvironment.localPhysicalDevice,
      name: 'Android fisico',
      baseUrl: physicalDevicePlaceholder,
      timeout: timeoutDefault,
      isProduction: false,
      allowManualOverride: true,
    ),
    ApiEnvironment.localDesktop: ApiEnvironmentConfig(
      environment: ApiEnvironment.localDesktop,
      name: 'Desktop local',
      baseUrl: 'http://127.0.0.1:5193/api',
      timeout: timeoutDefault,
      isProduction: false,
      allowManualOverride: true,
    ),
    ApiEnvironment.localWeb: ApiEnvironmentConfig(
      environment: ApiEnvironment.localWeb,
      name: 'Web local',
      baseUrl: 'http://localhost:5193/api',
      timeout: timeoutDefault,
      isProduction: false,
      allowManualOverride: true,
    ),
    ApiEnvironment.production: ApiEnvironmentConfig(
      environment: ApiEnvironment.production,
      name: 'Produccion',
      baseUrl: productionBaseUrl,
      timeout: timeoutDefault,
      isProduction: true,
      allowManualOverride: false,
    ),
  };

  static ApiEnvironmentConfig defaultForPlatform() {
    if (kIsWeb) return configs[ApiEnvironment.localWeb]!;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => configs[ApiEnvironment.localEmulator]!,
      TargetPlatform.iOS => configs[ApiEnvironment.localPhysicalDevice]!,
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => configs[ApiEnvironment.localDesktop]!,
      _ => configs[ApiEnvironment.localEmulator]!,
    };
  }

  static ApiEnvironmentConfig fromEnvironment(ApiEnvironment environment) {
    return configs[environment] ?? defaultForPlatform();
  }

  static ApiEnvironment parseEnvironment(String? value) {
    return ApiEnvironment.values.firstWhere(
      (item) => item.name == value,
      orElse: () => defaultForPlatform().environment,
    );
  }

  static Future<ApiEnvironmentConfig> resolve(
    Future<SharedPreferences> sharedPreferences,
  ) async {
    final prefs = await sharedPreferences;
    final environment = parseEnvironment(prefs.getString(environmentKey));
    final config = fromEnvironment(environment);
    final compileTimeOverride = compileTimeApiBaseUrlOverride.trim().isNotEmpty
        ? compileTimeApiBaseUrlOverride.trim()
        : compileTimeBaseUrlOverride.trim();
    if (compileTimeOverride.isNotEmpty && config.allowManualOverride) {
      return config.copyWith(baseUrl: compileTimeOverride);
    }
    final manualBaseUrl = prefs.getString(manualBaseUrlKey)?.trim();
    if (config.allowManualOverride &&
        manualBaseUrl != null &&
        manualBaseUrl.isNotEmpty) {
      return config.copyWith(baseUrl: normalizeBaseUrl(manualBaseUrl));
    }
    return config;
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static Uri healthUriForBaseUrl(String baseUrl) {
    final normalized = normalizeBaseUrl(baseUrl);
    final withoutApi = normalized.endsWith('/api')
        ? normalized.substring(0, normalized.length - 4)
        : normalized;
    return Uri.parse('$withoutApi/health');
  }

  static Uri apiUriForBaseUrl(String baseUrl, String path) {
    final normalized = normalizeBaseUrl(baseUrl);
    final apiBase = normalized.endsWith('/api')
        ? normalized
        : '$normalized/api';
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final withoutDuplicatedApi = normalizedPath.startsWith('/api/')
        ? normalizedPath.substring(4)
        : normalizedPath;
    return Uri.parse('$apiBase$withoutDuplicatedApi');
  }

  static Future<void> resetCloudRuntimeConfiguration(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(manualTokenKey);
    await prefs.remove(environmentKey);
  }

  ApiEnvironmentConfig copyWith({String? baseUrl, Duration? timeout}) {
    return ApiEnvironmentConfig(
      environment: environment,
      name: name,
      baseUrl: baseUrl ?? this.baseUrl,
      timeout: timeout ?? this.timeout,
      isProduction: isProduction,
      allowManualOverride: allowManualOverride,
    );
  }
}
