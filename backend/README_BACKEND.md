# Fiado App Backend

Backend inicial de Fiado App construido con ASP.NET Core, Entity Framework Core y SQL Server. La API soporta autenticacion JWT y sincronizacion cloud inicial desde `sync_queue` para Clientes, Productos, Imagenes de Productos, modulos financieros, Auditorias y Solicitudes de Autorizacion, manteniendo SQLite como fuente offline-first.

## Requisitos

- .NET SDK instalado. En esta maquina se uso .NET 10 porque es el SDK disponible.
- SQL Server local o remoto.

## Restaurar paquetes

```powershell
cd backend
dotnet restore FiadoApp.Backend.sln
```

## Ejecutar la API

```powershell
cd backend
dotnet run --project src/FiadoApp.Api/FiadoApp.Api.csproj
```

## Swagger

Al ejecutar en ambiente Development, abrir:

```text
https://localhost:<puerto>/swagger
```

El endpoint de verificacion rapida esta en:

```text
GET /api/health
```

Tambien esta disponible el health check tecnico:

```text
GET /health
```

## Precios de suscripcion

Los precios oficiales de suscripcion se mantienen en USD. La fuente unica de
verdad del backend es:

```text
src/FiadoApp.Api/Subscriptions/SubscriptionPlanCatalog.cs
```

Planes actuales:

```text
Basico       mensual USD 4.99  / trimestral USD 13.47 / anual USD 47.90
Crecimiento mensual USD 12.99 / trimestral USD 35.07 / anual USD 124.70
Empresarial mensual USD 20.99 / trimestral USD 56.67 / anual USD 201.50
```

Los montos DOP son solo equivalentes aproximados calculados desde USD con la
tasa configurada. Los precios historicos RD$700, RD$1,500 y RD$2,800 quedan
obsoletos y no deben usarse como precio oficial, ni en Stripe, ni en mock.

Stripe `PriceIds` debe apuntar a precios recurrentes TEST creados manualmente
con estos montos USD.

Para validar coherencia:

```powershell
dart run tools\qa\validate_subscription_prices.dart
```

## Auth inicial

Endpoints disponibles:

```text
POST /api/auth/register/personal
POST /api/auth/register/business
POST /api/auth/register/collaborator
POST /api/auth/login
GET  /api/auth/me
```

`GET /api/auth/me` requiere Bearer token. `POST /api/auth/register/collaborator` tambien queda protegido para que lo ejecute un usuario tipo `Negocio`.

### Registrar Personal

```json
{
  "name": "Juan Perez",
  "phone": "8095550001",
  "password": "123456"
}
```

### Registrar Negocio

```json
{
  "ownerName": "Maria Gomez",
  "businessName": "Colmado Maria",
  "phone": "8095550002",
  "password": "123456"
}
```

El registro de negocio crea:

- Usuario tipo `Negocio`.
- `Business` propio.
- Suscripcion `trial` con 30 dias gratis.

### Registrar Colaborador

Requiere token de un usuario `Negocio`:

```json
{
  "name": "Carlos Ruiz",
  "phone": "8095550003",
  "password": "123456"
}
```

El colaborador queda asociado al `businessId` del negocio autenticado. El endpoint existe para preparar la integracion futura, aunque el registro publico de colaboradores no debe exponerse desde la app.

### Login

```json
{
  "phone": "8095550002",
  "password": "123456"
}
```

La respuesta devuelve:

- `token`
- `expiresAt`
- datos del usuario
- rol
- `businessId` cuando aplica

En Swagger, usar el boton `Authorize` con:

```text
Bearer <token>
```

## Clientes y sync cloud inicial

Todos los endpoints requieren Bearer token y usan el `businessId` del usuario autenticado. Un usuario `Personal` no puede acceder a clientes de negocio. Un usuario `Negocio` o `Colaborador` solo ve clientes de su propio negocio.

Endpoints:

```text
GET  /api/clients
GET  /api/clients/{id}
POST /api/clients
PUT  /api/clients/{id}
POST /api/clients/sync/push
POST /api/clients/sync/pull
```

Crear cliente:

```json
{
  "name": "Juan Perez",
  "phone": "8095550101",
  "address": "Calle Principal 12"
}
```

Actualizar cliente:

```json
{
  "name": "Juan Perez",
  "phone": "8095550101",
  "address": "Calle Principal 12",
  "isActive": true
}
```

Push desde `sync_queue` Flutter:

