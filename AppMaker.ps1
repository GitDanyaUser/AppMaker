$ErrorActionPreference = 'Stop'

$tools = @(
    @{ File = 'New-Project.ps1';           Text = 'Create a new HTML/JS or WinRT (C#/XAML) project' },
    @{ File = 'Test-AppxTools.ps1';        Text = 'Check SDK tools and MSBuild' },
    @{ File = 'Test-AppxManifest.ps1';     Text = 'Check a manifest: identity, version, images, start page' },
    @{ File = 'Get-AppxInfo.ps1';          Text = 'Show details from a manifest or .appx' },
    @{ File = 'Update-AppxVersion.ps1';    Text = 'Change the package version in a manifest' },
    @{ File = 'Pack-Appx.ps1';             Text = 'Pack a folder into an .appx' },
    @{ File = 'Unpack-Appx.ps1';           Text = 'Extract an .appx' },
    @{ File = 'Make-Cert.ps1';             Text = 'Create a self-signed signing certificate' },
    @{ File = 'Sign-Appx.ps1';             Text = 'Sign an .appx with a PFX' },
    @{ File = 'Verify-AppxSignature.ps1';  Text = 'Verify a package signature' },
    @{ File = 'Build-Appx.ps1';            Text = 'Guided pack, sign and verify' },
    @{ File = 'Make-AppxBundle.ps1';       Text = 'Bundle .appx packages' },
    @{ File = 'Install-Certificate.ps1';   Text = 'Trust a certificate (Administrator)' },
    @{ File = 'Install-Appx.ps1';          Text = 'Install an .appx' },
    @{ File = 'Register-Appx.ps1';         Text = 'Register a folder for testing (loose files)' },
    @{ File = 'Start-App.ps1';             Text = 'Start an installed app' },
    @{ File = 'Uninstall-Appx.ps1';        Text = 'Remove an installed app' },
    @{ File = 'Clean-AppxOutput.ps1';      Text = 'Delete package files from an output folder' }
)

while ($true) {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "      WINDOWS 8.1 APPX / APP MAKER TOOLS" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    for ($i = 0; $i -lt $tools.Count; $i++) {
        $exists = Test-Path -LiteralPath (Join-Path $PSScriptRoot $tools[$i].File) -PathType Leaf
        $color = if ($exists) { 'White' } else { 'DarkGray' }
        Write-Host ("[{0,2}] {1,-26} {2}" -f ($i + 1), $tools[$i].File, $tools[$i].Text) -ForegroundColor $color
    }
    Write-Host "[ Q] Quit"

    $pick = Read-Host "`nSelect a tool"
    if ($pick -in @('q', 'Q')) { break }
    $n = 0
    if (-not [int]::TryParse($pick, [ref]$n) -or $n -lt 1 -or $n -gt $tools.Count) { continue }

    $script = Join-Path $PSScriptRoot $tools[$n - 1].File
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
        Write-Host "Script not found: $script" -ForegroundColor Red
        Read-Host "Press Enter to continue"
        continue
    }
    # Each tool runs in its own PowerShell so its own prompts and "exit" do not close this menu.
    & powershell.exe -NoProfile -File $script
}
