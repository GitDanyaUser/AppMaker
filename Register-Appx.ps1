$ErrorActionPreference = 'Stop'
try {
    $path = (Read-Host "Enter app folder (or AppxManifest.xml path) to register for testing").Trim('"')
    if (Test-Path -LiteralPath $path -PathType Container) {
        $manifest = Join-Path $path 'AppxManifest.xml'
    } else {
        $manifest = $path
    }
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "AppxManifest.xml not found: $manifest`nFor WinRT projects use the build output folder, e.g. bin\x86\Debug\AppX"
    }

    Write-Host "`nRegistering $manifest ..." -ForegroundColor Cyan
    Add-AppxPackage -Register $manifest
    Write-Host "`nRegistered. Look for the app on the Start screen." -ForegroundColor Green
    Write-Host "Use Uninstall-Appx.ps1 to remove it later."
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Write-Host "Windows 8.1 needs a developer license once per user: Show-WindowsDeveloperLicenseRegistration" -ForegroundColor Yellow
}
Read-Host "Press Enter to close"
