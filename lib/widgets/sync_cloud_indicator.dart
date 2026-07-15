import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/developer_tools.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../presentation/providers/sync_providers.dart';
import '../screens/sync_status_screen.dart';

class SyncCloudIndicator extends ConsumerStatefulWidget {
  const SyncCloudIndicator({super.key});

  @override
  ConsumerState<SyncCloudIndicator> createState() => _SyncCloudIndicatorState();
}

class _SyncCloudIndicatorState extends ConsumerState<SyncCloudIndicator>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _onlineSubscription;
  StreamSubscription<void>? _queueSubscription;
  Timer? _autoSyncPulse;

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
            _refreshAndScheduleAutoSync();
          });
      _queueSubscription = SyncQueueRepository.queueChanges.listen((_) {
        if (!mounted) return;
        _refreshAndScheduleAutoSync();
      });
      _autoSyncPulse = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!mounted) return;
        _refreshAndScheduleAutoSync();
      });
    });
  }

  @override
  void dispose() {
    _autoSyncPulse?.cancel();
    _onlineSubscription?.cancel();
    _queueSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAndScheduleAutoSync();
    }
  }

  Future<void> _refreshAndScheduleAutoSync() async {
    final notifier = ref.read(syncUserStatusProvider.notifier);
    await notifier.refresh();
    await notifier.scheduleAutoSync();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncUserStatusProvider).valueOrNull;
    final color = status == null
        ? Colors.grey
        : status.lastErrorMessage != null
        ? Colors.red.shade700
        : status.isSyncing
        ? Colors.blue
        : status.isCloudAuthenticated &&
              status.lastSyncSucceeded &&
              status.pendingCount == 0
        ? Colors.green
        : status.pendingCount > 0 || !status.isCloudAuthenticated
        ? Colors.amber.shade700
        : Colors.amber.shade700;
    final icon = status == null
        ? Icons.save_outlined
        : status.lastErrorMessage != null
        ? Icons.error_outline_rounded
        : status.isSyncing
        ? Icons.sync_rounded
        : status.isCloudAuthenticated &&
              status.lastSyncSucceeded &&
              status.pendingCount == 0
        ? Icons.check_circle_outline_rounded
        : status.pendingCount > 0 || !status.isCloudAuthenticated
        ? Icons.pending_actions_outlined
        : Icons.save_outlined;
    final message = status?.shortMessage ?? 'Todo guardado';

    return Tooltip(
      message: message,
      child: TextButton.icon(
        onPressed: showDeveloperTools
            ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
              )
            : null,
        icon: Icon(icon, color: color),
        label: Text(
          message,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
