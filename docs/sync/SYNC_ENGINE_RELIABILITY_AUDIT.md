# Fiado App Sync Engine Reliability Audit

Fecha: 2026-07-15
Rama auditada: `audit/sync-engine-reliability`
Tipo de auditoria: estatica, trazable, sin cambios funcionales

## Resumen ejecutivo

La sincronizacion de Fiado App esta en una transicion controlada entre dos rutas:

- `sync_outbox` + `SyncEngine` V2 para `clients`, `inventory` e `inventory_images`.
- `sync_queue` + servicios cloud legacy para movimientos, recibos, ciclos de credito, auditorias, autorizaciones, client scores y campanas WhatsApp.

El baseline actual tiene mejoras importantes: contratos locales, validacion de payloads, estados visibles honestos, endpoints V2 registrados, indices SQLite para colas y estado, indices backend por negocio/fecha, soporte de sesion activa unica y pruebas relevantes. Sin embargo, todavia hay riesgos de confiabilidad en escenarios de rechazo parcial, concurrencia entre instancias, paginacion de pull V2, migracion entre colas y cobertura de fallos intermedios.

Conclusiones principales:

- El motor V2 es razonable para `clients` e `inventory`, pero no debe considerarse completo para todos los modulos registrados.
- La mayor amenaza operativa es que un lote parcialmente aceptado por backend quede completo como fallido localmente y se reintente entero.
- La segunda amenaza es que los modulos registrados en V2 pero no aplicados realmente por backend puedan reportar aceptacion sin persistencia.
- La tercera amenaza es que `sync_queue` legacy esta aislado por feature flag, pero muchas escrituras funcionales siguen entrando por esa ruta.
- El sistema requiere pruebas de fallos intermedios, multiples instancias, multiples dispositivos y lotes grandes antes de declararse robusto para produccion multi-dispositivo.

## Alcance

Incluido:

- Motor V2: `SyncEngine`, `SyncOutboxRepository`, `SyncStateRepository`, `SyncEndpointRegistry`.
- Cola legacy: `SyncQueueRepository`, `AutoSyncService`, servicios `Cloud*SyncService`.
- Persistencia local: tablas `sync_outbox`, `sync_queue`, `sync_state`.
- Backend sync: `SyncController`, `GenericSyncService`, `InventoryImagesSyncController`.
- Autenticacion/sesion activa: claims `device_id`, `session_version`, validacion `SESSION_REPLACED`.
- Pruebas existentes relacionadas con sync.

Excluido:

- Ejecucion de comandos Dart/Flutter.
- Cambios funcionales.
- Migraciones nuevas.
- Validacion manual con backend real.
- Pruebas de carga reales.

## Arquitectura actual

### Flujo V2

```text
Repositorio local
  -> SyncOutboxRepository.enqueue()
  -> sync_outbox(status=pending)
  -> SyncScheduler / UI / provider llama SyncEngine.syncNow()
  -> SyncEngine.pushPending()
  -> POST /api/sync/{module}/push
  -> markSynced() + adapter.onPushAccepted()
  -> SyncEngine.pullChanges()
  -> POST /api/sync/{module}/pull
  -> adapter.applyPullChanges()
  -> SyncStateRepository.upsert()
```

Evidencia:

- Guard local `_syncing`: `lib/data/services/sync_engine.dart:75`.
- Push batch y rechazo: `lib/data/services/sync_engine.dart:174`, `lib/data/services/sync_engine.dart:217`.
- Pull por `lastPullAt`: `lib/data/services/sync_engine.dart:328`.
- Estado por modulo: `lib/data/services/sync_engine.dart:464`.
- `sync_outbox.uuid` unico: `lib/core/database/database_schema.dart:438`.
- `sync_state` unico por negocio/modulo: `lib/core/database/database_schema.dart:753`.

### Flujo legacy

```text
Repositorio local
  -> SyncQueueRepository.enqueueCreate/update/delete()
  -> sync_queue(status=pending)
  -> AutoSyncService.syncNow()
  -> Cloud*SyncService push/pull por handler legacy
  -> marca queue como synced/failed
  -> actualiza tablas locales y preferencias lastSyncAt
```

Evidencia:

