# Bug Fix Candidates

## Riesgos principales

| Prioridad | Area | Riesgo | Candidato de correccion |
| --- | --- | --- | --- |
| Alta | Movimientos | `MovimientosNotifier` carga hasta 10,000 filas en memoria. | Implementar estado paginado similar a clientes/productos. |
| Resuelto | Movimientos | `movimientos_by_client_100` subio a 129 ms con 100,000 clientes. | Agregado indice SQLite `idx_movimientos_negocio_cliente_telefono_fecha`. |
| Alta | Sync pull | Respuestas grandes si `lastSyncAt` es nulo o viejo. | Agregar paginacion por lote en contratos pull. |
| Alta | SQL Server | Falta indice uniforme por `(BusinessId, UpdatedAt)` en entidades sincronizadas. | Migracion futura solo de indices. |
| Media | Busqueda | `LIKE %texto%` en clientes/productos degrada a scans en volumen alto. | Busqueda por prefijo, FTS local o normalizacion de columnas. |
| Media | Inventario | Respaldo legacy lee hasta 10,000 productos despues de cambios. | Eliminar dependencia legacy cuando SQLite sea unica fuente local. |
| Media | Auditorias | Conteo de diferencias usa subquery por auditoria. | Cambiar a `JOIN/GROUP BY` si reporte supera 100 auditorias. |
| Media | Sync queue | Indice actual no incluye `attempts` ni `updated_at`. | Evaluar indice `(status, entity_type, updated_at)` para reintentos. |
| Baja | Providers | Resumen inventario recalcula sobre lista visible. | Separar resumen agregado desde query SQLite si se requiere total global. |
| Baja | Web | SQLite web compila pero runtime definitivo requiere estrategia propia. | Evaluar `sqflite_common_ffi_web` o IndexedDB. |

## Antes de iOS

- Confirmar soporte de `sqflite`, `image_picker`, `path_provider`, `printing` y permisos de archivos.
- Medir memoria en dispositivo fisico con 10,000 clientes.
- Confirmar que rutas de imagen local no dependan de paths Android-only.
- Validar baseUrl en red local y HTTPS productivo.

## Antes de pagos reales

- No depender solo de sync offline para confirmar cobros.
- Separar estados de pago local, pendiente proveedor, confirmado y fallido.
- Evitar duplicidad con idempotency keys en backend.
- Registrar auditoria de pagos y webhooks antes de mover dinero real.
- Cifrar/ocultar datos sensibles y nunca guardar secretos de proveedor en SQLite.
