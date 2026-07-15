# QA Phase Report

## Resumen

La arquitectura actual soporta una fase inicial de crecimiento con SQLite offline-first, `sync_queue` y backend por negocio. Clientes y productos ya usan paginacion local; sincronizacion cloud existe por modulos y el backend mantiene filtros por `BusinessId`.

## Capacidad estimada

| Volumen | Evaluacion |
| --- | --- |
| 1,000 clientes | Listo para QA funcional y pruebas manuales completas. |
| 10,000 clientes | Viable; dashboard 20 ms y busquedas 2-3 ms. |
| 50,000 clientes | Viable en SQLite; movimientos por cliente sube a 65 ms. |
| 100,000 clientes | Viable para consultas paginadas; dashboard 61 ms y DB 241.80 MB despues del indice. |

## Correcciones/herramientas creadas

- `tools/qa/generate_stress_sqlite_data.dart`: genera clientes, productos, movimientos, deuda_items y auditorias en DB QA.
- `tools/qa/benchmark_sqlite_queries.dart`: mide consultas SQLite criticas y consumo aproximado.
- `tools/qa/run_progressive_stress_test.dart`: ejecuta escalas 1,000, 10,000, 50,000 y 100,000 clientes y genera `STRESS_TEST_RESULTS.md`.
- `tools/qa/generate_stress_sql_server.sql`: script SQL Server seguro por defecto con `ROLLBACK`.
- `tools/qa/README.md`: instrucciones de uso.
- `STRESS_TEST_PLAN.md`: plan por 1,000, 10,000, 50,000 y 100,000 clientes.
- `PERFORMANCE_REPORT.md`: metricas, hallazgos e indices revisados.
- `BUG_FIX_CANDIDATES.md`: backlog tecnico antes de iOS y pagos reales.

## Cuellos de botella encontrados

- Movimientos se cargan en memoria con `limit: 10000` desde el provider principal.
- Busquedas con `LIKE %texto%` no escalan bien para 50,000+ registros.
- Inventario conserva un respaldo legacy que puede duplicar IO/memoria al guardar productos.
- Pull sync sin paginacion por lote puede devolver demasiada data si `lastSyncAt` es antiguo.
- SQL Server necesita indices futuros por `(BusinessId, UpdatedAt)` y posiblemente `RemoteId`.
- Stress progresivo: `movimientos_by_client_100` subio a 129 ms en 100,000 clientes antes del indice.
- Optimizacion aplicada: indice `idx_movimientos_negocio_cliente_telefono_fecha` sobre `movimientos(negocio_id, cliente_telefono, fecha DESC)`.
- Resultado despues del indice: `movimientos_by_client_100` bajo a 0 ms en 100,000 clientes.
- Stress progresivo: `insert_audits_ms` fue el mayor tiempo de carga QA, 627,269 ms para 5,000 auditorias. No bloquea lectura diaria, pero indica que bulk insert de auditorias debe optimizarse si se importan historiales.

## Riesgos antes de iOS

- Validar plugins con permisos nativos: imagenes, archivos PDF/printing/share y almacenamiento local.
- Verificar rutas de imagen offline al migrar entre plataformas.
- Medir memoria real en iPhone/iPad con bases de 10,000 clientes.
- Confirmar configuracion HTTPS/baseUrl productiva y certificados.

## Riesgos antes de pagos reales

- Se necesita idempotencia backend para evitar cobros duplicados.
- Se debe persistir estado de transaccion de proveedor y webhook confirmado.
- No guardar secretos de proveedor en SQLite ni en appsettings versionados.
- Requiere conciliacion: pago local pendiente vs pago confirmado por proveedor.

## Estado de verificacion

