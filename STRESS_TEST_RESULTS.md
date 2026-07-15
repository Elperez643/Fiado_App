# Stress Test Results

Generated with `tools/qa/run_progressive_stress_test.dart`.

## Summary

| Clientes | Insert clientes ms | Page 50 ms | Page 100 ms | Search nombre ms | Search telefono ms | Movs cliente ms | CxC count ms | Vencidos ms | Sync pending ms | Dashboard ms | DB MB | Estado |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1000 | 164 | 6 | 2 | 2 | 2 | 0 | 0 | 1 | 0 | 11 | 2.74 | OK |
| 10000 | 1145 | 3 | 1 | 1 | 1 | 0 | 1 | 0 | 0 | 10 | 24.27 | OK |
| 50000 | 5487 | 4 | 2 | 2 | 1 | 0 | 4 | 0 | 2 | 31 | 120.22 | OK |
| 100000 | 10481 | 4 | 1 | 2 | 1 | 0 | 9 | 1 | 3 | 61 | 241.80 | OK |

## Raw Metrics

### 1000 clientes

- Generate exit code: `0`
- Benchmark exit code: `0`

| Metric | Value |
| --- | ---: |
| database | C:\Users\eric_\fiado_app\qa_data/stress_1000.db |
| clients | 1000 |
| products | 500 |
| movements | 3000 |
| debt_items | 3000 |
| credit_cycles | 1000 |
| sync_queue | 500 |
| audits | 50 |
| insert_clients_ms | 164 |
| insert_products_ms | 98 |
| insert_movements_ms | 379 |
| insert_debt_items_ms | 397 |
| insert_credit_cycles_ms | 149 |
| insert_sync_queue_ms | 83 |
| insert_audits_ms | 54 |
| size_mb | 2.74 |
| clientes_count | 14 |
| clientes_page_50 | 6 |
| clientes_page_100 | 2 |
| clientes_search_name_limit_50 | 2 |
| clientes_search_phone_limit_50 | 2 |
| productos_page_50 | 3 |
| productos_code_lookup | 2 |
| movimientos_latest_100 | 4 |
| movimientos_by_client_100 | 0 |
| deuda_items_by_movement | 0 |
| cuentas_por_cobrar_count | 0 |
| ciclos_vencidos_count | 1 |
| sync_queue_pending_count | 0 |
| audits_report_100 | 2 |
| dashboard_read | 11 |
| database_size_mb | 2.74 |
| process_rss_mb | 229.84 |

### 10000 clientes

- Generate exit code: `0`
- Benchmark exit code: `0`

| Metric | Value |
| --- | ---: |
| database | C:\Users\eric_\fiado_app\qa_data/stress_10000.db |
| clients | 10000 |
| products | 2000 |
| movements | 30000 |
| debt_items | 30000 |
| credit_cycles | 10000 |
| sync_queue | 5000 |
| audits | 500 |
| insert_clients_ms | 1145 |
| insert_products_ms | 231 |
| insert_movements_ms | 3758 |
| insert_debt_items_ms | 2829 |
| insert_credit_cycles_ms | 1412 |
| insert_sync_queue_ms | 529 |
| insert_audits_ms | 211 |
| size_mb | 24.27 |
| clientes_count | 11 |
| clientes_page_50 | 3 |
| clientes_page_100 | 1 |
| clientes_search_name_limit_50 | 1 |
| clientes_search_phone_limit_50 | 1 |
| productos_page_50 | 1 |
| productos_code_lookup | 0 |
| movimientos_latest_100 | 3 |
| movimientos_by_client_100 | 0 |
| deuda_items_by_movement | 0 |
| cuentas_por_cobrar_count | 1 |
| ciclos_vencidos_count | 0 |
| sync_queue_pending_count | 0 |
| audits_report_100 | 1 |
| dashboard_read | 10 |
| database_size_mb | 24.27 |
| process_rss_mb | 232.68 |

### 50000 clientes

- Generate exit code: `0`
- Benchmark exit code: `0`

| Metric | Value |
| --- | ---: |
| database | C:\Users\eric_\fiado_app\qa_data/stress_50000.db |
| clients | 50000 |
| products | 5000 |
| movements | 150000 |
| debt_items | 150000 |
| credit_cycles | 50000 |
| sync_queue | 25000 |
| audits | 2500 |
| insert_clients_ms | 5487 |
| insert_products_ms | 659 |
| insert_movements_ms | 18704 |
| insert_debt_items_ms | 16448 |
| insert_credit_cycles_ms | 6555 |
| insert_sync_queue_ms | 2392 |
| insert_audits_ms | 932 |
| size_mb | 120.22 |
| clientes_count | 21 |
| clientes_page_50 | 4 |
| clientes_page_100 | 2 |
| clientes_search_name_limit_50 | 2 |
| clientes_search_phone_limit_50 | 1 |
| productos_page_50 | 2 |
| productos_code_lookup | 0 |
| movimientos_latest_100 | 2 |
| movimientos_by_client_100 | 0 |
| deuda_items_by_movement | 0 |
| cuentas_por_cobrar_count | 4 |
| ciclos_vencidos_count | 0 |
| sync_queue_pending_count | 2 |
| audits_report_100 | 2 |
| dashboard_read | 31 |
| database_size_mb | 120.22 |
| process_rss_mb | 231.80 |

### 100000 clientes

- Generate exit code: `0`
- Benchmark exit code: `0`

| Metric | Value |
| --- | ---: |
| database | C:\Users\eric_\fiado_app\qa_data/stress_100000.db |
| clients | 100000 |
| products | 10000 |
| movements | 300000 |
| debt_items | 300000 |
| credit_cycles | 100000 |
| sync_queue | 50000 |
| audits | 5000 |
| insert_clients_ms | 10481 |
| insert_products_ms | 1472 |
| insert_movements_ms | 35624 |
| insert_debt_items_ms | 31629 |
| insert_credit_cycles_ms | 12956 |
| insert_sync_queue_ms | 4920 |
| insert_audits_ms | 1870 |
| size_mb | 241.80 |
| clientes_count | 32 |
| clientes_page_50 | 4 |
| clientes_page_100 | 1 |
| clientes_search_name_limit_50 | 2 |
| clientes_search_phone_limit_50 | 1 |
| productos_page_50 | 1 |
| productos_code_lookup | 0 |
| movimientos_latest_100 | 3 |
| movimientos_by_client_100 | 0 |
| deuda_items_by_movement | 0 |
| cuentas_por_cobrar_count | 9 |
| ciclos_vencidos_count | 1 |
| sync_queue_pending_count | 3 |
| audits_report_100 | 1 |
| dashboard_read | 61 |
| database_size_mb | 241.80 |
| process_rss_mb | 232.14 |

## Interpretation

- Queries over 500 ms should be treated as candidates for index or pagination review.
- Queries over 1,500 ms at 100,000 clients are not acceptable for interactive screens.
- This benchmark measures SQLite query time, not full Flutter build/layout time.

## Movement Index Optimization

Se agrego el indice SQLite:

```sql
CREATE INDEX IF NOT EXISTS idx_movimientos_negocio_cliente_telefono_fecha
ON movimientos(negocio_id, cliente_telefono, fecha DESC);
```

Resultado antes vs despues para `movimientos_by_client_100`:

| Clientes | Antes | Despues |
| ---: | ---: | ---: |
| 1,000 | 2 ms | 0 ms |
| 10,000 | 17 ms | 0 ms |
| 50,000 | 65 ms | 0 ms |
| 100,000 | 129 ms | 0 ms |

Con este indice, la consulta por cliente deja de ser el cuello de botella en el stress SQLite.
