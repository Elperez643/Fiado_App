# Fiado App - Architecture

## Client Identity Integrity

Las relaciones internas entre clientes, deudas, pagos, comprobantes, ciclos,
score y recomendaciones usan `cliente_id` local estable. Nombre y telefono son
datos editables y se conservan como snapshots historicos en movimientos para
mostrar informacion aun si el cliente cambia o se elimina. Las consultas nuevas
deben preferir `cliente_id` y usar nombre/telefono solo como fallback legacy.

## Formato Monetario Global

Fiado App centraliza el formato monetario en
`lib/core/utils/money_formatter.dart`.

- `MoneyFormatter.format(value)` muestra numeros con separador de miles `,` y
  decimal `.`.
- `MoneyFormatter.formatCurrency(value)` muestra moneda con el mismo formato.
- `CurrencyFormatter.rd(value)` delega al formatter global para compatibilidad
  con codigo existente.
- SQLite, sync, backend, Stripe y calculos internos conservan valores numericos
  sin cambios; el formatter solo afecta presentacion.
- Comprobantes en pantalla y PDF usan el mismo formatter.

## Sincronizacion Simple Para Usuarios

La sincronizacion cloud conserva arquitectura offline-first y `sync_queue`, pero
la experiencia normal se simplifica:

- `SyncStatusScreen` muestra estados humanos y el boton unico
  `Sincronizar con la nube`.
- `AutoSyncService` ejecuta sincronizacion automatica con debounce, lock interno
  y deteccion de conexion.
- `SyncUserStatus` expone estado simple: online, sincronizando, pendientes,
  ultima sincronizacion y mensaje amigable.
- `SyncAdvancedSettingsScreen` conserva herramientas tecnicas solo para debug o
  configuracion avanzada.
- La pantalla normal no expone JWT, token, baseUrl, endpoint, push, pull,
  payload ni detalles de `sync_queue`.

## Security Hardening v1

La auditoria de seguridad v1 endurece almacenamiento de tokens, logout, CORS, errores backend y webhook Stripe. El token manual de backend se mueve a `flutter_secure_storage` mediante `SecureTokenStorage`; `SharedPreferences` queda solo como fallback/migracion para ese token.

En backend, produccion exige `Jwt:Key` fuerte, CORS usa `Cors:AllowedOrigins`, Swagger solo se habilita en Development y los errores de produccion usan respuesta generica.

## Seguridad De Sesion

La app usa `SessionTimeoutGuard` como wrapper global en `MaterialApp.builder`. El guard no actua si no hay usuario autenticado, por lo que LoginScreen queda fuera de advertencias. Cuando existe sesion activa, `SessionTimeoutService` controla timers de inactividad, advertencia y cierre automatico.

Reglas activas:

- 9 minutos sin actividad: dialogo de advertencia.
- 10 minutos sin actividad: logout automatico.
- 2 minutos en segundo plano: logout al volver.

El logout marca sesiones locales como inactivas, dejando inaccesible el JWT local asociado a la sesion activa.

## Onboarding v2

La Guia Rapida usa `OnboardingAssistantScreen` con contenido por rol y diseno
SaaS moderno. El estado se persiste en `user_onboarding`: completar u omitir
marca la guia como vista y evita que vuelva automaticamente. El modo manual se
abre desde `Menu -> Ayuda / Ver guia nuevamente` y no cambia ese estado.

## Personal Debt Guidance

Fiado App incluye `lib/personal_debt_guidance/` para usuario Personal. El modulo
calcula recordatorios y consejos de deuda desde SQLite usando solo el telefono
autenticado, ciclos 30/45/60, movimientos y comprobantes propios.

La pantalla `PersonalDebtRemindersScreen` agrupa saldos por negocio, muestra
prioridad suave y permite abrir un detalle con movimientos/comprobantes del
mismo telefono. No usa backend nuevo, no envia push, no abre WhatsApp y no
expone inventario ni datos internos del negocio.

## Business Copilot v1

Fiado App ahora incluye `lib/business_copilot/`, un centro de recomendaciones deterministicas para usuario Negocio. Consume Cobranza Inteligente, Inventario Inteligente, Client Scores, ciclos 30/45/60, auditorias, solicitudes y suscripcion.

