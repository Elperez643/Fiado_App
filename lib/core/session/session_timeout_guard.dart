import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/crash_diagnostics_service.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../screens/login_screen.dart';
import 'session_timeout_service.dart';
import 'session_timeout_warning_dialog.dart';

class SessionTimeoutGuard extends ConsumerStatefulWidget {
  final Widget child;

  const SessionTimeoutGuard({super.key, required this.child});

  @override
  ConsumerState<SessionTimeoutGuard> createState() =>
      _SessionTimeoutGuardState();
}

class _SessionTimeoutGuardState extends ConsumerState<SessionTimeoutGuard>
    with WidgetsBindingObserver {
  final SessionTimeoutService _service = SessionTimeoutService();
  bool _warningOpen = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusActivity);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusActivity);
    WidgetsBinding.instance.removeObserver(this);
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hasUser = ref.read(currentUserProvider) != null;
    if (!hasUser) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _service.markBackground();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_service.shouldLogoutAfterResume()) {
        _logout(reason: _SessionLogoutReason.backgroundTimeout);
      } else {
        _registerActivity();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      CrashDiagnosticsService.setUserRole(null);
      _service.stop();
      return widget.child;
    }
    CrashDiagnosticsService.setUserRole(user.tipoUsuario);

    _ensureStarted();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registerActivity(),
      onPointerMove: (_) => _registerActivity(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _registerActivity();
          return false;
        },
        child: widget.child,
      ),
    );
  }

  void _ensureStarted() {
    if (_service.lastActivityAt != null) return;
    _service.start(onWarning: _showWarning, onTimeout: _logout);
  }

  void _registerActivity() {
    if (ref.read(currentUserProvider) == null || _loggingOut) return;
    _service.registerActivity(onWarning: _showWarning, onTimeout: _logout);
  }

  void _handleFocusActivity() {
    if (FocusManager.instance.primaryFocus != null) {
      _registerActivity();
    }
  }

  Future<void> _showWarning() async {
    if (!mounted ||
        _warningOpen ||
        _loggingOut ||
        ref.read(currentUserProvider) == null) {
      return;
    }
    _warningOpen = true;
    final result = await showDialog<SessionTimeoutWarningResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SessionTimeoutWarningDialog(
        initialSeconds: sessionWarningBefore.inSeconds,
      ),
    );
    _warningOpen = false;
    _service.markWarningDismissed();
    if (!mounted || _loggingOut || ref.read(currentUserProvider) == null) {
      return;
    }

    switch (result) {
      case SessionTimeoutWarningResult.continueSession:
        _registerActivity();
        break;
      case SessionTimeoutWarningResult.logout:
      case SessionTimeoutWarningResult.timeout:
      case null:
        await _logout();
        break;
    }
  }

  Future<void> _logout({
    _SessionLogoutReason reason = _SessionLogoutReason.inactivityTimeout,
  }) async {
    if (_loggingOut) return;
    _loggingOut = true;
    _service.stop();

    if (_warningOpen && mounted) {
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
      _warningOpen = false;
    }

    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;

    final message = reason == _SessionLogoutReason.backgroundTimeout
        ? 'Sesion cerrada por permanecer fuera de la app.'
        : 'Sesion cerrada por inactividad.';
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
    _loggingOut = false;
  }
}

enum _SessionLogoutReason { inactivityTimeout, backgroundTimeout }
