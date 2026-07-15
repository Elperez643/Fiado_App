# Azul Payment Architecture

Fiado App usa `Payments:Provider` para elegir proveedor principal:

- `Azul`: proveedor principal para Republica Dominicana.
- `Stripe`: proveedor secundario de pruebas.
- `Mock`: proveedor local/secundario de desarrollo.

## Configuracion

```json
"Payments": {
  "Provider": "Azul"
},
"Azul": {
  "MerchantId": "",
  "MerchantName": "",
  "AuthKey": "",
  "ApiUrl": "",
  "SuccessUrl": "",
  "CancelUrl": "",
  "WebhookSecret": "",
  "Currency": "USD",
  "Environment": "Sandbox"
}
```

Los secretos Azul no deben guardarse en `appsettings`. Deben venir de user-secrets, variables de entorno o el secreto del ambiente de despliegue.

## Componentes

- `AzulPaymentProvider`: capa proveedor Azul. Hoy implementa `AzulSandboxMock` si faltan credenciales.
- `AzulPaymentOptions`: opciones de configuracion.
- `AzulPaymentModels`: contratos internos del proveedor.
- `AzulPaymentService`: orquesta negocio, tokenizacion, trial y cobro.
- `SubscriptionRenewalService`: cobra trials vencidos con Azul y actualiza estado.

## Endpoints

- `POST /api/payments/azul/create-card-token-session`
- `POST /api/payments/azul/confirm-card-token`
- `POST /api/subscriptions/activate-trial`
- `POST /api/payments/azul/charge-subscription`
- `POST /api/payments/azul/webhook`
- `POST /api/subscriptions/run-renewal-check`
- `GET /api/subscriptions/status`

## Datos de tarjeta

Fiado App guarda solo:

- `provider = Azul`
- `providerCustomerId`
- `providerPaymentMethodId`
- `brand`
- `last4`
- `expMonth`
- `expYear`
- `isDefault`
- `createdAt`

No se guarda numero completo ni CVV.

## Trial

`activate-trial` con Azul requiere:

- negocio autenticado
- plan valido
- metodo de pago Azul guardado
- `HasUsedTrial = false`

Al activar:

- `status = trial_active`
- `TrialStartedAt = now`
- `TrialEndsAt = now + 30 dias`
- `HasUsedTrial = true`
- `PaymentMethodRequired = false`
- `offlineAllowed = true`

## Renovacion

`SubscriptionRenewalService` busca subscriptions `trial_active` vencidas y cobra con el token Azul guardado.

- Pago OK: `active`
- Pago falla: `past_due`
- Nunca borra datos locales.

## Estado actual

`AzulSandboxMock` esta activo cuando faltan credenciales reales Azul. No debe interpretarse como produccion.

