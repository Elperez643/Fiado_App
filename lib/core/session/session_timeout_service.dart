import 'dart:async';

const int inactivityTimeoutMinutes = 10;
const int warningBeforeSeconds = 60;
const int backgroundTimeoutMinutes = 2;

const bool sessionTimeoutDebugMode = bool.fromEnvironment(
  'FIADO_SESSION_TIMEOUT_DEBUG',
  defaultValue: false,
);

Duration get sessionInactivityTimeout => sessionTimeoutDebugMode
    ? const Duration(seconds: 40)
    : const Duration(minutes: inactivityTimeoutMinutes);

Duration get sessionWarningBefore => sessionTimeoutDebugMode
    ? const Duration(seconds: 10)
    : const Duration(seconds: warningBeforeSeconds);

Duration get sessionBackgroundTimeout => sessionTimeoutDebugMode
    ? const Duration(seconds: 15)
    : const Duration(minutes: backgroundTimeoutMinutes);

class SessionTimeoutService {
  Timer? _warningTimer;
  Timer? _logoutTimer;
  DateTime? _lastActivityAt;
  DateTime? _backgroundEnteredAt;
  bool _isWarningVisible = false;
  bool _isActive = false;

  DateTime? get lastActivityAt => _lastActivityAt;
  bool get isWarningVisible => _isWarningVisible;

  void start({
    required VoidCallback onWarning,
    required VoidCallback onTimeout,
  }) {
    _isActive = true;
    registerActivity(onWarning: onWarning, onTimeout: onTimeout);
  }

  void registerActivity({
    required VoidCallback onWarning,
    required VoidCallback onTimeout,
  }) {
    if (!_isActive) return;
    _lastActivityAt = DateTime.now();
    _isWarningVisible = false;
    _warningTimer?.cancel();
    _logoutTimer?.cancel();

    final warningDelay = sessionInactivityTimeout - sessionWarningBefore;
    _warningTimer = Timer(warningDelay, () {
      if (!_isActive) return;
      _isWarningVisible = true;
      onWarning();
    });
    _logoutTimer = Timer(sessionInactivityTimeout, () {
      if (!_isActive) return;
      onTimeout();
    });
  }

  void markBackground() {
    if (!_isActive) return;
    _backgroundEnteredAt = DateTime.now();
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
  }

  bool shouldLogoutAfterResume() {
    final enteredAt = _backgroundEnteredAt;
    _backgroundEnteredAt = null;
    if (!_isActive || enteredAt == null) return false;
    return DateTime.now().difference(enteredAt) >= sessionBackgroundTimeout;
  }

  void markWarningDismissed() {
    _isWarningVisible = false;
  }

  void stop() {
    _isActive = false;
    _isWarningVisible = false;
    _lastActivityAt = null;
    _backgroundEnteredAt = null;
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
  }

  void dispose() => stop();
}

typedef VoidCallback = void Function();
