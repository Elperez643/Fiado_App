param(
    [int]$StartupTimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$runScript = Join-Path $PSScriptRoot "run_backend_staging_local.ps1"
$logsDir = Join-Path $repoRoot ".codex_logs"
$stdout = Join-Path $logsDir "staginglocal_windows_auth_backend.out.log"
$stderr = Join-Path $logsDir "staginglocal_windows_auth_backend.err.log"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue

function Stop-ProcessTree {
    param([int]$ProcessId)
    Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-ProcessTree -ProcessId ([int]$_.ProcessId) }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

$arguments = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", $runScript,
    "-Urls", "http://127.0.0.1:5000"
)
$backend = Start-Process powershell.exe -ArgumentList $arguments `
    -WorkingDirectory $repoRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr

try {
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    $health = $null
    while ((Get-Date) -lt $deadline) {
        if ($backend.HasExited) { break }
        try {
            $health = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:5000/health" -TimeoutSec 3
            if ([int]$health.StatusCode -eq 200) { break }
        } catch { }
        Start-Sleep -Milliseconds 750
    }

    if ($null -eq $health -or [int]$health.StatusCode -ne 200) {
        throw "Backend did not return health 200 within ${StartupTimeoutSeconds}s."
    }
    Write-Host "HealthStatus=$([int]$health.StatusCode)"
    Write-Host "HealthBody=$($health.Content)"

    $loginBody = @{
        phone = "0000000000"
        password = "invalid-staginglocal-password"
        deviceId = "staginglocal-false-login-check"
        deviceInfo = "local backend validation"
    } | ConvertTo-Json
    $loginStatus = 0
    try {
        $login = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:5000/api/auth/login" `
            -Method Post -ContentType "application/json" -Body $loginBody -TimeoutSec 10
        $loginStatus = [int]$login.StatusCode
    } catch {
        if ($null -ne $_.Exception.Response) {
            $loginStatus = [int]$_.Exception.Response.StatusCode
        } else {
            throw
        }
    }
    Write-Host "FalseLoginStatus=$loginStatus"
    if ($loginStatus -ne 401) { throw "False login returned $loginStatus instead of 401." }

    Start-Sleep -Milliseconds 500
    $combinedLogs = @(
        (Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue),
        (Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)
    ) -join "`n"
    $forbidden = @(
        "Login failed for user 'fiado_staginglocal_app'",
        "Invalid column name",
        "PendingModelChangesWarning",
        "Cannot generate SSPI context"
    )
    foreach ($text in $forbidden) {
        $found = $combinedLogs -match [regex]::Escape($text)
        Write-Host "ForbiddenLog text=$text found=$found"
        if ($found) { throw "Forbidden backend log detected: $text" }
    }
    Write-Host "BackendValidation=OK"
} finally {
    Stop-ProcessTree -ProcessId $backend.Id
}
