$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $signTool = Join-Path $sdk 'SignTool.exe'
    if (-not (Test-Path -LiteralPath $signTool -PathType Leaf)) { throw "SignTool.exe not found: $signTool" }

    $package = Read-Host "Enter full path to the .appx or .appxbundle to sign"
    if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw "Package not found: $package" }
    $pfx = Read-Host "Enter full path to the signing .pfx certificate"
    if (-not (Test-Path -LiteralPath $pfx -PathType Leaf)) { throw "PFX not found: $pfx" }
    $securePassword = Read-Host "Enter PFX password (leave blank if none)" -AsSecureString
    $args = @('sign', '/fd', 'SHA256', '/f', $pfx)
    if ($securePassword.Length -gt 0) {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        try {
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $args += @('/p', $plainPassword)
            & $signTool @args $package
            $code = $LASTEXITCODE
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            Remove-Variable plainPassword -ErrorAction SilentlyContinue
        }
    } else {
        & $signTool @args $package
        $code = $LASTEXITCODE
    }
    if ($code -ne 0) { throw "SignTool sign failed with exit code $code" }
    Write-Host "`nPackage signed successfully." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
