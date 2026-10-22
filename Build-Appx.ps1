$ErrorActionPreference = 'Stop'
try {
    $defaultSdk = 'C:\Program Files\Windows Kits\8.1\bin\x86'
    $sdk = Read-Host "SDK bin folder [$defaultSdk] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($sdk)) { $sdk = $defaultSdk }
    $makeAppx = Join-Path $sdk 'MakeAppx.exe'
    if (-not (Test-Path -LiteralPath $makeAppx -PathType Leaf)) { throw "MakeAppx.exe not found: $makeAppx" }

    $appFolder = Read-Host "Enter app source folder (must contain AppxManifest.xml)"
    if (-not (Test-Path -LiteralPath $appFolder -PathType Container)) { throw "Folder not found: $appFolder" }
    if (-not (Test-Path -LiteralPath (Join-Path $appFolder 'AppxManifest.xml') -PathType Leaf)) { throw "AppxManifest.xml is missing from $appFolder" }

    $output = Read-Host "Enter full output .appx path"
    if ([IO.Path]::GetExtension($output) -ine '.appx') { throw "Output filename must end in .appx" }
    $outDir = Split-Path -Parent $output
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $overwrite = $false
    if (Test-Path -LiteralPath $output) {
        $answer = Read-Host "Output exists. Overwrite? (y/N)"
        if ($answer -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; exit 0 }
        $overwrite = $true
    }

    # --- [1/2] Resources: if there is more than just en-US, generate resources.pri ---
    Write-Host "`n[1/2] Checking resources..."
    $stringsDir = Join-Path $appFolder 'strings'
    $langs = @()
    if (Test-Path -LiteralPath $stringsDir -PathType Container) {
        $langs = @(Get-ChildItem -LiteralPath $stringsDir -Directory |
            Where-Object { $_.Name -match '^[A-Za-z]{2,3}(-[A-Za-z0-9]+)*$' } |
            Where-Object {
                @(Get-ChildItem -LiteralPath $_.FullName -File -Recurse |
                    Where-Object { $_.Extension -in '.resjson', '.resw' }).Count -gt 0
            } |
            ForEach-Object { $_.Name })
        $langs = @($langs | Sort-Object @{ Expression = { if ($_ -ieq 'en-US') { 0 } else { 1 } } }, @{ Expression = { $_ } })
    }

    if ($langs.Count -gt 1) {
        Write-Host ("Languages found: " + ($langs -join ', '))
        $makePri = Join-Path $sdk 'makepri.exe'
        if (-not (Test-Path -LiteralPath $makePri -PathType Leaf)) { throw "makepri.exe not found: $makePri" }

        # Windows only uses languages that the manifest lists, so make sure every language is declared
        try {
            $manifestPath = Join-Path $appFolder 'AppxManifest.xml'
            [xml]$mx = Get-Content -LiteralPath $manifestPath -Raw
            $resNode = $mx.SelectSingleNode("//*[local-name()='Resources']")
            if ($resNode) {
                $declared = @($resNode.ChildNodes | Where-Object { $_.NodeType -eq 'Element' } | ForEach-Object { $_.GetAttribute('Language') })
                $missing = @($langs | Where-Object { $l = $_; -not ($declared | Where-Object { $_ -ieq $l }) })
                if ($missing.Count -gt 0) {
                    Write-Host ("Manifest <Resources> does not list: " + ($missing -join ', ') + " - the app would stay in English.") -ForegroundColor Yellow
                    $ans = Read-Host "Add them to AppxManifest.xml now? (Y/n)"
                    if ($ans -notin @('n','N','no','NO')) {
                        foreach ($l in $missing) {
                            $n = $mx.CreateElement('Resource', $resNode.NamespaceURI)
                            $n.SetAttribute('Language', $l)
                            [void]$resNode.AppendChild($n)
                        }
                        foreach ($c in @($resNode.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.GetAttribute('Language') -ieq 'x-generate' })) {
                            [void]$resNode.RemoveChild($c)
                        }
                        $mx.Save($manifestPath)
                        Write-Host 'Manifest updated.' -ForegroundColor Green
                    }
                }
            } else {
                Write-Host 'WARNING: no <Resources> block found in AppxManifest.xml' -ForegroundColor Yellow
            }
        } catch { Write-Host "Could not check manifest languages: $_" -ForegroundColor Yellow }

        $priFile = Join-Path $appFolder 'resources.pri'
        # remove old resources*.pri (incl. leftovers like resources-ru.pri) so they are not re-indexed into the new one
        Get-ChildItem -LiteralPath $appFolder -Filter 'resources*.pri' -File | ForEach-Object {
            Write-Host "Removing old $($_.Name)"
            Remove-Item -LiteralPath $_.FullName -Force
        }
        $priConfig = Join-Path ([IO.Path]::GetTempPath()) ('priconfig_' + [guid]::NewGuid().ToString('N') + '.xml')
        try {
            # default qualifier = default language only; the other languages are picked up from the strings\<lang> folder names
            & $makePri createconfig /cf $priConfig /dq $langs[0] /o
            if ($LASTEXITCODE -ne 0) { throw "makepri createconfig failed with exit code $LASTEXITCODE" }

            # The default config contains a <packaging> section that SPLITS languages into separate
            # resources.language-xx.pri files. The app only loads resources.pri, so remove that
            # section to keep every language inside the single resources.pri.
            [xml]$cfg = Get-Content -LiteralPath $priConfig -Raw
            foreach ($pn in @($cfg.SelectNodes("//*[local-name()='packaging']"))) { [void]$pn.ParentNode.RemoveChild($pn) }
            $cfg.Save($priConfig)

            $manifestPath = Join-Path $appFolder 'AppxManifest.xml'
            & $makePri new /pr $appFolder /cf $priConfig /of $priFile /mn $manifestPath /o
            if ($LASTEXITCODE -ne 0) {
                # some MakePri versions want the package name instead of the manifest path
                Write-Host 'Retrying makepri with /in (package identity name)...' -ForegroundColor Yellow
                [xml]$mx = Get-Content -LiteralPath $manifestPath -Raw
                $idName = $mx.SelectSingleNode("//*[local-name()='Identity']").GetAttribute('Name')
                if ([string]::IsNullOrWhiteSpace($idName)) { throw "Could not read Identity Name from AppxManifest.xml" }
                & $makePri new /pr $appFolder /cf $priConfig /of $priFile /in $idName /o
                if ($LASTEXITCODE -ne 0) { throw "makepri new failed with exit code $LASTEXITCODE" }
            }
        } finally {
            if (Test-Path -LiteralPath $priConfig) { Remove-Item -LiteralPath $priConfig -Force }
        }
        # safety net: split files (resources.language-xx.pri etc.) are not read from inside the same package
        $extra = @(Get-ChildItem -LiteralPath $appFolder -Filter 'resources*.pri' -File | Where-Object { $_.Name -ine 'resources.pri' })
        if ($extra.Count -gt 0) {
            Write-Host ("Removing split resource files: " + (($extra | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Yellow
            $extra | Remove-Item -Force
        }
        Write-Host "resources.pri generated: $priFile" -ForegroundColor Green

        # check that every language really ended up inside resources.pri
        $dumpFile = Join-Path ([IO.Path]::GetTempPath()) ('pridump_' + [guid]::NewGuid().ToString('N') + '.xml')
        try {
            & $makePri dump /if $priFile /of $dumpFile /o | Out-Null
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dumpFile)) {
                $dumpText = Get-Content -LiteralPath $dumpFile -Raw
                foreach ($l in $langs) {
                    if ($dumpText -match [regex]::Escape($l)) { Write-Host "  [ok] $l is in resources.pri" -ForegroundColor Green }
                    else { Write-Host "  [!!] $l NOT found in resources.pri" -ForegroundColor Yellow }
                }
            }
        } catch { } finally {
            if (Test-Path -LiteralPath $dumpFile) { Remove-Item -LiteralPath $dumpFile -Force }
        }
    } else {
        $only = if ($langs.Count -eq 1) { $langs[0] } else { 'none' }
        Write-Host "Only one language ($only) - resources.pri not needed, skipping."
    }

    Write-Host "`n[2/2] Packaging..."
    if ($overwrite) { & $makeAppx pack /d $appFolder /p $output /o }
    else { & $makeAppx pack /d $appFolder /p $output }
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx pack failed with exit code $LASTEXITCODE" }
    Write-Host "Package created: $output" -ForegroundColor Green

    $signChoice = Read-Host "`nSign package now? (y/N)"
    if ($signChoice -in @('y','Y','yes','YES')) {
        $signTool = Join-Path $sdk 'SignTool.exe'
        if (-not (Test-Path -LiteralPath $signTool -PathType Leaf)) { throw "SignTool.exe not found: $signTool" }
        $pfx = Read-Host "Enter full path to signing .pfx"
        if (-not (Test-Path -LiteralPath $pfx -PathType Leaf)) { throw "PFX not found: $pfx" }
        $securePassword = Read-Host "Enter PFX password (leave blank if none)" -AsSecureString
        $signArgs = @('sign', '/fd', 'SHA256', '/f', $pfx)
        if ($securePassword.Length -gt 0) {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            try {
                $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                $signArgs += @('/p', $plainPassword)
                & $signTool @signArgs $output
                $signCode = $LASTEXITCODE
            } finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
                Remove-Variable plainPassword -ErrorAction SilentlyContinue
            }
        } else {
            & $signTool @signArgs $output
            $signCode = $LASTEXITCODE
        }
        if ($signCode -ne 0) { throw "SignTool sign failed with exit code $signCode" }
        Write-Host 'Package signed.' -ForegroundColor Green

        $verifyChoice = Read-Host "Verify signature now? (Y/n)"
        if ($verifyChoice -notin @('n','N','no','NO')) {
            & $signTool verify /v /pa $output
            if ($LASTEXITCODE -ne 0) { throw "SignTool verify failed with exit code $LASTEXITCODE" }
            Write-Host 'Signature verification passed.' -ForegroundColor Green
        }
    }
    Write-Host "`nWorkflow complete: $output" -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"
