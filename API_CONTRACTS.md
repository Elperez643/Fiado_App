# Fiado App - API Contracts

## Convenciones

Base futura: `/api/v1`.

Formato JSON. Fechas en ISO 8601 UTC. Dinero como decimal. Todas las respuestas
de error usan:

```json
{
  "error": {
    "code": "validation_error",
    "message": "Mensaje legible",
    "details": {}
  }
}
```

Errores comunes:

- `400 validation_error`
- `401 unauthorized`
- `403 forbidden`
- `404 not_found`
- `409 conflict`
- `422 business_rule_violation`
- `500 server_error`

## Auth

### `POST /auth/register-personal`

Request:

```json
{ "nombre": "Juan Perez", "telefono": "8090000001", "password": "secret" }
```

Response:

```json
{ "user": { "id": "uuid", "tipoUsuario": "personal" }, "tokens": {} }
```

### `POST /auth/register-business`

Request:

```json
{
  "nombreNegocio": "Colmado Uno",
  "nombreAdmin": "Ana",
  "telefono": "8090000002",
  "password": "secret",
  "planId": "basico"
}
```

Response:

```json
{ "user": { "id": "uuid", "tipoUsuario": "negocio" }, "trialDays": 30 }
```

### `POST /auth/login`

Request:

```json
{ "telefono": "8090000002", "password": "secret" }
```

Response:

```json
{ "accessToken": "jwt", "refreshToken": "token", "user": {} }
```

### `POST /auth/refresh`

## Payments Mock

Base actual backend: `/api/payments`. Todos los endpoints requieren JWT de
Negocio/Colaborador con `business_id`; Personal no debe usarlos para datos de
negocio.

La fase actual no conecta proveedor real y no acepta ni almacena numero de
tarjeta, CVV ni datos sensibles. Solo usa metadata mock/tokenizada.

### `GET /api/payments/methods`

Devuelve metodos de pago tokenizados del negocio.

### `POST /api/payments/methods`

Request mock:

```json
{
  "provider": "mock",
  "mockCardLast4": "4242",
  "brand": "Visa",
  "expMonth": 12,
  "expYear": 2030,
  "isDefault": true
}
```

### `GET /api/payments/history`

Devuelve historial de pagos de suscripcion del negocio.

### `GET /api/payments/subscription`

Devuelve plan, ciclo, estado, USD, DOP, tasa mock, trial restante, proxima
renovacion y metodo default.

### `POST /api/payments/mock/charge`

Simula pago exitoso con proveedor mock.

### `POST /api/payments/mock/renew`

Simula renovacion exitosa.

### `POST /api/payments/mock/fail`

Simula pago fallido y registra transaccion mock.

Request: `{ "refreshToken": "token" }`

### `POST /auth/logout`

Request: `{ "refreshToken": "token" }`

## Usuarios

- `GET /users/me`
- `GET /users/{id}`
- `PATCH /users/{id}`
- `PATCH /users/{id}/active`

Request update:

```json
{ "nombre": "Nuevo nombre", "telefono": "8090000003", "activo": true }
```

## Negocios

- `GET /businesses/{businessId}`
- `PATCH /businesses/{businessId}`
- `GET /businesses/{businessId}/members`

Response:

```json
{ "id": "uuid", "nombre": "Colmado Uno", "ownerUserId": "uuid" }
```

## Colaboradores

- `GET /businesses/{businessId}/collaborators`
- `POST /businesses/{businessId}/collaborators`
- `PATCH /businesses/{businessId}/collaborators/{userId}`
- `PATCH /businesses/{businessId}/collaborators/{userId}/active`

Request create:

```json
{ "nombre": "Luis", "telefono": "8090000004", "password": "secret" }
```

## Suscripciones

- `GET /subscription-plans`
- `GET /businesses/{businessId}/subscription`
- `POST /businesses/{businessId}/subscription/select-plan`
- `POST /businesses/{businessId}/subscription/start-trial`

Request select plan:

```json
{ "planId": "crecimiento", "billingCycle": "anual" }
```

Response:

```json
{
  "planId": "crecimiento",
  "currencyCode": "USD",
  "originalPrice": 155.88,
  "finalPrice": 124.7,
  "discountPercent": 20
}
```

## Onboarding

- `GET /users/{userId}/onboarding/{onboardingKey}`
- `POST /users/{userId}/onboarding/{onboardingKey}/complete`
- `POST /users/{userId}/onboarding/{onboardingKey}/skip`

Response:

```json
{ "completed": false, "skipped": false, "onboardingKey": "initial_v1_negocio" }
```

## Clientes

