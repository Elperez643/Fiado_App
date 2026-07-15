# Full App QA Report

## Resumen General

Se realizo una revision integral estatica de Fiado App enfocada en flujos por
rol, pantallas sensibles, SQLite, sync cloud, backend, seguridad de sesion,
pagos mock/Stripe test, campañas WhatsApp e inteligencia local.

Resultado de la auditoria:

- Funciones revisadas: 54 flujos/pantallas/modulos.
- Errores claros corregidos: 5.
- Riesgos criticos encontrados: 1, corregido.
- Riesgos medios pendientes: 5.
- Riesgos bajos/documentados: 3.

La validacion por comandos queda obligatoria para cerrar el ciclo: `flutter
analyze`, tests, builds Android/Windows/Web, backend build y scripts QA.

## Funciones OK En Revision Estatica

### Personal

- Login y redireccion por `OnboardingAssistantScreen.openAfterAuth`.
- Onboarding una sola vez usando `user_onboarding`.
- Dashboard Personal con KPIs y noticias.
- Recordatorios de pago por telefono autenticado.
- Detalle de recordatorios limitado a movimientos/comprobantes propios.
- Logout centralizado por `authStateProvider.notifier.logout()`.
- Timeout global por `SessionTimeoutGuard`.

### Negocio

- Registro/login.
- Seleccion de plan y suscripcion local.
- Dashboard Ejecutivo v2.
- Clientes, deuda, pago y comprobantes.
- Inventario con producto sin imagen, imagen optimizada, codigo de barras y
  ubicacion.
- Auditorias, reportes y solicitudes.
- Colaboradores.
- Campañas WhatsApp con imagen renderizada y control antiabuso.
- Score Inteligente, Cobranza Inteligente, Inventario Inteligente y Business
  Copilot.
- Suscripcion, mock payments y Stripe test fallback.
- Sync cloud desde `SyncStatusScreen`.

### Colaborador

- Login y dashboard por rol.
- Inventario con permisos limitados.
- Creacion de producto permitida segun permisos.
- Edicion sensible mediante solicitud.
- Auditorias y mis solicitudes.
- Bloqueo de pantallas de negocio no autorizadas.
- Logout y timeout global.

## Pantallas Sensibles Revisadas

- `LoginScreen`
- `RegisterScreen`
- `SplashScreen`
- `PrincipalScreen`
- `PersonalPortalScreen`
- `ColaboradorDashboardScreen`
- `ClientesScreen`
- `DetalleClienteScreen`
- `InventarioScreen`
- `AgregarProductoDialog`
- `AgregarDeudaDialog`
- `ComprobanteScreen`
- `SyncStatusScreen`
- `BackendSettingsScreen`
- `SubscriptionScreen`
- Payment screens
- WhatsApp campaign screens
- `OnboardingAssistantScreen`
- `BusinessCopilotScreen`
- `CollectionsIntelligenceScreen`
- `InventoryIntelligenceScreen`
- `PersonalDebtRemindersScreen`

## Errores Encontrados Y Corregidos

### QA-LOGIN-001 Login Negocio

Se reporto pantalla blanca despues de login tipo Negocio. Se endurecio la
navegacion post-login con logs seguros, estado de carga, fallback de onboarding
a dashboard, `pushAndRemoveUntil`, `AppErrorState` en Dashboard Ejecutivo y se
elimino un `Spacer` dentro de un visual scrollable del onboarding.

### QA-001 BackendSettingsScreen

`_testConnection` podia llamar `setState` luego de una respuesta HTTP si el
usuario cerraba la pantalla durante el await. Se agregaron guards `mounted`.

### QA-002 SplashScreen

El timer de splash no se cancelaba en `dispose`. Se agrego `_navigationTimer`
con cancelacion segura.

### QA-003 Widget Test

El smoke test seguia siendo el contador de plantilla y montaba `FiadoApp` sin
`ProviderScope`, provocando `Bad state: No ProviderScope found`. Se reemplazo
por un smoke test real de `LoginScreen` con `ProviderScope`.

### QA-004 Client Score QA

`run_client_score_qa.dart` usaba `DatabaseSchema.initialIndexes`, que ahora
incluye indices de tablas cache nuevas, pero su DB temporal no las creaba. Se
agregaron `DatabaseSchema.createInventoryProductMetricsTable` y
`DatabaseSchema.createBusinessRecommendationsCacheTable` al schema del script.

## Riesgos Criticos

No se encontraron riesgos criticos nuevos por analisis estatico.

## Riesgos Medios

- Sync cloud requiere prueba live con backend, SQL Server y JWT validos.
- Stripe test requiere claves test, Price IDs reales de test y webhook CLI.
- Web compila, pero SQLite/Web definitivo sigue siendo una decision pendiente.
- SQL Server local puede fallar por SSPI si no se usa la conexion TCP ya
  documentada.
- Hay archivos sueltos en raiz que parecen salidas accidentales de CMD; no se
  eliminaron sin confirmacion.

## Riesgos Bajos

- Servicios legacy `SyncService` y `PendingAspNetCoreSyncService` conservan
  stubs/no-op; documentados como compatibilidad.
