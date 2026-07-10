$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "Building release binary..."
swift build -c release
if ($LASTEXITCODE -ne 0) { throw "swift build falhou (exit $LASTEXITCODE)" }
$binPath = Join-Path (swift build -c release --show-bin-path) "claudegauge.exe"

$installDir = Join-Path $env:LOCALAPPDATA "Programs\ClaudeGauge"
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item $binPath (Join-Path $installDir "claudegauge.exe") -Force

$iconsDir = Join-Path $env:APPDATA "ClaudeGauge\icons"
New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null
foreach ($icon in "claudegauge", "claudegauge-warn", "claudegauge-critical") {
  Copy-Item "Resources\windows\$icon.ico" (Join-Path $iconsDir "$icon.ico") -Force
}

Write-Host "Done: $installDir\claudegauge.exe"
Write-Host "Rode com:  claudegauge  (ou pelo menu Iniciar apontando pro exe)"
Write-Host "Login próprio (opcional):  claudegauge login"
