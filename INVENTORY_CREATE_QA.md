# Inventory Create QA

Checklist manual para validar creacion de articulos de inventario despues de
corregir la validacion de duplicados.

## Caso Principal

- Crear producto nuevo con nombre `prueba2`.
- Usar codigo de referencia `pWHoJ2`.
- Guardar sin imagen y confirmar que no aparece pantalla roja.
- Confirmar que el producto aparece inmediatamente en Inventario.
- Pulsar refresh y confirmar que el producto se mantiene visible.
- Buscar por `prueba2` y confirmar que aparece.
- Buscar por `pWHoJ2` y confirmar que aparece.
- Buscar por categoria si se completo una categoria y confirmar que aparece.

## Duplicados

- Intentar crear otro producto activo con nombre `prueba2` en el mismo negocio.
- Esperado: mostrar `Ya existe un articulo con ese nombre o codigo de referencia
  en este negocio.`
- Intentar crear otro producto activo con codigo `pWHoJ2` en el mismo negocio.
- Esperado: mostrar el mismo mensaje de duplicado.
- Crear un producto sin codigo de referencia.
- Esperado: solo se valida duplicado por nombre, sin error SQL.

## Actualizacion

- Editar un producto existente sin cambiar nombre/codigo.
- Esperado: se guarda correctamente porque la consulta excluye el producto
  actual.
- Editar un producto para usar nombre o codigo de otro producto activo.
- Esperado: mostrar mensaje de duplicado.

## Imagen Opcional

- Crear producto sin imagen.
- Crear producto con 1 imagen optimizada.
- Crear producto con 3 imagenes optimizadas.
- Intentar crear producto con 4 imagenes.
- Esperado: bloquear con error claro antes de guardar.

## Resultado Esperado

- No debe aparecer `DatabaseException(near ")": syntax error)`.
- La consulta de duplicados debe usar parentesis para agrupar nombre/codigo.
- Los argumentos SQL deben coincidir exactamente con los placeholders.
- El listado, refresh y busqueda deben leer desde SQLite actualizado.
