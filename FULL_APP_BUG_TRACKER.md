# Full App Bug Tracker

## Corregido - Integridad cliente/deudas al editar datos personales

- Causa: editar telefono podia borrar/recrear el registro de cliente y romper relaciones basadas en identidad editable.
- Correccion: `clientes.id` queda estable; movimientos nuevos guardan `cliente_id`, `cliente_nombre_snapshot` y `cliente_telefono_snapshot`.
- Cobranza Inteligente y detalle de cliente prefieren `cliente_id` y dejan telefono/nombre como fallback legacy.

## Hallazgos

| ID | Severidad | Modulo | Descripcion | Causa probable | Estado | Correccion recomendada |
| --- | --- | --- | --- | --- | --- | --- |
| QA-LOGIN-001 | Critica | Login Negocio | Pantalla blanca despues de login tipo Negocio. | Navegacion post-login sin fallback visual ante error de onboarding/dashboard y posible layout no acotado en Onboarding v2. | Corregido | Se agregaron logs seguros, loading de navegacion, fallback de onboarding a dashboard, `AppErrorState` en PrincipalScreen y se elimino `Spacer` dentro de visual scrollable. |
| QA-INVINT-001 | Alta | Inventario Inteligente | Pantalla vacia y boton visual de retorno sin respuesta al entrar a Inventario Inteligente. | La pantalla no diferenciaba cache vacia, negocio sin productos y errores de calculo; el AppBar dependia del stack implicito de navegacion. | Corregido | Se agregaron estados loading/error/empty, calculo inicial cuando hay productos sin cache, logs seguros de negocio/productos/metricas y boton back con `maybePop()` + fallback a dashboard. |
| QA-DEUDA-ITEMS-001 | Alta | Agregar Deuda | La seccion de articulos podia quedar desactivada y el monto total se bloqueaba cuando habia items. | El dialogo dependia de productos paginados/buscados en provider y el monto se forzaba a la suma exacta de items. | Corregido | Se cargan productos activos directo del repositorio, el selector queda visible, el total es editable, se conserva ajuste manual y existe accion para recalcular desde articulos. |
| QA-DEUDA-ITEMS-002 | Alta | Detalle/Comprobante Deuda | Mercancias no aparecian en popup ni comprobante/PDF despues de crear deuda con articulos. | El comprobante podia conservar payload sin productos y las vistas dependian de ese payload en vez de reconstruir desde `deuda_items` por `movimiento_id`. | Corregido | Popup consulta `deuda_items` por `movimiento.id` SQLite; comprobantes existentes se actualizan o reconstruyen desde DB; pantalla y PDF muestran subtotal, ajuste, abono inicial y monto final. |
| QA-DEUDA-ITEMS-003 | Alta | Agregar Deuda | Selector de articulos podia volver a desactivarse tras cambios en inventario, busqueda, providers o metricas. | El flujo no tenia una fuente unica estable de productos facturables separada del inventario visual. | Corregido | Se creo `BillableProduct`, consulta SQLite compartida, `ProductoRepository.obtenerProductosFacturables` y `billableProductsProvider`; `AgregarDeudaDialog` consume solo esa fuente. |
| QA-DEUDA-TOTAL-001 | Alta | Agregar Deuda | Al agregar articulos, `Monto total final` podia quedar vacio y al guardar mostraba que el monto debia ser mayor a 0. | El campo mostraba subtotal en el resumen, pero el controller del monto final no se sincronizaba con el subtotal de articulos. | Corregido | El monto final se autollena con el subtotal mientras no haya edicion manual; si se borra con articulos, guardar usa el subtotal; deuda manual sigue exigiendo monto mayor a 0. |
| QA-DEUDA-TOTAL-002 | Alta | Agregar Deuda | `Monto total final` no se actualizaba visualmente en tiempo real al agregar articulos. | La sincronizacion no estaba centralizada y el parser no aceptaba montos con separador de miles. | Corregido | Se agrego `_actualizarMontoTotalDesdeSubtotal`, bandera de actualizacion del sistema, parser que limpia comas y boton `Usar subtotal` para restaurar el subtotal visible. |
| QA-DEUDA-SELECTOR-001 | Media | Agregar Deuda | Despues de agregar un articulo, el selector seguia mostrando el ultimo producto y precio anterior. | El estado del producto seleccionado no se limpiaba al insertar el item en la lista. | Corregido | Despues de agregar, `_productoSeleccionado` vuelve a `null`, cantidad vuelve a `1`, precio a `0.00` y el dropdown muestra `Selecciona un producto`. |
| QA-SYNC-AUTH-001 | Alta | Sincronizacion Cloud | La sincronizacion simple fallaba porque el usuario normal no tenia token configurado y no debia pegarlo manualmente. | El login local no intentaba autenticacion cloud automatica ni guardaba token seguro para `ApiClient`. | Corregido | Se creo `CloudAuthService`, login cloud no bloqueante despues de login local, token en secure storage, limpieza en logout/timeout y uso automatico desde `ApiClient`. |
| QA-001 | Baja | BackendSettingsScreen | Posible `setState` despues de cerrar pantalla durante prueba `/health`. | `_testConnection` esperaba HTTP y luego llamaba `setState` sin comprobar `mounted`. | Corregido | Se agregaron guards `if (!mounted) return;` despues de awaits y antes de `setState`. |
| QA-002 | Baja | SplashScreen | Timer de splash no se cancelaba si la pantalla se desmontaba antes de navegar. | `Timer` anonimo en `initState`. | Corregido | Se guarda referencia `_navigationTimer` y se cancela en `dispose`. |
| QA-003 | Baja | Tests | `flutter test` fallaba porque el test seguia esperando el contador demo y montaba la app sin `ProviderScope`. | Test inicial de plantilla no actualizado al uso real de Riverpod/Login. | Corregido | Se reemplazo por smoke test de `LoginScreen` con `ProviderScope`. |
| QA-004 | Baja | Client Score QA | `run_client_score_qa.dart` fallaba creando indices de tablas cache nuevas sin crearlas en la DB temporal. | El script usa `DatabaseSchema.initialIndexes` pero no habia incluido todas las tablas que esos indices referencian. | Corregido | Se agregaron `createInventoryProductMetricsTable` y `createBusinessRecommendationsCacheTable` al schema QA. |
| QA-005 | Media | Repo / higiene | Existen archivos sueltos no versionados en raiz con nombres de comandos o excepciones (`flutter`, `dotnet`, `Microsoft.AspNetCore...`). | Salidas accidentales de CMD o comandos escritos como texto. | Pendiente | Revisar manualmente y eliminar solo si se confirma que no contienen informacion util. |
| QA-006 | Media | Backend / SQL Server local | Riesgo de SSPI/connection string en pruebas live. | Entorno SQL Server Express local sensible a SPN/Windows Auth. | Pendiente | Mantener TCP `127.0.0.1,14333`, ejecutar migraciones elevadas y documentar en `DB_SETUP.md`. |
| QA-007 | Media | Stripe test | Checkout/webhooks dependen de claves test y Price IDs externos. | Configuracion externa no verificable por analisis estatico. | Pendiente | Probar con Stripe CLI y claves test antes de demo publica. |
| QA-008 | Media | Sync cloud | Push/pull depende de backend levantado, JWT valido y SQL Server disponible. | Flujo distribuido no validable solo con analisis estatico. | Pendiente | Ejecutar QA live por modulo con token Negocio y revisar `sync_queue`. |
| QA-009 | Baja | SyncService legacy | `lib/data/services/sync_service.dart` y `api_sync_service.dart` conservan stubs/no-op legacy. | Servicios antiguos quedaron como compatibilidad mientras se agregaron servicios cloud concretos. | Documentado | Mantener si no se usan; limpiar solo con refactor controlado. |
| QA-010 | Media | Web | SQLite Web compila, pero almacenamiento definitivo Web sigue documentado como limitacion. | `sqflite` no es la estrategia ideal para Web productivo. | Pendiente | Definir IndexedDB/sqflite_common_ffi_web o backend-first para Web. |
| QA-011 | Baja | WhatsApp campaigns | Apertura de WhatsApp/share no puede confirmar publicacion real. | WhatsApp no expone confirmacion a Fiado App. | Documentado | Mantener confirmacion manual y mensaje de vigencia estimada. |
| QA-012 | Media | Barcode scanner | Camara no siempre disponible en Web/Desktop. | `mobile_scanner` depende de plataforma/permisos. | Documentado | Mostrar fallback "Escaneo no disponible" y probar Android fisico. |

