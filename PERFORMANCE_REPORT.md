# Fiado App Performance Report

## Estado de medicion

Esta fase deja medicion reproducible sin tocar datos reales. Los numeros finales por dispositivo deben capturarse con:

```bash
dart run tools/qa/generate_stress_sqlite_data.dart --clients=1000 --products=500 --movements=3000 --debt-items=3000 --audits=50 --reset
dart run tools/qa/benchmark_sqlite_queries.dart --db=qa_data/fiado_stress_test.db
```

## Medicion inicial QA SQLite

Ejecutado en Windows con una muestra pequena:

```bash
dart run tools/qa/generate_stress_sqlite_data.dart --clients=100 --products=50 --movements=200 --debt-items=200 --audits=5 --reset
dart run tools/qa/benchmark_sqlite_queries.dart --db=qa_data/fiado_stress_test.db
```

| Metrica | Resultado |
| --- | ---: |
| clientes_count | 12 ms |
| clientes_page_50 | 6 ms |
| clientes_search_limit_50 | 1 ms |
| productos_page_50 | 2 ms |
| productos_code_lookup | 0 ms |
| movimientos_latest_100 | 3 ms |
| deuda_items_by_movement | 0 ms |
| audits_report_100 | 0 ms |
| SQLite size | 0.45 MB |
| RSS proceso benchmark | 227.77 MB |

Nota: el RSS pertenece al proceso Dart que ejecuta el benchmark con hooks nativos, no equivale al consumo de la app Flutter en Android/iOS.

## Stress progresivo

Se agrego `tools/qa/run_progressive_stress_test.dart` para ejecutar automaticamente las escalas de 1,000, 10,000, 50,000 y 100,000 clientes. El runner genera bases separadas en `qa_data/stress_<clientes>.db`, mide consultas principales y escribe `STRESS_TEST_RESULTS.md`.

Metricas incluidas:

- Insercion de clientes, productos, movimientos, deuda_items, ciclos y `sync_queue`.
- Carga de pagina 50 y pagina 100.
- Busqueda por nombre y telefono.
- Movimientos por cliente.
- Conteo de cuentas por cobrar y ciclos vencidos.
- Conteo de `sync_queue` pendiente.
- Lectura tipo dashboard.
- Tamano de DB y memoria RSS del proceso benchmark.

Resultados completos:

| Clientes | Insert clientes | Movimientos insert | Deuda items insert | Auditorias insert | Page 50 | Search nombre | Movs cliente | CxC count | Sync pending | Dashboard | DB |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 256 ms | 460 ms | 339 ms | 6,154 ms | 6 ms | 3 ms | 2 ms | 1 ms | 0 ms | 13 ms | 2.67 MB |
| 10,000 | 1,340 ms | 3,288 ms | 2,900 ms | 61,580 ms | 7 ms | 3 ms | 17 ms | 2 ms | 1 ms | 20 ms | 22.77 MB |
| 50,000 | 6,111 ms | 19,540 ms | 16,764 ms | 299,418 ms | 6 ms | 3 ms | 65 ms | 7 ms | 3 ms | 51 ms | 112.61 MB |
| 100,000 | 10,567 ms | 33,984 ms | 31,944 ms | 627,269 ms | 6 ms | 3 ms | 129 ms | 14 ms | 6 ms | 97 ms | 226.51 MB |

Interpretacion:

- Las pantallas paginadas de clientes/productos se mantienen rapidas en 100,000 clientes.
- `movimientos_by_client_100` crecia de forma lineal antes del indice y fue optimizado con `idx_movimientos_negocio_cliente_telefono_fecha`.
- `dashboard_read` en 97 ms para 100,000 clientes sigue siendo aceptable para lectura SQLite pura.
- La generacion mas lenta fue auditorias/items; el costo viene del script de carga QA y de volumen de inserts, no de lectura interactiva.

## Resultado tras indice de movimientos

Indice agregado:

```sql
CREATE INDEX IF NOT EXISTS idx_movimientos_negocio_cliente_telefono_fecha
ON movimientos(negocio_id, cliente_telefono, fecha DESC);
```

Nuevo stress test:

| Clientes | Movs cliente antes | Movs cliente despues | Dashboard despues | DB despues |
| ---: | ---: | ---: | ---: | ---: |
| 1,000 | 2 ms | 0 ms | 11 ms | 2.74 MB |
| 10,000 | 17 ms | 0 ms | 10 ms | 24.27 MB |
| 50,000 | 65 ms | 0 ms | 31 ms | 120.22 MB |
| 100,000 | 129 ms | 0 ms | 61 ms | 241.80 MB |