Las recomendaciones se almacenan en cache local `business_recommendations_cache`, con expiracion corta y filtro por `business_id`. No se usa backend, IA externa, OpenAI ni machine learning.

El Dashboard Ejecutivo muestra un bloque superior "Fiado App recomienda" con las 3 recomendaciones de mayor score, y el menu lateral incluye Business Copilot.

## Cobranza Inteligente v1

Fiado App incluye un modulo local en `lib/collections_intelligence/` para priorizar cobranza sin backend ni IA externa. El servicio `CollectionsIntelligenceService` calcula insights desde SQLite usando `clientes`, `credito_ciclos`, `movimientos` y `client_scores`.

El Dashboard Ejecutivo de Negocio muestra KPIs de cobranza: cobrar hoy, vencen pronto, mora critica, bloqueados, monto critico y recuperacion sugerida. La pantalla `CollectionsIntelligenceScreen` permite revisar clientes por seccion y abrir WhatsApp con mensaje preparado, sin envio automatico.

La v1 no sincroniza `CollectionInsight` como entidad. Los datos se recalculan offline-first desde tablas existentes y se deja preparada la documentacion para una futura version cloud.

## Version Estable Pre-Backend

Este documento describe el estado funcional congelado de Fiado App antes de
iniciar la migracion progresiva hacia backend ASP.NET Core + SQL Server.

Alcance del freeze:

- Backend ASP.NET Core conectado inicialmente para sincronizacion cloud de
  clientes.
- No hay pagos reales integrados.
- SQLite sigue siendo la fuente local principal.
- `sync_queue` es la frontera tecnica para sincronizacion cloud. Clientes,
  Productos, Imagenes de Productos, Movimientos, Deuda Items, Comprobantes y
  Ciclos de Credito, Auditorias y Solicitudes de Autorizacion ya tienen
  sincronizacion inicial contra ASP.NET Core + SQL Server.
- Las reglas actuales de negocio, suscripciones, ciclos de credito,
  colaboradores, inventario, comprobantes y onboarding se consideran base
  estable para disenar API y modelo SQL Server.

## Resumen Del Proyecto

Fiado App es una aplicacion Flutter para gestionar clientes, deudas, pagos,
inventario, colaboradores, suscripciones, solicitudes de autorizacion,
auditorias y reportes. La app esta evolucionando hacia un modelo offline-first:
SQLite es la fuente local principal y cada escritura relevante queda preparada
en `sync_queue` para sincronizarse con una API REST ASP.NET Core y SQL Server.

El objetivo actual es mantener el flujo local estable y conectar modulos cloud
de forma progresiva. Clientes fue el primer modulo sincronizado; Productos,
Imagenes de Productos, Movimientos, Deuda Items, Comprobantes, Ciclos de
Credito, Auditorias y Solicitudes de Autorizacion ya tienen sync cloud inicial.

## Stack Actual

- Flutter para UI multiplataforma.
- SQLite como base local principal.
- `sqflite` como driver SQLite.
- Riverpod para providers y estado de presentacion.
- Repositorios locales sobre SQLite.
- `sync_queue` local para registrar cambios pendientes.
- API REST ASP.NET Core para autenticacion JWT y sync cloud inicial de clientes,
  productos, imagenes de productos, movimientos, deuda items, comprobantes,
  ciclos de credito, auditorias y solicitudes de autorizacion.
- Infraestructura profesional de pagos mock para suscripciones. El modulo
  prepara entidades, proveedor abstracto, proveedor `MockPaymentProvider`,
  historial, transacciones y logs de webhook sin conectar Stripe/Azul/CardNet
  ni guardar datos sensibles de tarjeta.
- SQL Server como base cloud.
- Configuracion central de backend por plataforma desde
  `lib/core/api/api_environment.dart`, con override local guardado y pantalla
  `BackendSettingsScreen`.
- SQLite usa `sqflite` en mobile/macOS y `sqflite_common_ffi` en Windows/Linux.
  Web compila como objetivo exploratorio, pero requiere decision futura de
  almacenamiento local.

## Arquitectura Por Capas

### `lib/core`

Contiene infraestructura transversal: constantes, tema, permisos, utilidades,
database schema, database helper y estados centrales de sincronizacion.

Archivos clave:

