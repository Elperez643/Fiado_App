import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/api/api_environment.dart';
import '../core/database/database_schema.dart';
import '../core/security/secure_token_storage.dart';
import '../presentation/providers/sync_providers.dart';

class BackendSettingsScreen extends ConsumerStatefulWidget {
  const BackendSettingsScreen({super.key});

  @override
  ConsumerState<BackendSettingsScreen> createState() =>
      _BackendSettingsScreenState();
}

class _BackendSettingsScreenState extends ConsumerState<BackendSettingsScreen> {
  final _secureTokenStorage = const SecureTokenStorage();
  late ApiEnvironment _environment;
  final _baseUrlController = TextEditingController();
  bool _loading = true;
  bool _testing = false;
  bool _detecting = false;
  String? _statusMessage;
  String? _tokenPreview;
  String? _manualBaseUrl;
  String? _effectiveBaseUrl;
  String? _lastHealthCheckUrl;
  String? _lastHealthStatus;
  String? _lastHealthResult;
  String? _lastHealthError;
  String? _lastHealthAttemptAt;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await ref.read(sharedPreferencesProvider);
    final environment = ApiEnvironmentConfig.parseEnvironment(
      prefs.getString(ApiEnvironmentConfig.environmentKey),
    );
    final config = ApiEnvironmentConfig.fromEnvironment(environment);
    final manualBaseUrl = prefs.getString(
      ApiEnvironmentConfig.manualBaseUrlKey,
    );
    final effectiveConfig = await ApiEnvironmentConfig.resolve(
      ref.read(sharedPreferencesProvider),
    );
    final manualToken = await _secureTokenStorage.readManualBackendToken(
      sharedPreferences: ref.read(sharedPreferencesProvider),
    );
    final cloudToken = await _secureTokenStorage.readCloudToken();
    final sessionToken = await ref
        .read(authRepositoryForSyncProvider)
        .obtenerJwtTokenActual();