- `GET /api/clients`
- `GET /api/clients/{id}`
- `POST /api/clients`
- `PUT /api/clients/{id}`
- `POST /api/clients/sync/push`
- `POST /api/clients/sync/pull`

Todos requieren Bearer token. El backend toma el `businessId` desde el JWT, no desde el request.

Reglas:

- `Personal` no accede a clientes de negocio.
- `Negocio` y `Colaborador` solo acceden a clientes de su `businessId`.
- Telefono unico por negocio: `businessId + phone`.
- El mismo telefono puede existir en negocios distintos.
- Soft delete: `isActive=false`, `deletedAt`.

Create request:

```json
{ "name": "Juan", "phone": "8090000001", "address": "Calle 1" }
```

Update request:

```json
{ "name": "Juan", "phone": "8090000001", "address": "Calle 1", "isActive": true }
```

Response:

```json
{
  "id": "uuid",
  "localId": 12,
  "remoteId": null,
  "businessId": "uuid",
  "name": "Juan",
  "phone": "8090000001",
  "address": "Calle 1",
  "debt": 0,
  "isActive": true,
  "createdAt": "2026-05-27T03:40:00Z",
  "updatedAt": "2026-05-27T03:40:00Z",
  "deletedAt": null,
  "lastSyncedAt": "2026-05-27T03:40:00Z"
}
```

Sync push request:

```json
{
  "clients": [
    {
      "localId": 12,
      "serverId": null,
      "name": "Juan",
      "phone": "8090000001",
      "address": "Calle 1",
      "operation": "create",
      "updatedAt": "2026-05-27T03:40:00Z"
    }
  ]
}
```

Sync push response:

```json
{
  "serverTime": "2026-05-27T03:41:00Z",
  "results": [
    {
      "localId": 12,
      "serverId": "uuid",
      "status": "created",
      "error": null,
      "serverUpdatedAt": "2026-05-27T03:41:00Z"
    }
  ]
}
```

Sync pull request:

```json
{ "lastSyncAt": "2026-05-27T00:00:00Z" }
```

Sync pull response:

```json
{
  "serverTime": "2026-05-27T03:42:00Z",
  "clients": []
}
```

## Movimientos

- `GET /api/movements/client/{clientId}`
- `POST /api/movements`
- `PUT /api/movements/{id}`
- `POST /api/movements/sync/push`
- `POST /api/movements/sync/pull`

Todos requieren Bearer token y `businessId` sale del JWT. `Personal` no accede.

Create/update:

```json
{
  "clientId": "uuid-cliente",
  "type": "deuda",
  "amount": 100.0,
  "concept": "Compra",
  "date": "2026-05-26T12:00:00Z",
  "isActive": true
}
```

Sync push:

```json
{
  "movements": [
    {
      "localId": 12,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:00:00Z",
      "payload": {
        "clientId": "uuid-cliente",
        "type": "deuda",
        "amount": 100.0,
        "concept": "Compra",
        "date": "2026-05-29T17:00:00Z"
      }
    }
  ]
}
```

## Deuda Items

- `GET /api/movements/{movementId}/debt-items`
- `POST /api/debt-items/sync/push`
- `POST /api/debt-items/sync/pull`

Sync push:

```json
{
  "debtItems": [
    {
      "localId": 44,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:00:00Z",
      "payload": {
        "movementId": "uuid-movimiento",
        "productId": "uuid-producto",
        "productName": "Arroz",
        "codeReference": "A-001",
        "quantity": 2,
        "unitPrice": 10.0,
        "subtotal": 20.0
      }
    }
  ]
}
```

## Productos

- `GET /api/products`
- `GET /api/products/{id}`
- `POST /api/products`
- `PUT /api/products/{id}`
- `POST /api/products/sync/push`
- `POST /api/products/sync/pull`

Todos requieren Bearer token. El backend toma `businessId` desde el JWT.

Reglas:

- `Personal` no accede a productos de negocio.
- `Negocio` y `Colaborador` solo acceden a productos de su `businessId`.
- `name` obligatorio.
- `codeReference` opcional y unico por negocio activo cuando no esta vacio.
- `name` unico por negocio activo.
- Soft delete: `isActive=false`, `deletedAt`.

Create/update request:

`purchasePrice` representa el costo unitario normalizado del inventario.
`salePrice` es el precio de venta y `profitMarginPercent` es el margen usado
para recalculo local cuando aplica.

```json
{
  "name": "Arroz",
  "codeReference": "A-001",
  "category": "Granos",
  "location": "estante-A3",
  "description": "Saco 10 lb",
  "quantity": 20,
  "purchasePrice": 8.0,
  "salePrice": 10.0,
  "profitMarginPercent": 25.0,
  "minimumStock": 5,
  "isActive": true
}
```

