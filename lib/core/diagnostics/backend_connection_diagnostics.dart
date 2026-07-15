import 'package:shared_preferences/shared_preferences.dart';

class BackendConnectionDiagnosticsSnapshot {
  final String? lastEndpoint;
  final int? lastStatusCode;
  final String? lastError;
  final String? lastModule;
  final String? lastOperation;
  final String? lastResponseBody;

  const BackendConnectionDiagnosticsSnapshot({
    this.lastEndpoint,
    this.lastStatusCode,
    this.lastError,
    this.lastModule,
    this.lastOperation,
    this.lastResponseBody,
  });
}

class BackendConnectionDiagnostics {
  static const lastEndpointKey = 'fiado_diag_last_endpoint';
  static const lastStatusCodeKey = 'fiado_diag_last_status';
  static const lastErrorKey = 'fiado_diag_last_error';
  static const lastModuleKey = 'fiado_diag_last_module';
  static const lastOperationKey = 'fiado_diag_last_operation';
  static const lastResponseBodyKey = 'fiado_diag_last_response_body';

  const BackendConnectionDiagnostics._();

  static Future<void> recordRequest({
    required Future<SharedPreferences> sharedPreferences,
    required Uri endpoint,
    String? module,
    String? operation,
  }) async {
    final prefs = await sharedPreferences;
    await prefs.setString(lastEndpointKey, endpoint.toString());
    if (module != null) await prefs.setString(lastModuleKey, module);
    if (operation != null) await prefs.setString(lastOperationKey, operation);
    await prefs.remove(lastStatusCodeKey);
    await prefs.remove(lastErrorKey);
    await prefs.remove(lastResponseBodyKey);
  }

  static Future<void> recordResponse({
    required Future<SharedPreferences> sharedPreferences,
    required int statusCode,
    required String body,
  }) async {
    final prefs = await sharedPreferences;
    await prefs.setInt(lastStatusCodeKey, statusCode);
    await prefs.setString(lastResponseBodyKey, _truncate(body));
    if (statusCode >= 200 && statusCode < 300) {
      await prefs.remove(lastErrorKey);
    }
  }

  static Future<void> recordError({
    required Future<SharedPreferences> sharedPreferences,
    required Object error,
    String? module,
    String? operation,
  }) async {
    final prefs = await sharedPreferences;
    await prefs.setString(lastErrorKey, _truncate(error.toString()));
    if (module != null) await prefs.setString(lastModuleKey, module);
    if (operation != null) await prefs.setString(lastOperationKey, operation);
  }

  static Future<BackendConnectionDiagnosticsSnapshot> read(
    Future<SharedPreferences> sharedPreferences,
  ) async {
    final prefs = await sharedPreferences;
    return BackendConnectionDiagnosticsSnapshot(
      lastEndpoint: prefs.getString(lastEndpointKey),
      lastStatusCode: prefs.getInt(lastStatusCodeKey),
      lastError: prefs.getString(lastErrorKey),
      lastModule: prefs.getString(lastModuleKey),
      lastOperation: prefs.getString(lastOperationKey),
      lastResponseBody: prefs.getString(lastResponseBodyKey),
    );
  }

  static String _truncate(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 900) return trimmed;
    return '${trimmed.substring(0, 900)}...';
  }
}
