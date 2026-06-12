$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$appDir = Join-Path $repoRoot "flutter\packages\bleunlock_app"
$releaseDir = Join-Path $appDir "build\windows\x64\runner\Release"
$zipDir = Join-Path $appDir "build\windows"
$zipPath = Join-Path $zipDir "bleunlock_app-windows-x64.zip"
$exePath = Join-Path $releaseDir "bleunlock_app.exe"

Push-Location $appDir
try {
    flutter config --enable-windows-desktop
    flutter pub get
    flutter build windows --release
} finally {
    Pop-Location
}

if (-not (Test-Path $exePath)) {
    throw "Windows release executable was not found: $exePath"
}

New-Item -ItemType Directory -Force -Path $zipDir | Out-Null
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$previousProgressPreference = $ProgressPreference
$ProgressPreference = "SilentlyContinue"
try {
    Compress-Archive -Path (Join-Path $releaseDir "*") -DestinationPath $zipPath
} finally {
    $ProgressPreference = $previousProgressPreference
}
$hash = Get-FileHash $zipPath -Algorithm SHA256

Write-Host "Windows x64 release package:"
Write-Host $zipPath
Write-Host "SHA256: $($hash.Hash)"
