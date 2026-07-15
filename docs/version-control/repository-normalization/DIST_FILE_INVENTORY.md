# Dist File Inventory

Date: 2026-07-15

## A. Documentacion Versionable

Selected candidates:

- `dist/README.md`
- `dist/fiado_app_manual_completo.csv`
- `dist/fiado_app_manual_completo_step_by_step.docx`
- `dist/fiado_app_manual_completo_step_by_step.md`
- `dist/fiado_app_manual_resumen.md`

These files appear to be manuals or documentation artifacts. They may be versioned if they contain no secrets.

## B. Scripts Fuente Versionables

No top-level scripts were observed in the provided `dist` listing.

## C. Binarios Generados No Versionables

Observed APK files:

- `dist/fiado_app_auth_connection_real_fix_debug.apk`
- `dist/fiado_app_cloud_status_register_fix_debug.apk`
- `dist/fiado_app_inventory_backfill_images_sync_debug.apk`
- `dist/fiado_app_inventory_images_endpoint_fix_debug.apk`
- `dist/fiado_app_inventory_images_validation_diagnostics_debug.apk`
- `dist/fiado_app_inventory_price_sync_fix_debug.apk`
- `dist/fiado_app_inventory_sync_debug.apk`
- `dist/fiado_app_single_active_session_debug.apk`
- `dist/fiado_app_sync_auth_business_diagnostics_debug.apk`
- `dist/fiado_app_sync_banner_stale_error_fix_debug.apk`
- `dist/fiado_app_sync_contable_debug.apk`
- `dist/fiado_app_sync_data_contract_audit_debug.apk`
- `dist/fiado_app_sync_diagnostics_screen_debug.apk`
- `dist/fiado_app_sync_endpoint_registry_audit_debug.apk`
- `dist/fiado_app_sync_global_legacy_status_fix_debug.apk`
- `dist/fiado_app_sync_legacy_queue_diagnostics_debug.apk`
- `dist/fiado_app_sync_v2_clients_debug.apk`

Generated folders:

- `dist/web/`
- `dist/windows/`

These must remain ignored by the root repository.

## D. Datos Locales o Sensibles

No `.db`, `.sqlite`, `.log`, token file, certificate, dump, or local config was observed in the top-level listing. This does not prove absence inside generated `web/` or `windows/`, which are ignored.

## E. Dudosos

- `dist/fiado_app_manual_completo_step_by_step.docx`: document binary format. Versionable if it is a required manual, but large binary diffs are less reviewable than Markdown/CSV.

## Selection for Root Versioning

Version:

- `dist/README.md`
- `dist/fiado_app_manual_completo.csv`
- `dist/fiado_app_manual_completo_step_by_step.docx`
- `dist/fiado_app_manual_completo_step_by_step.md`
- `dist/fiado_app_manual_resumen.md`

Ignore:

- APK files
- `dist/web/`
- `dist/windows/`
- Other generated binary/build outputs
