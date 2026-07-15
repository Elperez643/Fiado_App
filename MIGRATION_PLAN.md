# Fiado App - Migration Plan

## Objetivo

Preparar la migracion progresiva desde SQLite local hacia backend ASP.NET Core
+ SQL Server sin romper el modo offline-first actual. La app debe seguir
funcionando localmente mientras el backend se introduce por modulos y
sincroniza mediante `sync_queue`.

## Modulos Existentes

- Auth y sesiones locales.
- Usuarios, roles y permisos: Personal, Negocio y Colaborador.
- Suscripciones SaaS en USD, trial de 30 dias, ciclos mensual/trimestral/anual.
- Onboarding Assistant por usuario y tipo de cuenta.
- Clientes por negocio.
- Movimientos: deudas, pagos e historial.
- Deuda items: detalle de mercancias dentro de deudas.
- Inventario: productos, codigos, precios, stock, demanda e imagenes.
- Colaboradores y solicitudes de autorizacion.
- Auditorias diarias/semanales e items auditados.
- Comprobantes internos y PDF.
- Ciclos de credito 30/45/60, recordatorios y excepciones.
- Recordatorios y consejos de deuda para usuario Personal, calculados localmente
  por telefono autenticado.
- Sync queue local.
- Infraestructura mock de pagos para suscripciones.
- Motor de inteligencia comercial v1 para score offline de clientes.

Nota: Personal Debt Guidance no agrega entidad cloud en esta fase. Consume
`credito_ciclos`, `movimientos` y `comprobantes` ya sincronizables.

## Tablas SQLite Actuales

- `clientes`
- `movimientos`
- `pagos`
- `productos`
- `usuarios`
- `sesiones`
- `subscriptions`
- `solicitudes_autorizacion`
- `auditorias`
- `auditoria_items`
- `producto_imagenes`
- `deuda_items`
- `comprobantes`
- `credito_ciclos`
- `credito_ciclo_movimientos`
- `credito_recordatorios`
- `credito_excepciones`
- `user_onboarding`
- `sync_queue`

## Entidades Que Iran A SQL Server

- `User`
- `Business`
- `BusinessMember`
- `Subscription`
- `SubscriptionPlanSnapshot`
- `UserOnboarding`
- `Client`
- `Movement`
- `DebtItem`
- `Product`
- `ProductImage`
- `AuthorizationRequest`
- `Audit`
- `AuditItem`
- `Receipt`
- `CreditCycle`
- `CreditCycleMovement`
- `CreditReminder`
- `CreditException`
- `SyncOperation`
- `DeviceSession`

## Endpoints Necesarios Por Modulo

- Auth: login, refresh token, logout, registro Personal, registro Negocio.
- Usuarios: perfil actual, actualizacion basica, estado activo.
- Negocios: datos del negocio, miembros, configuracion.
- Colaboradores: listar, crear, editar, activar/desactivar.
- Suscripciones: planes, trial, plan actual, seleccion de plan, estado.
- Pagos: metodos tokenizados, historial, transacciones, renovaciones,
  cancelacion futura, webhooks y estado de facturacion.
- Inteligencia comercial: score de clientes, riesgo, limite sugerido y reportes
  de mejores clientes/clientes en riesgo.
- Onboarding: consultar estado, completar, omitir.
- Clientes: CRUD, busqueda, paginacion, cambios por negocio.
- Movimientos: crear deuda/pago, listar por cliente, listar por negocio.
- Deuda items: crear/listar detalle por movimiento.
- Productos: CRUD logico, busqueda, stock, imagenes.
- Producto imagenes: registrar metadata y flujo futuro de upload.
- Solicitudes: crear, listar, aprobar, rechazar.
- Auditorias: crear, listar, resolver items.
- Comprobantes: crear, consultar, export metadata.
- Ciclos credito: consultar estado, cuentas por cobrar, registrar excepcion.
- Recordatorios: generar, listar, marcar enviado.
- Sync queue: push de operaciones locales, pull incremental, confirmar apply.

## Estrategia Offline-First

1. SQLite continua como fuente inmediata para UI y escrituras locales.
2. Cada escritura relevante se guarda primero localmente.
3. La escritura local genera entrada en `sync_queue`.
4. Un servicio de sincronizacion enviara operaciones pendientes al backend.
5. El backend aplicara cambios de forma idempotente usando `remote_id`,
   `entity_type`, `entity_id`, timestamps y operacion.
6. Clientes ya cuenta con sync cloud inicial: push desde `sync_queue` a
   `/api/clients/sync/push` y pull incremental desde `/api/clients/sync/pull`.
7. Productos e imagenes ya cuentan con sync cloud inicial: productos usan
   `/api/products/sync/push` y `/api/products/sync/pull`; imagenes usan
   `/api/products/images/sync/push` y `/api/products/images/sync/pull`.
