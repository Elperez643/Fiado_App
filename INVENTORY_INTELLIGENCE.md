# Inventario Inteligente v1

Inventario Inteligente calcula indicadores locales desde SQLite. No usa IA
externa, machine learning ni backend para el calculo v1.

## Datos Usados

- `productos`
- `deuda_items`
- `movimientos`
- `producto_imagenes` solo para miniaturas visuales
- `inventory_product_metrics` como cache/resumen local incremental

## Formulas

Valor costo inventario:

```text
stock_actual * costo_unitario
```

Valor venta inventario:

```text
stock_actual * precio_venta
```

Ganancia potencial:

```text
valor_venta - valor_costo
```

Promedio diario:

```text
cantidad vendida en los ultimos 30 dias / 30
```

Cobertura:

```text
stock_actual / promedio_diario
```

Si el promedio diario es 0, la cobertura queda como `Sin datos`.

Reposicion sugerida:

```text
stock_objetivo = promedio_diario * 15 dias
reposicion = max(0, stock_objetivo - stock_actual)
```

## Estados

Prioridad:

1. `agotado`: stock <= 0
2. `critico`: cobertura <= 3 dias
3. `bajo_stock`: stock > 0 y stock <= stock_minimo
4. `sin_movimiento`: sin venta/movimiento en 30 dias o mas
5. `sobre_stock`: cobertura >= 60 dias y stock > stock_minimo
6. `normal`: ninguno de los anteriores

## Pantalla

`InventoryIntelligenceScreen` muestra:

- Valor costo inventario.
- Valor venta inventario.
- Ganancia potencial.
- Productos agotados.
- Productos criticos.
- Productos bajo stock.
- Reposicion sugerida total.
- Secciones de criticos, reposicion, sin movimiento, agotados, mayor ganancia
  potencial y sobre stock.

## Cache Incremental

La tabla `inventory_product_metrics` guarda un resumen por producto y negocio.
Cada registro tiene `dirty`:

- `dirty = 1`: el producto necesita recalculo.
- `dirty = 0`: la metrica cacheada esta lista para lectura rapida.

Se marca dirty cuando cambia producto, stock, deuda_items o sync pull de datos
relacionados. La pantalla usa cache como fuente principal y recalcula solo
productos dirty en lotes.

Boton manual:

- `Actualizar metricas` recalcula el negocio por lotes.

## Performance

El servicio usa `inventory_product_metrics` para lecturas normales. El calculo
inicial y los recalculos dirty usan consultas agregadas por lotes sobre
`deuda_items` y `movimientos`.
Los indices recomendados son:

- `productos(negocio_id, activo, cantidad)`
- `productos(negocio_id, activo, stock_minimo)`
- `deuda_items(negocio_id, producto_id)`
- `movimientos(negocio_id, fecha DESC)`

## Limitaciones

- No sincroniza `InventoryInsight` como entidad.
- Se recalcula localmente desde datos existentes.
- El promedio diario v1 usa ventana movil de 30 dias.
- En el futuro el backend puede recalcular los mismos snapshots para reportes
  cloud y comparacion multi-dispositivo.