- `enableLegacySync = false`: `lib/core/sync/sync_feature_flags.dart:5`.
- `AutoSyncService` retorna si legacy esta apagado: `lib/data/services/auto_sync_service.dart:142`.
- Encolado legacy con contratos: `lib/data/repositories/sync_queue_repository.dart:189`.
- Movimientos incrementan intento antes de enviar: `lib/data/services/cloud_movement_sync_service.dart:83`.

### Backend V2

```text
POST /api/sync/{module}/push
  -> GenericSyncService.PushAsync()
  -> clients/inventory aplican cambios reales
  -> otros modulos registrados se cuentan como aceptados

POST /api/sync/{module}/pull
  -> GenericSyncService.PullAsync()
  -> clients/inventory devuelven cambios reales
  -> HasMore=false
```

Evidencia:

- Rutas autorizadas: `backend/src/FiadoApp.Api/Controllers/SyncController.cs:8`.
- Modulos permitidos: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:15`.
- Aplicacion real `clients`: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:36`.
- Aplicacion real `inventory`: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:51`.
- Aceptacion generica restante: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:66`.
- Pull sin paginacion real: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:171`.

## Inventario de componentes

Componentes principales identificados: 31.

| Area | Componentes |
| --- | --- |
| Motor V2 | `SyncEngine`, `SyncScheduler`, `SyncModuleAdapter`, `ClientSyncAdapter`, `InventorySyncAdapter` |
| Persistencia V2 | `SyncOutboxRepository`, `SyncStateRepository`, `SyncOutboxItem`, `SyncStateModel` |
| Contratos V2 | `SyncEndpointRegistry`, `DataContractRegistry`, `DataContractValidator` |
| Media inventario | `InventoryMediaSyncService`, `InventoryImageSyncDiagnostics`, `InventoryImagesSyncController` |
| Legacy local | `SyncQueueRepository`, `SyncQueueItemModel`, `AutoSyncService` |
| Legacy servicios | `CloudClientSyncService`, `CloudProductSyncService`, `CloudMovementSyncService`, `CloudReceiptSyncService`, `CloudCreditCycleSyncService`, `CloudAuditSyncService`, `CloudAuthorizationRequestSyncService`, `CloudClientScoreSyncService`, `CloudWhatsappCampaignSyncService` |
| Backend V2 | `SyncController`, `GenericSyncService`, `GenericSyncPushRequest`, `GenericSyncPullRequest`, `OperationalSyncMapper`, `FinancialSyncMapper` |
| Seguridad | `AuthService.ValidateActiveSessionAsync`, `ApiClient` manejo `SESSION_REPLACED` |
| Diagnostico | `SyncDiagnosticsRepository`, `SyncStatusDiagnosticsRepository`, `BackendConnectionDiagnostics` |

## Matriz por modulo

| Modulo | Ruta local principal | Endpoint | Backend aplica cambios | Pull global | Riesgo |
| --- | --- | --- | --- | --- | --- |
| `clients` | `sync_outbox` V2 y residuos legacy | `/api/sync/clients` | Si | Si | Medio |
| `inventory` | `sync_outbox` V2 y residuos legacy | `/api/sync/inventory` | Si | Si | Medio |
| `inventory_images` | `sync_outbox` V2 especial | `/api/sync/inventory/images` | Si, controlador dedicado | No global; lazy | Medio |
| `movements` | `sync_queue` legacy | `/movements/sync` legacy y `/api/sync/movements` registrado | V2 no persiste | Si en legacy | Critico |
| `debt_items` | `sync_queue` legacy | `/debt-items/sync` legacy | No en V2 | Si en legacy | Alto |
| `receipts` | `sync_queue` legacy | `/receipts/sync` legacy | No en V2 | Si en legacy | Alto |
| `credit_cycles` | `sync_queue` legacy | `/credit-cycles/sync` legacy | No en V2 | Si en legacy | Alto |
| `audits` | `sync_queue` legacy | `/audits/sync` legacy y `/api/sync/audits` registrado | V2 acepta sin persistir | No claro | Alto |
| `authorization_requests` | `sync_queue` legacy | `/authorization-requests/sync` legacy | No en V2 | Si en legacy | Medio |
| `client_scores` | `sync_queue` legacy | `/client-scores/sync` legacy | No en V2 | Si en legacy | Medio |
| `whatsapp` / `whatsapp_campaigns` | V2 registra `whatsapp`; legacy usa `whatsapp_campaigns` | `/api/sync/whatsapp` y `/whatsapp-campaigns/sync` | V2 acepta sin persistir | Legacy cubre | Alto |
| `collaborators` | V2 registrado | `/api/sync/collaborators` | V2 acepta sin persistir | No claro | Alto |

## Hallazgos

### SYNC-CRIT-001 - Modulos V2 registrados pueden aceptarse sin persistencia real

Severidad: Critica

Evidencia:

- `SyncEndpointRegistry` registra `movements`, `audits`, `collaborators`, `whatsapp`: `lib/data/services/sync_endpoint_registry.dart:53`, `lib/data/services/sync_endpoint_registry.dart:88`, `lib/data/services/sync_endpoint_registry.dart:92`, `lib/data/services/sync_endpoint_registry.dart:96`.
- Backend V2 solo aplica `clients` e `inventory`: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:36`, `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:51`.
- Para otros modulos, `accepted = request.Changes.Count`: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:66`.

Escenario de fallo:

Un evento de `movements`, `audits`, `collaborators` o `whatsapp` llega por V2. El backend responde aceptado, el cliente marca el outbox como sincronizado y el dato nunca se persiste.

Impacto: perdida silenciosa de datos.
Probabilidad: media mientras esos modulos puedan entrar a V2.
Recomendacion: no permitir V2 para modulos sin implementacion real o devolver error 400/501 hasta que exista servicio especifico.
Prueba requerida: push V2 por cada modulo registrado no implementado debe fallar de forma controlada y no marcar `sync_outbox` como synced.

### SYNC-CRIT-002 - Rechazo parcial de backend puede duplicar aceptados en reintentos

Severidad: Critica

Evidencia:

- Cliente lanza error si `rejected > 0`: `lib/data/services/sync_engine.dart:217`.
- `markSynced()` ocurre despues del rechazo: `lib/data/services/sync_engine.dart:229`.
- En catch se marca fallido todo `moduleItems`: `lib/data/services/sync_engine.dart:269`.
- Backend puede aceptar algunos y rechazar otros: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:35`, `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:111`.

