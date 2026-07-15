# Debt Items Receipt QA

## Objetivo

Validar que las mercancias de una deuda se guarden, se consulten y se muestren en el popup de deuda, ComprobanteScreen, PDF y sync_queue.

## Casos Principales

### A. 1 articulo, monto final vacio

- Crear deuda con 1 articulo.
- Dejar `Monto total final` vacio.
- Resultado esperado:
  - `movimiento.monto` usa subtotal de articulos.
  - Popup muestra el articulo.
  - Comprobante muestra el articulo.
  - PDF muestra el articulo.

### B. 3 articulos, monto final vacio

- Crear deuda con 3 articulos.
- Dejar `Monto total final` vacio.
- Resultado esperado:
  - Popup muestra 3 articulos.
  - Comprobante muestra 3 articulos.
  - PDF muestra 3 articulos.

### C. Articulos con monto final manual

- Crear deuda con articulos.
- Escribir monto final distinto al subtotal.
- Resultado esperado:
  - `movimiento.monto` usa monto manual.
  - `deuda_items` se mantienen completos.
  - Popup muestra subtotal mercancias, ajuste y monto final.
  - Comprobante/PDF muestran items y monto final.

### D. Deuda manual sin articulos

- Crear deuda sin articulos.
- `Monto total final` es obligatorio.
- Resultado esperado:
  - Popup muestra `Esta deuda no tiene mercancias registradas.`
  - Comprobante no falla.

### E. Refrescar y reabrir

- Crear deuda con articulos.
- Refrescar cliente o cerrar/abrir app.
- Abrir la deuda otra vez.
- Resultado esperado:
  - Los articulos siguen apareciendo porque se consultan por `movimiento_id` SQLite.

### F. Sync queue

- Crear deuda con articulos.
- Revisar sync_queue.
- Resultado esperado:
  - Existe evento para movimiento.
  - Existen eventos para deuda_items.
  - Si hubo abono inicial, existe movimiento tipo `pago` informativo.

## Casos de Abono Inicial

### H. Subtotal 1000, monto final vacio

- Resultado: deuda 1000, abono 0.

### I. Subtotal 1000, monto final 700

- Resultado:
  - deuda 700.
  - abono inicial 300.
  - historial muestra deuda 700 y pago informativo 300 relacionado por concepto.
  - saldo pendiente real queda 700.
  - comprobante muestra mercancias 1000, abono 300, pendiente 700.

### J. Subtotal 1000, monto final 1000

- Resultado: deuda 1000, abono 0.

### K. Subtotal 1000, monto final 1200

- Resultado:
  - deuda 1200.
  - abono 0.
  - ajuste adicional 200.

### L. Subtotal 1000, monto final 0

- Resultado:
  - se pide confirmacion.
  - mercancia registrada.
  - pago informativo 1000.
  - deuda pendiente 0.

## Decision Tecnica

La relacion local usa `movimiento.id` SQLite como llave principal:

- `deuda_items.movimiento_id = movimientos.id`
- `comprobantes.movimiento_id = movimientos.id`

El abono inicial se registra como movimiento tipo `pago` informativo con concepto `Abono inicial del fiado #[id]`. No se aplica de nuevo al ciclo para evitar reducir dos veces el saldo, porque la deuda ya se guarda por el monto final fiado.