- `lib/core/database/database_schema.dart`
- `lib/core/database/database_helper.dart`
- `lib/core/sync/sync_status.dart`
- `lib/core/permissions/app_permissions.dart`

### `lib/data`

Contiene modelos SQLite, repositorios y servicios. Esta capa sabe como leer y
escribir en SQLite, y como encolar operaciones de sincronizacion.

Subcarpetas principales:

- `lib/data/models`
- `lib/data/repositories`
- `lib/data/services`
- `lib/data/datasources`

### `lib/domain`

Contiene entidades y contratos de repositorios mas puros. Algunas pantallas
todavia usan modelos legacy, por lo que esta capa convive con codigo en
transicion.

### `lib/presentation`

Contiene providers Riverpod, widgets compartidos, responsive layout y pantallas
en estructura nueva.

### `lib/screens`

Contiene pantallas principales actuales de la app. Varias pantallas viven aqui
por compatibilidad con el flujo existente.

### Providers

Los providers Riverpod conectan UI con repositorios y servicios. Los providers
principales viven en:

- `lib/presentation/providers/auth_providers.dart`
- `lib/presentation/providers/fiado_data_providers.dart`
- `lib/presentation/providers/sync_providers.dart`

### Repositories

Los repositorios son la puerta de entrada a SQLite. Las pantallas y providers
no deben manipular SQL directamente.

### Services

Los servicios contienen flujos de aplicacion o integraciones futuras. Por
ejemplo, `SyncService` simula sincronizacion sin hacer HTTP real.

### Backend Por Plataforma

`ApiClient` obtiene siempre la URL desde `ApiEnvironmentConfig`; no debe haber
baseUrl quemada en servicios de sync. Entornos soportados:

- Android emulador: `http://10.0.2.2:5193/api`.
- Android fisico: `http://TU_IP_LOCAL:5193/api`, reemplazando por la IP LAN de
  la computadora.
- Desktop local: `http://127.0.0.1:5193/api`.
- Web local: `http://localhost:5193/api`.
- Produccion: `https://api.fiadoapp.com/api`.

La pantalla `BackendSettingsScreen` permite cambiar entorno, guardar override
manual, probar `/health`, limpiar token local y ver solo una version parcial
del token.

### Builds Multiplataforma

- Android debug genera APK desde `flutter build apk --debug`.
- Windows Desktop usa SQLite FFI inicializado en `main.dart`.
- Web queda documentado en `WEB_COMPATIBILITY.md`: la persistencia offline con
  SQLite todavia no esta lista para produccion Web.
- iOS queda preparado para validacion en macOS/Xcode. `Info.plist` declara
  permisos de fotos/camara y esquemas de enlaces; la compilacion real iOS debe
  ejecutarse en macOS. Ver `IOS_COMPATIBILITY.md`.

### Compatibilidad iOS

- SQLite usa `sqflite`/`sqflite_darwin` en iPhone/iPad.
- Seleccion de imagenes usa `image_picker` y requiere permisos en
  `Info.plist`.
- Comprobantes PDF usan `pdf`, `printing` y `share_plus` para share sheet e
  impresion.
- WhatsApp se maneja como enlace compartido `wa.me` mediante `share_plus`.
- Campanas de Estados WhatsApp generan imagenes finales localmente con
  `WhatsappStatusImageRenderer`: formato `720 x 1280`, recorte centrado,
  franja inferior con texto/precio/branding y cache temporal.
- Backend local en simulador puede usar `localhost`; iPhone fisico requiere IP
  LAN o backend HTTPS publicado.
- Bundle identifier actual es placeholder y debe cambiarse en Xcode antes de
  pruebas reales con firma.

## Modulos Actuales

- Auth: registro, login, logout y sesiones locales.
- Roles: usuario Personal, Negocio y Colaborador.
- Dashboard Ejecutivo v2: pantalla inicial por rol con KPIs, noticias
  importantes y menu lateral. Negocio ve cartera, cobros, inventario,
  solicitudes, auditorias e inteligencia comercial; Personal ve deuda,
  vencimientos e historial; Colaborador ve auditorias, solicitudes e inventario.
- Suscripciones: trial, planes SaaS en USD, ciclos de facturacion, descuentos,
  estado de acceso y limites.
