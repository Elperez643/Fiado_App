# Collections Intelligence QA

## Casos Manuales

- Cliente vence en 3 dias: debe aparecer en "Vencen pronto" con prioridad media.
- Cliente vence hoy: debe aparecer en "Cobrar hoy" con prioridad alta.
- Cliente vencido 30: debe aparecer con estado `vencido_30`, prioridad alta y accion "Dar seguimiento hoy".
- Cliente mora 45: debe aparecer en "Mora 45" con accion "Llamar al cliente".
- Cliente bloqueado 60: debe aparecer en "Bloqueados 60", prioridad critica y accion "No fiar mas sin autorizacion".
- Cliente al dia con saldo: debe aparecer como saldo dentro de plazo y baja/media prioridad segun monto y score.
- Mensaje WhatsApp por estado: debe abrir WhatsApp con texto preparado; si no abre, debe copiar el mensaje.
- Multi-negocio: un negocio no debe ver ciclos/clientes de otro `negocio_id`.
- Score/riesgo: si existe `client_scores`, la tarjeta debe mostrar score y riesgo.

## Resultado Esperado

- La pantalla carga sin romper si no hay datos.
- Los botones "Ver cliente" y "Mensaje WhatsApp" funcionan.
- El Dashboard Ejecutivo muestra KPIs y noticias de cobranza.
- No se modifica backend ni sincronizacion cloud.
