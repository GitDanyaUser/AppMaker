$ErrorActionPreference = 'Stop'
try {
    $folder = Read-Host "Enter folder to clean (only package files in this folder will be considered)"
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw "Folder not found: $folder" }
    $targets = Get-ChildItem -LiteralPath $folder -File | Where-Object {
        $_.Extension -in @('.appx', '.appxbundle', '.msix', '.msixbundle')
    }
    if (-not $targets) { Write-Host 'No package files found.'; exit 0 }
    Write-Host "`nFiles selected for deletion:"
    $targets | ForEach-Object { Write-Host " - $($_.FullName)" }
    $answer = Read-Host "`nDelete these files? Type DELETE to confirm"
    if ($answer -cne 'DELETE') { Write-Host 'Cancelled.'; exit 0 }
    foreach ($item in $targets) {
        Remove-Item -LiteralPath $item.FullName -Force
        Write-Host "Deleted: $($item.Name)"
    }
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