8. Las imagenes sincronizan metadata (`local_path`, `remote_url`,
   `storage_key`, orden, mime, peso y dimensiones), no binarios todavia.
9. Movimientos, deuda items, comprobantes y ciclos de credito ya cuentan con
   sync cloud inicial. El backend persiste el estado financiero calculado por
   Flutter y no recalcula todavia reglas 30/45/60.
10. Auditorias, auditoria items y solicitudes de autorizacion ya cuentan con
    sync cloud inicial. El flujo sincroniza metadata/estado operacional y
    conserva SQLite como fuente offline-first.
11. La app recibira cambios remotos incrementales y actualizara SQLite.
12. La UI seguira leyendo repositorios locales para mantener respuesta rapida.
13. Pagos reales se habilitaran solo despues de integrar un proveedor formal
    (Stripe, Azul o CardNet) con tokenizacion, webhooks firmados e
    idempotencia. La fase actual usa proveedor mock y no guarda datos sensibles.
14. El score inteligente se calcula por reglas locales sobre datos reales de
    credito/pago; puede sincronizarse a cloud en una fase posterior como
    snapshot explicable, sin depender de IA externa.

## Inteligencia Comercial V1

El modulo `lib/credit_scoring/` contiene:

- `ClientScore`
- `ClientScoreService`
- `BusinessClientScoreReport`

Algoritmo deterministico:

- Suma puntos por pagos antes de 30 dias, pagos entre 30 y 45, ciclos saldados,
  pagos existentes y antiguedad.
- Resta puntos por pagos entre 45 y 60, vencidos 30, mora 45, bloqueos 60 y bajo
  cumplimiento.
- Clasifica: 70-100 bajo riesgo, 40-69 riesgo medio, 0-39 riesgo alto.
- Sugiere limite usando promedio historico de credito, score e historial pagado.
- Explica motivos y usa lenguaje de recomendacion: "Fiado App recomienda".

## Arquitectura De Pagos Preparada

- Backend:
  - `SubscriptionPayment`
  - `PaymentMethod`
  - `PaymentTransaction`
  - `PaymentWebhookLog`
  - `IPaymentProvider`
  - `MockPaymentProvider`
  - `PaymentService`
  - `PaymentsController`
- Flutter:
  - `PaymentService`
  - `SubscriptionBillingService`
  - `PaymentMethodsScreen`
  - `BillingHistoryScreen`
  - `SubscriptionStatusScreen`

Restricciones de seguridad:

- No guardar numero completo de tarjeta.
- No guardar CVV.
- No guardar fecha de expiracion de una tarjeta real como dato sensible de
  captura directa.
- Guardar solo metadata segura: proveedor, customer id, payment method id,
  marca y ultimos 4 digitos.

## Catalogo De Precios De Suscripcion

Flutter usa `lib/core/constants/subscription_plans.dart` como fuente unica de
verdad para los precios visibles. Backend usa
`backend/src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs` para mock,
Stripe Checkout, estado de suscripcion e historial.

Precios oficiales:

- Basico: USD 4.99 mensual, USD 13.47 trimestral, USD 47.90 anual.
- Crecimiento: USD 12.99 mensual, USD 35.07 trimestral, USD 124.70 anual.
- Empresarial: USD 20.99 mensual, USD 56.67 trimestral, USD 201.50 anual.

Los equivalentes DOP son aproximados y se calculan desde USD. Los precios
historicos RD$700, RD$1,500 y RD$2,800 quedan obsoletos y no deben aparecer
como importes oficiales activos.

## Configuracion De Backend Por Plataforma

La app usa `ApiEnvironmentConfig` como fuente central de `baseUrl`, timeout y
entorno activo. Esto evita cambiar codigo al probar en Android emulador,
Android fisico, Web o Desktop.

- Android emulador usa `http://10.0.2.2:5193/api`.
- Android fisico usa `http://TU_IP_LOCAL:5193/api`; se debe reemplazar por la
  IP LAN de la computadora que corre el backend.
- Desktop usa `http://127.0.0.1:5193/api`.
- Web usa `http://localhost:5193/api`.
- Produccion usa `https://api.fiadoapp.com/api`.

`BackendSettingsScreen` guarda el entorno y baseUrl localmente, prueba
`/health` y permite limpiar token sin tocar datos de negocio.

## Estado Multiplataforma

Android sigue siendo el objetivo principal offline-first. Windows/Linux Desktop
quedan preparados con `sqflite_common_ffi` para reutilizar SQLite sin cambiar
repositorios. Web puede compilar para validacion visual, pero requiere una
decision futura de almacenamiento (`sqflite_common_ffi_web`, IndexedDB o
backend-first) antes de considerarlo definitivo.

