param(
    [string[]]$DartDefine = @()
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")
$logsDir = Join-Path $repoRoot "tools\logs"
$runner = Join-Path $scriptDir "run_with_timeout.ps1"

$flutterRoot = if ($env:FLUTTER_ROOT -and (Test-Path -LiteralPath $env:FLUTTER_ROOT)) {
    [System.IO.Path]::GetFullPath($env:FLUTTER_ROOT)
} else {
    "C:\flutter"
}
$flutterBat = Join-Path $flutterRoot "bin\flutter.bat"
$dartExe = Join-Path $flutterRoot "bin\cache\dart-sdk\bin\dart.exe"
$flutterToolsDir = Join-Path $flutterRoot "packages\flutter_tools"
$flutterPackageConfig = Join-Path $flutterToolsDir ".dart_tool\package_config.json"
$flutterSnapshot = Join-Path $flutterRoot "bin\cache\flutter_tools.snapshot"
if (-not (Test-Path -LiteralPath $flutterBat)) {
    Write-Host "Flutter batch not found: $flutterBat"
    exit 1
}
if (-not (Test-Path -LiteralPath $dartExe)) {
    Write-Host "Dart executable not found: $dartExe"
    exit 1
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

$env:FLUTTER_ROOT = $flutterRoot
$env:FLUTTER_ALREADY_LOCKED = "true"

Push-Location $repoRoot
try {
    $buildArguments = @(
        "--packages=$flutterPackageConfig",
        $flutterSnapshot,
        "--no-version-check",
        "build",
        "apk",
        "--debug"
    )
    foreach ($define in $DartDefine) {
        if ([string]::IsNullOrWhiteSpace($define)) {
            continue
        }
        $buildArguments += "--dart-define=$define"
    }

    & $runner `
        -FilePath $dartExe `
        -Arguments $buildArguments `
        -TimeoutSeconds 900 `
        -LogFile (Join-Path $logsDir "flutter_build_apk_debug.log")
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
