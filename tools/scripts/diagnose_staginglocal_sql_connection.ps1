param(
    [int]$AttemptTimeoutSeconds = 8
)

$ErrorActionPreference = "Stop"
$databaseName = "FiadoAppDb_StagingLocal"
$machineName = $env:COMPUTERNAME
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$settingsPath = Join-Path $repoRoot "backend\src\FiadoApp.Api\appsettings.StagingLocal.json"

function Test-EffectiveSqlAuth {
    param([string]$ConnectionString)

    $job = Start-Job -ScriptBlock {
        param($Value)
        $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($Value)
        $builder["Connect Timeout"] = 5
        $connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
        try {
            $connection.Open()
            $command = $connection.CreateCommand()
            $command.CommandTimeout = 5
            $command.CommandText = @"
SELECT
    DB_NAME() AS DatabaseName,
    1 AS SelectOne,
    CASE WHEN OBJECT_ID(N'dbo.Users', N'U') IS NULL THEN 0 ELSE 1 END AS UsersExists,
    CASE WHEN OBJECT_ID(N'dbo.ProductImages', N'U') IS NULL THEN 0 ELSE 1 END AS ProductImagesExists,
    IS_ROLEMEMBER(N'db_owner') AS IsDbOwner,
    HAS_PERMS_BY_NAME(DB_NAME(), N'DATABASE', N'CONNECT') AS CanConnect;
"@
            $reader = $command.ExecuteReader()
            $null = $reader.Read()
            [pscustomobject]@{
                Success = $true
                DatabaseName = [string]$reader["DatabaseName"]
                SelectOne = [int]$reader["SelectOne"]
                UsersExists = [int]$reader["UsersExists"] -eq 1
                ProductImagesExists = [int]$reader["ProductImagesExists"] -eq 1
                IsDbOwner = [int]$reader["IsDbOwner"] -eq 1
                CanConnect = [int]$reader["CanConnect"] -eq 1
                Error = ""
            }
            $reader.Close()
        } catch {
            [pscustomobject]@{
                Success = $false; DatabaseName = ""; SelectOne = 0
                UsersExists = $false; ProductImagesExists = $false
                IsDbOwner = $false; CanConnect = $false; Error = $_.Exception.Message
            }
        } finally {
            $connection.Dispose()
        }
    } -ArgumentList $ConnectionString

    if (-not (Wait-Job -Job $job -Timeout $AttemptTimeoutSeconds)) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Success = $false; DatabaseName = ""; SelectOne = 0
            UsersExists = $false; ProductImagesExists = $false
            IsDbOwner = $false; CanConnect = $false
            Error = "Timed out after ${AttemptTimeoutSeconds}s"
        }
    }
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    return $result
}

