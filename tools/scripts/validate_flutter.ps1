$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$logsDir = Join-Path $repoRoot "tools\logs"
$runner = Join-Path $scriptDir "run_with_timeout.ps1"

function Get-FlutterRoot {
    if ($env:FLUTTER_ROOT -and (Test-Path -LiteralPath $env:FLUTTER_ROOT)) {
        return [System.IO.Path]::GetFullPath($env:FLUTTER_ROOT)
    }
    return "C:\flutter"
}

function Invoke-Step {
    param(
        [hashtable]$Step,
        [System.Collections.Generic.List[string]]$Summary
    )

    Write-Host ""
    Write-Host "Running $($Step.Name)"
    Write-Host "FilePath: $($Step.FilePath)"
    Write-Host "Arguments: $($Step.Arguments -join ' ')"

    if ($Step.Arguments.Count -gt 0) {
        & $runner `
            -FilePath $Step.FilePath `
            -Arguments $Step.Arguments `
            -TimeoutSeconds $Step.TimeoutSeconds `
            -LogFile $Step.LogFile
    } else {
        & $runner `
            -FilePath $Step.FilePath `
            -TimeoutSeconds $Step.TimeoutSeconds `
            -LogFile $Step.LogFile
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $Summary.Add("$($Step.Name) FAILED ($exitCode)")
        Write-Host ""
        Write-Host "Validation failed"
        foreach ($line in $Summary) { Write-Host $line }
        Write-Host "Failed command: $($Step.Name)"
        Write-Host "Executable: $($Step.FilePath)"
        Write-Host "Exit code: $exitCode"
        Write-Host "Log: $($Step.LogFile)"
        Write-Host "Last 60 log lines:"
        if (Test-Path -LiteralPath $Step.LogFile) {
            Get-Content -LiteralPath $Step.LogFile -Tail 60
        }
        exit $exitCode
    }
    $Summary.Add("$($Step.Name) OK")
}

if (-not (Test-Path -LiteralPath $logsDir)) {
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
}
$scriptAppData = Join-Path $repoRoot "tools\.appdata"
$scriptLocalAppData = Join-Path $repoRoot "tools\.localappdata"
New-Item -ItemType Directory -Force -Path $scriptAppData | Out-Null
New-Item -ItemType Directory -Force -Path $scriptLocalAppData | Out-Null
$env:APPDATA = $scriptAppData
$env:LOCALAPPDATA = $scriptLocalAppData
$env:DART_SUPPRESS_ANALYTICS = "true"
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"
$androidStudioJbr = "C:\Program Files\Android\Android Studio\jbr"
if (-not $env:JAVA_HOME -and (Test-Path -LiteralPath $androidStudioJbr)) {
    $env:JAVA_HOME = $androidStudioJbr
}
if ($env:JAVA_HOME) {
    $javaBin = Join-Path $env:JAVA_HOME "bin"
    if (Test-Path -LiteralPath $javaBin) {
        $env:Path = "$javaBin;$env:Path"
    }
}

$flutterRoot = Get-FlutterRoot
$dartExe = Join-Path $flutterRoot "bin\cache\dart-sdk\bin\dart.exe"
$flutterBat = Join-Path $flutterRoot "bin\flutter.bat"
$flutterToolsDir = Join-Path $flutterRoot "packages\flutter_tools"
$flutterPackageConfig = Join-Path $flutterToolsDir ".dart_tool\package_config.json"
$flutterSnapshot = Join-Path $flutterRoot "bin\cache\flutter_tools.snapshot"

if (-not (Test-Path -LiteralPath $dartExe)) {
    Write-Host "Dart executable not found: $dartExe"
    exit 1
}
if (-not (Test-Path -LiteralPath $flutterBat)) {
    Write-Host "Flutter batch not found: $flutterBat"
    exit 1
}
if (-not (Test-Path -LiteralPath $flutterPackageConfig)) {
    Write-Host "Flutter package config not found: $flutterPackageConfig"
    exit 1
}
if (-not (Test-Path -LiteralPath $flutterSnapshot)) {
    Write-Host "Flutter tools snapshot not found: $flutterSnapshot"
    exit 1
}

$flutterToolPrefix = @(
    "--packages=$flutterPackageConfig",
    $flutterSnapshot,
    "--no-version-check"
)
$env:FLUTTER_ROOT = $flutterRoot
$env:FLUTTER_ALREADY_LOCKED = "true"

$steps = @(
    @{
        Name = "dart.exe format ."
        FilePath = $dartExe
        Arguments = @("format", ".")
        TimeoutSeconds = 120
        LogFile = Join-Path $logsDir "dart_format.log"
    },
    @{
        Name = "flutter analyze"
        FilePath = $dartExe
        Arguments = $flutterToolPrefix + @("analyze")
        TimeoutSeconds = 300
        LogFile = Join-Path $logsDir "flutter_analyze.log"
    },
    @{
        Name = "flutter test"
        FilePath = $dartExe
        Arguments = $flutterToolPrefix + @("test")
        TimeoutSeconds = 600
        LogFile = Join-Path $logsDir "flutter_test.log"
    },
    @{
        Name = "flutter build apk --debug"
        FilePath = $dartExe
        Arguments = $flutterToolPrefix + @("build", "apk", "--debug")
        TimeoutSeconds = 900
        LogFile = Join-Path $logsDir "flutter_build_apk_debug.log"
    }
)

$summary = New-Object System.Collections.Generic.List[string]

Push-Location $repoRoot
try {
    Write-Host "FLUTTER_ROOT: $flutterRoot"
    Write-Host "Dart: $dartExe"
    Write-Host "Flutter: $flutterBat"
    Write-Host "JAVA_HOME: $env:JAVA_HOME"
    foreach ($step in $steps) {
        Invoke-Step -Step $step -Summary $summary
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Validation summary"
foreach ($line in $summary) { Write-Host $line }
exit 0
