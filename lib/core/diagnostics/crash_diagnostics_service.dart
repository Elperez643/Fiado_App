import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashDiagnosticsService {
  static const _lastCrashKey = 'fiado_last_crash_diagnostics';
  static const _lastStartupStepKey = 'fiado_last_startup_step';
  static const _lastStartupErrorKey = 'fiado_last_startup_error';
  static SharedPreferences? _prefs;
  static String _currentScreen = 'unknown';
  static String? _userRole;

  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      _prefs = null;
    }
  }

  static void setCurrentScreen(String screen) {
    if (screen.trim().isEmpty) return;
    _currentScreen = screen;
  }

  static void setUserRole(String? role) {
    _userRole = role?.trim().isEmpty == true ? null : role?.trim();
  }

  static Future<void> recordStartupStep(String step) async {
    if (step.trim().isEmpty) return;
    try {
      await _prefs?.setString(_lastStartupStepKey, step.trim());
    } catch (_) {
      // El diagnostico nunca debe bloquear el arranque.
    }
  }

  static Future<void> recordStartupError(Object error) async {
    try {
      await _prefs?.setString(_lastStartupErrorKey, _safeError(error));
    } catch (_) {
      // El diagnostico nunca debe bloquear el arranque.
    }
  }

  static String? getLastStartupStep() => _prefs?.getString(_lastStartupStepKey);

  static String? getLastStartupError() =>
      _prefs?.getString(_lastStartupErrorKey);

  static Future<void> record({
    required Object error,
    required StackTrace stackTrace,
    String source = 'unknown',
  }) async {
    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer()
      ..writeln('# Fiado App Crash Diagnostics')
      ..writeln()
      ..writeln('- fecha: $now')
      ..writeln('- origen: $source')
      ..writeln('- pantalla: $_currentScreen')
      ..writeln('- rol: ${_userRole ?? 'sin_sesion'}')
      ..writeln('- modo_debug: $kDebugMode')
      ..writeln()
      ..writeln('## Error')
      ..writeln('```')
      ..writeln(error)
      ..writeln('```')
      ..writeln()
      ..writeln('## Stack trace')
      ..writeln('```')
      ..writeln(stackTrace)
      ..writeln('```');

    try {
      await _prefs?.setString(_lastCrashKey, buffer.toString());
    } catch (_) {
      // El diagnostico no debe provocar un segundo crash.
    }
  }

  static String? getLastCrashLog() => _prefs?.getString(_lastCrashKey);

  static String _safeError(Object error) {
    final text = error.toString();
    if (text.length <= 500) return text;
    return text.substring(0, 500);
  }
}

class CrashRouteObserver extends NavigatorObserver {
  void _record(Route<dynamic>? route) {
    final settings = route?.settings;
    CrashDiagnosticsService.setCurrentScreen(
      settings?.name ?? route?.runtimeType.toString() ?? 'unknown',
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _record(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record(previousRoute);
    super.didPop(route, previousRoute);
  }
}
