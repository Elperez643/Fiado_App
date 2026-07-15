# Fiado App Stress Test Plan

## Objetivo

Validar que SQLite offline-first, `sync_queue`, backend ASP.NET Core y SQL Server soporten crecimiento gradual antes de iOS y pagos reales, sin tocar datos de produccion ni cambiar reglas de negocio.

## Datos de prueba

Usar datos artificiales con prefijo `QA` en una base separada:

```bash
dart run tools/qa/generate_stress_sqlite_data.dart --clients=1000 --products=500 --movements=3000 --debt-items=3000 --audits=50 --reset
dart run tools/qa/benchmark_sqlite_queries.dart --db=qa_data/fiado_stress_test.db
```

Ejecutar todas las escalas y generar `STRESS_TEST_RESULTS.md`:

```bash
dart run tools/qa/run_progressive_stress_test.dart
```

Para SQL Server, usar `tools/qa/generate_stress_sql_server.sql` solo contra una DB local/QA. El script hace `ROLLBACK` por defecto.

## Escenarios

| Escenario | Clientes | Productos | Movimientos | Deuda items | Auditorias | Objetivo |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| S1 | 1,000 | 500 | 3,000 | 3,000 | 50 | Flujo diario fluido en Android economico |
| S2 | 10,000 | 2,000 | 30,000 | 30,000 | 500 | Negocio con historial amplio |
| S3 | 50,000 | 5,000 | 150,000 | 150,000 | 2,500 | Limite alto para offline local |
| S4 | 100,000 | 10,000 | 300,000 | 300,000 | 5,000 | Prueba de techo; requiere paginacion estricta |

## Orden de prueba

1. Crear base QA SQLite o SQL Server disposable.
2. Ejecutar benchmark SQLite.
3. Abrir app con usuario QA.
4. Validar Login, Principal, Clientes, Inventario, SyncStatus, BackendSettings y Suscripcion.
5. Ejecutar sincronizacion manual en orden: clientes, productos, imagenes, movimientos/deuda_items, comprobantes, ciclos, auditorias/audit_items, solicitudes.
6. Cortar red/backend durante un push y confirmar que no borra datos locales.
7. Reintentar con backend activo y confirmar `attempts`, `last_error` y `sync_status`.

## Criterios de aceptacion

| Area | S1 | S2 | S3 | S4 |
| --- | ---: | ---: | ---: | ---: |
| Carga pagina clientes 50 filas | < 150 ms | < 250 ms | < 500 ms | < 800 ms |
| Busqueda clientes | < 250 ms | < 500 ms | < 1,200 ms | < 2,000 ms |
| Carga pagina productos 50 filas | < 150 ms | < 250 ms | < 500 ms | < 800 ms |
| Ultimos 100 movimientos | < 250 ms | < 500 ms | < 1,000 ms | < 1,500 ms |
| Sync push lote 500 | < 10 s | < 15 s | < 25 s | < 40 s |
| Memoria app Android | < 220 MB | < 300 MB | < 450 MB | < 650 MB |

## Validaciones especificas

- Paginacion: clientes y productos deben cargar por paginas de 50; movimientos no debe crecer sin limite en pantallas principales.
- Busquedas: probar nombre, telefono, codigo de producto y categoria.
- SQLite: confirmar indices con `PRAGMA index_list(tabla)` y `EXPLAIN QUERY PLAN`.
- SQL Server: confirmar indices para `BusinessId`, `UpdatedAt`, `RemoteId`, `ClientId`, `Date` y codigos unicos por negocio.
- Backend: revisar endpoints `sync/pull` para evitar respuestas masivas cuando `lastSyncAt` existe.
- Riverpod: confirmar que providers con listas grandes no recalculen resumenes sobre colecciones completas en cada rebuild.

## Riesgos por escenario

- 1,000 clientes: esperado estable.
- 10,000 clientes: estable si se mantiene paginacion; cuidado con movimientos cargados a 10,000.
- 50,000 clientes: requiere busqueda paginada real y evitar listas completas en memoria.
- 100,000 clientes: no recomendable como modo offline completo sin indices adicionales, busqueda incremental y limpieza/archivo de historial.