Escenario de fallo:

Un lote de 10 cambios tiene 9 aceptados y 1 rechazado. El backend persiste 9, devuelve `accepted=9,rejected=1`, el cliente marca los 10 como failed y reintenta los 10.

Impacto: duplicados, conflictos, reescrituras innecesarias o errores permanentes.
Probabilidad: media-alta con datos mixtos.
Recomendacion: respuesta por item con uuid y estado; marcar synced solo aceptados y failed solo rechazados.
Prueba requerida: lote mixto accepted/rejected valida estado local por item y reintento solo de rechazados.

### SYNC-HIGH-001 - El bloqueo de concurrencia es por instancia, no global

Severidad: Alta

Evidencia:

- `SyncEngine.syncNow()` usa `_syncing` de instancia: `lib/data/services/sync_engine.dart:75`.
- Scheduler dispara por timer, conectividad y arranque: `lib/data/services/sync_scheduler.dart:26`, `lib/data/services/sync_scheduler.dart:32`, `lib/data/services/sync_scheduler.dart:35`.

Escenario de fallo:

Dos providers o servicios crean instancias distintas de `SyncEngine` y ejecutan sync simultaneo sobre la misma base. Ambos leen pendientes antes de que el otro marque estado final.

Impacto: reintentos dobles, conteos inconsistentes y errores intermitentes.
Probabilidad: media.
Recomendacion: candado persistente o singleton garantizado por DI; transicion atomica `pending -> syncing` con condicion `WHERE status IN (...)`.
Prueba requerida: dos instancias contra la misma DB no deben enviar el mismo outbox dos veces.

### SYNC-HIGH-002 - Pull V2 no pagina y siempre reporta `HasMore=false`

Severidad: Alta

Evidencia:

- Cliente no procesa `hasMore`: `lib/data/services/sync_engine.dart:328`.
- Backend devuelve `HasMore = false`: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:171`.
- Pull de clients/inventory usa `ToListAsync()` sin limite: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:292`, `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:466`.

Escenario de fallo:

Un negocio con miles de clientes/productos hace restore inicial. El backend carga todo en memoria y el cliente lo aplica en un solo lote.

