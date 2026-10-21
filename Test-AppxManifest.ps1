$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Get-Nodes { param($Xml, [string]$Name) return @($Xml.SelectNodes("//*[local-name()='$Name']")) }

$script:problems = 0
function Report { param([string]$Status, [string]$Message)
    $color = switch ($Status) { 'OK' { 'Green' } 'WARN' { 'Yellow' } default { 'Red' } }
    if ($Status -eq 'FAIL') { $script:problems++ }
    Write-Host ("[{0}] {1}" -f $Status.PadRight(4), $Message) -ForegroundColor $color
}

try {
    $path = (Read-Host "Enter app folder (AppxManifest.xml or Package.appxmanifest) or manifest path").Trim('"')
    if (Test-Path -LiteralPath $path -PathType Container) {
        $root = $path
        $manifest = $null
        foreach ($name in 'AppxManifest.xml', 'Package.appxmanifest') {
            $c = Join-Path $path $name
            if (Test-Path -LiteralPath $c -PathType Leaf) { $manifest = $c; break }
        }
        if (-not $manifest) { throw "No manifest found in $path" }
    } elseif (Test-Path -LiteralPath $path -PathType Leaf) {
        $manifest = $path
        $root = Split-Path -Parent $path
    } else { throw "Not found: $path" }

    Write-Host "`nChecking $manifest`n"

    $xml = New-Object Xml.XmlDocument
    try { $xml.Load($manifest); Report 'OK' 'Manifest is well-formed XML' }
    catch { Report 'FAIL' "XML error: $($_.Exception.Message)"; throw "Fix the XML first." }

    $id = @(Get-Nodes $xml 'Identity')[0]
    if (-not $id) { Report 'FAIL' 'Identity element is missing' }
    else {
        $name = $id.GetAttribute('Name'); $ver = $id.GetAttribute('Version'); $pub = $id.GetAttribute('Publisher')
        if ($name -match '^[A-Za-z0-9][A-Za-z0-9.-]{1,48}[A-Za-z0-9]$') { Report 'OK' "Identity Name: $name" }
        else { Report 'FAIL' "Identity Name '$name' must be 3-50 chars of letters, digits, '.' or '-'" }
        if ($ver -match '^\d+\.\d+\.\d+\.\d+$') { Report 'OK' "Version: $ver" } else { Report 'FAIL' "Version '$ver' must be x.x.x.x" }
        if ($pub -match '^\s*CN\s*=') { Report 'OK' "Publisher: $pub" } else { Report 'WARN' "Publisher '$pub' does not start with CN=" }
    }

    $min = (Get-Nodes $xml 'OSMinVersion' | Select-Object -First 1)
    if ($min -and $min.InnerText -eq '6.3.0') { Report 'OK' 'Targets Windows 8.1 (OSMinVersion 6.3.0)' }
    else { Report 'WARN' 'OSMinVersion is not 6.3.0 - this may not be a Windows 8.1 manifest' }

    # Files referenced by the manifest, with expected pixel sizes.
    $sizes = @{
        'Logo' = '50x50'; 'Square150x150Logo' = '150x150'; 'Square30x30Logo' = '30x30'
        'Wide310x150Logo' = '310x150'; 'Square310x310Logo' = '310x310'; 'Square70x70Logo' = '70x70'
        'Image' = '620x300'
    }
    $refs = @()
    foreach ($n in (Get-Nodes $xml 'Logo')) { $refs += @{ Key = 'Logo'; Value = $n.InnerText } }
    foreach ($attr in $xml.SelectNodes("//@*")) {
        if ($sizes.ContainsKey($attr.LocalName) -and $attr.LocalName -ne 'Logo') { $refs += @{ Key = $attr.LocalName; Value = $attr.Value } }
    }
    foreach ($ref in $refs) {
        $rel = $ref.Value -replace '/', '\'
        $file = Join-Path $root $rel
        if (Test-Path -LiteralPath $file -PathType Leaf) {
            try {
                $img = [System.Drawing.Image]::FromFile($file)
                try { $actual = "$($img.Width)x$($img.Height)" } finally { $img.Dispose() }
                if ($actual -eq $sizes[$ref.Key]) { Report 'OK' "$($ref.Key): $rel ($actual)" }
                else { Report 'FAIL' "$($ref.Key): $rel is $actual, expected $($sizes[$ref.Key])" }
            } catch { Report 'FAIL' "$($ref.Key): $rel is not a readable image" }
        } else {
            $dir = Split-Path -Parent $file
            $stem = [IO.Path]::GetFileNameWithoutExtension($file); $ext = [IO.Path]::GetExtension($file)
            $scaled = @()
            if (Test-Path -LiteralPath $dir -PathType Container) { $scaled = @(Get-ChildItem -LiteralPath $dir -Filter "$stem.scale-*$ext" -ErrorAction SilentlyContinue) }
            if ($scaled.Count -gt 0) { Report 'OK' "$($ref.Key): $rel (scale variants found)" }
            else { Report 'FAIL' "$($ref.Key): file missing: $rel" }
        }
    }

    foreach ($app in (Get-Nodes $xml 'Application')) {
        if ($app.HasAttribute('StartPage')) {
            $sp = Join-Path $root ($app.GetAttribute('StartPage') -replace '/', '\')
            if (Test-Path -LiteralPath $sp -PathType Leaf) { Report 'OK' "StartPage: $($app.GetAttribute('StartPage'))" }
            else { Report 'FAIL' "StartPage missing: $($app.GetAttribute('StartPage'))" }
        }
    }

    if ($script:problems -eq 0) { Write-Host "`nNo problems found." -ForegroundColor Green }
    else { Write-Host "`n$script:problems problem(s) found." -ForegroundColor Red }
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "`nPress Enter to close"
