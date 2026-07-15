import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_environment.dart';
import '../core/config/developer_tools.dart';
import '../core/database/database_helper.dart';
import '../core/database/database_schema.dart';
import '../core/diagnostics/backend_connection_diagnostics.dart';
import '../core/security/secure_token_storage.dart';
import '../data/models/sync_user_status.dart';
import '../data/models/usuario_sqlite_model.dart';
import '../data/services/auto_sync_service.dart';
import '../data/services/cloud_auth_service.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/sync_providers.dart';
import 'backend_settings_screen.dart';
import 'sync_advanced_settings_screen.dart';

class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _onlineSubscription;
  GlobalSyncResult? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(syncUserStatusProvider.notifier).refresh();
      ref.read(syncUserStatusProvider.notifier).scheduleAutoSync();
      _onlineSubscription = ref
          .read(autoSyncServiceProvider)
          .onlineChanges()
          .listen((online) {
            if (!mounted || !online) return;
            ref.read(syncUserStatusProvider.notifier).scheduleAutoSync();
          });
    });
  }

  @override
  void dispose() {
    _onlineSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncUserStatusProvider.notifier).scheduleAutoSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(syncUserStatusProvider);
    final progress = ref.read(syncUserStatusProvider.notifier).currentProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de datos'),
        actions: [
          if (showDeveloperTools)
            IconButton(
              tooltip: 'Herramientas de desarrollo',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SyncAdvancedSettingsScreen(),
                ),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _SimpleSyncError(onRetry: _refresh),
        data: (status) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SyncHero(status: status, progress: progress),
              if (showDeveloperTools) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: status.isSyncing ? null : _manualSync,
                  icon: status.isSyncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Actualizar datos'),
                ),
              ],
              const SizedBox(height: 16),
              _InfoTile(
                icon: Icons.schedule_outlined,
                label: 'Ultima actualizacion',
                value: _formatDate(status.lastSyncAt),
              ),
              _InfoTile(
                icon: Icons.pending_actions_outlined,
                label: 'Cambios guardados pendientes',
                value: '${status.pendingCount}',
              ),
              _InfoTile(
                icon: status.isOnline
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                label: 'Estado',
                value: status.shortMessage,
              ),
              if (status.lastErrorMessage != null && showDeveloperTools) ...[
                const SizedBox(height: 14),
                _FriendlyMessage(message: status.lastErrorMessage!),
              ],
              if (status.pendingCount > 0 ||
                  status.lastErrorMessage != null ||
                  !status.isOnline) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BackendSettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.dns_outlined),
                    label: const Text('Configurar servidor'),
                  ),
                ),
              ],
              if (_lastResult != null && showDeveloperTools) ...[
                const SizedBox(height: 18),
                _SyncResultSummary(result: _lastResult!),
              ],
              if (showDeveloperTools) ...[
                const SizedBox(height: 18),
                const _LocalQueueDiagnostics(),
                const SizedBox(height: 18),
                const _BackendDebugDiagnostics(),
              ],
              const SizedBox(height: 24),
              Text(
                'Fiado App guarda tus datos primero en este dispositivo y los actualiza automaticamente cuando haya conexion.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF66756D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(syncUserStatusProvider.notifier).refresh();
  }

  Future<void> _manualSync() async {
    final currentStatus = ref.read(syncUserStatusProvider).valueOrNull;
    if (currentStatus != null && !currentStatus.isCloudAuthenticated) {
      final password = await _askPasswordForCloudLink();
      if (!mounted) return;
      if (password == null) return;

      final reconnectResult = await _connectCloudAccount(password);
      if (!mounted) return;
      if (!reconnectResult.connected) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(reconnectResult.message)));
        return;
      }
      await ref.read(syncUserStatusProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cuenta actualizada.')));
    }

    final result = await ref
        .read(syncUserStatusProvider.notifier)
        .runManualSync();
    if (!mounted) return;
    setState(() => _lastResult = result);
    final status = ref.read(syncUserStatusProvider).valueOrNull;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? status?.lastErrorMessage ??
                    'No pudimos sincronizar ahora. Revisa tu conexion e intentalo de nuevo.'
              : result.pendingAfter == 0
              ? 'Sincronizacion completada.'
              : 'Quedan ${result.pendingAfter} elementos pendientes. Se intentara nuevamente cuando tengas internet.',
        ),
      ),
    );
  }

  Future<_CloudReconnectResult> _connectCloudAccount(String password) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return _CloudReconnectResult.failed(_invalidCloudMessage);
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      return _CloudReconnectResult.failed(_invalidCloudMessage);
    }
    if (user.tipoUsuario == UsuarioSqliteModel.tipoColaborador) {
      return _CloudReconnectResult.failed(
        'Esta cuenta no se puede actualizar desde aqui por ahora.',
      );
    }

    try {
      var result = await ref
          .read(cloudAuthServiceProvider)
          .loginCloud(phone: user.telefono, password: trimmedPassword)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return _CloudReconnectResult.failed(_invalidCloudMessage);
      if (!result.success || result.user == null) {
        debugPrint(
          '[sync-cloud] cuenta local sin enlace cloud, intentando recovery staging',
        );
        result = await ref
            .read(cloudAuthServiceProvider)
            .linkLocalUserToCloud(
              phone: user.telefono,
              password: trimmedPassword,
              name: user.nombre,
              role: user.tipoUsuario,
              businessName: _businessNameForCloud(user),
            )
            .timeout(const Duration(seconds: 20));
      }
      if (!mounted) return _CloudReconnectResult.failed(_invalidCloudMessage);
      if (!result.success || result.user == null) {
        return _CloudReconnectResult.failed(
          result.userMessage ?? _invalidCloudMessage,
        );
      }

      final linkedUser = await ref
          .read(authRepositoryProvider)
          .vincularUsuarioCloudPorTelefono(
            telefono: user.telefono,
            cloudUser: result.user!,
            jwtToken: result.token,
          );
      if (!mounted) return _CloudReconnectResult.failed(_invalidCloudMessage);
      if (linkedUser != null) {
        ref.read(authStateProvider.notifier).setLocalUser(linkedUser);
      }
      await ref.read(syncUserStatusProvider.notifier).refresh();
      return const _CloudReconnectResult.connected();
    } catch (error) {
      debugPrint('[sync-cloud] reautenticacion omitida: $error');
      return _CloudReconnectResult.failed('Guardado en este dispositivo');
    }
  }

  String? _businessNameForCloud(UsuarioSqliteModel user) {
    if (user.tipoUsuario != UsuarioSqliteModel.tipoNegocio) return null;
    final separator = user.nombre.indexOf(' - ');
    if (separator <= 0) return user.nombre;
    return user.nombre.substring(0, separator).trim();
  }

  Future<String?> _askPasswordForCloudLink() {
    return showDialog<String>(
      context: context,
      builder: (_) => const CloudReconnectDialog(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin registros';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _CloudReconnectResult {
  final bool connected;
  final String message;

  const _CloudReconnectResult.connected()
    : connected = true,
      message = 'Cuenta actualizada.';

  const _CloudReconnectResult.failed(this.message) : connected = false;
}

const _invalidCloudMessage =
    'No se pudo actualizar. Verifica la contrasena o intenta nuevamente.';

class CloudReconnectDialog extends StatefulWidget {
  const CloudReconnectDialog({super.key});

  @override
  State<CloudReconnectDialog> createState() => _CloudReconnectDialogState();
}

class _CloudReconnectDialogState extends State<CloudReconnectDialog> {
  late final TextEditingController _passwordController;
  late final FocusNode _passwordFocusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorText = 'Ingresa tu contraseña para conectar la cuenta.';
      });
      _passwordFocusNode.requestFocus();
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Actualizar cuenta'),
      content: TextField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Contraseña',
          helperText:
              'Se usara solo ahora para validar esta cuenta con el servidor.',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText == null) return;
          setState(() => _errorText = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Conectar')),
      ],
    );
  }
}

