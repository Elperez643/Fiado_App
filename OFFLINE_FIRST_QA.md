# Offline First QA

- Database: `C:\Users\eric_\fiado_app\qa_data/offline_first_audit.db`
- Failed checks: 0

| Check | Status |
| --- | --- |
| DB limpia puede tener 0 usuarios locales | OK |
| Registro local negocio crea usuario | OK |
| Registro local personal crea usuario sin suscripcion | OK |
| Negocio offline recibe trial local pendiente de validacion cloud | OK |
| Login local valida password sin servidor | OK |
| Inventario nuevo queda vacio y aislado al negocio | OK |
| Sync queue no tiene falsos pendientes bloqueantes | OK |

## Manual QA

- App instalada limpia sin internet abre Login.
- Registro negocio local entra al Dashboard.
- Inventario nuevo aparece vacio.
- Stripe muestra mensaje de conexion requerida sin nube.