Impacto: timeout, consumo alto de memoria y restauraciones incompletas.
Probabilidad: media en negocios grandes.
Recomendacion: cursor estable, limite, `hasMore=true` y loop cliente hasta agotar paginas.
Prueba requerida: pull con mas de N cambios retorna paginas y mantiene orden sin omisiones.

### SYNC-HIGH-003 - Legacy sync esta apagado, pero muchas escrituras todavia dependen de `sync_queue`

Severidad: Alta

Evidencia:

- `enableLegacySync = false`: `lib/core/sync/sync_feature_flags.dart:5`.
- `AutoSyncService.autoSyncIfNeeded()` retorna null si legacy apagado: `lib/data/services/auto_sync_service.dart:142`.
- Repositorios de movimientos, deudas, recibos, ciclos, auditorias y WhatsApp encolan en `sync_queue`.
- Ejemplo movimiento: `lib/data/repositories/movimiento_repository.dart:210`.
- Ejemplo WhatsApp: `lib/data/repositories/whatsapp_campaign_repository.dart:272`.

Escenario de fallo:

El usuario crea movimientos o campanas. La UI muestra pendientes honestamente, pero la cola legacy no se procesa automaticamente si la bandera permanece apagada.

Impacto: datos guardados solo localmente mas tiempo del esperado.
Probabilidad: alta para funcionalidades fuera de clients/inventory.
Recomendacion: migrar esos dominios a V2 o habilitar legacy de manera explicita y monitoreada por dominio.
Prueba requerida: cada flujo funcional debe demostrar si queda en V2, legacy activo o local-only documentado.

### SYNC-HIGH-004 - Avance del cursor pull ocurre despues de aplicar cambios, pero usa hora local

Severidad: Alta

Evidencia:

- Pull envia `lastPullAt`: `lib/data/services/sync_engine.dart:331`.
- Despues de aplicar cambios actualiza `lastPullAt: DateTime.now()`: `lib/data/services/sync_engine.dart:351`.
- Backend retorna `ServerTime`: `backend/src/FiadoApp.Api/Services/GenericSyncService.cs:175`.

Escenario de fallo:

El reloj local esta adelantado. El cliente guarda `lastPullAt` futuro y omite cambios del servidor con `UpdatedAt` anterior a ese futuro.

Impacto: perdida temporal de cambios remotos hasta que exista correccion manual o cambio nuevo.
Probabilidad: media.
Recomendacion: guardar `serverTime` recibido o cursor backend, no `DateTime.now()` local.
Prueba requerida: reloj local adelantado no debe omitir cambios remotos.

### SYNC-MED-001 - `markSyncing` incrementa intentos antes de confirmar envio

Severidad: Media

Evidencia:

- `markSyncing()` sube `attempt_count`: `lib/data/repositories/sync_outbox_repository.dart:96`.
- `pending()` excluye `inventory_images` failed con `attempt_count >= 5`: `lib/data/repositories/sync_outbox_repository.dart:33`.

Escenario de fallo:

La app se cierra despues de marcar syncing y antes de enviar. El intento cuenta aunque no hubo request completo.

Impacto: eventos de imagen pueden alcanzar limite sin cinco envios reales.
Probabilidad: media-baja.
Recomendacion: registrar intento despues del request o distinguir `started_attempts` de `completed_attempts`.
Prueba requerida: crash simulado entre markSyncing y post no consume reintento definitivo.

### SYNC-MED-002 - Pull reaplica cambios si falla antes de actualizar `sync_state`

Severidad: Media

Evidencia:

- Adapter aplica cambios: `lib/data/services/sync_engine.dart:348`.
- Estado se actualiza despues: `lib/data/services/sync_engine.dart:351`.
- Adapters hacen upsert por uuid: `lib/data/services/client_sync_adapter.dart:37`, `lib/data/services/inventory_sync_adapter.dart:37`.

Escenario de fallo:

La app aplica cambios y se cierra antes de actualizar estado. En el siguiente pull recibe el mismo lote.

Impacto: aceptable para upserts idempotentes, riesgoso para modulos futuros con efectos acumulativos.
Probabilidad: media.
Recomendacion: exigir idempotencia por modulo y pruebas de replay.
Prueba requerida: mismo pull aplicado dos veces no duplica datos ni altera saldos.

### SYNC-MED-003 - Inventario de imagenes limita metadata a 25 y no tiene loop local de `hasMore`

Severidad: Media

Evidencia:

