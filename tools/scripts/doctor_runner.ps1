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

$flutterRoot = Get-FlutterRoot
$dartExe = Join-Path $flutterRoot "bin\cache\dart-sdk\bin\dart.exe"
$flutterBat = Join-Path $flutterRoot "bin\flutter.bat"
$flutterToolsDir = Join-Path $flutterRoot "packages\flutter_tools"
$flutterPackageConfig = Join-Path $flutterToolsDir ".dart_tool\package_config.json"
$flutterSnapshot = Join-Path $flutterRoot "bin\cache\flutter_tools.snapshot"

Write-Host "FLUTTER_ROOT used: $flutterRoot"
Write-Host "dart.exe used: $dartExe"
Write-Host "flutter.bat used: $flutterBat"
Write-Host ""
Write-Host "where flutter:"
where.exe flutter
Write-Host ""
Write-Host "where dart:"
where.exe dart

if (-not (Test-Path -LiteralPath $dartExe)) {
    Write-Host "Dart executable not found: $dartExe"
    exit 1
}
if (-not (Test-Path -LiteralPath $flutterBat)) {
    Write-Host "Flutter batch not found: $flutterBat"
    exit 1
}
$env:FLUTTER_ROOT = $flutterRoot
$env:FLUTTER_ALREADY_LOCKED = "true"

Push-Location $repoRoot
try {
    & $runner `
        -FilePath $dartExe `
        -Arguments @("--version") `
        -TimeoutSeconds 30 `
        -LogFile (Join-Path $logsDir "doctor_dart_version.log")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $runner `
        -FilePath $dartExe `
        -Arguments @("--packages=$flutterPackageConfig", $flutterSnapshot, "--version") `
        -TimeoutSeconds 60 `
        -LogFile (Join-Path $logsDir "doctor_flutter_version.log")
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
