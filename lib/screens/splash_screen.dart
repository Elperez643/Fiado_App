import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_environment.dart';
import '../core/constants/app_constants.dart';
import '../core/diagnostics/crash_diagnostics_service.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/sync_providers.dart';
import '../widgets/app_error_state.dart';
import 'login_screen.dart';
import 'onboarding_assistant_screen.dart';
import 'startup_diagnostics_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _startupTimeout = Duration(seconds: 22);
  bool _loading = true;
  Object? _startupError;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return AppErrorState(
        title: 'No pudimos iniciar Fiado App.',
        message:
            'El arranque tardo demasiado o encontro un problema. Puedes reintentar sin perder tus datos locales.',
        onRetry: _retry,
        onLogout: _clearLocalSession,
        extraActions: [
          TextButton.icon(
            onPressed: _goToLogin,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Ir a iniciar sesion'),
          ),
          OutlinedButton.icon(
            onPressed: _resetCloudConfiguration,
            icon: const Icon(Icons.cloud_off_outlined),
            label: const Text('Restablecer nube'),
          ),
          if (kDebugMode)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StartupDiagnosticsScreen(),
                ),
              ),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Ver diagnostico'),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 188,
              height: 188,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(44),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F17322C),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.asset(
                  'assets/images/fiado_logo.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    try {
      debugPrint('[splash] start');
      await CrashDiagnosticsService.recordStartupStep('[splash] start');
      await Future<void>.delayed(
        const Duration(seconds: AppConstants.splashDurationSeconds),
      );
      await _navigateAfterStartup().timeout(_startupTimeout);
    } on TimeoutException catch (error, stackTrace) {
      await _showStartupError(error, stackTrace, 'splash.timeout');
    } catch (error, stackTrace) {
      await _showStartupError(error, stackTrace, 'splash.error');
    }
  }

  Future<void> _navigateAfterStartup() async {
    if (!mounted) return;

    if (kIsWeb) {
      debugPrint('[splash] web -> login');
      await CrashDiagnosticsService.recordStartupStep(
        '[splash] navigate login web',
      );
      _goToLogin();
      return;
    }

    debugPrint('[splash] local db/session resolving');
    await CrashDiagnosticsService.recordStartupStep('[splash] local db start');
    final user = await ref
        .read(authRepositoryProvider)
        .obtenerUsuarioActual()
        .timeout(const Duration(seconds: 8));
    if (!mounted) return;
    await CrashDiagnosticsService.recordStartupStep('[splash] local db ok');

    if (user == null) {
      debugPrint('[splash] no session -> login');
      await CrashDiagnosticsService.recordStartupStep('[splash] no session');
      _goToLogin();
      return;
    }

    debugPrint(
      '[splash] session -> role=${user.tipoUsuario} id=${user.id} negocio=${user.negocioId}',
    );
    await CrashDiagnosticsService.recordStartupStep('[splash] session found');
    ref.read(authStateProvider.notifier).setLocalUser(user);
    if (!mounted) return;
    await OnboardingAssistantScreen.openAfterAuth(
      context: context,
      ref: ref,
      user: user,
    );
  }

  Future<void> _showStartupError(
    Object error,
    StackTrace stackTrace,
    String source,
  ) async {
    debugPrint('[splash] error: $error');
    await CrashDiagnosticsService.recordStartupError(error);
    unawaited(
      CrashDiagnosticsService.record(
        error: error,
        stackTrace: stackTrace,
        source: source,
      ),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _startupError = error;
    });
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _startupError = null;
    });
    ref.invalidate(authStateProvider);
    unawaited(_start());
  }

  Future<void> _clearLocalSession() async {
    try {
      await ref
          .read(authStateProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 5));
    } catch (error, stackTrace) {
      unawaited(
        CrashDiagnosticsService.record(
          error: error,
          stackTrace: stackTrace,
          source: 'startup.clearLocalSession',
        ),
      );
    }
    if (!mounted) return;
    _goToLogin();
  }

  Future<void> _resetCloudConfiguration() async {
    try {
      await ref
          .read(cloudAuthServiceProvider)
          .clearCloudToken()
          .timeout(const Duration(seconds: 5));
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
      );
      await ApiEnvironmentConfig.resetCloudRuntimeConfiguration(prefs);
    } catch (error, stackTrace) {
      unawaited(
        CrashDiagnosticsService.record(
          error: error,
          stackTrace: stackTrace,
          source: 'startup.resetCloudConfiguration',
        ),
      );
    }
    if (!mounted) return;
    _retry();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }
}
