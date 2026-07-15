# Subscription Trial Architecture

Fiado App usa estos estados para negocios: `registration_incomplete`, `payment_method_required`, `trial_active`, `active`, `past_due`, `canceled` y `expired`.

Flujo definitivo:

1. Registro Negocio requiere backend e internet.
2. `POST /api/auth/register/business/start` crea usuario/negocio cloud en `payment_method_required`.
3. `POST /api/payments/stripe/create-setup-session` abre Stripe Checkout Setup Mode.
4. Stripe guarda el metodo de pago; Fiado App solo persiste `providerPaymentMethodId`, `brand`, `last4`, `expMonth`, `expYear`.
5. `POST /api/subscriptions/activate-trial` valida trial unico, metodo de pago y plan.
6. Trial dura 30 dias y queda en `trial_active`.
7. Android/Windows crean sesion local SQLite solo despues de trial activo.
8. Web opera cloud-first.

Trial unico:

- `Business.HasUsedTrial` bloquea cualquier segundo trial del mismo negocio.
- Error humano: `Este negocio ya utilizo su periodo de prueba.`

Offline:

- `trial_active` y `active` permiten uso offline-first.
- Si vence mientras no hay internet, el cliente aplica gracia local de 72 horas.
- No se borran datos locales por vencimiento.