La consulta objetivo quedo resuelta en el benchmark SQLite. El tamano de DB sube ligeramente por el indice adicional.

## Metricas a medir

| Metrica | Metodo | Resultado esperado S1 | Observacion |
| --- | --- | ---: | --- |
| Tiempo carga clientes | Query paginada 50 filas | < 150 ms | Repositorio ya pagina por defecto |
| Tiempo busqueda clientes | `LIKE` por nombre/telefono con limit 50 | < 250 ms | `LIKE %texto%` no aprovecha indice completo |
| Tiempo carga productos | Query paginada 50 filas | < 150 ms | Repositorio ya pagina por defecto |
| Tiempo busqueda productos | nombre/categoria/codigo con limit 50 | < 250 ms | Codigo exacto seria mas eficiente que `LIKE` |
| Tiempo carga movimientos | Ultimos 100 o 10,000 segun pantalla | < 250 ms para 100 | Provider actual pide hasta 10,000 |
| Tiempo sync | Lote pendiente por modulo | < 10 s por 500 items | Depende de backend/red y tamano de payload |
| Memoria aproximada | `ProcessInfo.currentRss`, DevTools en app | < 220 MB S1 | Medir tambien en Android real |
| Consumo SQLite | Tamano `.db` + WAL | < 80 MB S1 | Crece con comprobantes/payload_json |

## Hallazgos actuales

- Clientes: `ClienteRepository.obtenerClientes` usa `limit`, `offset`, filtro por `negocio_id` y `is_active`.
- Productos: `ProductoRepository.obtenerProductos` usa `limit`, `offset`, filtro por `negocio_id` y `activo`.
- Movimientos: `MovimientosNotifier.build` solicita `limit: 10000`; esto es aceptable temporalmente, pero se vuelve cuello de botella con 50,000+ movimientos.
- Inventario legacy: `ProductosNotifier._actualizarRespaldoLegacy` lee hasta 10,000 productos para `StorageService`; puede duplicar memoria y trabajo de IO.
- Auditorias: reporte usa subquery por auditoria para contar diferencias. Con `LIMIT 100` es razonable; para reportes grandes conviene agregacion con `JOIN/GROUP BY`.
- Sync pull backend: usa `UpdatedAt` y `BusinessId`; conviene asegurar indices compuestos por modulo para cargas grandes.

## Indices revisados

SQLite ya tiene indices para:

- `clientes(nombre)`, `clientes(telefono)`, `clientes(negocio_id, telefono)`, `clientes(negocio_id, nombre)`.
- `productos(negocio_id, activo)`, `productos(negocio_id, nombre, activo)`, `productos(negocio_id, codigo_referencia, activo)`.
- `movimientos(negocio_id, fecha)`.
- `deuda_items(negocio_id, movimiento_id)`.
- `comprobantes(negocio_id, fecha)`.
- `auditorias(negocio_id, fecha)`, `auditoria_items(auditoria_id)`.
- `sync_queue(status, created_at)` y `sync_queue(entity_type, entity_id)`.

SQL Server ya define indices principales en EF para clientes, productos, movimientos, recibos, ciclos, auditoria items y sync logs. Faltan candidatos especificos para `RemoteId` y `UpdatedAt` por entidad de sync.

## Limites estimados

| Volumen | Estado estimado | Motivo |
| --- | --- | --- |
| 1,000 clientes | Bajo riesgo | Paginacion e indices existentes |
| 10,000 clientes | Riesgo moderado | Busqueda `LIKE %texto%` y movimientos 10,000 |
| 50,000 clientes | Viable con control | Consultas principales rapidas; vigilar movimientos, memoria y sync |
| 100,000 clientes | Viable para SQLite paginado, no para sync masivo | Consulta por movimientos optimizada; requiere lotes y prueba en dispositivo real |

## QA Motor Inteligente

Script ejecutado:

```bat
dart run tools\qa\run_client_score_qa.dart
```

Resultados:

| Caso | Cliente | Score | Riesgo | Limite sugerido | Resultado |
| --- | --- | ---: | --- | ---: | --- |
| A | Excelente | 100 | Bajo riesgo | 1800.00 | OK |
| B | Regular | 55 | Riesgo medio | 1215.00 | OK |
| C | Mora | 34 | Riesgo alto | 375.00 | OK |
| D | Bloqueado | 30 | Riesgo alto | 200.00 | OK |
| E | Nuevo | 50 | Riesgo medio | 0.00 | OK conservador |

