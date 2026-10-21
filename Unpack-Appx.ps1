$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $makeAppx = Join-Path $sdk 'MakeAppx.exe'
    if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw "MakeAppx.exe not found: $makeAppx" }

    $package = Read-Host "Enter full path to the .appx package"
    if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw "Package not found: $package" }
    $destination = Read-Host "Enter destination folder"
    if (Test-Path -LiteralPath $destination) {
        $answer = Read-Host "Destination exists. Delete and replace it? (y/N)"
        if ($answer -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; exit 0 }
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    & $makeAppx unpack /p $package /d $destination
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx unpack failed with exit code $LASTEXITCODE" }
    Write-Host "`nUnpacked to: $destination" -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
