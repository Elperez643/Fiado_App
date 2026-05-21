param(
    [string]$ApkPath = ".\dist\Fiado-Beta-Android-debug.apk",
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ResolvedApk = Resolve-Path (Join-Path $ProjectRoot $ApkPath)

if (-not (Test-Path $AdbPath)) {
    throw "No se encontro adb en '$AdbPath'. Instala Android SDK Platform Tools."
}

$devices = & $AdbPath devices
$connected = $devices |
    Select-String -Pattern "device$" |
    Where-Object { $_.Line -notmatch "^List of devices" }

if (-not $connected) {
    throw "No hay dispositivos Android conectados. Activa Depuracion USB y acepta la autorizacion en el telefono."
}

& $AdbPath install -r $ResolvedApk
