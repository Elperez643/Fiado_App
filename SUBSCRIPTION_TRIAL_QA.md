# Subscription Trial QA

Casos obligatorios:

| Caso | Resultado esperado |
| --- | --- |
| Android con internet registra Negocio | Crea negocio cloud en `payment_method_required` |
| Seleccionar plan | Plan queda asociado al negocio |
| Agregar tarjeta test | Stripe Setup Mode guarda solo token/metadatos |
| Activar trial | `trial_active`, 30 dias, `HasUsedTrial=true` |
| Segundo trial mismo negocio | Backend bloquea con mensaje humano |
| Trial termina pago OK | Webhook cambia a `active` |
| Pago falla | Webhook cambia a `past_due`, no borra datos |

Comandos:

```bash
dotnet build backend/FiadoApp.Backend.sln
dart run tools/qa/run_subscription_onboarding_audit.dart
```

Stripe pendiente de entorno:

```bash
stripe listen --forward-to http://localhost:5193/api/payments/stripe/webhook
```

