# Production Readiness Checklist

## Estabilidad Local

- [ ] `dart format .`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `dart run tools/qa/run_global_data_integrity_audit.dart`
- [ ] `dart run tools/qa/run_multi_business_isolation_audit.dart`
- [ ] `dart run tools/qa/run_core_flow_regression.dart`
- [ ] `dart run tools/qa/run_sync_integrity_audit.dart`

## Builds

- [ ] `flutter build apk --debug`
- [ ] `flutter build windows`
- [ ] `flutter build web`
- [ ] `dotnet build backend/FiadoApp.Backend.sln`

## Datos y Multi-Negocio

- [ ] Clientes, productos, movimientos, comprobantes, ciclos, scores y metricas tienen `negocio_id` correcto.
- [ ] Personal solo ve sus deudas/recordatorios por identidad propia.
- [ ] Colaborador solo opera sobre el negocio asignado.
- [ ] No hay productos, clientes ni movimientos globales.
- [ ] No hay relaciones principales por nombre/telefono cuando existe ID estable.

## Sync

- [ ] `sync_queue` queda sin pendientes falsos tras sync exitoso.
- [ ] Entidades locales no soportadas no quedan como pendientes indefinidos.
- [ ] Pull no mezcla negocios.
- [ ] Push no confia en `businessId` enviado desde cliente cuando el backend debe usar JWT.
- [ ] 401/token expirado no borra datos locales.

## UI y Ciclo de Vida

- [ ] No hay pantallas blancas en login, dashboard, inventario inteligente ni sync.
- [ ] Dialogs complejos tienen controllers/timers/focus con dispose.
- [ ] No hay `setState` despues de dispose.
- [ ] No hay `context` usado despues de `await` sin `mounted`.
- [ ] Estados empty/loading/error son visibles y recuperables.

## Riesgos Antes de Produccion

- [ ] Validar camara/barcode en Android fisico.
- [ ] Validar WhatsApp share en Android fisico.
- [ ] Validar Stripe solo en test mode.
- [ ] Validar backend SQL Server con datos reales de prueba.
- [ ] Ejecutar auditorias sobre DB real extraida por ADB.