Hallazgo corregido:

- El caso D bloqueado 60 calculaba riesgo alto, pero mantenia un limite
  sugerido demasiado alto. Se ajusto solo el tope del limite sugerido cuando
  existen mora 30/45 o bloqueo 60. El score y el nivel de riesgo no cambiaron.

Persistencia QA:

- `client_scores_rows`: 5.
- `sync_queue_pending_client_scores`: 5.
- Base QA separada: `qa_data/client_score_qa.db`.

## Benchmark Imagenes De Producto

El optimizador de imagenes de producto registra por cada seleccion:

- Resolucion original y optimizada.
- Peso original y optimizado.
- Calidad de compresion final.
- Porcentaje de ahorro de almacenamiento.

Estandar aplicado:

| Metrica | Valor |
| --- | --- |
| Resolucion final | 500 x 500 px |
| Formatos entrada | JPG, JPEG, PNG |
| Calidad JPG | Adaptativa 85, 80, 75, 70, 65 |
| Peso ideal | 120 KB a 200 KB |
| Peso aceptable | 200 KB a 300 KB |
| Peso maximo | 300 KB |

Formula de ahorro:

```text
ahorro = (1 - peso_optimizado / peso_original) * 100
```

Para QA manual, registrar 10 imagenes de producto y promediar:

| Metrica | Fuente |
| --- | --- |
| Promedio tamano original | `ProductOptimizedImageResult.originalSizeBytes` |
| Promedio tamano optimizado | `ProductOptimizedImageResult.optimizedSizeBytes` |
| Promedio calidad final | `ProductOptimizedImageResult.compressionQuality` |
| Promedio ahorro | `ProductOptimizedImageResult.savingsPercent` |

Resultado esperado:

- Imagenes grandes como 5 MB deben quedar en `500 x 500 px` y `<= 300 KB`.
- Imagenes medianas cercanas a 300 KB deben quedar en `500 x 500 px` dentro del
  rango 120-300 KB.
- Crear producto sin imagen sigue funcionando y no consume procesamiento.

## QA Inventario Inteligente

Script:

```bat
dart run tools\qa\run_inventory_intelligence_qa.dart
```

Escalas:

- 1,000 productos.
- 10,000 productos.
- 50,000 productos.

Metricas:

- Tiempo calculo insights.
- Tiempo productos criticos.
- Tiempo reposicion sugerida.
- Tiempo sin movimiento.
- Tamano aproximado SQLite.

Indices usados/recomendados:

- `productos(negocio_id, activo, cantidad)`.
- `productos(negocio_id, activo, stock_minimo)`.
- `deuda_items(negocio_id, producto_id)`.
- `movimientos(negocio_id, fecha DESC)`.

Desde la optimizacion cache/incremental, el script mide:

- Calculo inicial completo para llenar `inventory_product_metrics`.
- Recalculo incremental de 1 producto dirty.
- Recalculo incremental de 100 productos dirty.
- Carga de pantalla desde cache.
- Dashboard desde cache.

El script escribe `INVENTORY_INTELLIGENCE_QA_RESULTS.md` con los resultados de
cada escala. La meta principal es que la carga desde cache en 50,000 productos
quede por debajo de 500 ms y que el recalculo de 1 producto quede por debajo de
50 ms.
# Cobranza Inteligente v1

La v1 calcula insights desde SQLite con consulta agregada por cliente y usa indices nuevos en `credito_ciclos`:

- `idx_credito_ciclos_negocio_saldo_limite`
- `idx_credito_ciclos_negocio_estado_limites`

No se crea cache persistente todavia porque el modulo usa ciclos pendientes y no productos completos. Si la pantalla supera tiempos aceptables en negocios grandes, el siguiente paso recomendado es `collection_insights_cache` con recalculo incremental por cliente/ciclo.
# Business Copilot v1

Business Copilot usa cache local `business_recommendations_cache` para no recalcular todos los modulos en cada apertura. La primera carga puede recalcular Cobranza e Inventario Inteligente; cargas posteriores leen recomendaciones vigentes ordenadas por `score DESC`.

Indices agregados:

- `idx_business_recommendations_business_score`
- `idx_business_recommendations_business_type`
- `idx_business_recommendations_business_priority`

Riesgo pendiente: si el negocio tiene muchas recomendaciones descartadas, se recomienda limpiar cache expirado en una tarea futura.
