$ErrorActionPreference = 'Stop'
try {
    $path = (Read-Host "Enter app folder or manifest path").Trim('"')
    if (Test-Path -LiteralPath $path -PathType Container) {
        $manifest = $null
        foreach ($name in 'AppxManifest.xml', 'Package.appxmanifest') {
            $c = Join-Path $path $name
            if (Test-Path -LiteralPath $c -PathType Leaf) { $manifest = $c; break }
        }
        if (-not $manifest) { throw "No manifest found in $path" }
    } elseif (Test-Path -LiteralPath $path -PathType Leaf) { $manifest = $path }
    else { throw "Not found: $path" }

    $text = [IO.File]::ReadAllText($manifest)
    $pattern = '(?s)(<Identity\b[^>]*?\bVersion\s*=\s*")(\d+\.\d+\.\d+\.\d+)(")'
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { throw "Could not find a four-part Version in the Identity element." }

    $current = $m.Groups[2].Value
    $parts = $current.Split('.')
    $bumped = ($parts[0], $parts[1], $parts[2], ([int]$parts[3] + 1)) -join '.'
    Write-Host "Current version: $current"
    $new = Read-Host "New version [$bumped]"
    if ([string]::IsNullOrWhiteSpace($new)) { $new = $bumped }
    $new = $new.Trim()
    if ($new -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw "Version must have four numeric parts, e.g. 1.0.1.0" }

    $updated = [regex]::Replace($text, $pattern, { param($x) $x.Groups[1].Value + $new + $x.Groups[3].Value }, 'Singleline')
    [IO.File]::WriteAllText($manifest, $updated, (New-Object Text.UTF8Encoding($true)))
    Write-Host "`nVersion updated: $current -> $new" -ForegroundColor Green
    Write-Host $manifest
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
