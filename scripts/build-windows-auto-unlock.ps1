$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourceDir = Join-Path $repoRoot "windows\auto_unlock"
$buildDir = Join-Path $repoRoot "build\windows-auto-unlock"
$installDir = Join-Path $repoRoot "build\windows-auto-unlock\install"

cmake -S $sourceDir -B $buildDir -A x64
cmake --build $buildDir --config Release

New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Copy-Item (Join-Path $buildDir "Release\BLEUnlockCredentialService.exe") $installDir -Force
Copy-Item (Join-Path $buildDir "Release\BLEUnlockCredentialProvider.dll") $installDir -Force

Write-Host "Windows auto unlock components:"
Write-Host $installDir