- Pagos de suscripcion: arquitectura mock/API-ready con metodos de pago
  tokenizados por proveedor, cobros simulados, renovaciones simuladas,
  historial y preparacion para webhooks. No se almacenan numero de tarjeta,
  CVV ni fecha de expiracion completa de tarjeta real.
- Inteligencia comercial v1: score deterministico offline de clientes sin IA
  externa ni machine learning. Calcula riesgo, limite sugerido y motivos usando
  movimientos, pagos y ciclos de credito locales.
- Ciclos de credito: periodos de fiado por cliente y negocio con vencimiento
  30/45/60, recordatorios, bloqueo y excepciones manuales.
- Onboarding Assistant: guia inicial por usuario y tipo de cuenta, persistida
  localmente para mostrarse una sola vez.
- Colaboradores: creacion, edicion, activacion y desactivacion.
- Clientes: gestion de clientes, telefonos y deuda.
- Movimientos: deudas, pagos e historial.
- Deudas: pueden guardar detalle de mercancias con productos, cantidades,
  precios unitarios y subtotales mediante `deuda_items`. Al seleccionar un
  producto en la factura de deuda se precarga su precio de venta, se permite
  ajuste manual y el total se recalcula en vivo.
- Las deudas con mercancias descuentan inventario de forma transaccional al
  guardarse; los pagos normales siguen siendo abonos y no alteran stock.
- Inventario: productos, stock, ubicacion, demanda, disponibilidad, costo
  unitario, precio de venta y porcentaje de ganancia. El precio puede calcularse
  como `costo + costo * margen / 100`, sin impedir que el negocio ajuste el
  precio manualmente.
- Inventario soporta `codigo_referencia` unico en articulos activos e imagenes
  opcionales por articulo.
- Inventario muestra la primera imagen optimizada del producto en cada tarjeta.
  La carga de miniaturas se hace por lote desde `producto_imagenes` para evitar
  una consulta por producto visible.
- Creacion/edicion de productos soporta lectura de codigo de barras para
  `codigo_referencia` y `ubicacion`. La primera version es offline: el lookup
  solo busca codigos existentes del mismo negocio en SQLite y sugiere datos
  editables si encuentra coincidencia.
- Solicitudes de autorizacion: cambios de colaboradores que requieren aprobacion.
- Auditorias: auditorias diarias/semanales e items auditados.
- Reportes: reportes de auditoria e inventario.
- Reportes de inteligencia comercial: top mejores clientes y top clientes en
  riesgo, calculados localmente sobre SQLite.
- Inventario Inteligente v1: calcula offline rotacion, cobertura, reposicion
  sugerida, productos criticos, agotados, sin movimiento, sobre stock, valor
  inmovilizado y ganancia potencial desde `productos`, `deuda_items` y
  `movimientos`. Usa `inventory_product_metrics` como cache incremental local
  con bandera `dirty`; no se sincroniza como entidad todavia.
- Sync Queue: cola local de cambios para futura sincronizacion cloud.
- Comprobantes: comprobantes internos para deudas y pagos, PDF imprimible y
  compartir por menu nativo; WhatsApp y correo se usan via `share_plus`, sin
  integrar APIs oficiales externas.
- Campanas WhatsApp: seleccion de productos activos con stock, texto maximo de
  30 caracteres, preview, render local de flyers y publicacion con imagenes ya
  renderizadas para Estados. El render usa la imagen optimizada del producto
  cuando existe; si no hay imagen, genera un flyer simple.

## Reglas De Negocio Principales

- Usuario Personal no paga suscripcion.
- Usuario Negocio si paga suscripcion.
- Usuario Negocio tiene trial gratis de 30 dias.
- Los planes usan USD como moneda comercial principal.
- Plan Basico: USD 4.99 mensual / 3 colaboradores / hasta 1,000 clientes
  recomendados / reportes basicos / soporte estandar / sincronizacion normal.
- Plan Crecimiento: USD 12.99 mensual / 7 colaboradores / hasta 5,000 clientes
  recomendados / reportes avanzados / exportacion avanzada futura /
  sincronizacion prioritaria.
- Plan Empresarial: USD 20.99 mensual / 15 colaboradores / hasta 100,000+
  clientes recomendados / reportes completos / prioridad maxima de
  sincronizacion / preparado para multi sucursal futura.
