# Stripe Test Setup

## Objetivo

Habilitar Stripe Checkout/Billing en modo TEST para suscripciones de Fiado App.
Fiado App no guarda numero de tarjeta, CVV ni fecha completa; Stripe captura el
metodo de pago en Checkout.

## Crear Cuenta Y Activar Test Mode

1. Crear o entrar a una cuenta en Stripe.
2. Activar `Test mode` en el dashboard.
3. Copiar la clave secreta test `sk_test_...`.
4. No usar claves `sk_live_...` en esta fase.

## Productos Y Precios

Crear productos/precios recurrentes para cada plan y ciclo:

- `basico`: mensual USD 4.99, trimestral USD 13.47, anual USD 47.90.
- `crecimiento`: mensual USD 12.99, trimestral USD 35.07, anual USD 124.70.
- `empresarial`: mensual USD 20.99, trimestral USD 56.67, anual USD 201.50.

Copiar cada `price_...` y configurarlo en `Stripe:PriceIds`.

Los Price IDs deben corresponder a los montos USD anteriores. Fiado App no
crea precios Stripe automaticamente, y no deben reutilizarse precios historicos
en DOP como importes oficiales.

## Configuracion Backend

Usar variables de entorno o `appsettings.Development.json` local:

```json
{
  "Payments": {
    "Provider": "Stripe"
  },
  "Stripe": {
    "SecretKey": "sk_test_xxx",
    "WebhookSecret": "whsec_xxx",
    "SuccessUrl": "http://localhost:5193/stripe/success",
    "CancelUrl": "http://localhost:5193/stripe/cancel",
    "PriceIds": {
      "basico": {
        "mensual": "price_xxx",
        "trimestral": "price_xxx",
        "anual": "price_xxx"
      },
      "crecimiento": {
        "mensual": "price_xxx",
        "trimestral": "price_xxx",
        "anual": "price_xxx"
      },
      "empresarial": {
        "mensual": "price_xxx",
        "trimestral": "price_xxx",
        "anual": "price_xxx"
      }
    }
  }
}
```

Tambien puede configurarse por entorno:

```powershell
$env:Payments__Provider="Stripe"
$env:Stripe__SecretKey="sk_test_xxx"
$env:Stripe__WebhookSecret="whsec_xxx"
$env:Stripe__SuccessUrl="http://localhost:5193/stripe/success"
$env:Stripe__CancelUrl="http://localhost:5193/stripe/cancel"
$env:Stripe__PriceIds__basico__mensual="price_xxx"
```

## Probar Checkout

1. Iniciar backend.
2. Iniciar sesion como usuario `Negocio`.
3. En app abrir `Suscripcion`.
4. Seleccionar plan/ciclo.
5. Tocar `Pagar con Stripe (modo prueba)`.
6. Debe abrirse Stripe Checkout externo.

Tarjetas test:

- Exito: `4242 4242 4242 4242`.
- Requiere autenticacion: `4000 0025 0000 3155`.
- Fallo generico: `4000 0000 0000 9995`.

Usar cualquier fecha futura, CVC de 3 digitos y ZIP valido.

## Probar Webhook

Instalar Stripe CLI y autenticar:

```powershell
stripe login
```

Escuchar eventos contra backend local:

```powershell
stripe listen --forward-to http://localhost:5193/api/payments/stripe/webhook
```

Copiar el `whsec_...` mostrado por Stripe CLI en `Stripe:WebhookSecret`.

Eventos manejados:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

## Seguridad

- No guardar tarjetas en SQLite ni SQL Server.
- No versionar claves reales.
- No usar `sk_live_...` hasta la fase de produccion.
- Mantener `MockPaymentProvider` disponible para QA local sin Stripe.
