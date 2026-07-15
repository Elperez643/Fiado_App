# Fiado App Staging Local

Esta guia prepara esta PC Windows 10 Pro como servidor de pruebas para la app Flutter, sin romper el modo local-first. Si el backend no esta disponible, login y registro local siguen funcionando con SQLite.

## Backend

Proyecto principal:

```powershell
backend\src\FiadoApp.Api\FiadoApp.Api.csproj
```

El backend usa ASP.NET Core, controllers, Entity Framework Core y SQL Server:

```csharp
options.UseSqlServer(builder.Configuration.GetConnectionString("FiadoDb"))
```

Configuracion staging local:

```text
backend\src\FiadoApp.Api\appsettings.StagingLocal.json
```

Connection string por defecto:

```text
Server=127.0.0.1,14333;Database=FiadoAppDb_StagingLocal;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
```

Ajusta `Server` si tu SQL Server local usa otra instancia o puerto.

## SQL Server

Aplicar migraciones:

```powershell
cd C:\Users\eric_\fiado_app\backend\src\FiadoApp.Api
$env:ASPNETCORE_ENVIRONMENT="StagingLocal"
dotnet ef database update
```

Tablas principales esperadas: `Users`, `Businesses`, `Clients`, `Movements`, `Products`, `Receipts`, `Subscriptions`, `__EFMigrationsHistory`.

## Ejecutar Backend En LAN

Obtener IP local:

```powershell
ipconfig
```

Busca la IPv4 del adaptador WiFi, por ejemplo `192.168.1.50`.

Ejecutar escuchando en toda la red local:

```powershell
cd C:\Users\eric_\fiado_app\backend\src\FiadoApp.Api
$env:ASPNETCORE_ENVIRONMENT="StagingLocal"
dotnet run --urls "http://0.0.0.0:5000"
```

Probar desde la PC:

```powershell
curl http://localhost:5000/health
curl http://localhost:5000/api/health
```

Probar desde el celular en el mismo WiFi:

```text
http://IP_DE_LA_PC:5000/health
```

Respuesta esperada:

```json
{ "status": "ok", "environment": "StagingLocal" }
```

## Firewall Windows

Permitir puerto 5000 TCP solo para pruebas LAN:

```powershell
New-NetFirewallRule -DisplayName "Fiado App Staging Local 5000" -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow
```

No abras puertos del router para staging local.

## Flutter En Celular Fisico

Compilar APK apuntando a la IP LAN:

```powershell
cd C:\Users\eric_\fiado_app
flutter build apk --debug --dart-define=API_BASE_URL=http://IP_DE_LA_PC:5000/api
```

Android emulator:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

La app tambien sigue aceptando el define anterior:

```powershell
--dart-define=FIADO_API_BASE_URL=http://IP_DE_LA_PC:5000/api
```

## Pruebas Fuera Del WiFi

No abras el router. Usa un tunel temporal seguro.

Cloudflare Tunnel:

```powershell
cloudflared tunnel --url http://localhost:5000
flutter build apk --debug --dart-define=API_BASE_URL=https://URL_DEL_TUNEL/api
```

ngrok:

```powershell
ngrok http 5000
flutter build apk --debug --dart-define=API_BASE_URL=https://URL_DEL_TUNEL/api
```

Prueba primero:

```text
https://URL_DEL_TUNEL/health
```

## Endpoints Base

- `GET /health`
- `GET /api/health`
- `POST /api/auth/login`
- `POST /api/auth/register/personal`
- `POST /api/auth/register/business`
- `GET /api/clients`
- `POST /api/clients/sync/push`
- `POST /api/products/sync/push`
- `POST /api/movements/sync/push`