function Test-SqlCandidate {
    param([string]$Label, [string]$Server)

    $job = Start-Job -ScriptBlock {
        param($CandidateServer, $TargetDatabase)
        $connectionString = "Server=$CandidateServer;Database=master;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;Connection Timeout=5;"
        $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
        try {
            $connection.Open()
            $command = $connection.CreateCommand()
            $command.CommandTimeout = 5
            $command.CommandText = @"
SELECT
    CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName,
    CAST(SERVERPROPERTY('InstanceName') AS nvarchar(256)) AS InstanceName,
    CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS Edition,
    SUSER_SNAME() AS LoginName,
    DB_ID(@databaseName) AS DatabaseId;
"@
            $null = $command.Parameters.Add("@databaseName", [System.Data.SqlDbType]::NVarChar, 128)
            $command.Parameters["@databaseName"].Value = $TargetDatabase
            $reader = $command.ExecuteReader()
            $null = $reader.Read()
            [pscustomobject]@{
                Success = $true
                ServerName = [string]$reader["ServerName"]
                InstanceName = if ($reader.IsDBNull($reader.GetOrdinal("InstanceName"))) { "" } else { [string]$reader["InstanceName"] }
                Edition = [string]$reader["Edition"]
                LoginName = [string]$reader["LoginName"]
                DatabaseExists = -not $reader.IsDBNull($reader.GetOrdinal("DatabaseId"))
                Error = ""
                IsSspiError = $false
            }
            $reader.Close()
        } catch {
            [pscustomobject]@{
                Success = $false
                ServerName = ""
                InstanceName = ""
                Edition = ""
                LoginName = ""
                DatabaseExists = $false
                Error = $_.Exception.Message
                IsSspiError = $_.Exception.Message -match "SSPI|target principal name"
            }
        } finally {
            $connection.Dispose()
        }
    } -ArgumentList $Server, $databaseName

    if (-not (Wait-Job -Job $job -Timeout $AttemptTimeoutSeconds)) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Label = $Label; Server = $Server; Success = $false; ServerName = ""; InstanceName = ""
            Edition = ""; LoginName = ""; DatabaseExists = $false
            Error = "Timed out after ${AttemptTimeoutSeconds}s"; IsSspiError = $false
        }
    }

    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        Label = $Label
        Server = $Server
        Success = [bool]$result.Success
        ServerName = $result.ServerName
        InstanceName = $result.InstanceName
        Edition = $result.Edition
        LoginName = $result.LoginName
        DatabaseExists = [bool]$result.DatabaseExists
        Error = $result.Error
        IsSspiError = [bool]$result.IsSspiError
    }
}

Write-Host "StagingLocal SQL connection diagnostic"
Write-Host "Machine=$machineName"
Write-Host "TargetDatabase=$databaseName"
Write-Host "WindowsIdentity=$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host ""

$instanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -ErrorAction SilentlyContinue).SQLEXPRESS
$loginMode = $null
if (-not [string]::IsNullOrWhiteSpace($instanceId)) {
    $instanceProperties = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer" -ErrorAction SilentlyContinue
    $loginMode = $instanceProperties.LoginMode
}
$loginModeDescription = switch ($loginMode) {
    1 { "Windows Authentication only" }
    2 { "Mixed Mode (SQL Server and Windows Authentication)" }
    default { "Unknown" }
}
Write-Host "SqlExpressLoginMode=$loginMode ($loginModeDescription)"
Write-Host "MixedModeRequired=$($loginMode -eq 1)"
Write-Host ""

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$effectiveConnection = [string]$settings.ConnectionStrings.FiadoDb
$masked = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($effectiveConnection)
if ($masked.ContainsKey("Password")) { $masked.Password = "***" }
Write-Host "EffectiveConnectionString=$($masked.ConnectionString)"
$sqlAuthResult = Test-EffectiveSqlAuth -ConnectionString $effectiveConnection
Write-Host "[Effective StagingLocal connection] success=$($sqlAuthResult.Success) database=$($sqlAuthResult.DatabaseName) selectOne=$($sqlAuthResult.SelectOne)"
if ($sqlAuthResult.Success) {
    Write-Host "  UsersExists=$($sqlAuthResult.UsersExists) ProductImagesExists=$($sqlAuthResult.ProductImagesExists)"
    Write-Host "  CanConnect=$($sqlAuthResult.CanConnect) IsDbOwner=$($sqlAuthResult.IsDbOwner)"
} else {
    Write-Host "  error=$($sqlAuthResult.Error)"
}
Write-Host ""

$tcpClient = [System.Net.Sockets.TcpClient]::new()
try {
    $tcpTask = $tcpClient.ConnectAsync("127.0.0.1", 14333)
    $portOpen = $tcpTask.Wait(3000) -and $tcpClient.Connected
    Write-Host "TcpPort 127.0.0.1:14333 open=$portOpen"
} catch {
    Write-Host "TcpPort 127.0.0.1:14333 error=$($_.Exception.Message)"
} finally {
    $tcpClient.Dispose()
}

Write-Host ""
Write-Host "Local SQL services:"
Get-Service -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(MSSQL|SQLBrowser)' } |
    Select-Object Status, Name, DisplayName, StartType |
    Format-Table -AutoSize | Out-String | Write-Host

