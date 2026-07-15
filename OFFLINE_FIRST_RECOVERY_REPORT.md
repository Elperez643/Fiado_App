# Offline First Recovery Report

## Causa Encontrada

El arranque y login todavia estaban demasiado acoplados a inicializacion de sesion/DB con timeouts desalineados. Ademas, el login cloud fallback no cubria completamente el caso de usuario existente en backend pero ausente en SQLite local.

## Correcciones

- Splash conserva comportamiento offline-first: si no hay sesion local, navega a Login.
- Timeouts de Splash/Auth/DB se alinearon para evitar falsos errores de arranque.
- Login local sigue funcionando sin internet cuando el usuario existe en el dispositivo.
- Login cloud fallback crea/vincula usuario local cuando cloud autentica y no existe usuario SQLite.
- Web usa login cloud-first y evita SQLite local en Splash/Auth inicial.
- Trial local de negocio nuevo queda en `trial_local_pendiente_validacion` y permite acceso mientras se valida luego en cloud.
- Stripe muestra mensaje claro si no hay nube: para pagar se requiere internet.
- Metodos mock quedan visibles solo en debug.
- Se agrego reset local seguro en configuracion avanzada solo debug.

## Herramientas QA

- `tools/qa/run_offline_first_audit.dart`
- `tools/qa/reset_local_test_data.dart`
- `OFFLINE_FIRST_QA.md`
- `LOCAL_RESET_QA.md`

## Pendiente Manual

- Instalar APK en Android fisico.
- Probar sin internet: abrir, registrar negocio local, entrar, crear producto.
- Probar Web sin backend: Login visible y mensaje claro al intentar login.
