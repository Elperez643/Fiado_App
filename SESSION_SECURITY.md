# Session Security

Fiado App protege las sesiones locales con cierre automatico por inactividad y por permanencia en segundo plano.

## Reglas

- Dentro de la app: advertencia tras 9 minutos de inactividad.
- Cuenta regresiva: 60 segundos.
- Cierre automatico: 10 minutos de inactividad.
- Segundo plano: si la app permanece fuera 2 minutos o mas, se cierra sesion al volver.

Estas reglas aplican a:

- Negocio
- Personal
- Colaborador

## Actividad Detectada

`SessionTimeoutGuard` detecta:

- Tap
- Gestos/puntero
- Scroll
- Foco en campos de texto
- Reanudacion de la app

## Segundo Plano

Al entrar en `paused`, `inactive` o `hidden`, Fiado App guarda `backgroundEnteredAt` y detiene los timers de inactividad. Al volver a `resumed`:

- Si pasaron menos de 2 minutos, reinicia timers.
- Si pasaron 2 minutos o mas, ejecuta logout seguro y vuelve a Login.

## Logout Seguro

El logout usa `authStateProvider.notifier.logout()`, que marca las sesiones activas como inactivas. El JWT local deja de estar disponible porque se obtiene solo desde sesiones `is_active = 1`.

## Modo Debug

Por defecto se usan tiempos reales:

- `inactivityTimeoutMinutes = 10`
- `warningBeforeSeconds = 60`
- `backgroundTimeoutMinutes = 2`

Para pruebas rapidas se puede compilar con:

```cmd
flutter build apk --debug --dart-define=FIADO_SESSION_TIMEOUT_DEBUG=true
```

En ese modo los tiempos se reducen para validar el flujo sin esperar 10 minutos.
