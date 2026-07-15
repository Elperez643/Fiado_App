param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [string[]]$Arguments = @(),

    [Parameter(Mandatory = $true)]
    [int]$TimeoutSeconds,

    [Parameter(Mandatory = $true)]
    [string]$LogFile
)

$ErrorActionPreference = "Stop"

function Stop-ProcessTree {
    param([int]$ProcessId)

    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue
    foreach ($child in $children) {
        Stop-ProcessTree -ProcessId ([int]$child.ProcessId)
    }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -ne $process) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-LogPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

$resolvedFilePath = [System.IO.Path]::GetFullPath($FilePath)
$logPath = Resolve-LogPath $LogFile
$logDir = Split-Path -Parent $logPath
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("fiado_cmd_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$stdoutFile = Join-Path $tempRoot "stdout.log"
$stderrFile = Join-Path $tempRoot "stderr.log"

$displayCommand = "`"$resolvedFilePath`" $($Arguments -join ' ')".Trim()
$startedAt = Get-Date
$exitCode = 0
$timedOut = $false

try {
    if (-not (Test-Path -LiteralPath $resolvedFilePath)) {
        throw "Executable not found: $resolvedFilePath"
    }

    "[$($startedAt.ToString('o'))] RUN $displayCommand" | Set-Content -Path $logPath -Encoding UTF8
    "FilePath=$resolvedFilePath" | Add-Content -Path $logPath -Encoding UTF8
    "Arguments=$($Arguments -join ' ')" | Add-Content -Path $logPath -Encoding UTF8
    "TimeoutSeconds=$TimeoutSeconds" | Add-Content -Path $logPath -Encoding UTF8

    $startProcessArgs = @{
        FilePath = $resolvedFilePath
        NoNewWindow = $true
        PassThru = $true
        RedirectStandardOutput = $stdoutFile
        RedirectStandardError = $stderrFile
    }
    if ($Arguments.Count -gt 0) {
        $startProcessArgs.ArgumentList = $Arguments
    }

    $process = Start-Process @startProcessArgs

    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        $timedOut = $true
        Stop-ProcessTree -ProcessId $process.Id
        $exitCode = 124
    } else {
        $process.WaitForExit()
        $process.Refresh()
        $rawExitCode = $process.ExitCode
        if ($null -eq $rawExitCode) {
            $stdoutNow = if (Test-Path -LiteralPath $stdoutFile) { Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue } else { "" }
            $stderrNow = if (Test-Path -LiteralPath $stderrFile) { Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue } else { "" }
            $knownFailure = $stdoutNow -match '(?im)^Build FAILED\.|^Build failed\.|\berror [A-Z]+[0-9]+:'
            $exitCode = if (-not $knownFailure -and [string]::IsNullOrWhiteSpace($stderrNow)) { 0 } else { 1 }
        } else {
            $exitCode = $rawExitCode
        }
    }
} catch {
    $exitCode = 1
    "ERROR: $($_.Exception.Message)" | Add-Content -Path $logPath -Encoding UTF8
} finally {
    $finishedAt = Get-Date
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue } else { "" }

    "" | Add-Content -Path $logPath -Encoding UTF8
    "[$($finishedAt.ToString('o'))] EXIT $exitCode" | Add-Content -Path $logPath -Encoding UTF8
    "TimedOut=$timedOut" | Add-Content -Path $logPath -Encoding UTF8
    "DurationSeconds=$([int]($finishedAt - $startedAt).TotalSeconds)" | Add-Content -Path $logPath -Encoding UTF8
    "" | Add-Content -Path $logPath -Encoding UTF8
    "----- STDOUT -----" | Add-Content -Path $logPath -Encoding UTF8
    $stdout | Add-Content -Path $logPath -Encoding UTF8
    "----- STDERR -----" | Add-Content -Path $logPath -Encoding UTF8
    $stderr | Add-Content -Path $logPath -Encoding UTF8

    Write-Host "===== $displayCommand ====="
    Write-Host "Started: $($startedAt.ToString('o'))"
    Write-Host "Finished: $($finishedAt.ToString('o'))"
    if ($timedOut) {
        Write-Host "TIMEOUT after $TimeoutSeconds seconds"
    }
    Write-Host "ExitCode: $exitCode"
    Write-Host "LogFile: $logPath"
    Write-Host "----- STDOUT -----"
    if (-not [string]::IsNullOrWhiteSpace($stdout)) { Write-Host $stdout }
    Write-Host "----- STDERR -----"
    if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Host $stderr }

    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit $exitCode