```json
{
  "clients": [
    {
      "localId": 15,
      "serverId": null,
      "name": "Ana Lopez",
      "phone": "8095550102",
      "address": "Ensanche Central",
      "operation": "create",
      "updatedAt": "2026-05-27T03:40:00Z"
    }
  ]
}
```

Pull de cambios desde una fecha:

```json
{
  "lastSyncAt": "2026-05-27T00:00:00Z"
}
```

Para traer todo el catalogo inicial:

```json
{
  "lastSyncAt": null
}
```

Reglas:

- Telefono unico por negocio: `BusinessId + Phone`.
- El mismo telefono puede existir en negocios distintos.
- El borrado es logico: `isActive=false` y `deletedAt`.
- `sync/push` responde por item con `localId`, `serverId`, `status`, `error` y `serverUpdatedAt`.

## Productos e imagenes de productos

Todos los endpoints requieren Bearer token y usan el `businessId` del JWT. `Personal` no accede a productos de negocio; `Negocio` y `Colaborador` solo ven productos de su negocio. Nunca se acepta `businessId` desde requests publicos.

Endpoints de productos:

```text
GET  /api/products
GET  /api/products/{id}
POST /api/products
PUT  /api/products/{id}
POST /api/products/sync/push
POST /api/products/sync/pull
```

Endpoints de imagenes:

```text
GET  /api/products/{productId}/images
POST /api/products/images/sync/push
POST /api/products/images/sync/pull
```

Reglas:

- `name` es obligatorio.
- `codeReference` es opcional.
- `name` no se duplica dentro del mismo negocio activo.
- `codeReference` no se duplica dentro del mismo negocio activo cuando no esta vacio.
- El mismo nombre/codigo puede existir en negocios distintos.
- Productos usan soft delete: `isActive=false` y `deletedAt`.
- Maximo 3 imagenes por producto.
- Imagenes aceptan metadata `localPath`, `remoteUrl`, `storageKey`, `mimeType`, `sizeBytes`, `width`, `height` y `order`.
- Por ahora no se suben binarios; `remoteUrl` y `storageKey` preparan el futuro flujo Blob Storage.
- `mimeType` recomendado: `image/png` o `image/jpeg`.
- `sizeBytes` maximo: 2 MB.

Ejemplo push de productos:

```json
{
  "products": [
    {
      "localId": 10,
      "serverId": null,
      "name": "Arroz",
      "codeReference": "A-001",
      "category": "Granos",
      "description": "Saco 10 lb",
      "quantity": 20,
      "purchasePrice": 8.0,
      "salePrice": 10.0,
      "minimumStock": 5,
      "operation": "create",
      "updatedAt": "2026-05-29T16:00:00Z"
    }
  ]
}
```

## Movimientos, deuda items, comprobantes y ciclos de credito

Todos los endpoints requieren Bearer token y usan `businessId` desde el JWT.
`Personal` no accede a estos endpoints internos de negocio. `Negocio` y
`Colaborador` quedan limitados a su negocio.

Movimientos:

```text
GET  /api/movements/client/{clientId}
POST /api/movements
PUT  /api/movements/{id}
POST /api/movements/sync/push
POST /api/movements/sync/pull
```

Deuda items:

```text
GET  /api/movements/{movementId}/debt-items
POST /api/debt-items/sync/push
POST /api/debt-items/sync/pull
```

Comprobantes:

```text
GET  /api/receipts/client/{clientId}
GET  /api/receipts/{id}
GET  /api/receipts/code/{code}
POST /api/receipts/sync/push
POST /api/receipts/sync/pull
```

Ciclos de credito:

```text
GET  /api/credit-cycles/client/{clientId}
GET  /api/credit-cycles/accounts-receivable
GET  /api/credit-cycles/overdue-45
GET  /api/credit-cycles/blocked-60
POST /api/credit-cycles/sync/push
POST /api/credit-cycles/sync/pull
```

Los `sync/push` financieros reciben listas con `localId`, `serverId`,
`operation`, `updatedAt` y `payload`. El backend persiste el estado calculado
por Flutter para ciclos 30/45/60; no recalcula la logica completa todavia.

Ejemplo push de movimiento:

```json
{
  "movements": [
    {
      "localId": 25,
      "serverId": null,
      "operation": "create",
      "updatedAt": "2026-05-29T17:00:00Z",
      "payload": {
        "clientId": "uuid-cliente",
        "type": "deuda",
        "amount": 150.0,
        "concept": "Compra",
        "date": "2026-05-29T17:00:00Z"
      }
    }
  ]
}
```

