# Multi-Business Isolation Audit

- Database: `C:\Users\eric_\fiado_app\qa_data/device_fiado_app_after.db`
- Created QA DB: false
- Critical issues: 0

| Check | Status | Count | Detail |
| --- | --- | ---: | --- |
| clientes sin negocio_id | OK | 0 | Sin fuga detectada. |
| productos sin negocio_id | OK | 0 | Sin fuga detectada. |
| movimientos sin negocio_id | OK | 0 | Sin fuga detectada. |
| deuda_items con negocio distinto al movimiento | OK | 0 | Sin fuga detectada. |
| deuda_items con producto de otro negocio | OK | 0 | Sin fuga detectada. |
| comprobantes con negocio distinto al movimiento | OK | 0 | Sin fuga detectada. |
| ciclos con cliente de otro negocio | OK | 0 | Sin fuga detectada. |
| client_scores con cliente de otro negocio | OK | 0 | Sin fuga detectada. |
| imagenes con producto de otro negocio | OK | 0 | Sin fuga detectada. |
| metricas con producto de otro negocio | OK | 0 | Sin fuga detectada. |
| colaboradores sin negocio asignado | OK | 0 | Sin fuga detectada. |
| solicitudes con colaborador de otro negocio | OK | 0 | Sin fuga detectada. |
| auditorias con colaborador de otro negocio | OK | 0 | Sin fuga detectada. |

## Business Breakdown

| negocio_id | negocio | clientes | productos | movimientos |
| ---: | --- | ---: | ---: | ---: |
| 1 | Colmado Eric - Eric | 0 | 0 | 0 |