$localDb = Get-Command SqlLocalDB.exe -ErrorAction SilentlyContinue
if ($null -ne $localDb) {
    Write-Host "LocalDB instances:"
    & $localDb.Source info 2>&1 | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "LocalDB utility not installed."
}

$candidates = @(
    @{ Label = "Current TCP IP"; Server = "127.0.0.1,14333" },
    @{ Label = "TCP localhost"; Server = "localhost,14333" },
    @{ Label = "TCP machine name"; Server = "$machineName,14333" },
    @{ Label = "SQL Express local"; Server = ".\SQLEXPRESS" },
    @{ Label = "SQL Express machine"; Server = "$machineName\SQLEXPRESS" },
    @{ Label = "LocalDB"; Server = "(localdb)\MSSQLLocalDB" }
)

Write-Host ""
Write-Host "Connection attempts:"
$results = foreach ($candidate in $candidates) {
    $result = Test-SqlCandidate -Label $candidate.Label -Server $candidate.Server
    Write-Host "[$($result.Label)] server=$($result.Server) success=$($result.Success) databaseExists=$($result.DatabaseExists) sspi=$($result.IsSspiError)"
    if ($result.Success) {
        Write-Host "  respondsAs=$($result.ServerName) instance=$($result.InstanceName) login=$($result.LoginName)"
        Write-Host "  edition=$($result.Edition)"
    } else {
        Write-Host "  error=$($result.Error)"
    }
    $result
}

Write-Host ""
$effectiveBuilder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($effectiveConnection)
$sqlAuthReady = $sqlAuthResult.Success -and
    $sqlAuthResult.DatabaseName -eq $databaseName -and
    $sqlAuthResult.SelectOne -eq 1 -and
    $sqlAuthResult.UsersExists -and
    $sqlAuthResult.ProductImagesExists -and
    $sqlAuthResult.CanConnect -and
    $sqlAuthResult.IsDbOwner
if ($sqlAuthReady) {
    Write-Host "RecommendedConnection=$($masked.ConnectionString)"
    $readyMode = if ($effectiveBuilder.IntegratedSecurity) { "READY_WINDOWS_AUTH" } else { "READY_SQL_AUTH" }
    Write-Host "DiagnosticStatus=$readyMode"
    exit 0
}

if (-not $effectiveBuilder.IntegratedSecurity -and -not $sqlAuthResult.Success) {
    if ($loginMode -eq 1) {
        Write-Host "SQL Authentication is configured, but SQLEXPRESS is still in Windows-only mode. Enable Mixed Mode, restart SQLEXPRESS, then run tools/sql/create_staginglocal_sql_login.sql from an administrative SSMS session."
        Write-Host "DiagnosticStatus=MIXED_MODE_REQUIRED"
    } else {
        Write-Host "SQL Authentication is enabled, but the StagingLocal login could not connect. Run tools/sql/create_staginglocal_sql_login.sql from an administrative SSMS session."
        Write-Host "DiagnosticStatus=SQL_LOGIN_SETUP_REQUIRED"
    }
    exit 4
}

$recommended = $results | Where-Object { $_.Success -and $_.DatabaseExists } | Select-Object -First 1
if ($null -ne $recommended) {
    $connection = "Server=$($recommended.Server);Database=$databaseName;Integrated Security=True;TrustServerCertificate=True;Encrypt=False;"
    Write-Host "RecommendedConnection=$connection"
    Write-Host "DiagnosticStatus=READY"
    exit 0
}

$reachable = $results | Where-Object { $_.Success } | Select-Object -First 1
if ($null -ne $reachable) {
    Write-Host "A Windows-authenticated SQL instance responds, but it does not contain $databaseName."
    Write-Host "DiagnosticStatus=INSTANCE_AVAILABLE_DATABASE_MISSING"
    exit 2
}

Write-Host "No tested SQL instance accepted Windows authentication."
Write-Host "DiagnosticStatus=NO_WINDOWS_AUTH_CONNECTION"
exit 3
