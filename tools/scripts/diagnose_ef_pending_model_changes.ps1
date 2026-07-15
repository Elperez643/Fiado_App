param(
    [int]$TimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$apiProjectDir = Join-Path $repoRoot "backend\src\FiadoApp.Api"
$projectFile = Join-Path $apiProjectDir "FiadoApp.Api.csproj"
$migrationsDir = Join-Path $apiProjectDir "Migrations"
$logsDir = Join-Path $repoRoot ".codex_logs"
$appDataDir = Join-Path $repoRoot ".codex_appdata"
$runner = Join-Path $scriptDir "run_with_timeout.ps1"

New-Item -ItemType Directory -Force -Path $logsDir, $appDataDir | Out-Null
$env:ASPNETCORE_ENVIRONMENT = "StagingLocal"
$env:DOTNET_ENVIRONMENT = "StagingLocal"
$env:APPDATA = $appDataDir

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-ConfigConnectionString {
    $base = Read-JsonFile (Join-Path $apiProjectDir "appsettings.json")
    $staging = Read-JsonFile (Join-Path $apiProjectDir "appsettings.StagingLocal.json")
    $value = $base.ConnectionStrings.FiadoDb
    if ($null -ne $staging -and -not [string]::IsNullOrWhiteSpace($staging.ConnectionStrings.FiadoDb)) {
        $value = $staging.ConnectionStrings.FiadoDb
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ConnectionStrings__FiadoDb)) {
        $value = $env:ConnectionStrings__FiadoDb
    }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "ConnectionStrings:FiadoDb was not found." }
    return $value
}

function Mask-ConnectionString {
    param([string]$Value)
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($Value)
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

$connectionString = Get-ConfigConnectionString
$connectionBuilder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($connectionString)

Write-Host "ASPNETCORE_ENVIRONMENT=$env:ASPNETCORE_ENVIRONMENT"
Write-Host "DOTNET_ENVIRONMENT=$env:DOTNET_ENVIRONMENT"
Write-Host "EffectiveConnectionString=$(Mask-ConnectionString $connectionString)"
Write-Host "SqlServer=$($connectionBuilder.DataSource)"
Write-Host "Database=$($connectionBuilder.InitialCatalog)"
Write-Host ""

Write-Host "Latest migrations in code:"
Get-ChildItem -LiteralPath $migrationsDir -Filter "*.cs" |
    Where-Object { $_.Name -notlike "*.Designer.cs" -and $_.Name -ne "FiadoDbContextModelSnapshot.cs" } |
    Sort-Object Name |
    Select-Object -Last 10 -ExpandProperty BaseName |
    ForEach-Object { Write-Host "  $_" }

Write-Host ""
Write-Host "Applied migrations in __EFMigrationsHistory:"
$historySql = @"
IF OBJECT_ID(N'[dbo].[__EFMigrationsHistory]', N'U') IS NULL
    SELECT CAST(NULL AS nvarchar(150)) AS MigrationId WHERE 1 = 0;
ELSE
    SELECT MigrationId FROM [dbo].[__EFMigrationsHistory] ORDER BY MigrationId;
"@
try {
    $history = Invoke-SqlQuery $connectionString $historySql
    if ($history.Rows.Count -eq 0) {
        Write-Host "  (none)"
    } else {
        $history | ForEach-Object { Write-Host "  $($_.MigrationId)" }
    }
} catch {
    Write-Host "  query failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "Inventory image model files:"
@(
    "Entities\ProductImage.cs",
    "Data\FiadoDbContext.cs",
    "DTOs\InventoryImageSyncDtos.cs",
    "Migrations\20260623172000_AddInventoryImageMediaSyncFields.cs",
    "Migrations\20260623172000_AddInventoryImageMediaSyncFields.Designer.cs",
    "Migrations\FiadoDbContextModelSnapshot.cs"
) | ForEach-Object {
    $path = Join-Path $apiProjectDir $_
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        Write-Host "  exists=true modified=$($item.LastWriteTime.ToString('o')) file=$_"
    } else {
        Write-Host "  exists=false file=$_"
    }
}

$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
$log = Join-Path $logsDir "ef_pending_model_changes.log"
$arguments = @(
    "ef", "migrations", "has-pending-model-changes",
    "--project", $projectFile,
    "--startup-project", $projectFile
)

Write-Host ""
Write-Host "Checking pending model changes with timeout=${TimeoutSeconds}s..."
& $runner `
    -FilePath $dotnet -Arguments $arguments -TimeoutSeconds $TimeoutSeconds -LogFile $log
$exitCode = $LASTEXITCODE
Write-Host "Pending changes command exit code: $exitCode"
Write-Host "Diagnostic log: $log"
if ($exitCode -ne 0) { exit $exitCode }

$logContent = Get-Content -LiteralPath $log -Raw
if ($logContent -match "Changes have been made to the model since the last migration") {
    Write-Host "PendingModelChanges=true"
    exit 2
}
if ($logContent -match "No changes have been made to the model since the last migration") {
    Write-Host "PendingModelChanges=false"
    exit 0
}

Write-Host "PendingModelChanges=unknown"
exit 3
