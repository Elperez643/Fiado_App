param(
    [int]$FormatTimeoutSeconds = 120,
    [int]$AnalyzeTimeoutSeconds = 300,
    [int]$TestTimeoutSeconds = 600,
    [int]$DotnetBuildTimeoutSeconds = 300,
    [int]$ApkBuildTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$logsDir = Join-Path $repoRoot ".codex_logs"
$appDataDir = Join-Path $repoRoot ".codex_appdata"
$tempDir = Join-Path $appDataDir "temp"
$distDir = Join-Path $repoRoot "dist"
$finalApk = Join-Path $distDir "fiado_app_sync_banner_stale_error_fix_debug.apk"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
New-Item -ItemType Directory -Force -Path $appDataDir | Out-Null
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$env:APPDATA = $appDataDir
$env:TEMP = $tempDir
$env:TMP = $tempDir
$env:DART_SUPPRESS_ANALYTICS = "true"
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"
$env:PUB_ENVIRONMENT = "codex"

function Get-FlutterRoot {
    if ($env:FLUTTER_ROOT -and (Test-Path -LiteralPath $env:FLUTTER_ROOT)) {
        return [System.IO.Path]::GetFullPath($env:FLUTTER_ROOT)
    }
    return "C:\flutter"
}

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

function Stop-RelatedBuildProcesses {
    param([string]$Reason)

    Write-Host "Stopping related build processes after timeout: $Reason"
    Get-Process dart,dartaotruntime,flutter,dotnet,java,gradle -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function Resolve-CommandPath {
    param([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Command not found: $CommandName"
    }
    return $command.Source
}

function Invoke-TimedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )

    $stdoutFile = Join-Path $tempDir ("stdout_" + [Guid]::NewGuid().ToString("N") + ".log")
    $stderrFile = Join-Path $tempDir ("stderr_" + [Guid]::NewGuid().ToString("N") + ".log")
    $startedAt = Get-Date
    $display = "`"$FilePath`" $($Arguments -join ' ')".Trim()

    Write-Host ""
    Write-Host "==> $Name"
    Write-Host "Command: $display"
    Write-Host "Timeout: ${TimeoutSeconds}s"
    Write-Host "Log: $LogFile"

    "[$($startedAt.ToString('o'))] RUN $Name" | Set-Content -Path $LogFile -Encoding UTF8
    "Command=$display" | Add-Content -Path $LogFile -Encoding UTF8
    "TimeoutSeconds=$TimeoutSeconds" | Add-Content -Path $LogFile -Encoding UTF8

    $process = $null
    $timedOut = $false
    try {
        $startArgs = @{
            FilePath = $FilePath
            ArgumentList = $Arguments
            RedirectStandardOutput = $stdoutFile
            RedirectStandardError = $stderrFile
            PassThru = $true
            WindowStyle = "Hidden"
        }
        $process = Start-Process @startArgs
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            $timedOut = $true
            Stop-ProcessTree -ProcessId $process.Id
            Stop-RelatedBuildProcesses -Reason $Name
        } else {
            $process.WaitForExit()
            $process.Refresh()
        }
    } catch {
        "ERROR: $($_.Exception.Message)" | Add-Content -Path $LogFile -Encoding UTF8
        throw
    } finally {
        $finishedAt = Get-Date
        $stdout = if (Test-Path -LiteralPath $stdoutFile) {
            Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue
        } else {
            ""
        }
        $stderr = if (Test-Path -LiteralPath $stderrFile) {
            Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
        } else {
            ""
        }

        "" | Add-Content -Path $LogFile -Encoding UTF8
        "[$($finishedAt.ToString('o'))] FINISH $Name" | Add-Content -Path $LogFile -Encoding UTF8
        "TimedOut=$timedOut" | Add-Content -Path $LogFile -Encoding UTF8
        "DurationSeconds=$([int]($finishedAt - $startedAt).TotalSeconds)" | Add-Content -Path $LogFile -Encoding UTF8
        "ExitCode=$($process.ExitCode)" | Add-Content -Path $LogFile -Encoding UTF8
        "" | Add-Content -Path $LogFile -Encoding UTF8
        "----- STDOUT -----" | Add-Content -Path $LogFile -Encoding UTF8
        $stdout | Add-Content -Path $LogFile -Encoding UTF8
        "----- STDERR -----" | Add-Content -Path $LogFile -Encoding UTF8
        $stderr | Add-Content -Path $LogFile -Encoding UTF8

        Remove-Item -LiteralPath $stdoutFile,$stderrFile -Force -ErrorAction SilentlyContinue
    }

    $effectiveExitCode = $process.ExitCode
    if ($null -eq $effectiveExitCode) {
        $logText = if (Test-Path -LiteralPath $LogFile) {
            Get-Content -LiteralPath $LogFile -Raw -ErrorAction SilentlyContinue
        } else {
            ""
        }
        $hasStdErr = $logText -match "----- STDERR -----\s+\S"
        $hasFailureText =
            $logText -match "Some tests failed" -or
            $logText -match "Test failed" -or
            $logText -match "Build failed" -or
            $logText -match "Compilation failed" -or
            $logText -match "Analyzer found" -or
            $logText -match "NoSuchMethodError" -or
            $logText -match "Unhandled exception"
        $effectiveExitCode = if ($hasStdErr -or $hasFailureText) { 1 } else { 0 }
    }

    if ($timedOut) {
        Write-Host "TIMEOUT: $Name after ${TimeoutSeconds}s"
        Write-Host "Last 80 log lines:"
        Get-Content -LiteralPath $LogFile -Tail 80 -ErrorAction SilentlyContinue
        throw "$Name timed out after ${TimeoutSeconds}s"
    }

    if ($effectiveExitCode -ne 0) {
        Write-Host "FAILED: $Name exitCode=$effectiveExitCode"
        Write-Host "Last 80 log lines:"
        Get-Content -LiteralPath $LogFile -Tail 80 -ErrorAction SilentlyContinue
        throw "$Name failed with exit code $effectiveExitCode"
    }

    Write-Host "OK: $Name"
}

$flutterRoot = Get-FlutterRoot
$dartExe = Join-Path $flutterRoot "bin\cache\dart-sdk\bin\dart.exe"
$flutterPackageConfig = Join-Path $flutterRoot "packages\flutter_tools\.dart_tool\package_config.json"
$flutterSnapshot = Join-Path $flutterRoot "bin\cache\flutter_tools.snapshot"
$dotnetExe = Resolve-CommandPath "dotnet"
$androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr"

if (-not (Test-Path -LiteralPath $dartExe)) {
    throw "Dart executable not found: $dartExe"
}
if (-not (Test-Path -LiteralPath $flutterPackageConfig)) {
    throw "Flutter package config not found: $flutterPackageConfig"
}
if (-not (Test-Path -LiteralPath $flutterSnapshot)) {
    throw "Flutter tools snapshot not found: $flutterSnapshot"
}
if (-not $env:JAVA_HOME -and (Test-Path -LiteralPath $androidStudioJbr)) {
    $env:JAVA_HOME = $androidStudioJbr
}
if ($env:JAVA_HOME) {
    $javaBin = Join-Path $env:JAVA_HOME "bin"
    if (Test-Path -LiteralPath $javaBin) {
        $env:Path = "$javaBin;$env:Path"
    }
}

$env:FLUTTER_ROOT = $flutterRoot
$env:FLUTTER_ALREADY_LOCKED = "true"

$flutterArgsPrefix = @(
    "--packages=$flutterPackageConfig",
    $flutterSnapshot,
    "--no-version-check"
)

$summary = New-Object System.Collections.Generic.List[string]

Push-Location $repoRoot
try {
    Write-Host "Repo: $repoRoot"
    Write-Host "Logs: $logsDir"
    Write-Host "APPDATA: $env:APPDATA"
    Write-Host "TEMP: $env:TEMP"
    Write-Host "FLUTTER_ROOT: $env:FLUTTER_ROOT"
    Write-Host "JAVA_HOME: $env:JAVA_HOME"

    Invoke-TimedCommand `
        -Name "dart format ." `
        -FilePath $dartExe `
        -Arguments @("format", ".") `
        -TimeoutSeconds $FormatTimeoutSeconds `
        -LogFile (Join-Path $logsDir "01_dart_format.log")
    $summary.Add("dart format .: OK")

    Invoke-TimedCommand `
        -Name "flutter analyze" `
        -FilePath $dartExe `
        -Arguments ($flutterArgsPrefix + @("analyze")) `
        -TimeoutSeconds $AnalyzeTimeoutSeconds `
        -LogFile (Join-Path $logsDir "02_flutter_analyze.log")
    $summary.Add("flutter analyze: OK")

    Invoke-TimedCommand `
        -Name "flutter test" `
        -FilePath $dartExe `
        -Arguments ($flutterArgsPrefix + @("test")) `
        -TimeoutSeconds $TestTimeoutSeconds `
        -LogFile (Join-Path $logsDir "03_flutter_test.log")
    $summary.Add("flutter test: OK")

    Invoke-TimedCommand `
        -Name "dotnet build backend\FiadoApp.Backend.sln --no-restore" `
        -FilePath $dotnetExe `
        -Arguments @("build", "backend\FiadoApp.Backend.sln", "--no-restore") `
        -TimeoutSeconds $DotnetBuildTimeoutSeconds `
        -LogFile (Join-Path $logsDir "04_dotnet_build.log")
    $summary.Add("dotnet build: OK")

    Invoke-TimedCommand `
        -Name "flutter build apk --debug" `
        -FilePath $dartExe `
        -Arguments ($flutterArgsPrefix + @("build", "apk", "--debug")) `
        -TimeoutSeconds $ApkBuildTimeoutSeconds `
        -LogFile (Join-Path $logsDir "05_flutter_build_apk_debug.log")
    $summary.Add("flutter build apk --debug: OK")

    $builtApk = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-debug.apk"
    if (-not (Test-Path -LiteralPath $builtApk)) {
        throw "Built APK not found: $builtApk"
    }
    Copy-Item -LiteralPath $builtApk -Destination $finalApk -Force
    $apkItem = Get-Item -LiteralPath $finalApk
    $summary.Add("copy APK: OK $($apkItem.FullName) bytes=$($apkItem.Length)")

    Write-Host ""
    Write-Host "Validation summary"
    foreach ($line in $summary) {
        Write-Host "OK - $line"
    }
    Write-Host "APK: $($apkItem.FullName)"
} catch {
    Write-Host ""
    Write-Host "Validation failed: $($_.Exception.Message)"
    Write-Host "Partial summary"
    foreach ($line in $summary) {
        Write-Host "OK - $line"
    }
    exit 1
} finally {
    Pop-Location
}
