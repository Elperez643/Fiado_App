import 'dart:async';

import 'package:flutter/material.dart';

class SessionTimeoutWarningDialog extends StatefulWidget {
  final int initialSeconds;

  const SessionTimeoutWarningDialog({super.key, required this.initialSeconds});

  @override
  State<SessionTimeoutWarningDialog> createState() =>
      _SessionTimeoutWarningDialogState();
}

class _SessionTimeoutWarningDialogState
    extends State<SessionTimeoutWarningDialog> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        Navigator.of(context).pop(SessionTimeoutWarningResult.timeout);
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sesion por cerrarse'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tu sesion esta por cerrarse por inactividad.'),
          const SizedBox(height: 14),
          Text(
            'Tiempo restante: $_remainingSeconds segundos',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(SessionTimeoutWarningResult.logout),
          child: const Text('Cerrar sesion ahora'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(SessionTimeoutWarningResult.continueSession),
          child: const Text('Continuar sesion'),
        ),
      ],
    );
  }
}

enum SessionTimeoutWarningResult { continueSession, logout, timeout }