Sync push request:

```json
{
  "products": [
    {
      "localId": 10,
      "serverId": null,
      "name": "Arroz",
      "codeReference": "A-001",
      "category": "Granos",
      "location": "estante-A3",
      "description": "Saco 10 lb",
      "quantity": 20,
      "purchasePrice": 8.0,
      "salePrice": 10.0,
      "profitMarginPercent": 25.0,
      "minimumStock": 5,
      "operation": "create",
      "updatedAt": "2026-05-29T16:00:00Z"
    }
  ]
}
```

Sync pull request:

```json
{ "lastSyncAt": "2026-05-29T00:00:00Z" }
```

## Producto Imagenes

- `GET /api/products/{productId}/images`
- `POST /api/products/images/sync/push`
- `POST /api/products/images/sync/pull`

Las imagenes sincronizan metadata, no binarios reales todavia. `remoteUrl` y
`storageKey` quedan listos para Blob Storage futuro. Maximo 3 imagenes por
producto, `sizeBytes <= 2 MB`, mime recomendado `image/png` o `image/jpeg`.

Sync push request:

```json
{
  "images": [
    {
      "localId": 3,
      "serverId": null,
      "productLocalId": 10,
      "productServerId": "uuid-producto",
      "localPath": "/local/arroz.jpg",
      "remoteUrl": null,
      "storageKey": null,
      "order": 0,
      "mimeType": "image/jpeg",
      "sizeBytes": 120000,
      "width": 500,
      "height": 500,
      "operation": "create",
      "updatedAt": "2026-05-29T16:00:00Z"
    }
  ]
}
```

## Auditorias

- `GET /api/audits`
- `GET /api/audits/{id}`
- `GET /api/audits/business/report`
- `GET /api/audits/my`
- `POST /api/audits/sync/push`
- `POST /api/audit-items/sync/push`
- `POST /api/audits/sync/pull`
- `POST /api/audit-items/sync/pull`

Todos requieren Bearer token. `businessId` sale del JWT y no se acepta desde
requests publicos. `Negocio` ve auditorias del negocio; `Colaborador` solo las
suyas; `Personal` no accede.

Sync push de auditorias:

```json
{
  "audits": [
    {
      "localId": 6,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:40:00Z",
      "payload": {
        "collaboratorId": "uuid-colaborador",
        "type": "inventario",
        "date": "2026-05-29T17:40:00Z",
        "status": "pendiente",
        "totalProducts": 20,
        "validatedProducts": 5,
        "observations": "Conteo parcial"
      }
    }
  ]
}
```

Sync push de audit items:

```json
{
  "auditItems": [
    {
      "localId": 14,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:42:00Z",
      "payload": {
        "auditId": "uuid-auditoria",
        "productId": "uuid-producto",
        "systemStock": 10,
        "physicalStock": 9,
        "validationStatus": "diferencia",
        "observation": "Falta 1 unidad"
      }
    }
  ]
}
```

Reporte `GET /api/audits/business/report`:

```json
[
  {
    "auditId": "uuid",
    "collaborator": "Carlos Ruiz",
    "date": "2026-05-29T17:40:00Z",
    "type": "inventario",
    "productsReviewed": 5,
    "differencesFound": 1,
    "observations": "Conteo parcial"
  }
]
```

## Solicitudes De Autorizacion

- `GET /api/authorization-requests/pending`
- `GET /api/authorization-requests/my`
- `POST /api/authorization-requests/sync/push`
- `POST /api/authorization-requests/sync/pull`
- `POST /api/authorization-requests/{id}/approve`
- `POST /api/authorization-requests/{id}/reject`

Todos requieren Bearer token. `Negocio` puede aprobar/rechazar solicitudes de
su negocio. `Colaborador` solo ve y sincroniza sus solicitudes. `Personal` no
accede.

Sync push:

```json
{
  "authorizationRequests": [
    {
      "localId": 9,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:45:00Z",
      "payload": {
        "collaboratorId": "uuid-colaborador",
        "requestType": "editar_producto",
        "entity": "product",
        "entityId": "uuid-producto",
        "dataBeforeJson": "{}",
        "dataAfterJson": "{\"name\":\"Arroz premium\"}",
        "status": "pendiente"
      }
    }
  ]
}
```

Decision:

```json
{ "comment": "Aprobado para ajustar inventario" }
```

Sync pull:

```json
{ "lastSyncAt": "2026-05-29T00:00:00Z" }
```

## Comprobantes

- `GET /api/receipts/client/{clientId}`
- `GET /api/receipts/{id}`
- `GET /api/receipts/code/{code}`
- `POST /api/receipts/sync/push`
- `POST /api/receipts/sync/pull`

