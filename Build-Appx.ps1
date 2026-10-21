$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $makeAppx = Join-Path $sdk 'MakeAppx.exe'
    if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw "MakeAppx.exe not found: $makeAppx" }

    $appFolder = Read-Host "Enter app source folder (must contain AppxManifest.xml)"
    if (-not (Test-Path -LiteralPath $appFolder -PathType Container)) { throw "Folder not found: $appFolder" }
    if (-not (Test-Path -LiteralPath (Join-Path $appFolder 'AppxManifest.xml') -PathType Leaf)) { throw "AppxManifest.xml is missing from $appFolder" }

    $output = Read-Host "Enter full output .appx path"
    if ([IO.Path]::GetExtension($output) -ine '.appx') { throw "Output filename must end in .appx" }
    $outDir = Split-Path -Parent $output
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $overwrite = $false
    if (Test-Path -LiteralPath $output) {
        $answer = Read-Host "Output exists. Overwrite? (y/N)"
        if ($answer -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; exit 0 }
        $overwrite = $true
    }

    Write-Host "`n[1/3] Packaging..."
    if ($overwrite) { & $makeAppx pack /d $appFolder /p $output /o }
    else { & $makeAppx pack /d $appFolder /p $output }
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx pack failed with exit code $LASTEXITCODE" }
    Write-Host "Package created: $output" -ForegroundColor Green

    $signChoice = Read-Host "`nSign package now? (y/N)"
    if ($signChoice -in @('y','Y','yes','YES')) {
        $signTool = Join-Path $sdk 'SignTool.exe'
        if (-not (Test-Path -LiteralPath $signTool -PathType Leaf)) { throw "SignTool.exe not found: $signTool" }
        $pfx = Read-Host "Enter full path to signing .pfx"
        if (-not (Test-Path -LiteralPath $pfx -PathType Leaf)) { throw "PFX not found: $pfx" }
        $securePassword = Read-Host "Enter PFX password (leave blank if none)" -AsSecureString
        $signArgs = @('sign', '/fd', 'SHA256', '/f', $pfx)
        if ($securePassword.Length -gt 0) {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            try {
                $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                $signArgs += @('/p', $plainPassword)
                & $signTool @signArgs $output
                $signCode = $LASTEXITCODE
            } finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                Remove-Variable plainPassword -ErrorAction SilentlyContinue
            }
        } else {
            & $signTool @signArgs $output
            $signCode = $LASTEXITCODE
        }
        if ($signCode -ne 0) { throw "SignTool sign failed with exit code $signCode" }
        Write-Host 'Package signed.' -ForegroundColor Green

        $verifyChoice = Read-Host "Verify signature now? (Y/n)"
        if ($verifyChoice -notin @('n','N','no','NO')) {
            & $signTool verify /v /pa $output
            if ($LASTEXITCODE -ne 0) { throw "SignTool verify failed with exit code $LASTEXITCODE" }
            Write-Host 'Signature verification passed.' -ForegroundColor Green
        }
    }
    Write-Host "`nWorkflow complete: $output" -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
