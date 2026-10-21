$ErrorActionPreference = 'Stop'

function Get-Nodes { param($Xml, [string]$Name) return @($Xml.SelectNodes("//*[local-name()='$Name']")) }

try {
    $path = (Read-Host "Enter a .appx file, an app folder, or a manifest file").Trim('"')
    if (-not (Test-Path -LiteralPath $path)) { throw "Not found: $path" }

    $text = $null
    $item = Get-Item -LiteralPath $path
    if ($item.PSIsContainer) {
        foreach ($name in 'AppxManifest.xml', 'Package.appxmanifest') {
            $candidate = Join-Path $path $name
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $text = [IO.File]::ReadAllText($candidate); break }
        }
        if (-not $text) { throw "No AppxManifest.xml or Package.appxmanifest in $path" }
    } elseif ($item.Extension -ieq '.appx') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($item.FullName)
        try {
            $entry = $zip.Entries | Where-Object { $_.FullName -ieq 'AppxManifest.xml' } | Select-Object -First 1
            if (-not $entry) { throw "AppxManifest.xml not found inside the package." }
            $reader = New-Object IO.StreamReader($entry.Open())
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $zip.Dispose() }
    } else {
        $text = [IO.File]::ReadAllText($item.FullName)
    }

    $xml = New-Object Xml.XmlDocument
    $xml.LoadXml($text.TrimStart([char]0xFEFF))

    $id = @(Get-Nodes $xml 'Identity')[0]
    Write-Host "`n=== Identity ===" -ForegroundColor Cyan
    Write-Host "Name      : $($id.GetAttribute('Name'))"
    Write-Host "Publisher : $($id.GetAttribute('Publisher'))"
    Write-Host "Version   : $($id.GetAttribute('Version'))"

    Write-Host "`n=== Properties ===" -ForegroundColor Cyan
    foreach ($n in 'DisplayName', 'PublisherDisplayName', 'Logo') {
        $node = (Get-Nodes $xml $n | Where-Object { $_.ParentNode.LocalName -eq 'Properties' } | Select-Object -First 1)
        if ($node) { Write-Host ("{0,-21}: {1}" -f $n, $node.InnerText) }
    }

    Write-Host "`n=== Prerequisites ===" -ForegroundColor Cyan
    foreach ($n in 'OSMinVersion', 'OSMaxVersionTested') {
        $node = (Get-Nodes $xml $n | Select-Object -First 1)
        if ($node) { Write-Host ("{0,-19}: {1}" -f $n, $node.InnerText) }
    }

    Write-Host "`n=== Languages ===" -ForegroundColor Cyan
    Get-Nodes $xml 'Resource' | ForEach-Object { Write-Host $_.GetAttribute('Language') }

    Write-Host "`n=== Applications ===" -ForegroundColor Cyan
    foreach ($app in (Get-Nodes $xml 'Application')) {
        Write-Host "Id         : $($app.GetAttribute('Id'))"
        foreach ($a in 'StartPage', 'Executable', 'EntryPoint') {
            if ($app.HasAttribute($a)) { Write-Host ("{0,-11}: {1}" -f $a, $app.GetAttribute($a)) }
        }
        $ve = (Get-Nodes $xml 'VisualElements' | Select-Object -First 1)
        if ($ve) {
            foreach ($a in 'DisplayName', 'Description', 'ForegroundText', 'BackgroundColor') {
                Write-Host ("{0,-15}: {1}" -f $a, $ve.GetAttribute($a))
            }
        }
    }

    Write-Host "`n=== Capabilities ===" -ForegroundColor Cyan
    $caps = @(Get-Nodes $xml 'Capability') + @(Get-Nodes $xml 'DeviceCapability')
    if ($caps.Count -eq 0) { Write-Host "(none)" } else { $caps | ForEach-Object { Write-Host $_.GetAttribute('Name') } }

    $deps = @(Get-Nodes $xml 'PackageDependency')
    if ($deps.Count -gt 0) {
        Write-Host "`n=== Dependencies ===" -ForegroundColor Cyan
        $deps | ForEach-Object { Write-Host "$($_.GetAttribute('Name')) >= $($_.GetAttribute('MinVersion'))" }
    }
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "`nPress Enter to close"