- Duraciones de suscripcion soportadas: mensual, trimestral y anual.
- El ciclo trimestral aplica 10% de descuento sobre 3 meses.
- El ciclo anual aplica 20% de descuento sobre 12 meses.
- Los precios finales se calculan con truncado a 2 decimales para mantener los
  importes comerciales exactos mostrados en la app.
- Usuario Colaborador no paga; depende de la suscripcion del Negocio.
- Colaborador puede hacer auditoria diaria y semanal.
- Colaborador puede agregar inventario.
- Colaborador no puede editar ni eliminar sin aprobacion del Negocio.
- Cambios de colaborador sobre costo, margen o precio de venta de productos
  existentes pasan por solicitud de autorizacion.
- Cada producto puede tener maximo 3 imagenes.
- Imagenes de producto: la app optimiza automaticamente cada JPG/JPEG/PNG a
  `500 x 500 px` antes de guardar. La compresion JPG usa calidad adaptativa
  85/80/75/70/65, objetivo 120-200 KB, rango aceptable 200-300 KB y maximo
  estricto 300 KB. SQLite guarda solo la ruta optimizada y metadata optimizada
  (`width`, `height`, `mime_type`, `size_bytes`).
- Negocio puede agregar y editar imagenes de productos.
- Colaborador puede agregar imagenes al crear producto nuevo.
- Colaborador no puede editar imagenes de producto existente sin autorizacion.
- Negocio aprueba o rechaza solicitudes de autorizacion.
- Los limites de colaboradores se validan contra el plan activo del Negocio.
- La pantalla de suscripcion muestra comparacion de planes por tarjetas,
  seleccion de ciclo, precio original tachado cuando hay descuento, ahorro
  porcentual, ahorro monetario y beneficios visibles. Todavia no integra pagos
  reales.
- Cada cliente dentro de un negocio tiene ciclos de credito independientes:
  primera deuda abre un ciclo de 30 dias; deudas dentro de ese periodo entran
  al mismo ciclo; deudas despues del dia 30 abren un ciclo nuevo.
- Los pagos nunca cambian `fecha_inicio`, `fecha_limite_30`,
  `fecha_limite_45` ni `fecha_bloqueo_60`. Si el cliente paga una factura pero
  todavia queda cualquier saldo del ciclo, el conteo original continua.
- Borron y Cuenta Nueva: si el cliente salda todo antes de 30 dias, el ciclo se
  cierra definitivamente como `saldado` y el proximo fiado inicia un ciclo
  nuevo con nueva `fecha_inicio` y nueva `fecha_limite_30`.
- Si el cliente solo paga parcialmente y todavia queda cualquier saldo dentro
  del ciclo, las nuevas deudas dentro de los primeros 30 dias siguen entrando al
  ciclo original.
- A los 30 dias el ciclo pasa a `vencido_30`, se muestra amarillo, queda como
  cuenta por cobrar y permite preparar recordatorios.
- A los 45 dias pasa a `mora_45`, se destaca visualmente rojo/amarillo y genera
  aviso fuerte.
- A los 60 dias pasa a `bloqueado_60`, bloquea el fiado solo para ese
  cliente-negocio y permite `Fiar de todos modos` dejando excepcion manual.
- Los pagos se aplican primero al ciclo pendiente mas viejo. Un pago parcial
  reduce `saldo_pendiente`; un pago total marca el ciclo como `saldado` y
  guarda `fecha_saldado`.
- Los avisos internos al usuario Personal solo exponen nombre del negocio,
  monto pendiente, fecha limite y mensaje. No muestran datos de otros clientes
  ni detalles privados del negocio.
- WhatsApp no usa API oficial; la app genera enlaces `wa.me` normalizando
  telefonos dominicanos a `+1` cuando aplica y comparte el enlace con el menu
  nativo.
- Estados WhatsApp no usan API oficial: la app comparte imagenes renderizadas
  por `share_plus`, registra `enviado_a_whatsapp` al abrir el share sheet y
  pide confirmacion manual para marcar `confirmado_por_usuario` con vigencia
  estimada de 24 horas.
