param(
    [string]$Project = "backend/src/FiadoApp.Api/FiadoApp.Api.csproj",
    [string]$Urls = "http://0.0.0.0:5000"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$projectPath = Join-Path $repoRoot $Project
$settingsPath = Join-Path (Split-Path -Parent $projectPath) "appsettings.StagingLocal.json"

if (-not (Test-Path -LiteralPath $projectPath)) {
    Write-Error "Backend project not found: $projectPath"
}

$env:ASPNETCORE_ENVIRONMENT = "StagingLocal"
$env:DOTNET_ENVIRONMENT = "StagingLocal"

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$effectiveConnection = [string]$settings.ConnectionStrings.FiadoDb
$env:ConnectionStrings__FiadoDb = $effectiveConnection
$maskedConnection = [System.Data.SqlClient.SqlConnectionStringBuilder]::new($effectiveConnection)
if ($maskedConnection.ContainsKey("Password")) { $maskedConnection.Password = "***" }

Write-Host "Starting Fiado backend"
Write-Host "Project: $projectPath"
Write-Host "ASPNETCORE_ENVIRONMENT: $env:ASPNETCORE_ENVIRONMENT"
Write-Host "Effective connection: $($maskedConnection.ConnectionString)"
Write-Host "Urls: $Urls"
Write-Host ""
Write-Host "Health checks:"
Write-Host "  http://localhost:5000/health"
Write-Host "  http://<PC_LAN_IP>:5000/health"
Write-Host "  http://<PC_LAN_IP>:5000/api/health"
Write-Host ""

dotnet run --no-launch-profile --project $projectPath --urls $Urls
exit $LASTEXITCODE