## Correcciones Aplicadas En Esta Revision

- QA-001 corregido en `lib/screens/backend_settings_screen.dart`.
- QA-002 corregido en `lib/screens/splash_screen.dart`.
- QA-003 corregido en `test/widget_test.dart`.
- QA-004 corregido en `tools/qa/run_client_score_qa.dart`.
- QA-INVINT-001 corregido en `lib/screens/inventory_intelligence_screen.dart`, `lib/inventory_intelligence/inventory_intelligence_service.dart`, `lib/data/repositories/inventory_product_metrics_repository.dart`, `lib/presentation/providers/fiado_data_providers.dart` y `lib/core/database/database_helper.dart`.
- QA-DEUDA-ITEMS-001 corregido en `lib/screens/widgets/agregar_deuda_dialog.dart`, `lib/screens/detalle_cliente_screen.dart` y `lib/data/repositories/movimiento_repository.dart`.
- QA-DEUDA-ITEMS-002 corregido en `lib/screens/detalle_cliente_screen.dart`, `lib/screens/comprobante_screen.dart`, `lib/data/repositories/comprobante_repository.dart`, `lib/data/repositories/deuda_item_repository.dart`, `lib/data/repositories/movimiento_repository.dart` y `lib/data/services/comprobante_pdf_service.dart`.
- QA-DEUDA-ITEMS-003 corregido en `lib/data/models/billable_product.dart`, `lib/data/repositories/billable_product_query.dart`, `lib/data/repositories/producto_repository.dart`, `lib/presentation/providers/fiado_data_providers.dart`, `lib/screens/widgets/agregar_deuda_dialog.dart` y `tools/qa/run_billable_products_regression.dart`.
- QA-DEUDA-TOTAL-001 corregido en `lib/screens/widgets/agregar_deuda_dialog.dart`.
- QA-DEUDA-TOTAL-002 corregido en `lib/screens/widgets/agregar_deuda_dialog.dart`.
- QA-DEUDA-SELECTOR-001 corregido en `lib/screens/widgets/agregar_deuda_dialog.dart`.
- QA-SYNC-AUTH-001 corregido en `lib/data/services/cloud_auth_service.dart`, `lib/data/services/api_client.dart`, `lib/screens/login_screen.dart`, `lib/core/security/secure_token_storage.dart` y `lib/presentation/providers/auth_providers.dart`.

## Pendientes No Corregidos Por Alcance

- Limpieza de archivos sueltos en raiz requiere confirmacion del dueno.
- Stripe test requiere claves y webhook externo.
- Sync live requiere backend/SQL/JWT activos.
- Web storage definitivo requiere decision tecnica mayor.
# INVENTORY-ISOLATION-001

- Estado: corregido
- Problema: productos demo/legacy podian aparecer en negocios donde no fueron
  creados.
- Causa: si el inventario estaba vacio, la pantalla sembraba productos iniciales
  y existia respaldo legacy global de productos.
- Correccion: se elimino la siembra automatica, se neutralizo el datasource
  global legacy de productos, se reforzo filtro `negocio_id` en imagenes,
  auditorias, stock, sync pull y queries relacionadas.
