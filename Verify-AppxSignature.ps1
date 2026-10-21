$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $signTool = Join-Path $sdk 'SignTool.exe'
    if (-not (Test-Path -LiteralPath $signTool -PathType Leaf)) { throw "SignTool.exe not found: $signTool" }

    $package = Read-Host "Enter full path to the signed .appx or .appxbundle"
    if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw "Package not found: $package" }
    Write-Host "`nVerification mode:"
    Write-Host "1. Default Authenticode policy (/pa)"
    Write-Host "2. Kernel driver policy (/kp)"
    $choice = Read-Host "Choose 1 or 2 [1]"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
    if ($choice -eq '2') { $policy = '/kp' } else { $policy = '/pa' }

    & $signTool verify /v $policy $package
    if ($LASTEXITCODE -ne 0) { throw "SignTool verify failed with exit code $LASTEXITCODE" }
    Write-Host "`nSignature verification passed." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
