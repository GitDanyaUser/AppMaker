$ErrorActionPreference = 'Stop'
try {
    $filter = (Read-Host "Name filter (part of the package name)").Trim()
    if (-not $filter) { throw "Enter part of the package name." }
    $packages = @(Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.Name -like "*$filter*" } | Sort-Object Name)
    if ($packages.Count -eq 0) { throw "No installed package matches '$filter'." }

    if ($packages.Count -eq 1) { $pkg = $packages[0] }
    else {
        for ($i = 0; $i -lt $packages.Count; $i++) { Write-Host ("[{0,3}] {1}" -f ($i + 1), $packages[$i].Name) }
        $n = 0
        $pick = Read-Host "Number of the app to start"
        if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $packages.Count) { throw "Invalid selection: $pick" }
        $pkg = $packages[$n - 1]
    }

    $manifest = Get-AppxPackageManifest -Package $pkg.PackageFullName
    $apps = @($manifest.Package.Applications.Application)
    if ($apps.Count -eq 0) { throw "The package has no applications." }
    $appId = $apps[0].Id

    Write-Host "`nStarting $($pkg.Name) ($appId) ..." -ForegroundColor Cyan
    Start-Process explorer.exe "shell:AppsFolder\$($pkg.PackageFamilyName)!$appId"
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
