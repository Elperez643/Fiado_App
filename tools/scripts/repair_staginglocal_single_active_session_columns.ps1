$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$apiProjectDir = Join-Path $repoRoot "backend\src\FiadoApp.Api"

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-JsonValue {
    param($Object, [string[]]$Path)
    $current = $Object
    foreach ($segment in $Path) {
        if ($null -eq $current) { return $null }
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) { return $null }
        $current = $property.Value
    }
    return $current
}

function Get-EffectiveConnectionString {
    $baseConfig = Read-JsonFile (Join-Path $apiProjectDir "appsettings.json")
    $stagingConfig = Read-JsonFile (Join-Path $apiProjectDir "appsettings.StagingLocal.json")
    $connectionString = Get-JsonValue $baseConfig @("ConnectionStrings", "FiadoDb")
    $stagingConnectionString = Get-JsonValue $stagingConfig @("ConnectionStrings", "FiadoDb")
    if (-not [string]::IsNullOrWhiteSpace($stagingConnectionString)) {
        $connectionString = $stagingConnectionString
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ConnectionStrings__FiadoDb)) {
        $connectionString = $env:ConnectionStrings__FiadoDb
    }
    if ([string]::IsNullOrWhiteSpace($connectionString)) {
        throw "ConnectionStrings:FiadoDb was not found."
    }
    return $connectionString
}

function Mask-ConnectionString {
    param([string]$ConnectionString)
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($ConnectionString)
    if ($builder.ContainsKey("Password")) { $builder.Password = "***" }
    if ($builder.ContainsKey("Pwd")) { $builder["Pwd"] = "***" }
    return $builder.ConnectionString
}

function Invoke-SqlQuery {
    param([string]$ConnectionString, [string]$Sql)
    $connection = [System.Data.SqlClient.SqlConnection]::new($ConnectionString)
    $command = $connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = 30
    $table = [System.Data.DataTable]::new()
    try {
        $connection.Open()
        $reader = $command.ExecuteReader()
        $table.Load($reader)
    } finally {
        $connection.Dispose()
    }
    return $table
}

$env:ASPNETCORE_ENVIRONMENT = if ($env:ASPNETCORE_ENVIRONMENT) { $env:ASPNETCORE_ENVIRONMENT } else { "StagingLocal" }
$env:DOTNET_ENVIRONMENT = if ($env:DOTNET_ENVIRONMENT) { $env:DOTNET_ENVIRONMENT } else { "StagingLocal" }
$connectionString = Get-EffectiveConnectionString
$builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($connectionString)

Write-Host "ASPNETCORE_ENVIRONMENT=$env:ASPNETCORE_ENVIRONMENT"
Write-Host "DOTNET_ENVIRONMENT=$env:DOTNET_ENVIRONMENT"
Write-Host "EffectiveConnectionString=$(Mask-ConnectionString $connectionString)"
Write-Host "SqlServer=$($builder.DataSource)"
Write-Host "Database=$($builder.InitialCatalog)"
Write-Host ""

$repairSql = @"
IF OBJECT_ID(N'[dbo].[Users]', N'U') IS NULL
BEGIN
    THROW 51000, 'dbo.Users table does not exist. Repair aborted.', 1;
END;

DECLARE @Actions TABLE ([ColumnName] nvarchar(128), [ActionTaken] nvarchar(256));

IF COL_LENGTH(N'[dbo].[Users]', N'ActiveDeviceId') IS NULL
BEGIN
    ALTER TABLE [dbo].[Users] ADD [ActiveDeviceId] nvarchar(128) NULL;
    INSERT INTO @Actions VALUES (N'ActiveDeviceId', N'ADDED nvarchar(128) NULL');
END
ELSE INSERT INTO @Actions VALUES (N'ActiveDeviceId', N'EXISTS');

IF COL_LENGTH(N'[dbo].[Users]', N'DeviceInfo') IS NULL
BEGIN
    ALTER TABLE [dbo].[Users] ADD [DeviceInfo] nvarchar(260) NULL;
    INSERT INTO @Actions VALUES (N'DeviceInfo', N'ADDED nvarchar(260) NULL');
