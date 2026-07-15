# Subscription Trial Live QA Report

Fecha: 2026-06-19

## Estado general

Resultado: `BLOQUEADO_POR_CONFIG_STRIPE`

El flujo real `registro cloud -> plan -> tarjeta Stripe TEST -> trial_active -> offline-first` no pudo cerrarse completamente porque la configuracion local de Stripe TEST esta vacia:

- `Stripe:SecretKey`: vacio
- `Stripe:WebhookSecret`: vacio
- `Stripe:PriceIds:*`: vacios

No se guardaron secretos en `appsettings`. Esto es correcto para seguridad, pero requiere configurar secretos de entorno/user-secrets antes de la prueba live.

## Negocio creado

No creado en prueba live desde este cierre.

Motivo: Stripe TEST no esta configurado y el flujo real debe completar tarjeta antes de habilitar offline-first.

## Plan seleccionado

Pendiente de prueba live.

Plan esperado para validacion inicial: `basico / mensual`, o el plan elegido en UI.

## Payment method test guardado

Pendiente de prueba live.

Resultado esperado:

- Tarjeta test: `4242 4242 4242 4242`
- Provider: `stripe`
- Datos guardados: `providerPaymentMethodId`, `brand`, `last4`, `expMonth`, `expYear`
- Datos que NO se guardan: numero completo, CVV

## Estado trial

Pendiente de prueba live.

Resultado esperado tras `POST /api/subscriptions/activate-trial`:

- `status = trial_active`
- `hasUsedTrial = true`
- `paymentMethodRequired = false`
- `trialEndsAt = hoy + 30 dias`
- Suscripcion Stripe creada con trial de 30 dias y cobro automatico al finalizar

## Offline allowed

Pendiente de prueba live.

Resultado esperado:

- `offline_allowed = true` solo si `status` local/remoto es `trial_active` o `active`.
- Si queda en `payment_method_required`, no debe sincronizar ni habilitar negocio como activo.

## Prueba offline

Pendiente de ejecucion manual en Android/Windows con negocio en `trial_active`.

Casos a confirmar:

- Abrir app sin internet con sesion local valida.
- Entrar al Dashboard.
- Crear cliente.
- Crear producto.
- Crear fiado.
- Registrar pago.
- Generar comprobante.
- Ver sync pendiente.
- Volver internet y confirmar subida de sync.

## Validaciones negativas

Estado esperado:

- Sin tarjeta: `activate-trial` debe fallar con `Agrega una tarjeta para activar tu prueba gratis de 30 dias.`
- Sin internet: registro Negocio debe mostrar `Para registrar un negocio necesitas conexion a internet. Luego podras usar Fiado App sin conexion.`
- Segundo trial mismo negocio: debe fallar con `Este negocio ya utilizo su periodo de prueba.`
- Web sin backend/nube: debe requerir conexion.
- Datos locales: no se borran por vencimiento o falta de validacion.

## Errores encontrados

- Build backend fallo inicialmente por `priceId` fuera de alcance en `StripeBillingService.ActivateTrialAsync`.
- Correccion aplicada: se agrego `var priceId = PriceId(plan.PlanId, billingCycle);` dentro de `ActivateTrialAsync`.
- Build backend luego paso correctamente segun salida reportada por el usuario.

## Validaciones ya ejecutadas por el usuario

- `dotnet build backend\FiadoApp.Backend.sln`: OK
- `flutter pub get`: OK
- `dart format .`: OK
- `flutter analyze`: OK
- `flutter test`: OK
- `dart run tools\qa\run_subscription_onboarding_audit.dart`: OK
- `flutter build apk --debug`: OK

Resultado del audit local:

- Negocio local fixture: `trial_local_pendiente_validacion`
- `offline_allowed = false`

Ese resultado es correcto para un fixture local pendiente; la prueba live debe cambiar a `trial_active` luego de tarjeta + activacion cloud.

## Validaciones pendientes

- Configurar Stripe TEST por secretos de entorno o user-secrets.
- Ejecutar backend con webhook Stripe.
- Registrar negocio nuevo real.
- Completar tarjeta 4242 en Stripe Checkout Setup Mode.
- Activar trial.
- Confirmar `GET /api/subscriptions/status`.
- Ejecutar prueba offline Android/Windows.
- Ejecutar `flutter build windows`.
- Ejecutar `flutter build web`.

## Comandos pendientes sugeridos

```powershell
dotnet build backend\FiadoApp.Backend.sln
flutter analyze
flutter test
dart run tools\qa\run_subscription_onboarding_audit.dart
flutter build apk --debug
flutter build windows
flutter build web
```

Webhook Stripe:

```powershell
stripe listen --forward-to http://localhost:5193/api/payments/stripe/webhook
```

## Correcciones aplicadas

- Backend compila luego de corregir `priceId`.
- Arquitectura impide trial sin tarjeta.
- Arquitectura impide segundo trial por `Business.HasUsedTrial`.
- Registro Negocio Flutter exige nube/internet.
- Sync automatico queda bloqueado si el negocio esta en `payment_method_required`.
- APK debug generado previamente y copiable a `dist`.

