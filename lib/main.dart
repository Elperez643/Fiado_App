import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api/api_environment.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_platform.dart';
import 'core/database/database_helper.dart';
import 'core/diagnostics/crash_diagnostics_service.dart';
import 'core/session/session_timeout_guard.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'widgets/app_error_state.dart';
import 'data/contracts/data_contract_validator.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        debugPrint('[startup] main inicializado');
        configureDatabaseFactory();
        debugPrint('[startup] database factory configurada');
        await DataContractValidator.validate(DatabaseHelper.instance);
        debugPrint('[startup] contratos de datos verificados');
        unawaited(_logBackendConfigAtStartup());
        unawaited(
          CrashDiagnosticsService.initialize()
              .timeout(const Duration(seconds: 3))
              .catchError((Object error, StackTrace stackTrace) {
                debugPrint('[startup] crash diagnostics omitido: $error');
              }),
        );
      } catch (error, stackTrace) {
        debugPrint('[startup] error antes de runApp: $error');
        runApp(_StartupFailureApp(error: error, stackTrace: stackTrace));
        return;
      }

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(
          CrashDiagnosticsService.record(
            error: details.exception,
            stackTrace: details.stack ?? StackTrace.current,
            source: 'FlutterError.onError',
          ),
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(
          CrashDiagnosticsService.record(
            error: error,
            stackTrace: stackTrace,
            source: 'PlatformDispatcher.onError',
          ),
        );
        return true;
      };

      ErrorWidget.builder = (details) {
        if (kDebugMode) {
          return ErrorWidget(details.exception);
        }
        unawaited(
          CrashDiagnosticsService.record(
            error: details.exception,
            stackTrace: details.stack ?? StackTrace.current,
            source: 'ErrorWidget.builder',
          ),
        );
        return const AppErrorState();
      };

      runApp(const ProviderScope(child: FiadoApp()));
    },
    (error, stackTrace) {
      unawaited(
        CrashDiagnosticsService.record(
          error: error,
          stackTrace: stackTrace,
          source: 'runZonedGuarded',
        ),
      );
    },
  );
}

Future<void> _logBackendConfigAtStartup() async {
  if (!kDebugMode) return;
  try {
    final config = await ApiEnvironmentConfig.resolve(
      SharedPreferences.getInstance(),
    );
    debugPrint('[BackendConfig] effectiveBaseUrl=${config.baseUrl}');
  } catch (error) {
    debugPrint('[BackendConfig] error=$error');
  }
}

class _StartupFailureApp extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const _StartupFailureApp({required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    unawaited(
      CrashDiagnosticsService.record(
        error: error,
        stackTrace: stackTrace,
        source: 'main.startupFailure',
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.light(),
      home: AppErrorState(
        title: 'No pudimos iniciar Fiado App.',
        message:
            'Cierra y abre la app nuevamente. Si persiste, revisa la configuracion del dispositivo.',
        onRetry: () {},
      ),
    );
  }
}

class FiadoApp extends StatelessWidget {
  const FiadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.light(),
      home: const SplashScreen(),
      navigatorObservers: [CrashRouteObserver()],
      builder: (context, child) {
        return SessionTimeoutGuard(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