    if (!mounted) return;
    setState(() {
      _environment = environment;
      _baseUrlController.text = manualBaseUrl?.trim().isNotEmpty == true
          ? ApiEnvironmentConfig.normalizeBaseUrl(manualBaseUrl!)
          : config.baseUrl;
      _manualBaseUrl = manualBaseUrl?.trim().isNotEmpty == true
          ? ApiEnvironmentConfig.normalizeBaseUrl(manualBaseUrl!)
          : null;
      _effectiveBaseUrl = effectiveConfig.baseUrl;
      _lastHealthCheckUrl = prefs.getString(_lastHealthCheckUrlKey);
      _lastHealthStatus = prefs.getString(_lastHealthStatusKey);
      _lastHealthResult = prefs.getString(_lastHealthResultKey);
      _lastHealthError = prefs.getString(_lastHealthErrorKey);
      _lastHealthAttemptAt = prefs.getString(_lastHealthAttemptAtKey);
      _tokenPreview = _previewToken(cloudToken ?? manualToken ?? sessionToken);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config = ApiEnvironmentConfig.fromEnvironment(_environment);
    final defaultBaseUrl = config.baseUrl;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion de servidor')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<ApiEnvironment>(
            initialValue: _environment,
            decoration: const InputDecoration(
              labelText: 'Entorno',
              prefixIcon: Icon(Icons.public_outlined),
            ),
            items: ApiEnvironment.values
                .map(
                  (environment) => DropdownMenuItem(
                    value: environment,
                    child: Text(
                      ApiEnvironmentConfig.fromEnvironment(environment).name,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final next = ApiEnvironmentConfig.fromEnvironment(value);
              setState(() {
                _environment = value;
                _baseUrlController.text = next.baseUrl;
                _statusMessage = null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            enabled: config.allowManualOverride,
            decoration: InputDecoration(
              labelText: 'Base URL',
              hintText: config.baseUrl,
              prefixIcon: const Icon(Icons.link_outlined),
              helperText: config.allowManualOverride
                  ? 'Ejemplo: http://192.168.18.46:5000'
                  : 'Produccion no permite override manual.',
            ),
          ),
          const SizedBox(height: 16),
          _InfoTile(
            icon: Icons.badge_outlined,
            label: 'Entorno actual',
            value: config.name,
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.timer_outlined,
            label: 'Base URL efectiva',
            value: _effectiveBaseUrl ?? defaultBaseUrl,
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.edit_location_alt_outlined,
            label: 'URL manual guardada',
            value: _manualBaseUrl ?? 'Sin URL manual',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.home_repair_service_outlined,
            label: 'URL por defecto',
            value: defaultBaseUrl,
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.health_and_safety_outlined,
            label: 'Ultimo health check',
            value: _lastHealthCheckUrl ?? 'Sin intentos',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.fact_check_outlined,
            label: 'Ultimo resultado',
            value: _lastHealthResult ?? _lastHealthStatus ?? 'Sin resultado',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.error_outline,
            label: 'Ultimo error',
            value: _lastHealthError ?? 'Sin error',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.schedule_outlined,
            label: 'Ultimo intento',
            value: _lastHealthAttemptAt ?? 'Sin intentos',
          ),
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.key_outlined,
            label: 'Token',
            value: _tokenPreview ?? 'Sin token configurado',
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: TextStyle(
                color: _statusMessage == 'Conexion exitosa'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar configuracion'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _detecting ? null : _detectLocalServer,
            icon: _detecting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_outlined),
            label: const Text('Detectar servidor local'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering_outlined),
            label: const Text('Probar conexion'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _restoreDefault,
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restaurar URL por defecto'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _clearToken,
            icon: const Icon(Icons.key_off_outlined),
            label: const Text('Limpiar token'),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetLocalTestData,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Restablecer datos locales de prueba'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final baseUrl = ApiEnvironmentConfig.normalizeBaseUrl(
      _baseUrlController.text,
    );
    final config = ApiEnvironmentConfig.fromEnvironment(_environment);
    if (baseUrl.isEmpty) {
      setState(() => _statusMessage = 'La baseUrl no puede estar vacia.');
      return;
    }

    final prefs = await ref.read(sharedPreferencesProvider);
    await prefs.setString(
      ApiEnvironmentConfig.environmentKey,
      _environment.name,
    );
    if (config.allowManualOverride && baseUrl != config.baseUrl) {
      await prefs.setString(ApiEnvironmentConfig.manualBaseUrlKey, baseUrl);
      debugPrint('[BackendConfig] savedManualBaseUrl=$baseUrl');
    } else {
      await prefs.remove(ApiEnvironmentConfig.manualBaseUrlKey);
    }

    final effective = await ApiEnvironmentConfig.resolve(
      ref.read(sharedPreferencesProvider),
    );

    if (!mounted) return;
    setState(() {
      _baseUrlController.text = baseUrl;
      _manualBaseUrl = prefs.getString(ApiEnvironmentConfig.manualBaseUrlKey);
      _effectiveBaseUrl = effective.baseUrl;
      _statusMessage = 'Configuracion guardada';
    });
  }

  Future<void> _restoreDefault() async {
    final prefs = await ref.read(sharedPreferencesProvider);
    await prefs.remove(ApiEnvironmentConfig.manualBaseUrlKey);
    final effective = await ApiEnvironmentConfig.resolve(
      ref.read(sharedPreferencesProvider),
    );
    debugPrint(
      '[BackendConfig] clearedManualBaseUrl, effectiveBaseUrl=${effective.baseUrl}',
    );
    if (!mounted) return;
    setState(() {
      _manualBaseUrl = null;
      _effectiveBaseUrl = effective.baseUrl;
      _baseUrlController.text = effective.baseUrl;
      _statusMessage = 'URL por defecto restaurada';
    });
  }

  Future<void> _testConnection() async {
    final baseUrl = ApiEnvironmentConfig.normalizeBaseUrl(
      _baseUrlController.text,
    );
    if (baseUrl.isEmpty) {
      setState(() => _statusMessage = 'La baseUrl no puede estar vacia.');
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = null;
    });

    try {
      final result = await _runHealthCheck(baseUrl);
      if (!mounted) return;
      if (result.ok) {
        setState(() => _statusMessage = 'Conexion exitosa');
      } else {
        setState(
          () => _statusMessage =
              'El backend respondio HTTP ${result.statusCode ?? 'sin estado'}.',
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () => _statusMessage = 'Tiempo de espera agotado probando /health.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'No se pudo conectar a /health: $error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _detectLocalServer() async {
    setState(() {
      _detecting = true;
      _statusMessage = null;
    });
    try {
      final candidates =
          <String?>{
                ApiEnvironmentConfig.normalizeBaseUrl(_baseUrlController.text),
                _manualBaseUrl,
                _effectiveBaseUrl,
                if (!kReleaseMode)
                  ApiEnvironmentConfig.defaultLocalPhysicalDeviceBaseUrl,
              }
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toList(growable: false);

      for (final candidate in candidates) {
        try {
          final result = await _runHealthCheck(candidate);
          if (!mounted) return;
          if (result.ok) {
            setState(() {
              _baseUrlController.text = ApiEnvironmentConfig.normalizeBaseUrl(
                candidate,
              );
              _statusMessage =
                  'Servidor detectado. Revisa la URL y toca Guardar configuracion.';
            });
            return;
          }
        } catch (_) {
          // _runHealthCheck records the visible diagnostic details.
        }
      }

      if (!mounted) return;
      setState(() {
        _statusMessage =
            'No se detecto un servidor local. Verifica IP, puerto y Wi-Fi.';
      });
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<_HealthCheckResult> _runHealthCheck(String baseUrl) async {
    final normalized = ApiEnvironmentConfig.normalizeBaseUrl(baseUrl);
    final config = ApiEnvironmentConfig.fromEnvironment(_environment);
    final uri = ApiEnvironmentConfig.healthUriForBaseUrl(normalized);
    debugPrint('[HealthCheck] url=$uri');
    try {
      final response = await http.get(uri).timeout(config.timeout);
      debugPrint('[HealthCheck] status=${response.statusCode}');
      final result = _HealthCheckResult(
        url: uri.toString(),
        statusCode: response.statusCode,
        ok: response.statusCode >= 200 && response.statusCode < 300,
        message: response.body.trim().isEmpty
            ? 'HTTP ${response.statusCode}'
            : 'HTTP ${response.statusCode}: ${response.body.trim()}',
      );
      await _rememberHealthResult(result);
      return result;
    } catch (error) {
      debugPrint('[HealthCheck] error=$error');
      final result = _HealthCheckResult(
        url: uri.toString(),
        ok: false,
        error: '$error',
      );
      await _rememberHealthResult(result);
      rethrow;
    }
  }

  Future<void> _rememberHealthResult(_HealthCheckResult result) async {
    final prefs = await ref.read(sharedPreferencesProvider);
    final attemptedAt = DateTime.now().toLocal().toIso8601String();
    await prefs.setString(_lastHealthCheckUrlKey, result.url);
    await prefs.setString(
      _lastHealthStatusKey,
      result.statusCode?.toString() ?? 'sin estado',
    );
    await prefs.setString(
      _lastHealthResultKey,
      result.message ?? (result.ok ? 'Conexion exitosa' : 'Sin respuesta'),
    );
    if (result.error == null) {
      await prefs.remove(_lastHealthErrorKey);
    } else {
      await prefs.setString(_lastHealthErrorKey, result.error!);
    }
    await prefs.setString(_lastHealthAttemptAtKey, attemptedAt);
    if (!mounted) return;
    setState(() {
      _lastHealthCheckUrl = result.url;
      _lastHealthStatus = result.statusCode?.toString() ?? 'sin estado';
      _lastHealthResult =
          result.message ?? (result.ok ? 'Conexion exitosa' : 'Sin respuesta');
      _lastHealthError = result.error;
      _lastHealthAttemptAt = attemptedAt;
    });
  }

  Future<void> _clearToken() async {
    await _secureTokenStorage.clearCloudToken();
    await _secureTokenStorage.clearManualBackendToken(
      sharedPreferences: ref.read(sharedPreferencesProvider),
    );
    final db = await ref
        .read(authRepositoryForSyncProvider)
        .databaseHelper
        .database;
    await db.update(
      DatabaseSchema.sesionesTable,
      {'jwt_token': null},
      where: 'is_active = ?',
      whereArgs: [1],
    );
    if (!mounted) return;
    setState(() {
      _tokenPreview = null;
      _statusMessage = 'Token limpiado';
    });
  }

  Future<void> _resetLocalTestData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer datos locales'),
        content: const Text(
          'Esto elimina usuarios, sesiones, inventario, clientes, fiados, comprobantes y cola de sync locales. No cambia la estructura de la base de datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final db = await ref
        .read(authRepositoryForSyncProvider)
        .databaseHelper
        .database;
    for (final table in _localResetTables) {
      final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        [table],
      );
      if (exists.isNotEmpty) await db.delete(table);
    }
    if (!mounted) return;
    setState(() {
      _tokenPreview = null;
      _statusMessage = 'Datos locales de prueba restablecidos';
    });
  }

  String? _previewToken(String? token) {
    final value = token?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.length <= 12) return '${value.substring(0, 4)}...';
    return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
  }
}

const _localResetTables = [
  'credito_ciclo_movimientos',
  'credito_recordatorios',
  'credito_excepciones',
  'client_scores',
  'business_recommendations_cache',
  'inventory_product_metrics',
  'comprobantes',
  'deuda_items',
  'movimientos',
  'credito_ciclos',
  'auditoria_items',
  'auditorias',
  'solicitudes_autorizacion',
  'producto_imagenes',
  'productos',
  'clientes',
  'subscriptions',
  'user_onboarding',
  'sesiones',
  'sync_queue',
  'usuarios',
];

const _lastHealthCheckUrlKey = 'fiado_backend_last_health_url';
const _lastHealthStatusKey = 'fiado_backend_last_health_status';
const _lastHealthResultKey = 'fiado_backend_last_health_result';
const _lastHealthErrorKey = 'fiado_backend_last_health_error';
const _lastHealthAttemptAtKey = 'fiado_backend_last_health_attempt_at';

class _HealthCheckResult {
  final String url;
  final int? statusCode;
  final bool ok;
  final String? message;
  final String? error;

  const _HealthCheckResult({
    required this.url,
    required this.ok,
    this.statusCode,
    this.message,
    this.error,
  });
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}