- Anti-abuso de campanas: el cupo diario se consume al abrir WhatsApp/menu de
  compartir. Estados `enviado_a_whatsapp`, `confirmado_por_usuario` y
  `cancelado_por_usuario` cuentan; `pendiente` y
  `fallido_antes_de_abrir_whatsapp` no cuentan. El reintento de la misma
  publicacion reutiliza el mismo id y no consume cupo adicional mientras no
  cambien imagenes renderizadas, productos ni textos.
- El onboarding inicial se guarda en `user_onboarding` por `usuario_id`,
  `tipo_usuario` y `onboarding_key`. Si el usuario completa u omite la guia, no
  se vuelve a mostrar automaticamente en login, registro ni splash. La guia
  puede abrirse manualmente desde los paneles principales sin marcar al usuario
  como nuevo.
- En cuentas Negocio, el onboarding no se muestra por la simple creacion del
  usuario. La compuerta exige registro exitoso, plan seleccionado, trial gratis
  de 30 dias creado como suscripcion activa temporal y sesion valida. Solo
  despues de `validarAccesoNegocio` se consulta o crea el estado de onboarding.

## Flujo De Datos

El flujo esperado para lecturas y escrituras es:

```text
Pantalla -> Provider Riverpod -> Repository -> SQLite -> sync_queue
```

Reglas del flujo:

- La pantalla llama un provider o notifier.
- El provider usa un repositorio o servicio.
- El repositorio escribe primero en SQLite.
- Si la operacion debe sincronizarse, el repositorio registra un item en
  `sync_queue`.
- Clientes se sincroniza con el backend desde `CloudClientSyncService`: lee
  `sync_queue`, envia `POST /api/clients/sync/push`, aplica respuestas a
  SQLite y descarga cambios desde `POST /api/clients/sync/pull`.
- Productos e imagenes se sincronizan desde `CloudProductSyncService`: envia
  productos a `POST /api/products/sync/push`, descarga desde
  `POST /api/products/sync/pull`, envia metadata de imagenes a
  `POST /api/products/images/sync/push` y descarga metadata desde
  `POST /api/products/images/sync/pull`. No sube binarios todavia; conserva
  `local_path` para offline y prepara `remote_url`/`storage_key`.
- Movimientos y deuda items se sincronizan desde
  `CloudMovementSyncService`. Los movimientos resuelven el cliente remoto desde
  SQLite antes del push; si falta `clientes.remote_id`, el item queda fallido
  hasta sincronizar clientes.
- Comprobantes se sincronizan desde `CloudReceiptSyncService`, asociados a
  movimientos y clientes remotos ya sincronizados.
- Ciclos de credito se sincronizan desde `CloudCreditCycleSyncService`. El
  backend persiste el estado 30/45/60 calculado por Flutter y devuelve ciclos,
  recordatorios y excepciones para actualizar SQLite.
- Auditorias y auditoria items se sincronizan desde `CloudAuditSyncService`.
  Las escrituras salen de `sync_queue`, se actualiza `remote_id` local y el pull
  incremental respeta negocio/colaborador segun el JWT.
- Solicitudes de autorizacion se sincronizan desde
  `CloudAuthorizationRequestSyncService`. El colaborador sincroniza sus
  solicitudes y el negocio puede recibirlas para aprobar/rechazar; las
  decisiones remotas quedan preparadas con endpoints dedicados.
- Las deudas con mercancias guardan primero el movimiento y luego sus
  `deuda_items`; ambos quedan encolados para futura sincronizacion.
- Si la deuda incluye productos vinculados al inventario, el repositorio
  descuenta stock en la misma transaccion y encola los productos actualizados.
- Los comprobantes se guardan en SQLite con `payload_json`, pueden exportarse a
  PDF, imprimirse y compartirse por el menu nativo del dispositivo.
- La UI se refresca invalidando providers o recargando notifiers.

## Estado De Sincronizacion

Los estados centralizados viven en `lib/core/sync/sync_status.dart`.

- `pending`: creado localmente y pendiente de sincronizar.
- `synced`: procesado por el flujo de sincronizacion.
- `updated`: registro local modificado luego de crearse/sincronizarse.
- `deleted`: baja logica o eliminacion local que debe propagarse.
- `failed`: intento de sincronizacion fallido.

La tabla `sync_queue` contiene:

- `id`
- `entity_type`
- `entity_id`
- `operation`
- `payload`
- `status`
- `attempts`
- `last_error`
- `created_at`
- `updated_at`