Sync push:

```json
{
  "receipts": [
    {
      "localId": 8,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:00:00Z",
      "payload": {
        "movementId": "uuid-movimiento",
        "clientId": "uuid-cliente",
        "receiptCode": "FIA-001",
        "type": "deuda",
        "payloadJson": "{}",
        "total": 100.0,
        "previousBalance": 50.0,
        "newBalance": 150.0,
        "date": "2026-05-29T17:00:00Z"
      }
    }
  ]
}
```

## Ciclos Credito

- `GET /api/credit-cycles/client/{clientId}`
- `GET /api/credit-cycles/accounts-receivable`
- `GET /api/credit-cycles/overdue-45`
- `GET /api/credit-cycles/blocked-60`
- `POST /api/credit-cycles/sync/push`
- `POST /api/credit-cycles/sync/pull`

El backend persiste el estado calculado por Flutter para 30/45/60. No recalcula
toda la logica todavia.

Response:

```json
{
  "id": "uuid",
  "estado": "vencido_30",
  "saldoPendiente": 50.0,
  "fechaInicio": "2026-05-01T00:00:00Z",
  "fechaLimite30": "2026-05-31T00:00:00Z"
}
```

Sync push:

```json
{
  "creditCycles": [
    {
      "localId": 3,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:00:00Z",
      "payload": {
        "clientId": "uuid-cliente",
        "startDate": "2026-05-01T00:00:00Z",
        "dueDate30": "2026-05-31T00:00:00Z",
        "dueDate45": "2026-06-15T00:00:00Z",
        "blockDate60": "2026-06-30T00:00:00Z",
        "status": "activo",
        "totalAmount": 100.0,
        "paidAmount": 0.0,
        "pendingBalance": 100.0,
        "isBlocked": false
      }
    }
  ]
}
```

## Recordatorios

- `GET /businesses/{businessId}/credit-reminders`
- `GET /users/{userId}/credit-reminders`
- `POST /credit-cycles/{cycleId}/reminders`
- `POST /credit-reminders/{reminderId}/mark-sent`

## Score Inteligente De Clientes

Endpoints protegidos con JWT:

- `GET /api/client-scores/client/{clientId}`
- `GET /api/client-scores`
- `GET /api/client-scores/top`
- `GET /api/client-scores/risk`
- `POST /api/client-scores/sync/push`
- `POST /api/client-scores/sync/pull`

Reglas:

- `businessId` siempre sale del JWT.
- Negocio solo ve scores de su negocio.
- Colaborador puede sincronizar datos de su negocio, pero no accede a reportes
  globales hasta definir permisos finos.
- Personal no accede a scores internos de negocio.
- Flutter calcula offline y sincroniza snapshots; el backend queda preparado
  para calculo/validacion futura.

Sync push:

```json
{
  "clientScores": [
    {
      "localId": 12,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-30T18:30:00Z",
      "payload": {
        "clientId": "uuid-cliente",
        "clientLocalId": 7,
        "score": 82,
        "riskLevel": "Bajo riesgo",
        "suggestedCreditLimit": 3500.0,
        "paymentCompliancePercent": 94.5,
        "totalCredits": 12000.0,
        "totalPayments": 11340.0,
        "overdue30Count": 0,
        "overdue45Count": 0,
        "blocked60Count": 0,
        "lastCalculatedAt": "2026-05-30T18:28:00Z"
      }
    }
  ]
}
```

Sync response:

```json
{
  "serverTime": "2026-05-30T18:30:02Z",
  "results": [
    {
      "localId": 12,
      "serverId": "uuid-score",
      "status": "created",
      "error": null,
      "serverUpdatedAt": "2026-05-30T18:30:02Z"
    }
  ]
}
```

## Sync Queue

### `POST /sync/push`

Request:

```json
{
  "deviceId": "device-uuid",
  "operations": [
    {
      "operationId": "uuid",
      "entityType": "clientes",
      "entityId": 12,
      "remoteId": null,
      "operation": "create",
      "payload": {},
      "createdAt": "2026-05-26T12:00:00Z"
    }
  ]
}
```

Response:

```json
{
  "applied": [{ "operationId": "uuid", "remoteId": "uuid" }],
  "failed": []
}
```

### `GET /sync/pull?businessId=&since=`

Response:

```json
{
  "serverTime": "2026-05-26T12:05:00Z",
  "changes": [
    { "entityType": "clientes", "remoteId": "uuid", "operation": "update", "payload": {} }
  ]
}
```

### `POST /sync/ack`

Request:

```json
{ "changeIds": ["uuid"] }
```
