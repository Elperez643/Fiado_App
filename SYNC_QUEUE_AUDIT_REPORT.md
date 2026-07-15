# Sync Queue Audit Report

- Fecha: 2026-06-11T14:17:56.102426
- Base SQLite: `C:\Users\eric_\fiado_app\qa_data\device_fiado_app_after.db`
- Elementos abiertos antes: 0
- Marcados synced por auditor: 0
- Huerfanos limpiados por auditor: 0
- Elementos abiertos despues: 0

## Resumen Por Entidad

| entity_type | abiertos |
| --- | ---: |
| ninguno | 0 |

## Detalle

| entity_type | entity_id | operation | status | last_error | diagnostico |
| --- | ---: | --- | --- | --- | --- |
| ninguno | 0 | - | - | - | Cola limpia |

## Criterios

- Se auditan registros con estado `pending`, `failed` o `retry`.
- Si la entidad local existe con `sync_status = synced` y tiene `remote_id`, la cola puede marcarse `synced`.
- `usuarios`, `subscriptions` y `user_onboarding` son locales/no soportadas por el sync cloud simple actual; se pueden marcar `synced` para que no cuenten como pendientes falsos.
- Si la tabla o la fila local no existe, el registro se considera huerfano.
- El auditor solo modifica datos cuando se ejecuta con `--repair`, `--fix-synced` o `--clean-orphans`.
