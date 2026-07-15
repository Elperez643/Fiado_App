# Fiado App - Sync and Data Contract Matrix

Last audit: 2026-07-01

## Status vocabulary

- **Complete (outbox v2):** SQLite is authoritative offline and `sync_outbox` has an explicit module and endpoint.
- **Complete (legacy queue):** SQLite is authoritative offline and `sync_queue` has a dedicated, registered handler.
- **Local-only:** device state or a reproducible projection; it must never enter a cloud queue.
- **Server-managed cache:** cloud is authoritative; SQLite only caches auth/billing state.
- **Legacy inactive:** retained for compatibility, with no active repository writing business facts.
- **Infrastructure:** technical table, not a business entity.
- **Server-only:** sensitive/provider data intentionally never stored in the mobile database.

## Mobile and cloud coverage

| Entity/module | Flutter model | SQLite table | SQLite migration | Repository | Offline save | Queue/outbox | Push | Pull | Backend DTO/controller | EF entity / SQL table | Tests | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Clients | `ClienteSqliteModel` | `clientes` | v1-v29 | `ClienteRepository` | Yes | `clients` outbox v2; legacy `clientes` supported | `/api/sync/clients/push` | `/api/sync/clients/pull` | Generic sync + client DTO/controllers | `Client` / `Clients` | Client v2 and restore tests | Complete (outbox v2) |
| Movements/debts/payments | `MovimientoSqliteModel` | `movimientos` | v1-v29 | `MovimientoRepository` | Yes | legacy handler `movements` | `/movements/sync/push` | `/movements/sync/pull` | Financial DTO + controller | `Movement` / `Movements` | Financial/regression tests | Complete (legacy queue) |
| Old payment rows | `PagoSqliteModel` | `pagos` | v1-v29 | No active repository | No active writes | None | N/A | N/A | Active payment facts use movements/provider endpoints | No equivalent legacy table | Schema coverage | Legacy inactive |
| Debt items | `DeudaItemSqliteModel` | `deuda_items` | v1-v29 | `DeudaItemRepository` / movement repository | Yes | legacy handler `debt_items` | `/debt-items/sync/push` | `/debt-items/sync/pull` | Financial DTO/controller | `DebtItem` / `DebtItems` | Regression tests | Complete (legacy queue) |
| Products/inventory | `ProductoSqliteModel` | `productos` | v2-v29 | `ProductoRepository` | Yes | `inventory` outbox v2; legacy supported | `/api/sync/inventory/push` | `/api/sync/inventory/pull` | Generic sync + product DTO/controller | `Product` / `Products` | Inventory v2 tests | Complete (outbox v2) |
| Product image metadata/content | `ProductoImagenSqliteModel` | `producto_imagenes` | v8-v29 | `ProductoImagenRepository` | Yes | `inventory_images` outbox v2; legacy supported | `/api/sync/inventory/images/push` | Lazy `/api/sync/inventory/images/pull` | Inventory image DTO/controller | `ProductImage` / `ProductImages` | Lazy/media tests | Complete (outbox v2, lazy) |
| Receipts | `ComprobanteSqliteModel` | `comprobantes` | v9-v29 | `ComprobanteRepository` | Yes | legacy handler `receipts` | `/receipts/sync/push` | `/receipts/sync/pull` | Financial DTO/controller | `Receipt` / `Receipts` | Financial tests | Complete (legacy queue) |
| Credit cycles | `CreditoCicloSqliteModel` | `credito_ciclos` | v18-v29 | `CreditoCicloRepository` | Yes | legacy handler `credit_cycles` | `/credit-cycles/sync/push` | `/credit-cycles/sync/pull` | Financial DTO/controller | `CreditCycle` / `CreditCycles` | Credit-cycle tests | Complete (legacy queue) |
| Credit cycle movement links | `CreditoCicloMovimientoSqliteModel` | `credito_ciclo_movimientos` | v18-v29 | `CreditoCicloRepository` | Yes | None by design | N/A | Rebuilt from cycle/movement data | N/A | Represented by `CreditCycle` + `Movement` | Credit-cycle tests | Local-only projection |
| Credit reminders | `CreditoRecordatorioSqliteModel` | `credito_recordatorios` | v18-v29 | `CreditoCicloRepository` | Yes | legacy handler `credit_cycles` | `/credit-cycles/sync/push` | `/credit-cycles/sync/pull` | Financial DTO/controller | `CreditReminder` / `CreditReminders` | Credit-cycle tests | Complete (legacy queue) |
| Credit exceptions | `CreditoExcepcionSqliteModel` | `credito_excepciones` | v18-v29 | `CreditoCicloRepository` | Yes | legacy handler `credit_cycles` | `/credit-cycles/sync/push` | `/credit-cycles/sync/pull` | Financial DTO/controller | `CreditException` / `CreditExceptions` | Credit-cycle tests | Complete (legacy queue) |
| Audits | `AuditoriaSqliteModel` | `auditorias` | v7-v29 | `AuditoriaRepository` | Yes | legacy handler `audits` | `/audits/sync/push` | `/audits/sync/pull` | Audit DTO/controller | `Audit` / `Audits` | Contract/queue tests | Complete (legacy queue) |
| Audit items | `AuditoriaItemSqliteModel` | `auditoria_items` | v7-v29 | `AuditoriaRepository` | Yes | legacy handler `audit_items` | `/audit-items/sync/push` | `/audit-items/sync/pull` | Audit DTO/controller | `AuditItem` / `AuditItems` | Contract/queue tests | Complete (legacy queue) |
| Authorization requests | `SolicitudAutorizacionSqliteModel` | `solicitudes_autorizacion` | v6-v29 | `SolicitudAutorizacionRepository` | Yes | legacy handler `authorization_requests` | `/authorization-requests/sync/push` | `/authorization-requests/sync/pull` | Authorization DTO/controller | `AuthorizationRequest` / `AuthorizationRequests` | Contract/queue tests | Complete (legacy queue) |
| Client scores | `ClientScoreSyncModel` | `client_scores` | v22-v29 | Integrated with client/movement services | Yes | legacy handler `client_scores` | `/client-scores/sync/push` | `/client-scores/sync/pull` | Score DTO/controller | `ClientScore` / `ClientScores` | Score/contract tests | Complete (legacy queue) |
| WhatsApp publications | `WhatsappCampaignPublication` | `whatsapp_campaign_publications` | v29 | `WhatsappCampaignRepository` | Yes | legacy handler `whatsapp_campaigns` | `/whatsapp-campaigns/sync/push` | `/whatsapp-campaigns/sync/pull` | WhatsApp DTO/controller | `WhatsappCampaignPublication` | Campaign tests | Complete (legacy queue) |
| Users/collaborators | `UsuarioSqliteModel` | `usuarios` | v1-v29 | `AuthRepository` | Cached locally | Explicit local queue suppression | Auth/register/link endpoints | Auth/me/login responses | Auth DTO/controller | `User` / `Users`; collaborator is a role | Auth tests | Server-managed cache |
| Device sessions | `SessionSqliteModel` | `sesiones` | v1-v29 | `AuthRepository` | Yes | Never queued | N/A | N/A | Device ID/session version travel in auth | Session fields on `User` | Session replacement tests | Local-only security state |
| Subscriptions | `SubscriptionSqliteModel` | `subscriptions` | v5-v29 | `SubscriptionRepository` | Cached locally | Explicit local queue suppression | Billing endpoints | Subscription status endpoint | Payment DTO/controllers | `Subscription` / `Subscriptions` | Subscription/auth tests | Server-managed cache |
| User onboarding | `UserOnboardingSqliteModel` | `user_onboarding` | v24-v29 | `UserOnboardingRepository` | Yes | Explicit local queue suppression | N/A | N/A | N/A | N/A | Contract tests | Local-only preference |
| Inventory metrics | `InventoryProductMetricSqliteModel` | `inventory_product_metrics` | v25-v29 | `InventoryProductMetricsRepository` | Derived | Never queued | N/A | Recomputed locally | N/A | N/A | Inventory tests | Local-only projection |
| Business recommendations cache | Internal Copilot model | `business_recommendations_cache` | v27-v29 | `BusinessCopilotService` | Derived cache | Never queued | N/A | Recomputed/expired locally | N/A | N/A | Contract tests | Local-only cache |
| Sync queue | `SyncQueueItemModel` | `sync_queue` | v7-v29 | `SyncQueueRepository` | Technical | It is the queue | Registry-controlled | Registry-controlled | N/A | `SyncLog` is separate telemetry | Queue contract tests | Infrastructure |
| Sync outbox | `SyncOutboxItem` | `sync_outbox` | v29 | `SyncOutboxRepository` | Technical | It is the outbox | Registry-controlled | Registry-controlled | Generic/image DTOs | N/A | Outbox tests | Infrastructure |
| Sync state | `SyncStateModel` | `sync_state` | v29 | `SyncStateRepository` | Technical | None | N/A | N/A | N/A | N/A | Sync status tests | Infrastructure |