`SyncService` conserva la simulacion general. Los flujos reales por modulo
viven en servicios dedicados: `CloudClientSyncService`,
`CloudProductSyncService`, `CloudMovementSyncService`,
`CloudReceiptSyncService`, `CloudCreditCycleSyncService`,
`CloudAuditSyncService`, `CloudAuthorizationRequestSyncService` y
`CloudClientScoreSyncService`.

## Inteligencia Comercial

El Motor de Inteligencia Comercial v1 calcula `ClientScore` offline desde
movimientos, ciclos de credito y pagos locales. Cada snapshot se guarda en
SQLite (`client_scores`) y entra a `sync_queue`, conservando el patron
offline-first. La sync cloud inicial publica esos snapshots a
`/api/client-scores/sync/push` y descarga cambios desde
`/api/client-scores/sync/pull`.

El backend ASP.NET Core persiste `ClientScores` por `BusinessId + ClientId`,
expone reportes `top` y `risk`, y deja preparada la futura validacion o
recalculo servidor sin reemplazar el calculo local actual.

## Pagos Y Suscripciones

El modulo de pagos conserva `MockPaymentProvider` para QA local y agrega
`StripePaymentProvider` en modo TEST. Stripe se usa solo a traves de Checkout:
Fiado App no recibe ni guarda numero de tarjeta, CVV ni fecha completa. El
backend guarda identificadores tecnicos de Stripe (`customer`, `subscription`,
facturas/webhooks) y actualiza la suscripcion local desde webhooks.

Endpoints Stripe:

- `POST /api/payments/stripe/create-checkout-session`
- `POST /api/payments/stripe/webhook`

La app abre `checkoutUrl` con `url_launcher`. Si Stripe no esta configurado, el
backend devuelve error claro y el flujo mock sigue disponible.

### Catalogo De Precios

La fuente unica de verdad en Flutter es
`lib/core/constants/subscription_plans.dart`. La fuente unica de verdad en
backend es `backend/src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs`.
Ambas definen precios oficiales en USD:

- Basico: USD 4.99 mensual, USD 13.47 trimestral, USD 47.90 anual, 3
  colaboradores.
- Crecimiento: USD 12.99 mensual, USD 35.07 trimestral, USD 124.70 anual, 7
  colaboradores.
- Empresarial: USD 20.99 mensual, USD 56.67 trimestral, USD 201.50 anual, 15
  colaboradores.

DOP se muestra solo como equivalente aproximado calculado desde USD. Stripe
TEST debe configurar `PriceIds` que correspondan exactamente a esos montos USD,
sin crear precios automaticamente desde la app.

## Dashboard Ejecutivo V2

Las pantallas iniciales dejaron de ser listas grandes de accesos y ahora usan
un dashboard por rol:

- `PrincipalScreen`: dashboard de Negocio con KPIs de clientes, fiado activo,
  cobros del mes, score, riesgo, stock bajo, vencidos 30 y bloqueados 60.
- `PersonalPortalScreen`: dashboard Personal con total adeudado, negocios donde
  debe, proximo vencimiento e historial de cumplimiento.
- `ColaboradorDashboardScreen`: dashboard Colaborador con auditorias,
  solicitudes y productos vinculados a su operacion.

Los accesos se organizaron en `AppNavigationDrawer`, manteniendo pantallas
existentes. Los widgets reutilizables viven en `lib/widgets/`:

- `dashboard_kpi_card.dart`
- `dashboard_news_card.dart`
- `dashboard_section_header.dart`
- `app_navigation_drawer.dart`
- `animated_dashboard_card.dart`
- `executive_kpi_card.dart`
- `fiado_gradient_card.dart`
- `fiado_action_tile.dart`
- `fiado_empty_state.dart`
- `fiado_loading_state.dart`

El dashboard usa datos ya disponibles por providers/repositorios existentes y
debe mostrar `0` o `Sin datos` cuando no exista informacion suficiente.

## Sistema Visual

El sistema visual se documenta en `UI_DESIGN_SYSTEM.md` y centraliza paleta,
gradientes, sombras, motion, `ThemeData` y componentes reutilizables. La
inspiracion es la simpleza de apps SaaS para pequenos negocios, pero Fiado App
mantiene identidad propia: verde moderno, azul de confianza, alertas suaves y
profundidad visual ligera.

