# Agregar Deuda con Articulos QA

## Objetivo

Validar que `AgregarDeudaDialog` permita registrar deudas manuales y deudas con articulos sin bloquear el total ni ocultar la seccion de inventario.

## Casos

- Abrir deuda con productos disponibles: la seccion `Agregar articulos` se ve y el selector esta activo.
- Seleccionar producto: trae `precio_venta` automaticamente como precio unitario.
- Cambiar cantidad a 2: el subtotal se calcula como `cantidad * precio_unitario`.
- Agregar varios productos: el total se calcula en vivo desde la suma de subtotales.
- Editar `Monto total` manualmente con articulos agregados: el valor se conserva y aparece `Recalcular total desde articulos`.
- Eliminar un producto con total manual: el sistema no sobrescribe el monto hasta tocar `Recalcular total desde articulos`.
- Tocar `Recalcular total desde articulos`: el monto vuelve a coincidir con la suma de subtotales.
- Guardar deuda con articulos: crea movimiento, deuda_items, comprobante y descuenta stock.
- Guardar deuda manual sin articulos: crea movimiento y comprobante sin items.
- Producto con precio 0: muestra advertencia suave y permite corregir precio unitario.
- Producto sin imagen: se puede agregar normalmente.
- Refresh inventario: confirma que el stock se desconto.
- Selector no muestra productos de otro negocio.
- Selector no permite productos con stock 0.
- Comprobante muestra articulos, subtotales y total del movimiento.
- Ciclo de credito se crea o actualiza segun reglas 30/45/60.

## Resultado Esperado

- La seccion de articulos no desaparece.
- La deuda manual sigue funcionando.
- La deuda con articulos permite ajuste manual del total.
- El inventario, comprobantes, ciclos de credito y sync_queue siguen funcionando.
