try {
    # Default Windows SDK folder
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'

    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) {
        $sdk = $defaultSdk
    }

    # Locate SDK tools
    $makeCert = Join-Path $sdk 'makecert.exe'
    $pvk2pfx = Join-Path $sdk 'pvk2pfx.exe'

    if (-not (Test-Path -LiteralPath $makeCert -PathType Leaf)) {
        throw "MakeCert.exe not found: $makeCert"
    }

    if (-not (Test-Path -LiteralPath $pvk2pfx -PathType Leaf)) {
        throw "Pvk2Pfx.exe not found: $pvk2pfx"
    }

    # Ask for OUTPUT FOLDER, not a filename
    $outDir = Read-Host "Enter output folder (e.g. D:\test)"

    if ([string]::IsNullOrWhiteSpace($outDir)) {
        throw "Output folder cannot be empty."
    }

    $outDir = [System.IO.Path]::GetFullPath($outDir)

    if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outDir -Force |
            Out-Null
    }

    # Certificate details
    $cn = Read-Host "Type CN [MyName]"
    if ([string]::IsNullOrWhiteSpace($cn)) {
        $cn = 'MyName'
    }

    $filename = Read-Host "Type filename [MyCert]"
    if ([string]::IsNullOrWhiteSpace($filename)) {
        $filename = 'MyCert'
    }

    # Validate filename
    if ($filename.IndexOfAny(
        [System.IO.Path]::GetInvalidFileNameChars()
    ) -ge 0) {
        throw "Invalid filename: $filename"
    }

    # Build output paths
    $pvk = Join-Path $outDir "$filename.pvk"
    $cer = Join-Path $outDir "$filename.cer"
    $pfx = Join-Path $outDir "$filename.pfx"

    Write-Host "`nCreating certificate..." -ForegroundColor Cyan

    # Generate self-signed code-signing certificate
    & $makeCert -r -pe -n "CN=$cn" `
        -eku "1.3.6.1.5.5.7.3.3" `
        -sv $pvk `
        $cer

    if ($LASTEXITCODE -ne 0) {
        throw "MakeCert.exe failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path -LiteralPath $pvk -PathType Leaf) -or
        -not (Test-Path -LiteralPath $cer -PathType Leaf)) {
        throw "Certificate generation failed: PVK or CER file is missing."
    }

    # Convert PVK + CER to PFX
    $securePass = Read-Host "Enter the PVK password"
    $pass = $securePass

    Write-Host "`nConverting certificate to PFX..." -ForegroundColor Cyan

    & $pvk2pfx `
        -pvk $pvk `
        -pi $pass `
        -spc $cer `
        -pfx $pfx `
        -po $pass

    if ($LASTEXITCODE -ne 0) {
        throw "Pvk2Pfx.exe failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path -LiteralPath $pfx -PathType Leaf)) {
        throw "PFX file was not created: $pfx"
    }

    Write-Host "`nCertificate created successfully!" -ForegroundColor Green
    Write-Host "Output folder: $outDir"
    Write-Host "PVK: $pvk"
    Write-Host "CER: $cer"
    Write-Host "PFX: $pfx"
}
catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}

Read-Host "`nPress Enter to close"