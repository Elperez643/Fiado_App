# Startup Runtime Fix Report

## Causa Encontrada

El arranque dependia de resolver sesion local desde `authStateProvider` y podia caer en error recuperable si la DB/auth tardaba. El login no tenia recuperacion cloud cuando el usuario existia en backend pero no en SQLite local.

## Correcciones Aplicadas

- `SplashScreen` navega a login cuando no hay sesion y tiene timeout recuperable.
- `SplashScreen` en Web no intenta abrir SQLite local.
- `LoginScreen` usa login con fallback cloud y evita doble login cloud si ya quedo vinculado.
- `AuthStateNotifier` usa cloud-first en Web con timeout.
- `AuthRepository.loginWithCloudFallback` vincula o crea usuario local cuando cloud autentica un usuario que no existe en el dispositivo.
- `CloudAuthService` devuelve datos minimos del usuario autenticado sin exponer token.
- `tools/qa/run_auth_startup_audit.dart` reporta usuarios locales, sesiones activas, tablas auth y cola abierta.

## Validacion Pendiente Manual

- Android fisico con APK instalado.
- Web Chrome con backend disponible.
- Login `8098678456` contra backend real configurado.
