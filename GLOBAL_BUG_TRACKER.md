# Global Bug Tracker

## Estado

Auditoria preventiva de estabilidad global.

## Bugs corregidos en esta fase

| Severidad | Area | Causa | Correccion |
| --- | --- | --- | --- |
| Alta | QA CLI | Faltaban auditorias globales repetibles para detectar datos huerfanos, fugas multi-negocio y sync_queue falsa. | Se agregaron scripts QA dedicados para integridad global, aislamiento multi-negocio, regresion de flujo core y sync. |

## Riesgos vigilados por scripts

- Datos de negocio sin `negocio_id`.
- Movimientos activos sin `cliente_id`.
- Deuda items o comprobantes sin `movimiento_id` valido.
- Ciclos y scores huerfanos.
- Producto, imagenes y metricas mezcladas entre negocios.
- Colaboradores sin negocio o relacionados con otro negocio.
- `sync_queue` con entidades locales no soportadas, huerfanos o registros ya sincronizados que siguen abiertos.
- Rutas de recomendaciones basadas en telefono/nombre.

## Pendientes

- Ejecutar auditorias sobre una base real extraida del dispositivo despues de abrir la version actualizada de la app.
- Revisar manualmente flujos de UI que dependen de camara, WhatsApp y conectividad real.
- Confirmar endpoints cloud contra backend real con JWT vigente cuando corresponda.
