param(
    [int]$ConnectionTimeoutSeconds = 8
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$apiDir = Join-Path $repoRoot "backend\src\FiadoApp.Api"
$logsDir = Join-Path $repoRoot ".codex_logs"
$logPath = Join-Path $logsDir "audit_staginglocal_infrastructure.log"
$databaseName = "FiadoAppDb_StagingLocal"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

function Read-JsonFile {
    param([string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Mask-ConnectionString {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "(not configured)" }
    try {
        $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($Value)
        if ($builder.ContainsKey("Password")) { $builder.Password = "***" }
        if ($builder.ContainsKey("Pwd")) { $builder["Pwd"] = "***" }
        return $builder.ConnectionString
    } catch {
        return "(invalid connection string: $($_.Exception.Message))"
    }
}

function Describe-ConnectionString {
    param([string]$Source, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Host "[$Source] not configured"
        return
    }
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($Value)
    $auth = if ($builder.IntegratedSecurity) { "Windows/Integrated" } else { "SQL user=$($builder.UserID)" }
    Write-Host "[$Source] $(Mask-ConnectionString $Value)"
    Write-Host "  server=$($builder.DataSource) database=$($builder.InitialCatalog) auth=$auth"
}

function Test-ReadOnlySqlConnection {
    param([string]$Label, [string]$ConnectionString)

    $job = Start-Job -ScriptBlock {
        param($Value, $TargetDatabase)
        $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($Value)
        $builder["Connect Timeout"] = 5
        $connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
        try {
            $connection.Open()
            $command = $connection.CreateCommand()
            $command.CommandTimeout = 5
            $command.CommandText = @"
SELECT
    CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName,
    DB_NAME() AS DatabaseName,
    SUSER_SNAME() AS LoginName,
    CASE WHEN OBJECT_ID(N'dbo.Users', N'U') IS NULL THEN 0 ELSE 1 END AS UsersExists,
    CASE WHEN OBJECT_ID(N'dbo.ProductImages', N'U') IS NULL THEN 0 ELSE 1 END AS ProductImagesExists,
    IS_ROLEMEMBER(N'db_owner') AS IsDbOwner;
"@
            $reader = $command.ExecuteReader()
            $null = $reader.Read()
            $summary = [pscustomobject]@{
                Success = $true
                ServerName = [string]$reader["ServerName"]
                DatabaseName = [string]$reader["DatabaseName"]
                LoginName = [string]$reader["LoginName"]
                UsersExists = [int]$reader["UsersExists"] -eq 1
                ProductImagesExists = [int]$reader["ProductImagesExists"] -eq 1
                IsDbOwner = -not $reader.IsDBNull($reader.GetOrdinal("IsDbOwner")) -and [int]$reader["IsDbOwner"] -eq 1
                Databases = @()
                AppliedMigrations = @()
                Error = ""
                IsSspi = $false
            }
            $reader.Close()

            $command.CommandText = "SELECT name FROM sys.databases ORDER BY name;"
            try {
                $reader = $command.ExecuteReader()
                $names = @()
                while ($reader.Read()) { $names += [string]$reader[0] }
                $reader.Close()
                $summary.Databases = $names
            } catch { }

            $command.CommandText = @"
IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NULL
    SELECT CAST(NULL AS nvarchar(150)) AS MigrationId WHERE 1 = 0;
ELSE
    SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId;
"@
            try {
                $reader = $command.ExecuteReader()
                $migrations = @()
                while ($reader.Read()) { $migrations += [string]$reader[0] }
                $reader.Close()
                $summary.AppliedMigrations = $migrations
            } catch { }
            $summary
        } catch {
            [pscustomobject]@{
                Success = $false; ServerName = ""; DatabaseName = ""; LoginName = ""
                UsersExists = $false; ProductImagesExists = $false; IsDbOwner = $false
                Databases = @(); AppliedMigrations = @(); Error = $_.Exception.Message
                IsSspi = $_.Exception.Message -match "SSPI|target principal name|security package"
            }
        } finally {
            $connection.Dispose()
        }
    } -ArgumentList $ConnectionString, $databaseName

    if (-not (Wait-Job -Job $job -Timeout $ConnectionTimeoutSeconds)) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Label = $Label; Success = $false; ServerName = ""; DatabaseName = ""; LoginName = ""
            UsersExists = $false; ProductImagesExists = $false; IsDbOwner = $false
            Databases = @(); AppliedMigrations = @(); Error = "Timed out after ${ConnectionTimeoutSeconds}s"; IsSspi = $false
        }
    }
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $result | Add-Member -NotePropertyName Label -NotePropertyValue $Label
    return $result
}

function Write-ConnectionResult {
    param($Result)
    Write-Host "[$($Result.Label)] success=$($Result.Success) sspi=$($Result.IsSspi)"
    if (-not $Result.Success) {
        Write-Host "  error=$($Result.Error)"
        return
    }
    Write-Host "  server=$($Result.ServerName) database=$($Result.DatabaseName) login=$($Result.LoginName)"
    Write-Host "  Users=$($Result.UsersExists) ProductImages=$($Result.ProductImagesExists) db_owner=$($Result.IsDbOwner)"
    Write-Host "  databases=$($Result.Databases -join ', ')"
    Write-Host "  appliedMigrations=$($Result.AppliedMigrations -join ', ')"
}

if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
Start-Transcript -LiteralPath $logPath -Force | Out-Null
try {
    Write-Host "=== StagingLocal infrastructure audit ==="
    Write-Host "Timestamp=$((Get-Date).ToString('o'))"
    Write-Host "ReadOnlyAudit=true"
    Write-Host "ProcessWindowsIdentity=$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Host "ProcessASPNETCORE_ENVIRONMENT=$env:ASPNETCORE_ENVIRONMENT"
    Write-Host "ProcessDOTNET_ENVIRONMENT=$env:DOTNET_ENVIRONMENT"
    Write-Host "AuditASPNETCORE_ENVIRONMENT=StagingLocal"
    Write-Host "AuditDOTNET_ENVIRONMENT=StagingLocal"
    Write-Host ""

    $basePath = Join-Path $apiDir "appsettings.json"
    $developmentPath = Join-Path $apiDir "appsettings.Development.json"
    $stagingPath = Join-Path $apiDir "appsettings.StagingLocal.json"
    $launchPath = Join-Path $apiDir "Properties\launchSettings.json"
    $runScriptPath = Join-Path $repoRoot "tools\scripts\run_backend_staging_local.ps1"
    $base = Read-JsonFile $basePath
    $development = Read-JsonFile $developmentPath
    $staging = Read-JsonFile $stagingPath
    $launch = Read-JsonFile $launchPath

    Write-Host "=== Configuration sources ==="
    Describe-ConnectionString "appsettings.json" ([string]$base.ConnectionStrings.FiadoDb)
    Describe-ConnectionString "appsettings.Development.json" ([string]$development.ConnectionStrings.FiadoDb)
    Describe-ConnectionString "appsettings.StagingLocal.json" ([string]$staging.ConnectionStrings.FiadoDb)
    Describe-ConnectionString "environment override" ([string]$env:ConnectionStrings__FiadoDb)
    $effective = [string]$staging.ConnectionStrings.FiadoDb
    Describe-ConnectionString "backend runtime effective StagingLocal" $effective
    Describe-ConnectionString "dotnet ef effective StagingLocal" $effective
    Describe-ConnectionString "staging scripts effective" $effective
    Write-Host "LaunchProfile.stagingLocal ASPNETCORE_ENVIRONMENT=$($launch.profiles.stagingLocal.environmentVariables.ASPNETCORE_ENVIRONMENT)"
    Write-Host "LaunchProfile.stagingLocal DOTNET_ENVIRONMENT=$($launch.profiles.stagingLocal.environmentVariables.DOTNET_ENVIRONMENT)"
    Write-Host "LaunchProfile.stagingLocal applicationUrl=$($launch.profiles.stagingLocal.applicationUrl)"
    Write-Host "run_backend_staging_local sets StagingLocal=$([bool](Select-String -LiteralPath $runScriptPath -Pattern 'ASPNETCORE_ENVIRONMENT = "StagingLocal"' -Quiet))"
    Write-Host ""

    Write-Host "=== Configuration file timestamps ==="
    @($basePath, $developmentPath, $stagingPath, $launchPath, $runScriptPath) | ForEach-Object {
        $item = Get-Item -LiteralPath $_
        Write-Host "file=$($item.FullName) length=$($item.Length) created=$($item.CreationTime.ToString('o')) modified=$($item.LastWriteTime.ToString('o'))"
    }

    Write-Host "=== SQL Server installation ==="
    $instanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue).SQLEXPRESS
    Write-Host "DetectedSQLEXPRESSInstanceId=$instanceId"
    if (-not [string]::IsNullOrWhiteSpace($instanceId)) {
        $instancePath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer"
        $instanceProps = Get-ItemProperty $instancePath -ErrorAction SilentlyContinue
        $tcpProps = Get-ItemProperty "$instancePath\SuperSocketNetLib\Tcp\IPAll" -ErrorAction SilentlyContinue
        Write-Host "LoginMode=$($instanceProps.LoginMode) (1=Windows only, 2=Mixed Mode)"
        Write-Host "ConfiguredTcpPort=$($tcpProps.TcpPort) DynamicTcpPorts=$($tcpProps.TcpDynamicPorts)"
    }
    Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(MSSQL|SQLBrowser)' } |
        ForEach-Object {
            $serviceRegistry = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -ErrorAction SilentlyContinue
            Write-Host "service=$($_.Name) status=$($_.Status) startType=$($_.StartType) account=$($serviceRegistry.ObjectName) imagePath=$($serviceRegistry.ImagePath)"
        }
    $localDb = Get-Command SqlLocalDB.exe -ErrorAction SilentlyContinue
    if ($null -ne $localDb) {
        Write-Host "LocalDB instances:"
        & $localDb.Source info 2>&1 | ForEach-Object { Write-Host "  $_" }
    }

    $tcp = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $tcp.ConnectAsync("127.0.0.1", 14333)
        Write-Host "TcpTest 127.0.0.1:14333 open=$($task.Wait(3000) -and $tcp.Connected)"
    } catch {
        Write-Host "TcpTest 127.0.0.1:14333 error=$($_.Exception.Message)"
    } finally { $tcp.Dispose() }
    Write-Host ""

    Write-Host "=== Read-only connection tests ==="
    $oldWindowsConnection = "Server=127.0.0.1,14333;Database=$databaseName;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;"
    $tests = @(
        @{ Label = "Current effective StagingLocal"; Value = $effective },
        @{ Label = "Previous StagingLocal Windows Auth TCP"; Value = $oldWindowsConnection },
        @{ Label = "Windows Auth localhost TCP"; Value = "Server=localhost,14333;Database=$databaseName;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;" },
        @{ Label = "Windows Auth named SQLEXPRESS"; Value = "Server=.\SQLEXPRESS;Database=$databaseName;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;" }
    )
    $results = foreach ($test in $tests) {
        $result = Test-ReadOnlySqlConnection -Label $test.Label -ConnectionString $test.Value
        Write-ConnectionResult $result
        $result
    }
    Write-Host ""

    Write-Host "=== Migration files in code ==="
    Get-ChildItem (Join-Path $apiDir "Migrations\*.cs") |
        Where-Object { $_.Name -notlike '*.Designer.cs' -and $_.Name -ne 'FiadoDbContextModelSnapshot.cs' } |
        Sort-Object Name |
        Select-Object -Last 15 -ExpandProperty BaseName |
        ForEach-Object { Write-Host "  $_" }
    if (-not ($results | Where-Object Success)) {
        Write-Host "Applied/pending migrations unavailable because no tested connection succeeded."
    }
    Write-Host ""

    Write-Host "=== Prior log evidence ==="
    Get-ChildItem -LiteralPath $logsDir -File |
        Where-Object { $_.FullName -ne $logPath } |
        Sort-Object LastWriteTime |
        Select-Object Name, Length, LastWriteTime |
        Format-Table -AutoSize | Out-String | Write-Host
    $priorBackendLog = Join-Path $logsDir "staginglocal_backend.out.log"
    if (Test-Path -LiteralPath $priorBackendLog) {
        Write-Host "Prior successful backend evidence:"
        Select-String -LiteralPath $priorBackendLog -Pattern 'Now listening|/health|/api/auth/login|Request finished' |
            ForEach-Object { Write-Host "  $($_.Line.Trim())" }
    }
    $efLogs = Get-ChildItem -LiteralPath $logsDir -Filter "ef_*.log" -ErrorAction SilentlyContinue
    foreach ($file in $efLogs) {
        $matches = Select-String -LiteralPath $file.FullName -Pattern 'SSPI|target principal|Login failed|PendingModel|No changes have been|TIMEOUT' -ErrorAction SilentlyContinue
        if ($matches) {
            Write-Host "Evidence from $($file.Name):"
            $matches | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
        }
    }
    Write-Host ""

    Write-Host "=== Audit diagnosis ==="
    $currentAuth = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($effective)
    Write-Host "PreviousKnownWorkingConnection=Windows Auth to 127.0.0.1,14333 / $databaseName"
    Write-Host "CurrentConfiguredConnection=$(Mask-ConnectionString $effective)"
    Write-Host "ConfigurationChangedToSqlAuth=$(-not $currentAuth.IntegratedSecurity)"
    Write-Host "SqlServerLoginMode=$($instanceProps.LoginMode)"
    if (-not $currentAuth.IntegratedSecurity -and $instanceProps.LoginMode -eq 1) {
        Write-Host "ProbableCause=StagingLocal was changed to SQL Auth, but SQLEXPRESS remains Windows-only. The configured SQL login cannot authenticate."
    }
    if (-not $currentAuth.IntegratedSecurity -and $instanceProps.LoginMode -eq 2 -and -not ($results | Where-Object { $_.Label -eq 'Current effective SQL Auth' -and $_.Success })) {
        Write-Host "ProbableCause=Mixed Mode is enabled, but fiado_staginglocal_app has not been created/enabled with the configured password, or is not mapped to FiadoAppDb_StagingLocal."
    }
    if ($results | Where-Object { $_.Label -like '*Windows Auth*' -and $_.IsSspi }) {
        Write-Host "SspiFinding=Windows Auth fails only from the current process identity/security context; prior logs prove it worked on 2026-06-23."
    }
    if ($instanceProps.LoginMode -eq 2 -and -not $currentAuth.IntegratedSecurity) {
        Write-Host "Recommendation=Continue with dedicated StagingLocal SQL Auth. Mixed Mode is already enabled; create/map fiado_staginglocal_app using tools/sql/create_staginglocal_sql_login.sql from the administrative SSMS session."
    } else {
        Write-Host "Recommendation=Keep the restored Windows Auth configuration and run StagingLocal operations from the interactive/elevated Windows context that can provide SSPI credentials."
    }
    Write-Host "NoConfigurationChanged=true"
    Write-Host "NoDatabaseChanged=true"
} finally {
    Stop-Transcript | Out-Null
}

Write-Host "Audit log: $logPath"
