# Onboarding v2

La Guia Rapida de Fiado App ahora es un onboarding profesional por rol.

## Regla Una Sola Vez

El estado se guarda en `user_onboarding`.

Equivalencia funcional:

- `has_seen_onboarding = completed OR skipped`
- `onboarding_completed_at = completed_at` si completo la guia
- `onboarding_completed_at = skipped_at` si la omitio

Si el usuario completa u omite la guia, `debeMostrarOnboarding` devuelve
`false` y la guia no vuelve a aparecer automaticamente.

## Reentrada Manual

El usuario puede abrirla desde:

`Menu -> Ayuda / Ver guia nuevamente`

El modo manual no modifica `completed`, `skipped`, `completed_at` ni
`skipped_at`.

## Negocio

La guia de Negocio destaca:

- Dashboard ejecutivo.
- Score Inteligente.
- Cobranza Inteligente.
- Ciclos 30/45/60.
- Codigo de barras, ubicaciones e Inventario Inteligente.
- Auditorias.
- Campanas WhatsApp.
- Business Copilot y recomendaciones.

## Personal

La guia Personal destaca:

- Consulta de compras a credito.
- Historial de compras, pagos y comprobantes.
- Recordatorios, vencimientos y consejos.
- Relacion de pago saludable con negocios.

## Colaborador

La guia Colaborador destaca:

- Inventario.
- Ubicaciones.
- Codigo de barras.
- Auditorias diarias/semanales.
- Solicitudes y aprobaciones.

## Diseno

Usa el sistema visual actual:

- `AppColors`
- `AppGradients`
- `AppShadows`

Incluye tarjetas tipo SaaS, gradientes, indicadores de progreso y animaciones
suaves con Flutter nativo.
