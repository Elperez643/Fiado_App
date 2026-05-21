param(
    [string]$JavaHome = "C:\Program Files\Android\Android Studio\jbr",
    [string]$OutputName = "Fiado-Beta-Android-debug.apk"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$AndroidRoot = Join-Path $ProjectRoot "android"
$ApkSource = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-debug.apk"
$DistDir = Join-Path $ProjectRoot "dist"
$ApkTarget = Join-Path $DistDir $OutputName

if (-not (Test-Path (Join-Path $JavaHome "bin\java.exe"))) {
    throw "No se encontro Java en '$JavaHome'. Instala Android Studio o pasa -JavaHome con la ruta correcta."
}

Get-Process |
    Where-Object { $_.ProcessName -match '^(dart|flutter|java|gradle|gradlew)$' } |
    Stop-Process -ErrorAction SilentlyContinue

$env:JAVA_HOME = $JavaHome
$env:Path = "$JavaHome\bin;$env:Path"

Push-Location $AndroidRoot
try {
    .\gradlew.bat assembleDebug --no-daemon --console=plain
}
finally {
    Pop-Location
}

if (-not (Test-Path $ApkSource)) {
    throw "Gradle termino, pero no se encontro el APK esperado en '$ApkSource'."
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
Copy-Item -Path $ApkSource -Destination $ApkTarget -Force

Get-Item $ApkTarget | Select-Object FullName, Length, LastWriteTime