## Server-only entities

| Entity | Why it is not in SQLite | Backend coverage | Status |
|---|---|---|---|
| `Business` | Business identity is represented locally by user/business IDs | EF entity, auth/business association | Server-only by design |
| `SyncLog` | Server telemetry must not become offline business state | EF entity/table | Server-only by design |
| `PaymentMethod` | Sensitive provider metadata | Payment DTO/controller/entity | Server-only by design |
| `SubscriptionPayment` | Billing ledger is server-authoritative | Payment DTO/controller/entity | Server-only by design |
| `PaymentTransaction` | Provider transaction integrity | Payment DTO/controller/entity | Server-only by design |
| `PaymentWebhookLog` | Provider webhook audit/security | Payment infrastructure entity | Server-only by design |

## Findings and severity

### Critical - fixed

1. SQLite used `onDatabaseDowngradeDelete`, which could erase all local data after installing a build with a lower schema version. Downgrades now fail explicitly and preserve the database.
2. Unknown outbox modules could previously reach an invented `/api/sync/{module}` URL. The endpoint registry now rejects unknown modules before HTTP or persistence.

### High - fixed

1. `sync_queue` accepted arbitrary `entity_type` values. Enqueue and debug startup now require a registered legacy handler or an explicit local-only declaration.
2. Main outbox payloads had no allowlist. Client, inventory, and image metadata payloads now reject unsupported fields before persistence.