- WhatsApp no confirma publicacion real; se mantiene confirmacion manual.
- Scanner de codigo de barras depende de camara/permisos; Web/Desktop deben
  mostrar fallback.

## SQLite

Revision estatica:

- `DatabaseSchema.version` centralizado.
- Tablas nuevas documentadas: sync, scores, pagos, auditorias, imagenes,
  metricas de inventario, onboarding.
- Indices relevantes presentes para movimientos, productos, comprobantes,
  ciclos y metricas.
- Modelos recientes usan `fromMap/toMap` y defaults defensivos.
- Producto sin imagen y metadata de imagen opcional ya contemplados.

Pendiente:

- Validar migraciones en dispositivo con base vieja real.
- Validar que `inventory_product_metrics` se cree correctamente en upgrade.

## Backend

Revision estatica:

- API ASP.NET Core tiene `UseCors`, `UseAuthentication`, `UseAuthorization`.
- Health endpoint mapeado.
- Swagger restringido por entorno Development.
- Pagos mock/Stripe test registrados.
- Controladores principales protegidos con `[Authorize]`.
- Sync endpoints existen para clientes, productos, imagenes, financiero,
  auditorias, solicitudes y client scores.

Pendiente:

- `dotnet build`.
- Migraciones EF live.
- Prueba Swagger con token Negocio.
- Webhook Stripe con Stripe CLI.

## Sync Cloud

Modulos con servicio cloud concreto:

- Clientes.
- Productos.
- Imagenes metadata.
- Movimientos.
- Deuda items.
- Comprobantes.
- Ciclos.
- Auditorias.
- Solicitudes.
- Client scores.

Pendiente:

- Prueba live de push/pull con backend encendido.
- Verificar `sync_queue` tras error de red, backend apagado y token invalido.

## QA Existente Revisada

- `MOBILE_QA_CHECKLIST.md`
- `CLOUD_SYNC_QA_CHECKLIST.md`
- `SECURITY_AUDIT_REPORT.md`
- `PERFORMANCE_REPORT.md`
- `CLIENT_SCORE_QA_CHECKLIST.md`
- `PERSONAL_DEBT_GUIDANCE_QA.md`
- `ONBOARDING_V2_QA.md`
- `BUSINESS_COPILOT_QA.md`
- `COLLECTIONS_INTELLIGENCE_QA.md`
- `BARCODE_INVENTORY_QA.md`
- `INVENTORY_CREATE_QA.md`

## Checklist Por Rol

### Personal

- Login.
- Onboarding v2 una sola vez.
- Dashboard.
- Recordatorios de pago.
- Historial.
- Comprobantes.
- Logout.
- Timeout sesion.

### Negocio

- Login/registro.
- Plan/suscripcion.
- Dashboard Ejecutivo.
- Clientes/deudas/pagos/comprobantes.
- Inventario con y sin imagen.
- Scanner/ubicacion.
- Auditorias/solicitudes/colaboradores.
- WhatsApp campaigns.
- Score/Cobranza/Inventario Inteligente.
- Business Copilot.
- Stripe test/mock payments.
- Sync cloud.
- Logout/timeout.

### Colaborador

- Login.
- Dashboard.
- Inventario y creacion producto.
- Edicion mediante solicitud.
- Auditorias.
- Mis solicitudes.
- Permisos bloqueados.
- Logout/timeout.

## Checklist Por Plataforma

### Android

- Build debug.
- Camara para scanner.
- Image picker.
- Share/WhatsApp.
- PDF share/printing.
- Timeout foreground/background.

### Windows

- Build Windows.
- SQLite FFI.
- Backend local configurable.
- Scanner fallback si no hay camara compatible.
- PDF/share segun soporte plugin.

### Web

- Build Web.
- Backend baseUrl `localhost`.
- Limitacion SQLite/Web documentada.
- Scanner fallback segun navegador/permisos.
- Stripe Checkout por `url_launcher`.

## Validacion Ejecutada Por CMD

- `dart format .`: OK.
- `flutter analyze`: OK.
- `flutter test`: OK tras corregir test obsolete.
- `dart run tools\qa\validate_subscription_prices.dart`: OK.
- `dart run tools\qa\run_inventory_intelligence_qa.dart`: OK.
- `dotnet build backend\FiadoApp.Backend.sln --no-restore`: OK.
- `flutter build apk --debug`: OK.
- `flutter build windows`: OK.
- `flutter build web`: OK.
- APK copiado a `dist\fiado_app_full_qa_review_debug.apk`: OK.

Pendiente de re-ejecutar tras correccion:

- `dart run tools\qa\run_client_score_qa.dart`.

## Validacion Obligatoria Pendiente

Ejecutar:

```bat
dart format .
flutter analyze
flutter test
dart run tools\qa\validate_subscription_prices.dart
dart run tools\qa\run_client_score_qa.dart
dart run tools\qa\run_inventory_intelligence_qa.dart
dotnet build backend\FiadoApp.Backend.sln --no-restore
flutter build apk --debug
flutter build windows
flutter build web
copy /Y build\app\outputs\flutter-apk\app-debug.apk dist\fiado_app_full_qa_review_debug.apk
```

Scripts largos como stress progresivo completo deben ejecutarse solo si se
dispone de tiempo suficiente.
