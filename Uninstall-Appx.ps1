$ErrorActionPreference = 'Stop'
try {
    $filter = (Read-Host "Name filter (Enter to list all non-framework apps)").Trim()
    $packages = @(Get-AppxPackage | Where-Object { -not $_.IsFramework } | Sort-Object Name)
    if ($filter) { $packages = @($packages | Where-Object { $_.Name -like "*$filter*" }) }
    if ($packages.Count -eq 0) { throw "No matching packages found." }

    Write-Host ""
    for ($i = 0; $i -lt $packages.Count; $i++) {
        Write-Host ("[{0,3}] {1}  ({2})" -f ($i + 1), $packages[$i].Name, $packages[$i].Version)
    }

    $pick = Read-Host "`nNumber of the app to remove (Enter to cancel)"
    if ([string]::IsNullOrWhiteSpace($pick)) { Write-Host 'Cancelled.'; Read-Host "Press Enter to close"; exit 0 }
    $n = 0
    if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $packages.Count) { throw "Invalid selection: $pick" }

    $target = $packages[$n - 1]
    Write-Host "`nSelected: $($target.PackageFullName)" -ForegroundColor Yellow
    Write-Host "Do not remove Microsoft or system apps unless you know what you are doing." -ForegroundColor Yellow
    $confirm = Read-Host "Remove it for the current user? (y/N)"
    if ($confirm -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; Read-Host "Press Enter to close"; exit 0 }

    Remove-AppxPackage -Package $target.PackageFullName
    Write-Host "`nRemoved." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
