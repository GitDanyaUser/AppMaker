$ErrorActionPreference = 'Stop'
$defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
$sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }

Write-Host "`nChecking SDK tools in: $sdk`n"
$missing = @()
foreach ($tool in @('MakeAppx.exe', 'SignTool.exe')) {
    $path = Join-Path $sdk $tool
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Write-Host "[OK]      $path" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $path" -ForegroundColor Red
        $missing += $tool
    }
}
# Optional: MSBuild 12.0 is only needed for the WinRT build.bat.
$msbuild = 'C:\Program Files\MSBuild\12.0\Bin\MSBuild.exe'
if (Test-Path -LiteralPath $msbuild -PathType Leaf) {
    Write-Host "[OK]      $msbuild (optional, WinRT builds)" -ForegroundColor Green
} else {
    Write-Host "[OPTIONAL] $msbuild not found (only needed to build WinRT projects)" -ForegroundColor Yellow
}

if ($missing.Count) {
    Write-Host "`nMissing: $($missing -join ', ')" -ForegroundColor Red
    Write-Host "Check that the Windows 8.1 SDK is installed and the path is correct."
    exit 1
}
Write-Host "`nAll required tools were found." -ForegroundColor Green
Read-Host "Press Enter to close"