Ejemplo pull incremental:

```json
{ "lastSyncAt": "2026-05-29T00:00:00Z" }
```

Ejemplo push de imagenes:

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

## Auditorias y solicitudes de autorizacion

Todos los endpoints requieren Bearer token y usan `businessId` desde el JWT.
`Personal` no accede a auditorias ni solicitudes de negocio. `Colaborador`
solo ve sus auditorias/solicitudes; `Negocio` ve la informacion del negocio y
puede aprobar o rechazar solicitudes.

Auditorias:

```text
GET  /api/audits
GET  /api/audits/{id}
GET  /api/audits/business/report
GET  /api/audits/my
POST /api/audits/sync/push
POST /api/audit-items/sync/push
POST /api/audits/sync/pull
POST /api/audit-items/sync/pull
```

Solicitudes:

```text
GET  /api/authorization-requests/pending
GET  /api/authorization-requests/my
POST /api/authorization-requests/sync/push
POST /api/authorization-requests/sync/pull
POST /api/authorization-requests/{id}/approve
POST /api/authorization-requests/{id}/reject
```

Los `sync/push` reciben listas con `localId`, `serverId`, `operation`,
`updatedAt` y `payload`. La respuesta por item incluye `localId`, `serverId`,
`status`, `error` y `serverUpdatedAt`.

Ejemplo push de auditoria:

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

Ejemplo push de solicitud:

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

## Connection string

La cadena de conexion local esta en `src/FiadoApp.Api/appsettings.json`:

```text
Server=127.0.0.1,14333;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
```

Si aparece `Cannot generate SSPI context`, revisar `backend/DB_SETUP.md`. En
esta maquina la migracion `AddAuditAuthorizationSyncFields` se aplico con la
misma cadena ejecutando `dotnet ef database update` con privilegios elevados.

## Crear migraciones

Instalar la herramienta de EF si no esta disponible:

```powershell
dotnet tool install --global dotnet-ef
```

Crear la migracion inicial:

```powershell
cd backend
dotnet ef migrations add InitialCreate --project src/FiadoApp.Api/FiadoApp.Api.csproj --startup-project src/FiadoApp.Api/FiadoApp.Api.csproj
```

## Actualizar base de datos

```powershell
cd backend
dotnet ef database update --project src/FiadoApp.Api/FiadoApp.Api.csproj --startup-project src/FiadoApp.Api/FiadoApp.Api.csproj
```

## Estructura

- `Controllers/`: endpoints HTTP.
- `Data/`: `FiadoDbContext` y configuracion de persistencia.
- `Entities/`: entidades base para usuarios, negocios, suscripciones, clientes, productos, movimientos, comprobantes, ciclos de credito, auditorias, score inteligente y sincronizacion.
- `DTOs/`: contratos futuros de entrada y salida.
- `Services/`: servicios de aplicacion futuros.
- `Repositories/`: repositorios futuros.
- `Auth/`: configuracion de autenticacion/JWT futura.
- `Middleware/`: middleware transversal futuro.
- `Common/`: utilidades y respuestas comunes futuras.

## Estado actual

Esta version crea la base tecnica del backend y sync cloud inicial por modulo:

- ASP.NET Core Web API.
- SQL Server via Entity Framework Core.
- Swagger/OpenAPI.
- JWT Authentication configurado.
- Health endpoint.
- Entidades iniciales y campos cloud para clientes, productos e imagenes.
- Campos cloud para movimientos, deuda items, comprobantes, ciclos,
  recordatorios y excepciones.
- Campos cloud para auditorias, auditoria items y solicitudes de autorizacion.
- Infraestructura cloud inicial para `ClientScores`: el calculo sigue naciendo
  offline en Flutter y el backend persiste el snapshot para reportes y futura
  validacion/calculo del servidor.
- `FiadoDbContext`.
- Sync real de Clientes, Productos, Imagenes de Productos, modulos financieros,
  Auditorias, Solicitudes de Autorizacion y Score Inteligente desde
  Flutter/API.
- Infraestructura de pagos mantiene `MockPaymentProvider` y agrega Stripe
  Checkout/Billing en modo TEST mediante endpoints
  `/api/payments/stripe/create-checkout-session` y
  `/api/payments/stripe/webhook`.

No implementa produccion de pagos ni subida binaria de imagenes todavia.
Stripe queda limitado a claves `sk_test_...`; ver `STRIPE_TEST_SETUP.md`.
