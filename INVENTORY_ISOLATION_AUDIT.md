# Inventory Isolation Audit

- Fecha: 2026-06-11T14:56:45.625786
- Base SQLite: `C:\Users\eric_\fiado_app\qa_data\device_inventory_isolation.db`
- Total productos: 0
- Productos activos: 0
- Productos con `negocio_id` null/0: 0
- Imagenes huerfanas: 0
- Metricas huerfanas: 0

## Regla

Los productos no son globales. Cada producto pertenece exclusivamente a un negocio.

## Productos Por Negocio

| negocio_id | total | activos |
| --- | ---: | ---: |

## Visibilidad Por Negocio

| negocio_id | negocio | productos visibles |
| ---: | --- | ---: |
| 1 | Colmado Eric - Eric | 0 |

## Productos Globales Detectados

| id | nombre | codigo | negocio_id | activo |
| ---: | --- | --- | --- | ---: |
| - | ninguno | - | - | - |

## Sync Queue Productos

| entity_type | status | total |
| --- | --- | ---: |
| ninguno | - | 0 |