- Push metadata toma limite 25: `lib/data/services/inventory_media_sync_service.dart:29`.
- Backend push toma 25: `backend/src/FiadoApp.Api/Controllers/InventoryImagesSyncController.cs:49`.
- Backend pull calcula `hasMore`: `backend/src/FiadoApp.Api/Controllers/InventoryImagesSyncController.cs:118`.
- Descarga por productos no evidencia loop sobre `hasMore`: `lib/data/services/inventory_media_sync_service.dart:70`.

Escenario de fallo:

Un producto con mas de 25 imagenes o lotes grandes deja paginas pendientes sin descargar si no se repite manualmente.

Impacto: media incompleta.
Probabilidad: baja-media.
Recomendacion: loop de paginas con limite y cursor.
Prueba requerida: 60 imagenes se descargan en multiples paginas.

### SYNC-MED-004 - Estado UI combina V2 y legacy, pero el origen de bloqueo puede ser ambiguo

Severidad: Media

Evidencia:

- V2 calcula estado con `sync_outbox` y `sync_state`: `lib/data/services/sync_engine.dart:384`.
- Legacy reporta resumen aparte: `lib/data/repositories/sync_queue_repository.dart:161`.
- Diagnostico distingue stores: `lib/data/repositories/sync_diagnostics_repository.dart:148`.

Escenario de fallo:

El usuario ve "No se pudo actualizar" o "Guardado en este dispositivo" sin saber si el bloqueo viene de V2 o legacy.

Impacto: soporte tecnico mas lento y menor confianza.
Probabilidad: media.
Recomendacion: mostrar origen tecnico en pantalla diagnostica y mantener mensaje usuario simple.
Prueba requerida: estado con fallos simultaneos identifica origen en diagnostico.

### SYNC-LOW-001 - `sync_outbox` conserva filas `synced`

Severidad: Baja

Evidencia:

- `markSynced()` actualiza status a `synced`: `lib/data/repositories/sync_outbox_repository.dart:135`.
- No se observo limpieza periodica equivalente a `limpiarProcesados()` de `sync_queue`: `lib/data/repositories/sync_queue_repository.dart:131`.

Escenario de fallo:

Con uso prolongado, `sync_outbox` crece con historico sincronizado.

Impacto: crecimiento local y consultas mas lentas.
Probabilidad: media a largo plazo.
Recomendacion: retencion configurable para synced antiguos.
Prueba requerida: limpieza preserva fallidos/pendientes y no afecta diagnostico reciente.

## Cobertura de pruebas existente

Cobertura fuerte:

- `test/client_sync_v2_test.dart`: encolado, push, pull, soft delete, multi-dispositivo basico, status sin token/businessId, endpoints.
- `test/inventory_sync_v2_test.dart`: inventario V2, imagenes, endpoint canonico, limite de reintentos, diagnostico redactado.
- `test/sync_engine_base_test.dart`: device id, outbox, state, UI status, legacy inactivo.
- `test/sync_endpoint_registry_test.dart`: endpoints V2 y legacy.
- `test/data_contract_registry_test.dart`: contratos, rechazo de entidades/modulos desconocidos.
- `test/sync_diagnostics_test.dart`: diagnostico sin secretos.
- `test/api_client_session_replaced_test.dart` y `test/session_replaced_status_test.dart`: sesion reemplazada.
- `test/credit_cycle_sync_test.dart`, `test/whatsapp_campaign_sync_test.dart`, `test/regression/client_debt_payment_regression_test.dart`: dominios legacy y regresiones financieras puntuales.

Vacios principales:

1. Rechazo parcial accepted/rejected por item en V2.
2. Dos instancias de `SyncEngine` sobre la misma DB.
3. Crash entre `markSyncing`, request HTTP, `markSynced` y `_updateModuleState`.
4. Pull V2 paginado y `hasMore`.
5. Reloj local adelantado/atrasado frente a `serverTime`.
6. Migracion completa de dominios legacy a V2 o decision explicita local-only.
7. Carga con miles de clientes/productos y muchas imagenes.
8. Sesion reemplazada durante push con outbox pendiente.
9. Ordenamiento y reconciliacion multi-dispositivo para saldos, pagos y deudas.
10. Limpieza/retencion de `sync_outbox`.

## Evaluaciones especificas

### Idempotencia

