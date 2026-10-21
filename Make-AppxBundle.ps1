$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $makeAppx = Join-Path $sdk 'MakeAppx.exe'
    if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw "MakeAppx.exe not found: $makeAppx" }

    $folder = Read-Host "Enter folder containing the .appx package(s) to bundle"
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw "Folder not found: $folder" }
    $packages = Get-ChildItem -LiteralPath $folder -File | Where-Object { $_.Extension -ieq '.appx' }
    if (-not $packages) { throw "No .appx files found in $folder" }
    Write-Host "`nPackages found:"
    $packages | ForEach-Object { Write-Host " - $($_.Name)" }

    $output = Read-Host "Enter full output path, e.g. C:\Build\MyApp.appxbundle"
    if ([IO.Path]::GetExtension($output) -ine '.appxbundle') { throw "Output filename must end in .appxbundle" }
    $outDir = Split-Path -Parent $output
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    if (Test-Path -LiteralPath $output) {
        $answer = Read-Host "Output exists. Overwrite? (y/N)"
        if ($answer -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; exit 0 }
    }
    & $makeAppx bundle /d $folder /p $output /o
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx bundle failed with exit code $LASTEXITCODE" }
    Write-Host "`nBundle created: $output" -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
