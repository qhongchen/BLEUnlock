$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Please run this script from an elevated PowerShell window."
    }
}

Assert-Administrator

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$componentDir = Join-Path $repoRoot "build\windows-auto-unlock\install"
$targetDir = Join-Path ${env:ProgramFiles} "BLEUnlock"
$serviceExe = Join-Path $targetDir "BLEUnlockCredentialService.exe"
$providerDll = Join-Path $targetDir "BLEUnlockCredentialProvider.dll"

if (-not (Test-Path (Join-Path $componentDir "BLEUnlockCredentialService.exe"))) {
    throw "Build output was not found. Run .\scripts\build-windows-auto-unlock.ps1 first."
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item (Join-Path $componentDir "BLEUnlockCredentialService.exe") $serviceExe -Force
Copy-Item (Join-Path $componentDir "BLEUnlockCredentialProvider.dll") $providerDll -Force

$existing = Get-Service -Name "BLEUnlockCredentialService" -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name "BLEUnlockCredentialService" -ErrorAction SilentlyContinue
    sc.exe delete "BLEUnlockCredentialService" | Out-Null
    Start-Sleep -Seconds 1
}

sc.exe create "BLEUnlockCredentialService" binPath= "`"$serviceExe`"" start= auto DisplayName= "BLEUnlock Credential Service" | Out-Null
sc.exe description "BLEUnlockCredentialService" "Provides one-time credential grants for BLEUnlock Windows automatic unlock." | Out-Null

& regsvr32.exe /s $providerDll
Start-Service -Name "BLEUnlockCredentialService"

Write-Host "BLEUnlock Windows auto unlock components installed."
Write-Host "Service: BLEUnlockCredentialService"
Write-Host "Credential Provider: $providerDll"
Write-Host "Next: run .\scripts\set-windows-auto-unlock-credential.ps1"
