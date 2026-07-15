# Subscription Pricing

## Fuente Oficial

Los precios oficiales de Fiado App se expresan en USD.

- Flutter: `lib/core/constants/subscription_plans.dart`.
- Backend: `backend/src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs`.

Los precios historicos RD$700, RD$1,500 y RD$2,800 quedan obsoletos y no deben
mostrarse como precio oficial en pantallas, documentos, DTOs, Stripe o mock.

## Precios Actuales

| Plan | Ciclo | Precio USD | Colaboradores |
| --- | --- | ---: | ---: |
| Basico | Mensual | 4.99 | 3 |
| Basico | Trimestral | 13.47 | 3 |
| Basico | Anual | 47.90 | 3 |
| Crecimiento | Mensual | 12.99 | 7 |
| Crecimiento | Trimestral | 35.07 | 7 |
| Crecimiento | Anual | 124.70 | 7 |
| Empresarial | Mensual | 20.99 | 15 |
| Empresarial | Trimestral | 56.67 | 15 |
| Empresarial | Anual | 201.50 | 15 |

## Ciclos Y Descuentos

- Mensual: sin descuento.
- Trimestral: 10% de descuento sobre 3 meses.
- Anual: 20% de descuento sobre 12 meses.

## DOP Aproximado

Cuando se muestra DOP, debe etiquetarse como equivalente aproximado y calcularse
desde USD usando la tasa configurada por el backend/app. No debe usarse como
precio oficial ni reutilizar los precios viejos en pesos.

Ejemplo:

```text
Basico mensual: USD 4.99
Equivalente aproximado: RD$295.66 con tasa 59.25
```

## Stripe

Stripe Price IDs deben crearse manualmente en Stripe TEST con los montos USD
correctos de esta tabla. Fiado App no crea precios Stripe automaticamente.

## Mock

`MockPaymentProvider` cobra el `FinalPrice` oficial en USD de la suscripcion y
calcula DOP como aproximado con la tasa configurada en el servicio.

## Validacion

Ejecutar:

```bat
dart run tools\qa\validate_subscription_prices.dart
```

El script falla si encuentra precios oficiales visibles con los valores viejos
historicos de suscripcion en DOP o sus equivalentes escritos como USD.
