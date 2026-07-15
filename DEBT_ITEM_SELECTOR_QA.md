# Debt Item Selector QA

Validacion manual del reinicio del selector de productos en `AgregarDeudaDialog`.

## Caso A - Primer Articulo

1. Abrir un cliente.
2. Agregar deuda.
3. Seleccionar un producto.
4. Tocar `Agregar articulo`.

Resultado esperado:

- El producto aparece en la lista de mercancias.
- El selector vuelve a `Selecciona un producto`.
- Precio unitario vuelve a `0.00`.
- Cantidad vuelve a `1`.
- `Subtotal actual` vuelve a `RD$0.00`.
- `Monto total final` mantiene el total acumulado.

## Caso B - Segundo Producto

1. Despues del Caso A, seleccionar otro producto.
2. Tocar `Agregar articulo`.

Resultado esperado:

- El segundo producto se suma al total.
- El selector vuelve a quedar en blanco.
- El monto total final sigue sincronizado si no fue editado manualmente.

## Caso C - Monto Manual

1. Agregar un producto.
2. Editar `Monto total final`.
3. Agregar otro producto.

Resultado esperado:

- El selector se limpia.
- El subtotal acumulado cambia.
- El monto manual no se sobrescribe.

## Caso D - Sin Producto

1. Dejar el selector en blanco.
2. Revisar el boton `Agregar articulo`.

Resultado esperado: el boton queda desactivado hasta seleccionar un producto valido.