Clients e inventory tienen upsert por uuid/remote id y comparan `UpdatedAt`, lo que reduce duplicados. El riesgo permanece en lotes parcialmente aceptados, replay de pull para modulos futuros y operaciones financieras acumulativas.

### Concurrencia

El guard `_syncing` protege solo una instancia. No hay evidencia de candado global por base de datos. La transicion de estado no condiciona atomicamente que el item siga pendiente.

### Multi-dispositivo

Hay pruebas basicas de multi-dispositivo para clients/inventory y sesion activa unica. Falta stress de ediciones concurrentes, saldos, pagos y cierre de sesion durante sincronizacion.

### Multi-negocio

El filtrado por `businessId` existe en outbox/state, backend y queries principales. WhatsApp tiene prueba multi-negocio. El riesgo principal no es mezcla directa, sino rutas legacy/V2 divergentes por dominio.

### Backend

El backend V2 esta maduro para clients/inventory basico. No debe aceptar silenciosamente modulos sin persistencia. Pull necesita paginacion real y cursor servidor.

### Performance

Existen indices backend para `BusinessId`, `UpdatedAt`, `RemoteId`, `LocalId` y SQLite para colas. Falta limitar pulls V2 y plan de retencion de outbox.

## Plan recomendado

### Fase A - Cerrar perdida silenciosa

- Bloquear V2 para modulos no implementados o implementar persistencia real.
- Aceptacion: ningun modulo registrado responde `accepted` sin guardar o sin declarar `501/400`.

### Fase B - Resolver rechazo parcial

- Respuesta backend por item: `uuid`, `accepted`, `error`.
- Cliente marca estado por item.
- Aceptacion: test de lote mixto pasa y reintenta solo rechazados.

### Fase C - Candado de concurrencia

- Candado singleton verificado o lock persistente por DB.
- Update atomico de pendientes a syncing.
- Aceptacion: dos instancias no duplican requests.

### Fase D - Cursor y paginacion

- Backend devuelve paginas con cursor/`serverTime`.
- Cliente itera `hasMore`.
- Aceptacion: restore de N grande completa sin memoria excesiva.

### Fase E - Migracion legacy por dominio

- Decidir por cada dominio: V2, legacy habilitado o local-only.
- Aceptacion: matriz de modulos sin ambiguedad y pruebas por flujo.

### Fase F - Pruebas de resiliencia

- Fallos entre fases, session replaced durante sync, offline/online, relojes alterados.
- Aceptacion: suite de tests cubre todos los puntos de falla enumerados.

### Fase G - Operacion y observabilidad

- Retencion de outbox, metricas por modulo, diagnostico de origen de bloqueo.
- Aceptacion: soporte puede identificar modulo, cola, ultimo error y siguiente accion sin payload sensible.

## Items que no deben tocarse sin fase dedicada

- Contratos DTO backend y payloads moviles fuera de una migracion planificada.
- Calculo financiero de deuda/pagos.
- Estados de suscripcion y gating de negocio.
- Manejo de sesion activa unica.
- Migraciones SQL existentes.
- Feature flags de sync sin plan de rollback.
- Borrado masivo de `sync_queue` o `sync_outbox`.

## Preguntas abiertas para prueba manual

1. Que modulos deben sincronizarse en nube en la proxima version publica?
2. Se espera que movimientos/deudas/recibos funcionen cloud ahora o queden local-only?
3. Cual es el tamano maximo real de clientes/productos/imagenes por negocio?
4. Cual debe ser la retencion de historico synced local?
5. La sesion unica debe cancelar sync en curso o permitir terminar lote actual?
6. Deben mostrarse al usuario nombres de modulos con problemas o solo mensajes simples?
7. Hay backend staging con datos suficientes para probar paginacion y multi-dispositivo?

## Criterios de aceptacion para baseline robusto

- Todos los modulos registrados tienen persistencia backend real o respuesta no soportada.
- Rechazo parcial no duplica ni pierde cambios.
- Dos sync simultaneos no envian el mismo item.
- Pull grande pagina y usa cursor servidor.
- `sync_queue` legacy no bloquea silenciosamente funciones criticas.
- Tests cubren crash/replay/session replaced/offline por modulo critico.
- Diagnostico distingue origen V2 vs legacy sin secretos.
- Estado UI nunca muestra "Todo actualizado" con pendientes/fallidos activos.
