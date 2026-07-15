# Business Copilot v1

Business Copilot es el Centro de Recomendaciones Inteligentes de Fiado App. Convierte datos existentes en acciones concretas para el usuario Negocio sin usar IA externa, OpenAI, ML ni servicios cloud.

## Fuente De Datos

- Client Scores.
- Credit Cycles 30/45/60.
- Cobranza Inteligente.
- Inventario Inteligente.
- Auditorias.
- Solicitudes de autorizacion.
- Suscripcion.
- Campanas WhatsApp como destino de accion promocional.

## Tipos

- `collection`
- `inventory`
- `promotion`
- `credit`
- `audit`
- `authorization`
- `subscription`
- `general`

## Prioridades

- `low`
- `medium`
- `high`
- `critical`

## Cache

Las recomendaciones se guardan en `business_recommendations_cache` con expiracion corta. La pantalla usa cache valido para no recalcular todo en cada apertura. El usuario puede recalcular manualmente desde el boton de refrescar.

## Reglas Implementadas

- Cobranza: clientes de prioridad alta/critica generan "Debes cobrar hoy".
- Credito: score menor a 40, mora 45 o bloqueo 60 genera recomendacion de no fiar.
- Inventario: agotado, critico, bajo stock o cobertura menor/igual a 3 dias genera reabastecimiento.
- Promocion: stock alto, rotacion baja y ganancia potencial alta genera sugerencia de campana WhatsApp.
- Inventario inmovilizado: productos sin movimiento participan como candidatos de promocion.
- Auditoria: auditorias pendientes generan recomendacion operativa.
- Autorizacion: solicitudes pendientes generan recomendacion operativa.
- Suscripcion: trial proximo a vencer, renovacion cercana o pago fallido generan recomendacion.
- General: resumen de dinero por recuperar, clientes criticos y productos agotados.

## Acciones

Cada recomendacion incluye `actionRoute` local para abrir cobranza, inventario, campanas, auditorias, solicitudes, suscripcion o inteligencia comercial.

## Limitaciones

Business Copilot v1 no sincroniza recomendaciones ni crea backend. Las recomendaciones son explicables, deterministicas y se recalculan desde datos locales.
