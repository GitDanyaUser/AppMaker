$ErrorActionPreference = 'Stop'
try {
    $package = (Read-Host "Enter full path to the .appx or .appxbundle to install").Trim('"')
    if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw "Package not found: $package" }
    if ([IO.Path]::GetExtension($package) -notin @('.appx', '.appxbundle')) { throw "File must end in .appx or .appxbundle" }

    $depInput = (Read-Host "Dependency package path(s), comma-separated (Enter to skip)").Trim()
    $deps = @()
    if ($depInput) {
        foreach ($d in ($depInput -split ',')) {
            $d = $d.Trim().Trim('"')
            if (-not (Test-Path -LiteralPath $d -PathType Leaf)) { throw "Dependency not found: $d" }
            $deps += $d
        }
    }

    Write-Host "`nInstalling $package ..." -ForegroundColor Cyan
    if ($deps.Count -gt 0) { Add-AppxPackage -Path $package -DependencyPath $deps }
    else { Add-AppxPackage -Path $package }
    Write-Host "`nInstalled. Look for the app on the Start screen." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    if ("$_" -match '0x800B010|untrusted|not trusted|trust') {
        Write-Host "The signing certificate is probably not trusted. Run Install-Certificate.ps1 as Administrator first." -ForegroundColor Yellow
    }
    if ("$_" -match 'license|0x80073CFF|developer') {
        Write-Host "A developer license or sideloading may be required. Try: Show-WindowsDeveloperLicenseRegistration" -ForegroundColor Yellow
    }
}
Read-Host "Press Enter to close"