### Medium - controlled

1. Two sync generations coexist. Outbox v2 is active; legacy auto-sync remains feature-flagged off but handlers stay registered for pending historical rows.
2. `pagos` remains as an inactive compatibility table. Active payment facts are movements; no active repository writes `pagos`.
3. Credit cycle movement links have no cloud table because they are a local projection over cloud-backed cycles and movements.

### Low - documented

1. Backend payment infrastructure has server-only tables intentionally absent from mobile.
2. Local caches/projections do not have cloud DTOs by design.

## Runtime protection

In debug/test startup, `DataContractValidator` verifies:

1. Every `DatabaseSchema` table has one declared contract.
2. Every expected table exists after SQLite migrations.
3. Every active `sync_queue.entity_type` has a handler or explicit local-only declaration.
4. Every active `sync_outbox.module` exists in `SyncEndpointRegistry`.
5. Errors identify module/entity, expected table/endpoint, likely file, and recommended action.

Release startup is not blocked by this audit layer; normal SQLite constraints and enqueue validation still apply.

## Adding a new module safely

1. Add the SQLite table and a non-destructive `DatabaseSchema.version` upgrade.
2. Add model and repository with explicit offline ownership.
3. Choose exactly one active transport: outbox v2, legacy queue, server-managed cache, or local-only.
4. Register outbox modules in `SyncEndpointRegistry`, including payload allowlist and pull policy.
5. Register legacy handlers in `LegacySyncEndpointRegistry` and remove endpoint literals from services.
6. Add the entity to `DataContractRegistry` with justification.
7. Add backend DTO/controller/entity/migration when cloud persistence applies.
8. Add tests for offline save, queue event, payload shape, push success cleanup, pull completeness, and retry behavior.
9. Never rename a persisted module/table without an idempotent migration and legacy transformer.
10. Run format, analyze, Flutter tests, backend build, and APK build.
