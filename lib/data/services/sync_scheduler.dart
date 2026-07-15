import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'sync_engine.dart';

class SyncScheduler {
  static const defaultInterval = Duration(seconds: 20);

  final SyncEngine syncEngine;
  final Connectivity connectivity;
  final Duration interval;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncScheduler({
    required this.syncEngine,
    Connectivity? connectivity,
    this.interval = defaultInterval,
  }) : connectivity = connectivity ?? Connectivity();

  Future<void> start() async {
    await syncEngine.start();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(syncEngine.syncNow()));
    _connectivitySubscription?.cancel();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        unawaited(syncEngine.syncNow());
      }
    });
    unawaited(syncEngine.syncNow());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await syncEngine.stop();
  }

  Future<void> syncNow({String? module}) {
    return syncEngine.syncNow(module: module);
  }
}