END
ELSE INSERT INTO @Actions VALUES (N'DeviceInfo', N'EXISTS');

IF COL_LENGTH(N'[dbo].[Users]', N'LastLoginAt') IS NULL
BEGIN
    ALTER TABLE [dbo].[Users] ADD [LastLoginAt] datetime2 NULL;
    INSERT INTO @Actions VALUES (N'LastLoginAt', N'ADDED datetime2 NULL');
END
ELSE INSERT INTO @Actions VALUES (N'LastLoginAt', N'EXISTS');

IF COL_LENGTH(N'[dbo].[Users]', N'LastSeenAt') IS NULL
BEGIN
    ALTER TABLE [dbo].[Users] ADD [LastSeenAt] datetime2 NULL;
    INSERT INTO @Actions VALUES (N'LastSeenAt', N'ADDED datetime2 NULL');
END
ELSE INSERT INTO @Actions VALUES (N'LastSeenAt', N'EXISTS');

IF COL_LENGTH(N'[dbo].[Users]', N'SessionVersion') IS NULL
BEGIN
    ALTER TABLE [dbo].[Users] ADD [SessionVersion] int NOT NULL CONSTRAINT [DF_Users_SessionVersion_StagingRepair] DEFAULT 0;
    INSERT INTO @Actions VALUES (N'SessionVersion', N'ADDED int NOT NULL DEFAULT 0');
END
ELSE INSERT INTO @Actions VALUES (N'SessionVersion', N'EXISTS');

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[Users]')
      AND name = N'IX_Users_Id_ActiveDeviceId'
)
AND COL_LENGTH(N'[dbo].[Users]', N'ActiveDeviceId') IS NOT NULL
BEGIN
    CREATE INDEX [IX_Users_Id_ActiveDeviceId] ON [dbo].[Users] ([Id], [ActiveDeviceId]);
    INSERT INTO @Actions VALUES (N'IX_Users_Id_ActiveDeviceId', N'ADDED index');
END
ELSE INSERT INTO @Actions VALUES (N'IX_Users_Id_ActiveDeviceId', N'EXISTS');

IF OBJECT_ID(N'[dbo].[__EFMigrationsHistory]', N'U') IS NOT NULL
AND NOT EXISTS (
    SELECT 1
    FROM [dbo].[__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260623141000_AddSingleActiveUserSession'
)
AND COL_LENGTH(N'[dbo].[Users]', N'ActiveDeviceId') IS NOT NULL
AND COL_LENGTH(N'[dbo].[Users]', N'DeviceInfo') IS NOT NULL
AND COL_LENGTH(N'[dbo].[Users]', N'LastLoginAt') IS NOT NULL
AND COL_LENGTH(N'[dbo].[Users]', N'LastSeenAt') IS NOT NULL
AND COL_LENGTH(N'[dbo].[Users]', N'SessionVersion') IS NOT NULL
BEGIN
    DECLARE @ProductVersion nvarchar(32) =
        ISNULL((SELECT TOP (1) [ProductVersion] FROM [dbo].[__EFMigrationsHistory] ORDER BY [MigrationId] DESC), N'10.0.8');
    INSERT INTO [dbo].[__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260623141000_AddSingleActiveUserSession', @ProductVersion);
    INSERT INTO @Actions VALUES (N'__EFMigrationsHistory', N'ADDED 20260623141000_AddSingleActiveUserSession');
END
ELSE IF OBJECT_ID(N'[dbo].[__EFMigrationsHistory]', N'U') IS NULL
    INSERT INTO @Actions VALUES (N'__EFMigrationsHistory', N'MISSING table; not changed');
ELSE IF EXISTS (
    SELECT 1
    FROM [dbo].[__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260623141000_AddSingleActiveUserSession'
)
    INSERT INTO @Actions VALUES (N'__EFMigrationsHistory', N'EXISTS');
ELSE
    INSERT INTO @Actions VALUES (N'__EFMigrationsHistory', N'NOT changed; columns incomplete');

SELECT [ColumnName], [ActionTaken] FROM @Actions;
"@

$result = Invoke-SqlQuery $connectionString $repairSql
$result | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Repair completed. The script is idempotent and only adds missing session columns/index."
