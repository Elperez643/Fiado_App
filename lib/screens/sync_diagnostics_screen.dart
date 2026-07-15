import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/developer_tools.dart';
import '../data/repositories/sync_diagnostics_repository.dart';
import '../presentation/providers/sync_providers.dart';

class SyncDiagnosticsScreen extends ConsumerStatefulWidget {
  const SyncDiagnosticsScreen({super.key});

  @override
  ConsumerState<SyncDiagnosticsScreen> createState() =>
      _SyncDiagnosticsScreenState();
}

class _SyncDiagnosticsScreenState extends ConsumerState<SyncDiagnosticsScreen> {
  SyncDiagnosticsReport? _report;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (!syncDiagnosticsEnabled) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de sincronización')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _DiagnosticError(error: _error!, onRetry: _refresh)
          : _DiagnosticBody(
              report: _report!,
              onRefresh: _refresh,
              onCopy: _copy,
            ),
    );
  }

  Future<void> _refresh() async {
    if (!syncDiagnosticsEnabled) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(syncUserStatusProvider.notifier).refresh();
      final status = ref.read(syncUserStatusProvider).valueOrNull;
      if (status == null) throw StateError('Estado del banner no disponible.');
      final report = await ref
          .read(syncDiagnosticsRepositoryProvider)
          .load(bannerStatus: status);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report.toPlainText()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnóstico copiado.')));
  }
}

class _DiagnosticBody extends StatelessWidget {
  final SyncDiagnosticsReport report;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCopy;

  const _DiagnosticBody({
    required this.report,
    required this.onRefresh,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar diagnóstico'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar diagnóstico'),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Backend y conectividad',
            values: {
              'Base URL efectiva': report.effectiveBaseUrl,
              'Online': _yesNo(report.isOnline),
              'Timeout': '${report.timeoutSeconds} s',
              'Health URL': report.healthUrl ?? '-',
              'Health status': report.healthStatus ?? '-',
              'Health resultado': report.healthResult ?? '-',
              'Health error': report.healthError ?? '-',
              'Health intento': report.healthAttemptAt ?? '-',
            },
          ),
          _Section(
            title: 'Autenticación cloud',
            values: {
              'Autenticado': _yesNo(report.isCloudAuthenticated),
              'Cloud user ID presente': _yesNo(report.cloudUserIdPresent),
              'Business ID presente': _yesNo(report.businessIdPresent),
              'Rol': report.role ?? '-',
              'Device ID presente': _yesNo(report.deviceIdPresent),
              'Session version presente': _yesNo(report.sessionVersionPresent),
              'Token presente': _yesNo(report.tokenPresent),
            },
          ),
          _Section(
            title: 'Estado global del banner',
            values: {
              'Texto': report.bannerStatus.shortMessage,
              'Sincronizando': _yesNo(report.bannerStatus.isSyncing),
              'Último sync exitoso': _yesNo(
                report.bannerStatus.lastSyncSucceeded,
              ),
              'Último éxito': report.bannerStatus.lastSyncAt?.toString() ?? '-',
              'Error visible': report.bannerStatus.lastErrorMessage ?? '-',
              'Fuente del error': report.errorSource ?? '-',
            },
          ),
          _StoreSection(title: 'sync_outbox', summary: report.outbox),
          _StoreSection(
            title:
                'sync_queue · legacy ${report.legacyEnabled ? 'activo' : 'apagado'}',
            summary: report.legacyQueue,
          ),
        ],
      ),
    );
  }

  static String _yesNo(bool value) => value ? 'Sí' : 'No';
}

class _Section extends StatelessWidget {
  final String title;
  final Map<String, String> values;

  const _Section({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          for (final entry in values.entries)
            _ValueRow(label: entry.key, value: entry.value),
        ],
      ),
    );
  }
}

class _StoreSection extends StatelessWidget {
  final String title;
  final SyncStoreDiagnosticSummary summary;

  const _StoreSection({required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          _ValueRow(label: 'Total', value: '${summary.total}'),
          _ValueRow(label: 'Pendientes', value: '${summary.pending}'),
          _ValueRow(label: 'Fallidos', value: '${summary.failed}'),
          _ValueRow(label: 'Completados', value: '${summary.completed}'),
          _ValueRow(
            label: 'Máximo de intentos',
            value: '${summary.maxAttempts}',
          ),
          _ValueRow(label: 'Último error', value: summary.lastError ?? '-'),
          _ValueRow(label: 'Agrupados', value: _groups(summary.grouped)),
          if (summary.activeItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Primeros ${summary.activeItems.length} pendientes/fallidos',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            for (final item in summary.activeItems)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('#${item.id ?? '-'} · ${item.module}'),
                subtitle: Text('${item.status} · ${item.operation}'),
                children: [
                  _ValueRow(label: 'Intentos', value: '${item.attempts}'),
                  _ValueRow(label: 'Error', value: item.lastError ?? '-'),
                  _ValueRow(label: 'Creado', value: item.createdAt ?? '-'),
                  _ValueRow(label: 'Actualizado', value: item.updatedAt ?? '-'),
                  _ValueRow(
                    label: 'Payload keys',
                    value: item.payloadKeys.isEmpty
                        ? '-'
                        : item.payloadKeys.join(', '),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  static String _groups(Map<String, int> values) =>
      values.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _DiagnosticError extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _DiagnosticError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
