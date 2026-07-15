param(
    [int]$DatabaseTimeoutSeconds = 180,
    [int]$BuildTimeoutSeconds = 300,
    [switch]$UseExistingGeneratedSql
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$project = Join-Path $repoRoot "backend\src\FiadoApp.Api\FiadoApp.Api.csproj"
$solution = Join-Path $repoRoot "backend\FiadoApp.Backend.sln"
$migration = Get-ChildItem (Join-Path $repoRoot "backend\src\FiadoApp.Api\Migrations\*FixPendingInventoryImageMediaModelChanges.cs") |
    Where-Object { $_.Name -notlike "*.Designer.cs" } |
    Select-Object -First 1
$runner = Join-Path $scriptDir "run_with_timeout.ps1"
$logsDir = Join-Path $repoRoot ".codex_logs"
$appDataDir = Join-Path $repoRoot ".codex_appdata"
$stagingSettings = Join-Path $repoRoot "backend\src\FiadoApp.Api\appsettings.StagingLocal.json"

if ($null -eq $migration) { throw "Corrective migration was not found." }
New-Item -ItemType Directory -Force -Path $logsDir, $appDataDir | Out-Null
$env:ASPNETCORE_ENVIRONMENT = "StagingLocal"
$env:DOTNET_ENVIRONMENT = "StagingLocal"
$env:APPDATA = $appDataDir

$source = Get-Content -LiteralPath $migration.FullName -Raw
$upMatch = [regex]::Match(
    $source,
    'protected override void Up\(MigrationBuilder migrationBuilder\)(?<body>[\s\S]*?)protected override void Down',
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
if (-not $upMatch.Success) { throw "Could not inspect Up() in $($migration.Name)." }
$dangerous = [regex]::Matches($upMatch.Groups['body'].Value, 'DropTable|DropColumn|DeleteData|AlterColumn')
if ($dangerous.Count -gt 0) {
    throw "Unsafe operation found in Up(): $($dangerous.Value -join ', '). Database update was not executed."
}

Write-Host "Migration safety check OK: $($migration.Name)"
Write-Host "Environment: StagingLocal"
$dotnet = (Get-Command dotnet -ErrorAction Stop).Source
$settings = Get-Content -LiteralPath $stagingSettings -Raw | ConvertFrom-Json
$connectionString = [string]$settings.ConnectionStrings.FiadoDb
if ([string]::IsNullOrWhiteSpace($connectionString)) {
    throw "The effective StagingLocal connection string is empty."
}
$env:ConnectionStrings__FiadoDb = $connectionString
$maskedConnection = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($connectionString)
if ($maskedConnection.ContainsKey("Password")) { $maskedConnection.Password = "***" }
Write-Host "EffectiveConnectionString=$($maskedConnection.ConnectionString)"

$generatedSqlPath = Join-Path $logsDir "FixPendingInventoryImageMediaModelChanges.sql"
if (-not $UseExistingGeneratedSql) {
    $buildArgs = @("build", $solution, "--no-restore")
    & $runner -FilePath $dotnet -Arguments $buildArgs `
        -TimeoutSeconds $BuildTimeoutSeconds `
        -LogFile (Join-Path $logsDir "dotnet_build_backend_pending_model_fix.log")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $scriptArgs = @(
        "ef", "migrations", "script",
        "20260622191605_AddSyncPerformanceIndexes",
        "20260627193614_FixPendingInventoryImageMediaModelChanges",
        "--idempotent",
        "--project", $project,
        "--startup-project", $project,
        "--no-build",
        "--output", $generatedSqlPath
    )
    & $runner -FilePath $dotnet -Arguments $scriptArgs `
        -TimeoutSeconds $DatabaseTimeoutSeconds `
        -LogFile (Join-Path $logsDir "ef_generate_inventory_media_migration_sql.log")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} elseif (-not (Test-Path -LiteralPath $generatedSqlPath)) {
    throw "Generated EF SQL was not found: $generatedSqlPath"
}

$generatedSql = Get-Content -LiteralPath $generatedSqlPath -Raw
$generatedDangerous = [regex]::Matches($generatedSql, '(?im)\bDROP\s+(TABLE|COLUMN)\b|\bDELETE\s+FROM\b')
if ($generatedDangerous.Count -gt 0) {
    throw "Generated EF SQL contains a destructive operation. Nothing was applied."
}
$generatedSql = [regex]::Replace($generatedSql, '(?im)^\s*GO\s*$', '')
$requiredColumns = @{
    ProductImages = @("ContentBase64", "ContentHash", "FileName", "HasContent", "ProductRemoteId")
    Users = @("ActiveDeviceId", "DeviceInfo", "LastLoginAt", "LastSeenAt", "SessionVersion")
}
$databaseJob = Start-Job -ScriptBlock {
    param($Value, $Sql, $Required, $CommandTimeout)
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($Value)
    $builder["Connect Timeout"] = 10
    $connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = $CommandTimeout
        $command.CommandText = $Sql
        $null = $command.ExecuteNonQuery()

        $checks = @()
        $missing = @()
        foreach ($tableName in $Required.Keys) {
            $command.Parameters.Clear()
            $command.CommandTimeout = 15
            $command.CommandText = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = @tableName;"
            $null = $command.Parameters.Add("@tableName", [System.Data.SqlDbType]::NVarChar, 128)
            $command.Parameters["@tableName"].Value = $tableName
            $reader = $command.ExecuteReader()
            $existing = @()
            while ($reader.Read()) { $existing += [string]$reader[0] }
            $reader.Close()
            foreach ($columnName in $Required[$tableName]) {
                $exists = $existing -contains $columnName
                $checks += "SchemaCheck table=$tableName column=$columnName exists=$exists"
                if (-not $exists) { $missing += "dbo.$tableName.$columnName" }
            }
        }
        [pscustomobject]@{ Success = $missing.Count -eq 0; Checks = $checks; Missing = $missing; Error = "" }
    } catch {
        [pscustomobject]@{ Success = $false; Checks = @(); Missing = @(); Error = $_.Exception.Message }
    } finally {
        $connection.Dispose()
    }
} -ArgumentList $connectionString, $generatedSql, $requiredColumns, $DatabaseTimeoutSeconds

if (-not (Wait-Job -Job $databaseJob -Timeout ($DatabaseTimeoutSeconds + 30))) {
    Stop-Job -Job $databaseJob -ErrorAction SilentlyContinue
    Remove-Job -Job $databaseJob -Force -ErrorAction SilentlyContinue
    throw "Database migration job timed out after $($DatabaseTimeoutSeconds + 30)s."
}
$databaseResult = Receive-Job -Job $databaseJob
Remove-Job -Job $databaseJob -Force -ErrorAction SilentlyContinue
$databaseResult.Checks | ForEach-Object { Write-Host $_ }
if (-not $databaseResult.Success) {
    $detail = if ($databaseResult.Error) { $databaseResult.Error } else { "Missing columns: $($databaseResult.Missing -join ', ')" }
    throw "Migration verification failed: $detail"
}
Write-Host "Migration applied and verified: 20260627193614_FixPendingInventoryImageMediaModelChanges"

exit 0
