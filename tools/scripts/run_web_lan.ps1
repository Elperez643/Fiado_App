param(
    [string]$ApiBaseUrl = "http://192.168.18.46:5000/api",
    [int]$TimeoutSeconds = 0
)

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
$env:FLUTTER_ALREADY_LOCKED = "true"

$flutterRoot = Get-FlutterRoot
$dartExe = Join-Path $flutterRoot "bin\cache\dart-sdk\bin\dart.exe"
$flutterPackageConfig = Join-Path $flutterRoot "packages\flutter_tools\.dart_tool\package_config.json"
$flutterSnapshot = Join-Path $flutterRoot "bin\cache\flutter_tools.snapshot"

if (-not (Test-Path -LiteralPath $dartExe)) {
    Write-Host "Dart executable not found: $dartExe"
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

$env:FLUTTER_ROOT = $flutterRoot
$arguments = @(
    "--packages=$flutterPackageConfig",
    $flutterSnapshot,
    "--no-version-check",
    "run",
    "-d",
    "chrome",
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
)

Push-Location $repoRoot
try {
    Write-Host "Running Flutter Web LAN"
    Write-Host "API_BASE_URL: $ApiBaseUrl"
    Write-Host "Dart: $dartExe"
    Write-Host "Flutter snapshot: $flutterSnapshot"
    if ($TimeoutSeconds -gt 0) {
        & $runner `
            -FilePath $dartExe `
            -Arguments $arguments `
            -TimeoutSeconds $TimeoutSeconds `
            -LogFile (Join-Path $logsDir "flutter_run_web_lan.log")
        exit $LASTEXITCODE
    }

    & $dartExe @arguments
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
