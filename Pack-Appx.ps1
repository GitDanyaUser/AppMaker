$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $makeAppx = Join-Path $sdk 'MakeAppx.exe'
    if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw "MakeAppx.exe not found: $makeAppx" }

    $appFolder = Read-Host "Enter the app source folder (must contain AppxManifest.xml)"
    if (-not (Test-Path -LiteralPath $appFolder -PathType Container)) { throw "Folder not found: $appFolder" }
    $manifest = Join-Path $appFolder 'AppxManifest.xml'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { throw "AppxManifest.xml not found: $manifest" }

    $outputAppx = Read-Host "Enter full output path, e.g. C:\Build\Output\MyApp.appx"
    if ([IO.Path]::GetExtension($outputAppx) -ine '.appx') { throw "Output filename must end in .appx" }
    $outDir = Split-Path -Parent $outputAppx
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    if (Test-Path -LiteralPath $outputAppx) {
        $answer = Read-Host "Output exists. Overwrite? (y/N)"
        if ($answer -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; exit 0 }
    }

    & $makeAppx pack /d $appFolder /p $outputAppx /o
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx pack failed with exit code $LASTEXITCODE" }
    Write-Host "`nPackage created: $outputAppx" -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