class _SyncHero extends StatelessWidget {
  final SyncUserStatus status;
  final String? progress;

  const _SyncHero({required this.status, this.progress});

  @override
  Widget build(BuildContext context) {
    final color = status.isSyncing
        ? Colors.blue
        : !status.isOnline
        ? Colors.grey
        : status.pendingCount > 0
        ? Colors.amber.shade700
        : Colors.green;
    final icon = status.isSyncing
        ? Icons.sync_rounded
        : !status.isOnline
        ? Icons.save_outlined
        : status.pendingCount > 0
        ? Icons.pending_actions_outlined
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.userFriendlyStatus,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  progress ?? status.friendlySubtitle,
                  style: const TextStyle(color: Color(0xFF66756D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FriendlyMessage extends StatelessWidget {
  final String message;

  const _FriendlyMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message),
    );
  }
}

class _SyncResultSummary extends StatelessWidget {
  final GlobalSyncResult result;

  const _SyncResultSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.hasErrors
                ? 'Sincronizacion parcial'
                : 'Sincronizacion completada',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final step in result.steps)
            Text(
              step.succeeded
                  ? '${step.label}: listo'
                  : '${step.label}: se intentara nuevamente',
            ),
          const SizedBox(height: 8),
          Text('Pendientes: ${result.pendingAfter}'),
        ],
      ),
    );
  }
}

