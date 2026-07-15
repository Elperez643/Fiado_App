$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$apiProjectDir = Join-Path $repoRoot "backend\src\FiadoApp.Api"
$migrationsDir = Join-Path $apiProjectDir "Migrations"

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

function Write-TableOrEmpty {
    param($Rows, [string]$EmptyMessage)
    if ($null -eq $Rows -or $Rows.Rows.Count -eq 0) {
        Write-Host $EmptyMessage
        return
    }
    $Rows | Format-Table -AutoSize | Out-String | Write-Host
}

$env:ASPNETCORE_ENVIRONMENT = if ($env:ASPNETCORE_ENVIRONMENT) { $env:ASPNETCORE_ENVIRONMENT } else { "StagingLocal" }
$env:DOTNET_ENVIRONMENT = if ($env:DOTNET_ENVIRONMENT) { $env:DOTNET_ENVIRONMENT } else { "StagingLocal" }
$connectionString = Get-EffectiveConnectionString
$builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($connectionString)
$requiredColumns = @("ActiveDeviceId", "DeviceInfo", "LastLoginAt", "LastSeenAt", "SessionVersion")

Write-Host "ASPNETCORE_ENVIRONMENT=$env:ASPNETCORE_ENVIRONMENT"
Write-Host "DOTNET_ENVIRONMENT=$env:DOTNET_ENVIRONMENT"
Write-Host "EffectiveConnectionString=$(Mask-ConnectionString $connectionString)"
Write-Host "SqlServer=$($builder.DataSource)"
Write-Host "Database=$($builder.InitialCatalog)"
$authMode = if ($builder.IntegratedSecurity) { "Integrated Security / Trusted Connection" } else { "SQL Login user=$($builder.UserID)" }
Write-Host "Authentication=$authMode"
Write-Host ""

Write-Host "EF migrations in code:"
$migrationFiles = Get-ChildItem -LiteralPath $migrationsDir -Filter "*.cs" |
    Where-Object { $_.Name -notlike "*.Designer.cs" -and $_.Name -ne "FiadoDbContextModelSnapshot.cs" } |
    Sort-Object Name
foreach ($file in $migrationFiles) {
    Write-Host "  $($file.BaseName)"
}
Write-Host "AddSingleActiveUserSession migration exists: $([bool]($migrationFiles | Where-Object { $_.BaseName -eq '20260623141000_AddSingleActiveUserSession' }))"
Write-Host ""

Write-Host "__EFMigrationsHistory rows:"
$historySql = @"
IF OBJECT_ID(N'[dbo].[__EFMigrationsHistory]', N'U') IS NULL
    SELECT CAST(NULL AS nvarchar(150)) AS MigrationId, CAST(NULL AS nvarchar(32)) AS ProductVersion WHERE 1 = 0;
ELSE
    SELECT MigrationId, ProductVersion FROM [dbo].[__EFMigrationsHistory] ORDER BY MigrationId;
"@
$history = Invoke-SqlQuery $connectionString $historySql
Write-TableOrEmpty $history "__EFMigrationsHistory does not exist or has no rows."
$applied = @($history | ForEach-Object { $_.MigrationId })
Write-Host "AddSingleActiveUserSession applied in history: $($applied -contains '20260623141000_AddSingleActiveUserSession')"
Write-Host ""

Write-Host "Real Users columns:"
$columnsSql = @"
SELECT
    COLUMN_NAME AS ColumnName,
    DATA_TYPE AS DataType,
    CHARACTER_MAXIMUM_LENGTH AS MaxLength,
    IS_NULLABLE AS IsNullable,
    COLUMN_DEFAULT AS ColumnDefault
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Users'
ORDER BY ORDINAL_POSITION;
"@
$columns = Invoke-SqlQuery $connectionString $columnsSql
Write-TableOrEmpty $columns "dbo.Users does not exist or has no columns."
$existingColumns = @($columns | ForEach-Object { $_.ColumnName })
Write-Host "Required session columns:"
foreach ($column in $requiredColumns) {
    Write-Host "  $column exists=$($existingColumns -contains $column)"
}
Write-Host ""
if (($applied -contains '20260623141000_AddSingleActiveUserSession') -and ($requiredColumns | Where-Object { $existingColumns -notcontains $_ }).Count -gt 0) {
    Write-Host "INCONSISTENCY: EF history says AddSingleActiveUserSession is applied, but dbo.Users is missing required session columns."
}