## Deudas Con Mercancias Y Abono Inicial

- La fuente unica para seleccionar articulos facturables es
  `billableProductsProvider`, respaldado por
  `ProductoRepository.obtenerProductosFacturables` y la consulta SQLite
  compartida `BillableProductQuery`.
- `AgregarDeudaDialog` no debe usar `productosProvider`,
  `productoBusquedaProvider`, `InventarioScreen`, dashboard ni metricas de
  inventario para poblar el selector de articulos.
- Las relaciones locales de mercancias usan el `id` SQLite real:
  `deuda_items.movimiento_id = movimientos.id` y
  `comprobantes.movimiento_id = movimientos.id`.
- `AgregarDeudaDialog` permite dejar `Monto total final` vacio para usar el
  subtotal de articulos, o escribir un monto manual para ajustar el fiado.
- Si el monto final manual es menor al subtotal de mercancias, Fiado App guarda
  la deuda por el monto final y registra un movimiento tipo `pago` informativo
  con concepto `Abono inicial del fiado #[id]`.
- El pago inicial se registra para historial, reportes y sync, pero no reduce
  otra vez el ciclo de credito porque la deuda ya fue creada por el saldo final.
- ComprobanteScreen y PDF reconstruyen mercancias desde `deuda_items` si un
  comprobante existente no trae productos en su payload.

## Que NO Hacer

- No volver a usar `SharedPreferences` como fuente principal de datos.
- No guardar contrasenas en texto plano.
- No dispersar logica de permisos directamente en pantallas.
- No eliminar migraciones SQLite existentes.
- No conectar backend real ignorando `sync_queue`.
- No hacer llamadas HTTP reales desde repositorios locales.
- No romper el flujo offline-first: primero SQLite, luego cola, luego sync.
- No revertir cambios de estructura sin revisar dependencias entre pantallas,
  providers y repositorios.

## Proximas Fases Recomendadas

- Mejorar validacion visual en formularios y pantallas criticas.
- Hardening de seguridad local.
- Reemplazar hash local temporal por autenticacion backend.
- Crear backend ASP.NET Core.
- Crear modelo cloud en SQL Server.
- Definir API REST para entidades sincronizables.
- Implementar autenticacion JWT.
- Implementar sincronizacion real usando `sync_queue`.
- Sincronizar comprobantes creados localmente respetando `sync_queue`.
- Resolver conflictos de datos entre local y cloud.
- Agregar pruebas automatizadas de repositorios y reglas de negocio.
- Agregar pruebas de UI para flujos principales.

## Guia Para Codex

Al modificar Fiado App en futuras tareas:

- Lee primero los repositorios, providers y modelos afectados antes de editar.
- Conserva SQLite como fuente local principal.
- Manten el flujo `Pantalla -> Provider -> Repository -> SQLite -> sync_queue`.
- Si agregas una escritura local sincronizable, tambien agrega entrada en
  `sync_queue`.
- Usa `SyncStatus` y `SyncOperationType` centralizados; no dupliques strings.
- No conectes HTTP real dentro de repositorios locales.
- Si se agrega backend, hazlo desde servicios dedicados y respetando
  `sync_queue`.
- No metas reglas de permisos repetidas en pantallas; usa helpers o providers.
- Manten los cambios pequenos y compatibles con pantallas existentes.
- Antes de borrar o renombrar tablas/campos, revisa migraciones y modelos.
- Evita depender de `SharedPreferences` para datos de negocio nuevos.
- Si el toolchain Dart/Flutter se queda colgado, mata procesos vivos y valida
  con cambios pequenos antes de reintentar comandos largos.
# Inventario Por Negocio

Los productos no son globales. Cada producto pertenece exclusivamente a un
negocio mediante `negocio_id`. Los usuarios Negocio usan su propio `id` como
negocio activo; los Colaboradores usan el `negocio_id` del negocio al que
pertenecen; Personal no accede a inventario de negocio.

La app no debe sembrar productos demo ni migrar productos legacy globales a un
negocio nuevo. Las imagenes, metricas de inventario, auditorias, campanas
WhatsApp y selectores de articulos deben filtrar por el negocio activo.
