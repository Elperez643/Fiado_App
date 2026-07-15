# Cobranza Inteligente v1

Cobranza Inteligente ayuda al usuario Negocio a priorizar a quien cobrar usando datos locales existentes: clientes, ciclos de credito 30/45/60, movimientos y ClientScore.

## Fuente De Datos

- `credito_ciclos`: saldo pendiente, fechas limite y estado 30/45/60.
- `clientes`: nombre, telefono y negocio.
- `movimientos`: ultima deuda y ultimo pago.
- `client_scores`: score y riesgo si ya existen.

No se usa IA externa, machine learning ni backend. El calculo es offline-first.

## Estados

- `al_dia`: cliente con saldo dentro del plazo.
- `vence_pronto`: fecha limite 30 vence en 3 dias o menos.
- `vencido_30`: ciclo ya vencido a 30 dias.
- `mora_45`: ciclo en mora 45.
- `bloqueado_60`: ciclo bloqueado a 60.
- `saldo_pendiente`: saldo sin clasificacion urgente.
- `sin_accion`: sin saldo accionable.

## Prioridad

- Critica: bloqueado 60, mora 45 con saldo alto, o score alto riesgo con deuda vencida.
- Alta: vencido 30, vence hoy/manana o saldo alto.
- Media: vence en los proximos 3 dias, riesgo medio o saldo medio.
- Baja: saldo reciente o cliente al dia.

## KPIs

- Total por cobrar.
- Monto critico.
- Clientes que vencen pronto.
- Clientes en mora 45.
- Clientes bloqueados 60.
- Recuperacion sugerida hoy.

## Mensajes WhatsApp

El mensaje se genera automaticamente segun estado, pero Fiado App no envia mensajes por si sola. Abre WhatsApp con el texto preparado y el usuario confirma el envio. Si WhatsApp no abre, el mensaje queda copiado para pegarlo manualmente.

## Performance

La v1 no crea cache persistente. Usa una consulta agregada por cliente con indices en `credito_ciclos` para evitar cargar todos los ciclos en memoria. Si en pruebas futuras el calculo supera el objetivo de respuesta, el siguiente paso sera una tabla `collection_insights_cache`.

## Futuro Cloud

El backend podra calcular y validar insights de cobranza en el futuro, pero por ahora los insights se recalculan localmente desde SQLite para preservar el enfoque offline-first.
