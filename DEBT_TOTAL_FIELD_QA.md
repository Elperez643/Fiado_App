# Debt Total Field QA

Validacion manual del campo `Monto total final` en `AgregarDeudaDialog`.

## Reglas Esperadas

- Si hay articulos, el subtotal de articulos llena automaticamente el campo.
- Si el usuario edita el campo, Fiado App respeta el monto escrito.
- Si el usuario borra el campo y hay articulos, al guardar usa el subtotal.
- Si no hay articulos, el monto total final es obligatorio y debe ser mayor a 0.
- El boton `Usar subtotal` restaura el total calculado desde articulos.

## Casos

### Caso A - 1 Articulo Sin Tocar Monto

1. Abrir un cliente.
2. Agregar deuda.
3. Seleccionar 1 producto con precio `1000`.
4. Agregar articulo.
5. Revisar `Monto total final`.
6. No editar `Monto total final`.
7. Guardar.

Resultado esperado: `Subtotal` muestra `RD$1,000.00`, `Monto total final`
se llena visualmente con `1,000` y la deuda guarda usando ese subtotal.

### Caso B - 3 Articulos Sin Tocar Monto

1. Agregar un articulo por `1000`.
2. Agregar un segundo articulo por `500`.
3. Revisar `Monto total final`.
4. Agregar un tercer articulo.
5. No editar `Monto total final`.
6. Guardar.

Resultado esperado: al segundo articulo, el subtotal cambia a `RD$1,500.00`
y `Monto total final` cambia visualmente a `1,500`. Al guardar usa la suma
de subtotales.

### Caso C - Monto Menor Al Subtotal

1. Agregar articulos.
2. Escribir `1200` como monto final.
3. Agregar otro articulo.
4. Guardar.

Resultado esperado: el subtotal cambia, pero `Monto total final` sigue en
`1200`. Guarda el monto escrito y registra abono inicial por la diferencia.

### Caso D - Monto Mayor Al Subtotal

1. Agregar articulos.
2. Escribir un monto final mayor al subtotal.
3. Tocar `Usar subtotal`.
4. Guardar.

Resultado esperado: `Monto total final` vuelve al subtotal actual y se oculta
el ajuste manual. Si no se toca `Usar subtotal`, guarda el monto escrito y
muestra ajuste adicional.

### Caso E - Campo Borrado Con Articulos

1. Agregar articulos.
2. Borrar `Monto total final`.
3. Guardar.

Resultado esperado: usa el subtotal de articulos y guarda sin error.

### Caso E2 - Monto Con Coma

1. Agregar articulos.
2. Escribir `1,500.50` en `Monto total final`.
3. Guardar.

Resultado esperado: parsea correctamente `1500.50` y guarda.

### Caso F - Deuda Manual Sin Monto

1. No agregar articulos.
2. Dejar `Monto total final` vacio.
3. Guardar.

Resultado esperado: muestra `El monto total debe ser mayor a 0.`

### Caso G - Deuda Manual Con Monto

1. No agregar articulos.
2. Escribir un monto mayor a 0.
3. Guardar.

Resultado esperado: guarda la deuda manual normalmente.
