# Billable Products Regression QA

## Fuente Unica

`AgregarDeudaDialog` no debe usar `productosProvider`, `productoBusquedaProvider`,
`InventarioScreen`, metricas de inventario ni dashboard para seleccionar
articulos.

La fuente estable es:

- Modelo: `BillableProduct`
- Consulta compartida: `BillableProductQuery.obtenerProductosFacturables`
- Repositorio: `ProductoRepository.obtenerProductosFacturables`
- Provider: `billableProductsProvider`

## Casos Manuales

- Crear producto nuevo con stock.
- Abrir deuda inmediatamente: seccion articulos activa.
- Seleccionar producto: trae precio de venta.
- Agregar articulo y guardar deuda.
- Volver a abrir deuda: seccion articulos sigue activa si quedan productos con stock.
- Refresh inventario no rompe selector.
- Cambiar busqueda/listado de inventario no rompe selector.
- Abrir Inventario Inteligente no rompe selector.
- Producto sin imagen aparece como facturable si tiene stock.
- Producto con stock 0 no aparece.
- Producto inactivo no aparece.
- Producto de otro negocio no aparece.
- Login/logout no rompe selector.
- Ventas futura debe reutilizar `billableProductsProvider`.

## QA Automatizada

Ejecutar:

```cmd
dart run tools\qa\run_billable_products_regression.dart
```

Valida en una base SQLite temporal:

- producto activo con stock aparece.
- producto sin imagen aparece.
- producto stock 0 no aparece.
- producto inactivo no aparece.
- producto de otro negocio no aparece.
- busqueda/listado visual no afecta facturables.
- metricas de inventario no afectan facturables.
