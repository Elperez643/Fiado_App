# Personal Debt Guidance

Fiado App incluye una seccion voluntaria para usuario Personal llamada
`Recordatorios de pago`.

## Objetivo

Ayudar al usuario Personal a ver sus saldos pendientes por negocio y recibir
consejos suaves para ordenar pagos, sin exponer informacion interna del negocio.

## Datos Visibles

- Nombre del negocio.
- Monto pendiente vinculado al telefono del usuario Personal.
- Fecha de deuda mas antigua.
- Fecha limite 30 dias mas cercana.
- Estado suave de la deuda.
- Prioridad orientativa.
- Ultimo pago visible.
- Comprobantes propios si existen.

## Estados

- `al_dia`: existe saldo, pero no esta cerca de vencer.
- `por_vencer`: la fecha limite esta cerca.
- `vencido_30`: el ciclo paso la fecha de 30 dias.
- `mora_45`: el ciclo paso la fecha de 45 dias.
- `bloqueado_60`: el ciclo paso la fecha de 60 dias.
- `saldo_pendiente`: estado generico de respaldo.

## Prioridades

- `baja`
- `media`
- `alta`
- `critica`

La prioridad sirve para ordenar pagos. No bloquea acciones y no califica al
usuario con lenguaje negativo.

## Privacidad

El servicio filtra por el telefono autenticado del usuario Personal. No muestra
inventario, informacion interna de clientes, reportes de negocio ni score
interno completo.

## Limites

No envia notificaciones push, WhatsApp automatico ni recordatorios externos.
La pantalla solo aparece cuando el usuario entra voluntariamente.