iOS queda preparado para la siguiente fase de pruebas en macOS/Xcode sin cambio
de logica de negocio. La app conserva SQLite offline-first via `sqflite`, usa
permisos declarados para imagenes, y debe validar en dispositivo real share
sheet, impresion PDF, seleccion de imagenes y conexion al backend por IP LAN o
HTTPS.

## Estrategia `sync_queue`

- Mantener operaciones: `create`, `update`, `delete`.
- Payload debe incluir entidad completa y bloque `_sync`.
- Agregar en backend un identificador idempotente por operacion.
- Procesar en orden de `created_at`.
- Reintentar fallos con contador `attempts`.
- Marcar `synced` solo cuando el backend confirme persistencia.
- Guardar `last_error` para diagnostico.
- Resolver conflictos por entidad, modulo y marca temporal.

## Riesgos

- Conflictos entre ediciones offline y cambios remotos.
- Duplicados por reintentos sin idempotencia.
- Migracion de IDs locales a `remote_id`.
- Sesiones y password hash local actual no son seguridad final.
- Imagenes requieren estrategia separada de almacenamiento.
- Comprobantes PDF no deben depender de archivos locales para validez.
- Ciclos de credito tienen reglas sensibles de fechas y saldos.
- Multi-negocio exige filtros estrictos por `negocio_id`.
- Cambios en schema SQLite deben conservar migraciones existentes.

## Orden Recomendado De Migracion

1. Definir modelo SQL Server y contratos API.
2. Implementar Auth backend con JWT/refresh tokens.
3. Migrar usuarios, negocios y colaboradores.
4. Implementar endpoint de sync generico e idempotente.
5. Continuar desde clientes hacia movimientos sin inventario. Clientes ya tiene
   el primer puente cloud funcional y debe servir como patron.
6. Migrar productos e imagenes metadata. Hecho como sync cloud inicial; los
   productos ya incluyen costo unitario, precio de venta y porcentaje de
   ganancia, codigo de referencia y ubicacion. El lector de codigo de barras
   alimenta datos locales editables; no usa APIs externas. Falta subida binaria
   futura a almacenamiento tipo Blob Storage.
7. Migrar deuda items y comprobantes. Hecho como sync cloud inicial.
8. Migrar ciclos de credito, recordatorios y excepciones. Hecho como sync
   cloud inicial para ciclos y pull de recordatorios/excepciones; falta
   validacion cloud avanzada.
9. Migrar auditorias y solicitudes de autorizacion. Hecho como sync cloud
   inicial para auditorias, audit items y solicitudes; falta observabilidad
   avanzada y resolucion de conflictos fina.
10. Migrar score inteligente de clientes. Hecho como sync cloud inicial:
    Flutter calcula offline, guarda `client_scores`, encola `sync_queue` y el
    backend persiste snapshots por negocio para reportes y calculo futuro.
11. Integrar Stripe TEST para suscripciones. Hecho como infraestructura
    inicial con Checkout/Billing y webhooks, manteniendo MockPaymentProvider.
12. Habilitar pull incremental por negocio.
13. Inventario Inteligente v1 calcula insights localmente desde SQLite. No
    sincroniza `InventoryInsight` como entidad; usa cache local
    `inventory_product_metrics` con recalculo incremental/dirty. Futuro backend
    puede calcular snapshots cloud usando las mismas formulas.
14. Agregar resolucion de conflictos y observabilidad.
15. Endurecer seguridad, validaciones y backups.

## Criterio De Exito

- La app sigue funcionando offline.
- Ninguna pantalla escribe directo a HTTP.
- Repositorios locales mantienen SQLite como fuente de lectura.
- `sync_queue` es el unico puente de escrituras hacia cloud; clientes,
  productos, imagenes, movimientos, deuda items, comprobantes, ciclos,
  auditorias, solicitudes y score inteligente ya lo usan para sincronizar
  contra ASP.NET Core sin reemplazar SQLite.
- Backend puede reconstruir estado cloud desde operaciones sincronizadas.
- Pagos reales de produccion siguen bloqueados hasta configurar Stripe live,
  conciliacion final, observabilidad e idempotencia avanzada.
# Cobranza Inteligente v1

- Agregado modulo Flutter offline-first `collections_intelligence`.
- No se agrega backend ni entidad sincronizable nueva.
- Se agregan indices SQLite sobre `credito_ciclos` para consultas de cartera por negocio, estado, saldo y fechas limite.
- Futuro: evaluar `collection_insights_cache` o calculo cloud si el volumen de ciclos crece sobre los objetivos de performance.
# Business Copilot v1

- Nueva tabla SQLite `business_recommendations_cache`.
- Nueva version de schema local para crear cache e indices.
- No hay migracion backend.
- Las recomendaciones no se sincronizan todavia; se recalculan localmente desde datos existentes.