- `dotnet build backend/FiadoApp.Backend.sln --no-restore`: limpio, 0 warnings, 0 errores.
- `flutter analyze`: limpio, 0 issues.
- Scripts QA SQLite: generacion y benchmark OK con 100 clientes, 50 productos, 200 movimientos, 200 deuda_items y 5 auditorias.
- Benchmark SQLite inicial: pagina clientes 50 filas en 6 ms, busqueda clientes en 1 ms, ultimos 100 movimientos en 3 ms, DB 0.45 MB.
- Stress progresivo completo: OK en 1,000, 10,000, 50,000 y 100,000 clientes.
- 100,000 clientes antes del indice: DB 226.51 MB, page 50 6 ms, busqueda nombre 3 ms, movimientos por cliente 129 ms, dashboard 97 ms.
- 100,000 clientes despues del indice: DB 241.80 MB, page 50 4 ms, busqueda nombre 2 ms, movimientos por cliente 0 ms, dashboard 61 ms.
- `dotnet build backend/FiadoApp.Backend.sln --no-restore`: limpio, build succeeded.
- Benchmark runtime en dispositivo: pendiente, requiere correr escenarios en equipo objetivo.

## QA Motor Inteligente

Artefactos creados:

- `CLIENT_SCORE_QA_CHECKLIST.md`.
- `tools/qa/run_client_score_qa.dart`.
- Base QA separada generada en `qa_data/client_score_qa.db`.

Resultados A-E:

| Caso | Score | Riesgo | Limite | Observacion |
| --- | ---: | --- | ---: | --- |
| A Excelente | 100 | Bajo riesgo | 1800.00 | Pagos antes de 30 dias y cumplimiento 100%. |
| B Regular | 55 | Riesgo medio | 1215.00 | Pagos 30-45 y cumplimiento parcial. |
| C Mora | 34 | Riesgo alto | 375.00 | Vencido 30, mora 45 y saldo pendiente. |
| D Bloqueado | 30 | Riesgo alto | 200.00 | Bloqueo 60 con limite muy bajo. |
| E Nuevo | 50 | Riesgo medio | 0.00 | Sin historial; recomendacion conservadora. |

Correccion aplicada:

- Se ajusto el calculo del limite sugerido para clientes con mora o bloqueo:
  bloqueo 60 limita el credito sugerido a un valor muy bajo, sin cambiar el
  algoritmo de score ni los niveles de riesgo.

Validaciones:

- `ClientScoreScreen` usa lenguaje `Fiado App recomienda`.
- No se encontro texto `Fiado App prohibe/prohíbe`.
- `ClientScoreReportScreen` mantiene top mejores y top riesgo por score.
- El script QA persistio 5 scores y encolo 5 items en `sync_queue`.
- `flutter analyze`: limpio.
- `dotnet build backend\FiadoApp.Backend.sln --no-restore`: limpio.
- `flutter build apk --debug`: limpio.
- APK QA: `dist\fiado_app_client_score_qa_debug.apk`.

## Live Sync ClientScore

Prueba realizada contra backend ASP.NET Core + SQL Server:

- Backend: `http://127.0.0.1:5197/api`.
- Negocio usado: `QA Score Live 0530165948921`.
- BusinessId: `619b7a8a-d757-4f0b-bb0b-05784adb2cf6`.
- Cliente usado: `Cliente Score Live 0530165948921`.
- ClientId: `9d802807-f785-4eb3-b9da-a069bc35441c`.

Score sincronizado:

- Score: `88`.
- RiskLevel: `Bajo riesgo`.
- SuggestedCreditLimit: `1500.00`.
- PaymentCompliancePercent: `95.00`.
- TotalCredits: `3000.00`.
- TotalPayments: `2850.00`.

Evidencia:

- Push `POST /api/client-scores/sync/push`: status `created`.
- ServerId: `24a3b55c-4d47-4b1d-9dc1-eb4cfa2e3601`.
- Pull `POST /api/client-scores/sync/pull`: devolvio 1 score con los mismos
  valores.
- SQL Server `ClientScores` contiene el registro con BusinessId y ClientId
  correctos.
- Un segundo negocio (`b34098a1-f1a4-4b08-b5a4-aade5676c03b`) recibio 0 scores,
  validando que no hay mezcla de negocios.

Estado:

- Sync cloud live del Motor Inteligente: validado.
- APK live sync: `dist\fiado_app_client_score_live_sync_debug.apk`.
