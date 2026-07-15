# Global Stability Audit Report

- Database: `C:\Users\eric_\fiado_app\qa_data/device_fiado_app_after.db`
- Created QA DB: false
- Critical issues: 0

## Data Integrity Checks

| Check | Status | Count | Detail |
| --- | --- | ---: | --- |
| movimientos.cliente_id existe para identidad estable de cliente | OK | 0 | OK |
| deuda_items.movimiento_id existe para enlazar factura a deuda | OK | 0 | OK |
| comprobantes.movimiento_id existe para recibos trazables | OK | 0 | OK |
| client_scores.cliente_id existe para score por cliente estable | OK | 0 | OK |
| clientes sin negocio_id | OK | 0 | Sin hallazgos. |
| productos sin negocio_id | OK | 0 | Sin hallazgos. |
| movimientos activos sin cliente_id | OK | 0 | Sin hallazgos. |
| movimientos huerfanos por cliente_id | OK | 0 | Sin hallazgos. |
| deuda_items huerfanos por movimiento_id | OK | 0 | Sin hallazgos. |
| comprobantes huerfanos por movimiento_id | OK | 0 | Sin hallazgos. |
| ciclos huerfanos por cliente_id | OK | 0 | Sin hallazgos. |
| scores huerfanos por cliente_id | OK | 0 | Sin hallazgos. |
| imagenes de producto huerfanas | OK | 0 | Sin hallazgos. |
| metricas de inventario huerfanas | OK | 0 | Sin hallazgos. |
| business recommendations con rutas fragiles por telefono/nombre | OK | 0 | Sin hallazgos. |

## Correcciones Aplicadas

- La auditoria valida relaciones por IDs estables y negocio_id obligatorio.
- No se aplican cambios destructivos ni limpieza automatica desde este script.