class _BackendDebugDiagnostics extends ConsumerWidget {
  const _BackendDebugDiagnostics();

  Future<_BackendDebugDiagnosticsData> _load(WidgetRef ref) async {
    final prefsFuture = ref.read(sharedPreferencesProvider);
    final prefs = await prefsFuture;
    final token = await const SecureTokenStorage().readCloudToken();
    final apiTokenPresent = await ref.read(apiClientProvider).hasUsableToken();
    final user = await ref.read(authRepositoryProvider).obtenerUsuarioActual();
    final businessId = switch (user?.tipoUsuario) {
      UsuarioSqliteModel.tipoNegocio => user?.id?.toString(),
      UsuarioSqliteModel.tipoColaborador => user?.negocioId?.toString(),
      _ => null,
    };
    final deviceId = await ref
        .read(syncDeviceIdentityServiceProvider)
        .getOrCreateDeviceId();
    final config = await ApiEnvironmentConfig.resolve(prefsFuture);
    final diagnostic = await BackendConnectionDiagnostics.read(prefsFuture);
    final pending = await ref.read(syncOutboxRepositoryProvider).pendingCount();
    return _BackendDebugDiagnosticsData(
      authConnected: token != null,
      tokenSaved: token != null,
      apiTokenPresent: apiTokenPresent,
      userId: user?.id?.toString(),
      businessId: businessId,
      cloudBusinessId: prefs.getString(CloudAuthService.cloudBusinessIdKey),
      role: user?.tipoUsuario,
      deviceId: deviceId,
      storedDeviceId: prefs.getString(CloudAuthService.cloudDeviceIdKey),
      sessionVersion: prefs
          .getInt(CloudAuthService.cloudSessionVersionKey)
          ?.toString(),
      effectiveBaseUrl: config.baseUrl,
      lastEndpoint: diagnostic.lastEndpoint,
      lastStatus: diagnostic.lastStatusCode?.toString(),
      lastError: diagnostic.lastError,
      lastModule: diagnostic.lastModule,
      lastOperation: diagnostic.lastOperation,
      pendingOutboxCount: pending,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_BackendDebugDiagnosticsData>(
      future: _load(ref),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD7DEE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diagnostico backend',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                Text('No se pudo cargar diagnostico: ${snapshot.error}')
              else ...[
                _DiagnosticLine(
                  text:
                      'Auth: ${data!.authConnected ? 'conectado' : 'no conectado'}',
                ),
                _DiagnosticLine(
                  text: 'Token guardado: ${data.tokenSaved ? 'si' : 'no'}',
                ),
                _DiagnosticLine(
                  text:
                      'Token usable por API: ${data.apiTokenPresent ? 'si' : 'no'}',
                ),
                _DiagnosticLine(text: 'UserId: ${data.userId ?? 'null'}'),
                _DiagnosticLine(
                  text: 'BusinessId: ${data.businessId ?? 'null'}',
                ),
                _DiagnosticLine(
                  text: 'CloudBusinessId: ${data.cloudBusinessId ?? 'null'}',
                ),
                _DiagnosticLine(text: 'Role: ${data.role ?? 'null'}'),
                _DiagnosticLine(text: 'DeviceId: ${data.deviceId}'),
                _DiagnosticLine(
                  text: 'StoredDeviceId: ${data.storedDeviceId ?? 'null'}',
                ),
                _DiagnosticLine(
                  text: 'SessionVersion: ${data.sessionVersion ?? 'null'}',
                ),
                _DiagnosticLine(
                  text: 'BaseUrl efectiva: ${data.effectiveBaseUrl}',
                ),
                _DiagnosticLine(
                  text: 'Ultimo endpoint: ${data.lastEndpoint ?? 'null'}',
                ),
                _DiagnosticLine(
                  text: 'Ultimo status HTTP: ${data.lastStatus ?? 'null'}',
                ),
                _DiagnosticLine(
                  text: 'Ultimo modulo sync: ${data.lastModule ?? 'null'}',
                ),
                _DiagnosticLine(
                  text:
                      'Ultima operacion sync: ${data.lastOperation ?? 'null'}',
                ),
                _DiagnosticLine(
                  text: 'Pending outbox count: ${data.pendingOutboxCount}',
                ),
                if (data.lastError != null)
                  _DiagnosticLine(
                    text: 'Ultimo error backend: ${data.lastError}',
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LocalQueueDiagnostics extends StatelessWidget {
  const _LocalQueueDiagnostics();

  Future<_LocalQueueDiagnosticsData> _load() async {
    final db = await DatabaseHelper.instance.database;
    final queue = await db.query(
      DatabaseSchema.syncQueueTable,
      columns: [
        'id',
        'entity_type',
        'entity_id',
        'operation',
        'status',
        'attempts',
        'last_error',
        'updated_at',
      ],
      orderBy: 'updated_at DESC',
      limit: 20,
    );
    final clients = await db.query(
      DatabaseSchema.clientesTable,
      columns: [
        'id',
        'nombre',
        'telefono',
        'sync_status',
        'remote_id',
        'last_synced_at',
      ],
      orderBy: 'id DESC',
      limit: 10,
    );
    final localCounts = <String, int>{};
    for (final table in _parityTables) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
      localCounts[table] = (rows.first['count'] as num? ?? 0).toInt();
    }
    final pendingByType = await db.rawQuery('''
SELECT entity_type, status, COUNT(*) AS count
FROM ${DatabaseSchema.syncQueueTable}
WHERE status IN ('pending', 'retry', 'failed')
GROUP BY entity_type, status
ORDER BY entity_type, status
''');
    final prefs = await _sharedPreferences();
    return _LocalQueueDiagnosticsData(
      queue: queue,
      clients: clients,
      localCounts: localCounts,
      pendingByType: pendingByType,
      lastSyncAt: prefs.getString('fiado_user_last_cloud_sync_at'),
      lastSyncSucceeded:
          prefs.getBool('fiado_user_last_cloud_sync_succeeded') == true,
    );
  }

  Future<SharedPreferences> _sharedPreferences() {
    return SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LocalQueueDiagnosticsData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD7DEE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estado de cola local',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                Text('No se pudo cargar diagnostico: ${snapshot.error}')
              else ...[
                const Text(
                  'Paridad multi-dispositivo',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                _DiagnosticLine(
                  text:
                      'ultima_sync=${data!.lastSyncAt ?? 'null'} success=${data.lastSyncSucceeded}',
                ),
                for (final entry in data.localCounts.entries)
                  _DiagnosticLine(text: '${entry.key}: local=${entry.value}'),
                const SizedBox(height: 10),
                const Text(
                  'pendientes/fallidos por entidad',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (data.pendingByType.isEmpty)
                  const Text('Sin pendientes ni fallidos.')
                else
                  for (final item in data.pendingByType)
                    _DiagnosticLine(
                      text:
                          '${item['entity_type']} ${item['status']} count=${item['count']}',
                    ),
                const SizedBox(height: 12),
                const Text(
                  'sync_queue ultimos 20',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (data.queue.isEmpty)
                  const Text('Sin items en cola.')
                else
                  for (final item in data.queue)
                    _DiagnosticLine(
                      text:
                          '#${item['id']} ${item['entity_type']}(${item['entity_id']}) '
                          '${item['operation']} ${item['status']} '
                          'attempts=${item['attempts']} updated=${item['updated_at']}'
                          '${item['last_error'] == null ? '' : '\nerror=${item['last_error']}'}',
                    ),
                const SizedBox(height: 12),
                const Text(
                  'clientes ultimos 10',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (data.clients.isEmpty)
                  const Text('Sin clientes.')
                else
                  for (final client in data.clients)
                    _DiagnosticLine(
                      text:
                          '#${client['id']} ${client['nombre']} tel=${client['telefono']} '
                          'sync=${client['sync_status']} remote=${client['remote_id'] ?? 'null'} '
                          'last=${client['last_synced_at'] ?? 'null'}',
                    ),
              ],
            ],
          ),
        );
      },
    );
  }
}

const _parityTables = [
  DatabaseSchema.clientesTable,
  DatabaseSchema.productosTable,
  DatabaseSchema.movimientosTable,
  DatabaseSchema.deudaItemsTable,
  DatabaseSchema.comprobantesTable,
  DatabaseSchema.creditoCiclosTable,
  DatabaseSchema.auditoriasTable,
  DatabaseSchema.solicitudesAutorizacionTable,
  DatabaseSchema.whatsappCampaignPublicationsTable,
];

class _DiagnosticLine extends StatelessWidget {
  final String text;

  const _DiagnosticLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

class _LocalQueueDiagnosticsData {
  final List<Map<String, Object?>> queue;
  final List<Map<String, Object?>> clients;
  final Map<String, int> localCounts;
  final List<Map<String, Object?>> pendingByType;
  final String? lastSyncAt;
  final bool lastSyncSucceeded;

  const _LocalQueueDiagnosticsData({
    required this.queue,
    required this.clients,
    required this.localCounts,
    required this.pendingByType,
    required this.lastSyncAt,
    required this.lastSyncSucceeded,
  });
}

class _BackendDebugDiagnosticsData {
  final bool authConnected;
  final bool tokenSaved;
  final bool apiTokenPresent;
  final String? userId;
  final String? businessId;
  final String? cloudBusinessId;
  final String? role;
  final String deviceId;
  final String? storedDeviceId;
  final String? sessionVersion;
  final String effectiveBaseUrl;
  final String? lastEndpoint;
  final String? lastStatus;
  final String? lastError;
  final String? lastModule;
  final String? lastOperation;
  final int pendingOutboxCount;

  const _BackendDebugDiagnosticsData({
    required this.authConnected,
    required this.tokenSaved,
    required this.apiTokenPresent,
    required this.userId,
    required this.businessId,
    required this.cloudBusinessId,
    required this.role,
    required this.deviceId,
    required this.storedDeviceId,
    required this.sessionVersion,
    required this.effectiveBaseUrl,
    required this.lastEndpoint,
    required this.lastStatus,
    required this.lastError,
    required this.lastModule,
    required this.lastOperation,
    required this.pendingOutboxCount,
  });
}

class _SimpleSyncError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _SimpleSyncError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No pudimos revisar la sincronizacion ahora.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
