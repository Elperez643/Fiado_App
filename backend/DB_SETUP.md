# Fiado App DB Setup

Guia para preparar SQL Server local y aplicar las migraciones de Entity Framework Core del backend `FiadoApp.Api`.

## Requisitos

- SQL Server Express o SQL Server Developer Edition.
- .NET SDK.
- Herramienta EF Core CLI:

```powershell
dotnet ef --version
```

Si no esta instalada:

```powershell
dotnet tool install --global dotnet-ef
```

## Connection string local

La API usa esta cadena en `backend/src/FiadoApp.Api/appsettings.json` para
SQL Server Express local por TCP:

```text
Server=127.0.0.1,14333;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
```

Esta variante evita problemas de Kerberos/SPN/SSPI con instancias nombradas
locales. Para que funcione, `SQLEXPRESS` debe tener TCP habilitado y escuchar
en el puerto `14333`.

Alternativas utiles para diagnostico:

```text
Server=.\SQLEXPRESS;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
Server=localhost\SQLEXPRESS;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
Server=127.0.0.1\SQLEXPRESS;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
Server=.\SQLEXPRESS;Database=FiadoAppDb;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;
```

Si se instala SQL Server Developer Edition como instancia por defecto, puede
usarse:

```text
Server=localhost;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
```

## Comandos EF

Restaurar y compilar:

```powershell
dotnet restore backend/FiadoApp.Backend.sln
dotnet build backend/FiadoApp.Backend.sln
```

Crear migracion inicial:

```powershell
dotnet ef migrations add InitialCreate --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj
```

Aplicar migraciones:

```powershell
dotnet ef database update --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj
```

## Borrar y recrear base en desarrollo

Solo para desarrollo local:

```powershell
dotnet ef database drop --force --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj
dotnet ef database update --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj
```

## Verificar la base

Con SQL Server Management Studio o Azure Data Studio:

1. Conectar a `.\SQLEXPRESS`.
2. Abrir la base `FiadoAppDb`.
3. Confirmar tablas como `Users`, `Businesses`, `Clients`, `Movements`, `DebtItems`, `Receipts`, `CreditCycles`, `Audits`, `AuthorizationRequests` y `__EFMigrationsHistory`.

Tambien puede validarse con:

```powershell
sqlcmd -S .\SQLEXPRESS -E -Q "SELECT name FROM sys.databases WHERE name = 'FiadoAppDb'"
```

## Errores comunes

### dotnet ef no existe

Instalar la herramienta:

```powershell
dotnet tool install --global dotnet-ef
```

Si sigue sin aparecer, cerrar y abrir la terminal para refrescar el `PATH`.

### No se puede conectar a SQL Server

Verificar que el servicio este activo:

```powershell
Get-Service MSSQL`$SQLEXPRESS
```

Si no existe, instalar SQL Server Express o Developer Edition.

### Error SSPI: Cannot generate SSPI context

Sintoma:

```text
The target principal name is incorrect. Cannot generate SSPI context.
```

Causas comunes:

- Problema de Kerberos/SPN al usar una instancia nombrada local.
- La terminal/proceso esta corriendo con un contexto Windows restringido.
- SQL Server solo tiene Shared Memory activo y fuerza una ruta de autenticacion
  integrada que no puede generar contexto SSPI.
- SQL Browser esta detenido y `127.0.0.1\SQLEXPRESS` no puede resolver la
  instancia.

Solucion aplicada en esta maquina:

1. Habilitar TCP para `SQLEXPRESS`.
2. Fijar puerto local `14333`.
3. Reiniciar `MSSQL$SQLEXPRESS`.
4. Usar la connection string:

```text
Server=127.0.0.1,14333;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;
```

Comandos PowerShell equivalentes, ejecutados como administrador:

```powershell
$tcp = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Tcp'
Set-ItemProperty -Path $tcp -Name Enabled -Value 1
Set-ItemProperty -Path "$tcp\IPAll" -Name TcpDynamicPorts -Value ''
Set-ItemProperty -Path "$tcp\IPAll" -Name TcpPort -Value '14333'
Restart-Service -Name 'MSSQL$SQLEXPRESS' -Force
```

Verificar servicio:

```powershell
Get-Service MSSQL`$SQLEXPRESS
```

Aplicar migraciones usando la cadena TCP:

```powershell
dotnet ef database update --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj --startup-project backend/src/FiadoApp.Api/FiadoApp.Api.csproj --connection "Server=127.0.0.1,14333;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;"
```

En esta maquina, las migraciones SQL Server deben ejecutarse con la cadena TCP
anterior y, si la terminal normal vuelve a mostrar SSPI, con permisos elevados.
La migracion `AddPaymentsInfrastructure` fue aplicada correctamente a
`FiadoAppDb` usando:

```powershell
dotnet ef database update --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj --connection "Server=127.0.0.1,14333;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;"
```

Si el mismo comando falla desde una terminal normal pero SQL Server esta
corriendo, ejecutar la terminal como administrador o permitir la ejecucion
elevada del comando EF. En esta maquina la migracion
`AddAuditAuthorizationSyncFields` se aplico correctamente de esa forma con:

```powershell
dotnet ef database update --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj
```

Verificar migraciones aplicadas:

```powershell
dotnet ef migrations list --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj --startup-project backend/src/FiadoApp.Api/FiadoApp.Api.csproj --connection "Server=127.0.0.1,14333;Database=FiadoAppDb;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False;"
```

Salida esperada despues de la migracion de pagos:

```text
20260527031653_InitialCreate
20260527033850_AddClientSyncFields
20260529163948_AddProductSyncFields
20260529170447_AddMovementReceiptCreditSyncFields
20260529174505_AddAuditAuthorizationSyncFields
20260530031942_AddPaymentsInfrastructure
```

Si se prefiere resolver la instancia nombrada por nombre en vez de puerto, se
puede iniciar SQL Browser:

```powershell
Start-Service SQLBrowser
```

### Opcion SQL Auth local

Si Windows Auth sigue fallando, puede usarse SQL Auth local en desarrollo.
No guardes contrasenas reales en git. Usa `appsettings.Development.json` local
o variables de entorno.

Ejemplo sin password real:

```json
{
  "ConnectionStrings": {
    "FiadoDb": "Server=127.0.0.1,14333;Database=FiadoAppDb;User Id=sa;Password=<TU_PASSWORD_LOCAL>;TrustServerCertificate=True;Encrypt=False;"
  }
}
```

Tambien puede usarse Secret Manager:

```powershell
dotnet user-secrets set "ConnectionStrings:FiadoDb" "Server=127.0.0.1,14333;Database=FiadoAppDb;User Id=sa;Password=<TU_PASSWORD_LOCAL>;TrustServerCertificate=True;Encrypt=False;" --project backend/src/FiadoApp.Api/FiadoApp.Api.csproj
```

### Server=localhost falla

Si SQL Server esta instalado como instancia nombrada, usar:

```text
Server=.\SQLEXPRESS
```

### Login failed

La cadena actual usa autenticacion integrada de Windows:

```text
Trusted_Connection=True
```

Ejecutar la terminal con un usuario que tenga permisos sobre SQL Server o agregar ese usuario como login en la instancia.

### Error de cifrado local

Si aparece un error como "requires encryption but this machine does not support it", en desarrollo local usar:

```text
Encrypt=False;TrustServerCertificate=True;
```

Para produccion debe configurarse TLS/certificado correctamente en SQL Server.
