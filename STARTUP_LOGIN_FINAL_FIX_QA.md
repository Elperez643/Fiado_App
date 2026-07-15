# Startup Login Final Fix QA

## Causa encontrada

Splash esperaba el `authStateProvider.future` y convertia timeouts/errores de arranque local en la pantalla `No pudimos iniciar Fiado App`. Eso podia mostrarse aunque la situacion correcta fuera simplemente `no hay sesion local`.

Login usaba un flujo cloud fallback que podia esperar nube antes de permitir entrada, y ademas el login local bloqueaba por estado de suscripcion. Eso hacia que backend apagado, cloud lento o suscripcion pendiente se sintieran como login infinito.

## Correcciones aplicadas

- Splash ahora es local-first:
  - inicia minimo local
  - lee sesion local directamente desde `AuthRepository`
  - si no hay sesion navega a Login
  - si hay sesion navega al dashboard/onboarding por rol
  - no espera backend, sync, pagos, Stripe/Azul ni suscripcion remota

- Login Android/Windows ahora es local-first:
  - si usuario local existe valida password local y entra
  - cloud login queda best-effort posterior
  - si usuario local no existe intenta cloud por maximo 15 segundos
  - loading se apaga siempre en `finally`

- Web queda cloud-first:
  - requiere backend/nube
  - no debe quedar con spinner infinito

- Suscripcion ya no bloquea login local:
  - `payment_method_required`, `past_due` o `expired` deben manejar permisos/gates despues del login

- Diagnostico debug:
  - `StartupDiagnosticsScreen`
  - muestra `dbReady`, `sessionCount`, `activeSession`, `localUsersCount`, `authProviderStatus`, `lastStartupStep`, `lastErrorSafe`, `platform`, `isWeb`
  - no muestra token, contrasena ni datos sensibles

## Casos QA

| Caso | Resultado esperado |
| --- | --- |
| A. Sin sesion local | App abre Login, sin error falso |
| B. Con sesion local | App abre Dashboard/onboarding por rol |
| C. Backend apagado + usuario local existe | Login local entra |
| D. Backend apagado + usuario local no existe | Muestra `No encontramos este usuario en este dispositivo...` |
| E. Backend encendido + usuario cloud valido no local | Crea/vincula local y entra |
| F. Contrasena incorrecta | Loading se detiene y muestra error |
| G. Web sin backend | Mensaje cloud required, sin spinner |
| H. Web con backend | Login cloud entra |
| I. Session timeout/logout | Va a Login y puede volver a entrar |

## Validacion recomendada

```powershell
dart format .
flutter analyze
flutter test
dart run tools\qa\run_auth_startup_audit.dart
dart run tools\qa\run_offline_first_audit.dart
flutter build apk --debug
flutter build windows
flutter build web
dotnet build backend\FiadoApp.Backend.sln
```

APK final:

`dist\fiado_app_startup_login_final_fix_debug.apk`

