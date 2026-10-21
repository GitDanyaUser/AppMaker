#requires -Version 4.0
# New-Project.ps1
# Windows 8.1 app project generator
#   1) HTML/JS  - WinJS 2.0 Store app (loose files + AppxManifest.xml)
#   2) WinRT    - C# / XAML Store app (.csproj + build.bat for MSBuild 12.0)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Read-RequiredValue {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )

    while ($true) {
        if ([string]::IsNullOrWhiteSpace($Default)) {
            $value = Read-Host $Prompt
        }
        else {
            $value = Read-Host "$Prompt [$Default]"
            if ([string]::IsNullOrWhiteSpace($value)) {
                $value = $Default
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }

        Write-Host "This field is required." -ForegroundColor Yellow
    }
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Options,
        [int]$DefaultIndex = 1
    )

    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host ("  [{0}] {1}" -f ($i + 1), $Options[$i])
    }

    while ($true) {
        $value = Read-Host "$Prompt [$DefaultIndex]"

        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultIndex
        }

        $number = 0
        if ([int]::TryParse($value.Trim(), [ref]$number) -and
            $number -ge 1 -and $number -le $Options.Count) {
            return $number
        }

        Write-Host "Enter a number from 1 to $($Options.Count)." `
            -ForegroundColor Yellow
    }
}

function Escape-Xml {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function Escape-Html {
    param([string]$Value)
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Escape-CSharp {
    param([string]$Value)
    return ($Value -replace '\\', '\\' -replace '"', '\"')
}

function ConvertTo-XamlText {
    param([string]$Value)

    $text = Escape-Xml $Value

    # A leading "{" would be read as a XAML markup extension.
    if ($text.StartsWith("{")) {
        $text = "{}" + $text
    }

    return $text
}

function ConvertTo-BatchSafeText {
    param([string]$Value)

    # Remove characters that have special meaning in a .bat file.
    $text = $Value -replace '[%^&|<>"!]', ''

    if ([string]::IsNullOrWhiteSpace($text)) {
        $text = "App"
    }

    return $text.Trim()
}

function ConvertTo-ValidIdentifier {
    param([string]$Value)

    # Package identity names allow letters, digits, "." and "-" only,
    # must be 3-50 characters and must not end with ".".
    $result = $Value -replace '[^A-Za-z0-9.-]', '.'
    $result = $result.Trim('.')

    if ($result.Length -gt 50) {
        $result = $result.Substring(0, 50).Trim('.')
    }

    if ([string]::IsNullOrWhiteSpace($result)) {
        $result = "GeneratedApp"
    }

    if ($result.Length -lt 3) {
        $result = "$result.App"
    }

    return $result
}

function ConvertTo-CSharpIdentifier {
    param([string]$Value)

    $result = $Value -replace '[^A-Za-z0-9_]', '_'

    if ([string]::IsNullOrWhiteSpace($result)) {
        $result = "GeneratedApp"
    }

    if ($result -match '^[0-9]') {
        $result = "_$result"
    }

    return $result
}

function Expand-Template {
    param(
        [string]$Template,
        [hashtable]$Values
    )

    $result = $Template

    foreach ($key in $Values.Keys) {
        $result = $result.Replace($key, [string]$Values[$key])
    }

    return $result
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Content,
        [bool]$Bom = $true
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and
        -not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    # Always write Windows line endings.
    $text = $Content -replace "`r?`n", "`r`n"
    $encoding = New-Object System.Text.UTF8Encoding($Bom)

    [System.IO.File]::WriteAllText($Path, $text, $encoding)
}

function New-ProjectImage {
    param(
        [string]$Path,
        [int]$Width,
        [int]$Height,
        [string]$Text,
        [float]$FontSize,
        [string]$BackgroundColor,
        [string]$TextColor = "#FFFFFF"
    )

    $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.Clear(
            [System.Drawing.ColorTranslator]::FromHtml($BackgroundColor)
        )
        $graphics.SmoothingMode =
            [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.TextRenderingHint =
            [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        if (-not [string]::IsNullOrWhiteSpace($Text)) {
            # Scale text down when necessary so longer entered names fit.
            $maxFontSize = [Math]::Min(
                [float]$FontSize,
                [float]($Height * 0.62)
            )
            $font = New-Object System.Drawing.Font(
                "Segoe UI",
                [float][Math]::Max(6, $maxFontSize),
                [System.Drawing.FontStyle]::Regular,
                [System.Drawing.GraphicsUnit]::Pixel
            )
            $brush = New-Object System.Drawing.SolidBrush(
                [System.Drawing.ColorTranslator]::FromHtml($TextColor)
            )
            $format = New-Object System.Drawing.StringFormat
            $format.Alignment = [System.Drawing.StringAlignment]::Center
            $format.LineAlignment = [System.Drawing.StringAlignment]::Center
            $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

            try {
                $rect = New-Object System.Drawing.RectangleF(
                    [float]($Width * 0.04),
                    [float]($Height * 0.04),
                    [float]($Width * 0.92),
                    [float]($Height * 0.92)
                )
                $graphics.DrawString($Text, $font, $brush, $rect, $format)
            }
            finally {
                $font.Dispose()
                $brush.Dispose()
                $format.Dispose()
            }
        }

        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "Created $(Split-Path $Path -Leaf) ($Width x $Height)" `
            -ForegroundColor Green
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

# ============================================================
# QUESTIONNAIRE
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       WINDOWS 8.1 PROJECT GENERATOR" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Project type:"
$typeChoice = Read-Choice "Select project type" @(
    "HTML/JS  - Windows Store app using WinJS 2.0",
    "WinRT    - Windows Store app in C# / XAML (adds build.bat for MSBuild 12.0)"
) 1
$isWinRT = ($typeChoice -eq 2)
$typeLabel = if ($isWinRT) { "WinRT (C# / XAML)" } else { "HTML/JS (WinJS)" }

Write-Host ""
$projectName = Read-RequiredValue "Project name" "MyProject"
$fullName = Read-RequiredValue "Full name" "My Windows App"
$shortName = Read-RequiredValue "Short name" "My App"
$description = Read-RequiredValue "Description" "A Windows 8.1 application"
$certificateInput = Read-RequiredValue "Certificate name (CN=)" "MyCompany"
$versionInput = Read-RequiredValue "Version (x.x.x.x)" "1.0.0.0"
$parentPathInput = Read-RequiredValue "Path" (Get-Location).Path
$backgroundColor = Read-RequiredValue "Color (e.g. #0078D7)" "#0078D7"

Write-Host ""
Write-Host "App theme:"
$themeChoice = Read-Choice "Select app theme" @("Dark", "Light") 1
$isDarkTheme = ($themeChoice -eq 1)

$capabilityCatalog = @(
    @{ Name = "internetClient";            Device = $false; Label = "Internet (client)" },
    @{ Name = "internetClientServer";      Device = $false; Label = "Internet (client and server)" },
    @{ Name = "privateNetworkClientServer"; Device = $false; Label = "Home / work networks" },
    @{ Name = "picturesLibrary";           Device = $false; Label = "Pictures library" },
    @{ Name = "musicLibrary";              Device = $false; Label = "Music library" },
    @{ Name = "videosLibrary";             Device = $false; Label = "Videos library" },
    @{ Name = "location";                  Device = $true;  Label = "Location" },
    @{ Name = "microphone";                Device = $true;  Label = "Microphone" },
    @{ Name = "webcam";                    Device = $true;  Label = "Webcam" }
)

Write-Host ""
Write-Host "Capabilities:"
for ($i = 0; $i -lt $capabilityCatalog.Count; $i++) {
    Write-Host ("  [{0}] {1}" -f ($i + 1), $capabilityCatalog[$i].Label)
}
$capabilityInput = Read-Host "Select capabilities (comma-separated, 0 = none) [1]"

# ============================================================
# VALIDATION AND NORMALIZATION
# ============================================================

if ($projectName -match '[<>:"/\\|?*]') {
    Write-Host "Project name contains invalid folder-name characters." `
        -ForegroundColor Red
    return
}

if ($versionInput -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    Write-Host "Version must have four numeric parts, e.g. 1.0.0.0." `
        -ForegroundColor Red
    return
}
$version = $versionInput

try {
    $parentPath = [System.IO.Path]::GetFullPath(
        [Environment]::ExpandEnvironmentVariables($parentPathInput)
    )
}
catch {
    Write-Host "The supplied path is invalid." -ForegroundColor Red
    return
}

try {
    $parsedColor =
        [System.Drawing.ColorTranslator]::FromHtml($backgroundColor)

    if ($parsedColor.IsEmpty) {
        throw "Invalid color"
    }

    # Always store #RRGGBB (ToHtml can return names such as "Blue").
    $backgroundColor = '#{0:X2}{1:X2}{2:X2}' -f `
        $parsedColor.R, $parsedColor.G, $parsedColor.B
}
catch {
    Write-Host "Invalid color. Use a value such as #0078D7." `
        -ForegroundColor Red
    return
}

# Pick light or dark text for tiles/images from the background brightness.
$luminance = (0.299 * $parsedColor.R) +
    (0.587 * $parsedColor.G) +
    (0.114 * $parsedColor.B)

if ($luminance -gt 170) {
    $foregroundText = "dark"
    $imageTextColor = "#1A1A1A"
}
else {
    $foregroundText = "light"
    $imageTextColor = "#FFFFFF"
}

# Capabilities.
$selectedCapabilities = @()

if ([string]::IsNullOrWhiteSpace($capabilityInput)) {
    $capabilityInput = "1"
}

if ($capabilityInput.Trim() -ne "0") {
    foreach ($token in ($capabilityInput -split '[,\s]+')) {
        if ($token -eq "") { continue }

        $number = 0
        if (-not [int]::TryParse($token, [ref]$number) -or
            $number -lt 1 -or
            $number -gt $capabilityCatalog.Count) {
            Write-Host "Invalid capability selection: $token" `
                -ForegroundColor Red
            return
        }

        $capability = $capabilityCatalog[$number - 1]
        if ($selectedCapabilities -notcontains $capability) {
            $selectedCapabilities += $capability
        }
    }
}

# Accept either MyCompany or CN=MyCompany.
$certificateName = $certificateInput.Trim()

if ($certificateName -match '^\s*CN\s*=') {
    $publisher = $certificateName
    $publisherDisplayName = $certificateName -replace '^\s*CN\s*=\s*', ''
}
else {
    $publisher = "CN=$certificateName"
    $publisherDisplayName = $certificateName
}

$publisherDisplayName = $publisherDisplayName.Trim()

# Use a valid package identity derived from the project name.
$identityName = ConvertTo-ValidIdentifier $projectName
$csName = ConvertTo-CSharpIdentifier $projectName

$language = "en-US"
$assetsFolder = if ($isWinRT) { "Assets" } else { "images" }

# ============================================================
# CREATE PROJECT DIRECTORY
# ============================================================

$projectPath = Join-Path $parentPath $projectName

try {
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {
        New-Item -ItemType Directory -Path $parentPath -Force |
            Out-Null
    }

    if (Test-Path -LiteralPath $projectPath) {
        if (-not (Test-Path -LiteralPath $projectPath -PathType Container)) {
            throw "The project path exists but is not a directory."
        }

        $existingItems = @(
            Get-ChildItem -LiteralPath $projectPath -Force
        )

        if ($existingItems.Count -gt 0) {
            Write-Host ""
            Write-Host "The project folder already exists and is not empty:" `
                -ForegroundColor Yellow
            Write-Host $projectPath

            $confirm = Read-Host "Continue and overwrite generated files? (Y/N)"

            if ($confirm -notmatch '^(Y|YES)$') {
                Write-Host "Cancelled."
                return
            }
        }
    }
    else {
        New-Item -ItemType Directory -Path $projectPath -Force |
            Out-Null
    }
}
catch {
    Write-Host "Could not create project folder: $($_.Exception.Message)" `
        -ForegroundColor Red
    return
}

# ============================================================
# TEMPLATE VALUES
# ============================================================

$assetsPath = Join-Path $projectPath $assetsFolder
New-Item -ItemType Directory -Path $assetsPath -Force | Out-Null

$values = @{
    "@@IDENTITY@@"          = $identityName
    "@@PUBLISHER_XML@@"     = (Escape-Xml $publisher)
    "@@PUBLISHERNAME_XML@@" = (Escape-Xml $publisherDisplayName)
    "@@PUBLISHERNAME_CS@@"  = (Escape-CSharp $publisherDisplayName)
    "@@VERSION@@"           = $version
    "@@FULLNAME_XML@@"      = (Escape-Xml $fullName)
    "@@FULLNAME_HTML@@"     = (Escape-Html $fullName)
    "@@FULLNAME_XAML@@"     = (ConvertTo-XamlText $fullName)
    "@@FULLNAME_CS@@"       = (Escape-CSharp $fullName)
    "@@FULLNAME_BAT@@"      = (ConvertTo-BatchSafeText $fullName)
    "@@SHORTNAME_XML@@"     = (Escape-Xml $shortName)
    "@@DESCRIPTION_XML@@"   = (Escape-Xml $description)
    "@@DESCRIPTION_HTML@@"  = (Escape-Html $description)
    "@@DESCRIPTION_XAML@@"  = (ConvertTo-XamlText $description)
    "@@DESCRIPTION_CS@@"    = (Escape-CSharp $description)
    "@@LANG@@"              = $language
    "@@BG@@"                = $backgroundColor
    "@@FG@@"                = $foregroundText
    "@@ASSETS@@"            = $assetsFolder
    "@@NAMESPACE@@"         = $csName
    "@@CSNAME@@"            = $csName
    "@@PROJECTFILE@@"       = "$projectName.csproj"
    "@@PROJECTGUID@@"       = ([guid]::NewGuid().ToString("B").ToUpper())
    "@@WINJS_THEME@@"       = $(if ($isDarkTheme) { "ui-dark" } else { "ui-light" })
    "@@XAML_THEME@@"        = $(if ($isDarkTheme) { "Dark" } else { "Light" })
}

# Capabilities block for the manifest.
$capabilityLines = @()
if ($selectedCapabilities.Count -gt 0) {
    $capabilityLines += "  <Capabilities>"

    foreach ($capability in ($selectedCapabilities |
            Where-Object { -not $_.Device })) {
        $capabilityLines += "    <Capability Name=`"$($capability.Name)`" />"
    }

    foreach ($capability in ($selectedCapabilities |
            Where-Object { $_.Device })) {
        $capabilityLines +=
            "    <DeviceCapability Name=`"$($capability.Name)`" />"
    }

    $capabilityLines += "  </Capabilities>"
}
$values["@@CAPABILITIES@@"] = ($capabilityLines -join "`r`n")

# Type-specific manifest pieces.
if ($isWinRT) {
    $values["@@RESOURCELANG@@"] = "x-generate"
    $values["@@APPATTRS@@"] =
        "Executable=`"`$targetnametoken`$.exe`" EntryPoint=`"$csName.App`""
    $values["@@DEPENDENCIES@@"] = ""
}
else {
    $values["@@RESOURCELANG@@"] = $language
    $values["@@APPATTRS@@"] = "StartPage=`"default.html`""
    $values["@@DEPENDENCIES@@"] = @(
        "  <Dependencies>",
        "    <PackageDependency Name=`"Microsoft.WinJS.2.0`" MinVersion=`"1.0.9600.16384`" />",
        "  </Dependencies>"
    ) -join "`r`n"
}

# ============================================================
# GENERATE MANIFEST (Windows 8.1 / 2013 schema)
# ============================================================

$manifestTemplate = @'
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/2010/manifest"
  xmlns:m2="http://schemas.microsoft.com/appx/2013/manifest">

  <Identity
    Name="@@IDENTITY@@"
    Publisher="@@PUBLISHER_XML@@"
    Version="@@VERSION@@" />

  <Properties>
    <DisplayName>@@FULLNAME_XML@@</DisplayName>
    <PublisherDisplayName>@@PUBLISHERNAME_XML@@</PublisherDisplayName>
    <Logo>@@ASSETS@@\StoreLogo.png</Logo>
  </Properties>

  <Prerequisites>
    <OSMinVersion>6.3.0</OSMinVersion>
    <OSMaxVersionTested>6.3.0</OSMaxVersionTested>
  </Prerequisites>

  <Resources>
    <Resource Language="@@RESOURCELANG@@" />
  </Resources>

  <Applications>
    <Application Id="App" @@APPATTRS@@>

      <m2:VisualElements
        DisplayName="@@FULLNAME_XML@@"
        Description="@@DESCRIPTION_XML@@"
        ForegroundText="@@FG@@"
        BackgroundColor="@@BG@@"
        Square150x150Logo="@@ASSETS@@\Square150x150Logo.png"
        Square30x30Logo="@@ASSETS@@\Square30x30Logo.png">

        <m2:DefaultTile
          ShortName="@@SHORTNAME_XML@@"
          Wide310x150Logo="@@ASSETS@@\Wide310x150Logo.png"
          Square310x310Logo="@@ASSETS@@\Square310x310Logo.png"
          Square70x70Logo="@@ASSETS@@\Square70x70Logo.png" />

        <m2:SplashScreen Image="@@ASSETS@@\SplashScreen.png" />

      </m2:VisualElements>
    </Application>
  </Applications>

@@CAPABILITIES@@
@@DEPENDENCIES@@
</Package>
'@

$manifestName = if ($isWinRT) { "Package.appxmanifest" } else { "AppxManifest.xml" }

Write-TextFile `
    -Path (Join-Path $projectPath $manifestName) `
    -Content (Expand-Template $manifestTemplate $values)

# ============================================================
# GENERATE BRANDING IMAGES
# ============================================================

# Entered Full name is used for banners and splash screens.
# Entered Short name is used for square icons and tiles.
# Tiny logos use a shortened label to keep the text legible.

$iconLabel = $shortName
if ($iconLabel.Length -gt 4) {
    $iconLabel = $iconLabel.Substring(0, 4)
}

$imageDefinitions = @(
    @{ Name = "Banner.png";             Width = 1240; Height = 600; Label = $fullName;  FontSize = 152 },
    @{ Name = "AppIcon.png";            Width = 512;  Height = 512; Label = $shortName; FontSize = 190 },
    @{ Name = "SplashScreen.png";       Width = 620;  Height = 300; Label = $fullName;  FontSize = 76 },
    @{ Name = "Square150x150Logo.png";  Width = 150;  Height = 150; Label = $shortName; FontSize = 56 },
    @{ Name = "Square30x30Logo.png";    Width = 30;   Height = 30;  Label = $iconLabel; FontSize = 12 },
    @{ Name = "Square310x310Logo.png";  Width = 310;  Height = 310; Label = $shortName; FontSize = 112 },
    @{ Name = "Square70x70Logo.png";    Width = 70;   Height = 70;  Label = $iconLabel; FontSize = 27 },
    @{ Name = "StoreLogo.png";          Width = 50;   Height = 50;  Label = $iconLabel; FontSize = 20 },
    @{ Name = "Wide310x150Logo.png";    Width = 310;  Height = 150; Label = $shortName; FontSize = 52 }
)

foreach ($image in $imageDefinitions) {
    New-ProjectImage `
        -Path (Join-Path $assetsPath $image.Name) `
        -Width $image.Width `
        -Height $image.Height `
        -Text $image.Label `
        -FontSize $image.FontSize `
        -BackgroundColor $backgroundColor `
        -TextColor $imageTextColor
}

# ============================================================
# COMMON FILES
# ============================================================

$gitIgnore = @'
bin/
obj/
AppPackages/
*.log
*.pfx
*.pvk
*.user
*.suo
.vs/
'@

Write-TextFile `
    -Path (Join-Path $projectPath ".gitignore") `
    -Content $gitIgnore `
    -Bom $false

# ============================================================
# HTML/JS PROJECT
# ============================================================

if (-not $isWinRT) {

$htmlTemplate = @'
<!DOCTYPE html>
<html lang="@@LANG@@">
<head>
    <meta charset="utf-8" />
    <meta name="description" content="@@DESCRIPTION_HTML@@" />
    <title>@@FULLNAME_HTML@@</title>

    <!-- WinJS 2.0 references (Windows 8.1) -->
    <link href="//Microsoft.WinJS.2.0/css/@@WINJS_THEME@@.css" rel="stylesheet" />
    <script src="//Microsoft.WinJS.2.0/js/base.js"></script>
    <script src="//Microsoft.WinJS.2.0/js/ui.js"></script>

    <!-- App references -->
    <link href="/css/default.css" rel="stylesheet" />
    <script src="/js/default.js"></script>
</head>
<body class="win-type-body">
    <header class="app-header">
        <h1 class="win-type-xx-large">@@FULLNAME_HTML@@</h1>
        <p class="win-type-medium">@@DESCRIPTION_HTML@@</p>
    </header>

    <main class="app-content">
        <button id="helloButton" class="win-button" type="button">Test JavaScript</button>
        <p id="message" class="win-type-large" aria-live="polite"></p>
    </main>
</body>
</html>
'@

$jsTemplate = @'
// For an introduction to the Blank template, see the following documentation:
// http://go.microsoft.com/fwlink/?LinkId=232509
(function () {
    "use strict";

    var app = WinJS.Application;
    var activation = Windows.ApplicationModel.Activation;
    var clicks = 0;

    function showMessage() {
        var message = document.getElementById("message");

        if (message) {
            message.textContent = clicks === 0
                ? ""
                : "JavaScript is working! Clicks: " + clicks;
        }
    }

    function wireUi() {
        var button = document.getElementById("helloButton");

        if (button) {
            button.addEventListener("click", function () {
                clicks++;
                showMessage();
            });
        }

        showMessage();
    }

    app.onactivated = function (args) {
        if (args.detail.kind === activation.ActivationKind.launch) {
            if (args.detail.previousExecutionState !==
                activation.ApplicationExecutionState.terminated) {
                // New launch: initialize the app here.
            } else {
                // The app was terminated while suspended: restore state.
                clicks = app.sessionState.clicks || 0;
            }

            args.setPromise(WinJS.UI.processAll().then(wireUi));
        }
    };

    app.oncheckpoint = function (args) {
        // The app is about to be suspended. Save state that must survive
        // termination here; use args.setPromise() for async work.
        app.sessionState.clicks = clicks;
    };

    app.start();
}());
'@

$cssTemplate = @'
/* Layout follows the Windows 8.1 guidelines: 120px left margin,
   content under a 140px title area. */

.app-header {
    padding: 40px 60px 24px 120px;
    background-color: @@BG@@;
    color: @@FG@@;
}

.app-header h1 {
    margin: 0 0 8px 0;
    font-weight: 300;
}

.app-header p {
    margin: 0;
}

.app-content {
    padding: 40px 60px 40px 120px;
}

#message {
    margin-top: 20px;
}

/* Narrow window (minimum width in Windows 8.1 is 500px). */
@media screen and (max-width: 660px) {
    .app-header {
        padding: 24px 24px 16px 24px;
    }

    .app-content {
        padding: 24px;
    }
}
'@

$registerBat = @'
@echo off
setlocal
cd /d "%~dp0"
title Register @@FULLNAME_BAT@@

rem Registers this folder as a loose-file app for testing.
rem Windows 8.1 needs a developer license once per user. If registration
rem fails, run:  powershell Show-WindowsDeveloperLicenseRegistration

echo Registering %~dp0AppxManifest.xml ...
powershell -NoProfile -Command "Add-AppxPackage -Register '%~dp0AppxManifest.xml'"

if errorlevel 1 (
    echo.
    echo Registration failed.
) else (
    echo.
    echo Registered. Find "@@FULLNAME_BAT@@" on the Start screen.
)

echo.
pause
'@

$unregisterBat = @'
@echo off
setlocal
title Unregister @@FULLNAME_BAT@@

echo Removing package @@IDENTITY@@ ...
powershell -NoProfile -Command "Get-AppxPackage -Name '@@IDENTITY@@' | Remove-AppxPackage"

echo.
pause
'@

$readmeTemplate = @'
# @@FULLNAME_XML@@

Windows 8.1 Store app (HTML/JS, WinJS 2.0).

## Structure

- `AppxManifest.xml`  package manifest (Windows 8.1 / 2013 schema)
- `default.html`      start page
- `js\default.js`     activation, suspend/resume and app code
- `css\default.css`   styles
- `images\`           generated tile, logo and splash images
- `register.bat`      registers this folder for testing (Add-AppxPackage -Register)
- `unregister.bat`    removes the registered test app

## Run it

Run `register.bat`, then start the app from the Start screen.

## Package it

Use the scripts in the AppMaker folder:
`Test-AppxManifest.ps1`, then `Build-Appx.ps1` (pack, sign, verify).
The signing certificate must match the manifest publisher: @@PUBLISHER_XML@@
'@

Write-TextFile (Join-Path $projectPath "default.html") (Expand-Template $htmlTemplate $values)
Write-TextFile (Join-Path $projectPath "js\default.js") (Expand-Template $jsTemplate $values)
Write-TextFile (Join-Path $projectPath "css\default.css") (Expand-Template $cssTemplate $values)
Write-TextFile (Join-Path $projectPath "register.bat") (Expand-Template $registerBat $values) -Bom $false
Write-TextFile (Join-Path $projectPath "unregister.bat") (Expand-Template $unregisterBat $values) -Bom $false
Write-TextFile (Join-Path $projectPath "README.md") (Expand-Template $readmeTemplate $values)

}

# ============================================================
# WINRT PROJECT (C# / XAML)
# ============================================================

if ($isWinRT) {

$appXaml = @'
<Application
    x:Class="@@NAMESPACE@@.App"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:local="using:@@NAMESPACE@@"
    RequestedTheme="@@XAML_THEME@@">

</Application>
'@

$appCs = @'
using System;
using Windows.ApplicationModel;
using Windows.ApplicationModel.Activation;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;

namespace @@NAMESPACE@@
{
    /// <summary>
    /// Provides application-specific behavior to supplement the default
    /// Application class.
    /// </summary>
    sealed partial class App : Application
    {
        public App()
        {
            this.InitializeComponent();
            this.Suspending += OnSuspending;
        }

        /// <summary>
        /// Invoked when the application is launched normally by the end user.
        /// </summary>
        protected override void OnLaunched(LaunchActivatedEventArgs e)
        {
#if DEBUG
            if (System.Diagnostics.Debugger.IsAttached)
            {
                this.DebugSettings.EnableFrameRateCounter = true;
            }
#endif

            Frame rootFrame = Window.Current.Content as Frame;

            if (rootFrame == null)
            {
                rootFrame = new Frame();

                if (e.PreviousExecutionState == ApplicationExecutionState.Terminated)
                {
                    // TODO: Restore the saved session state here.
                }

                Window.Current.Content = rootFrame;
            }

            if (rootFrame.Content == null)
            {
                if (!rootFrame.Navigate(typeof(MainPage), e.Arguments))
                {
                    throw new Exception("Failed to create initial page");
                }
            }

            Window.Current.Activate();
        }

        /// <summary>
        /// Invoked when application execution is being suspended.
        /// </summary>
        private void OnSuspending(object sender, SuspendingEventArgs e)
        {
            var deferral = e.SuspendingOperation.GetDeferral();

            // TODO: Save application state and stop any background activity.

            deferral.Complete();
        }
    }
}
'@

$mainPageXaml = @'
<Page
    x:Class="@@NAMESPACE@@.MainPage"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:local="using:@@NAMESPACE@@"
    xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
    mc:Ignorable="d">

    <Grid Background="{ThemeResource ApplicationPageBackgroundThemeBrush}">
        <Grid.RowDefinitions>
            <RowDefinition Height="140" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="120,40,40,0">
            <TextBlock
                Text="@@FULLNAME_XAML@@"
                Style="{StaticResource HeaderTextBlockStyle}" />
            <TextBlock
                Text="@@DESCRIPTION_XAML@@"
                Style="{StaticResource SubheaderTextBlockStyle}"
                Opacity="0.7" />
        </StackPanel>

        <StackPanel Grid.Row="1" Margin="120,20,40,0">
            <Button
                x:Name="HelloButton"
                Content="Test C#"
                Click="HelloButton_Click" />
            <TextBlock
                x:Name="MessageText"
                Margin="0,20,0,0"
                Style="{StaticResource BodyTextBlockStyle}" />
        </StackPanel>
    </Grid>
</Page>
'@

$mainPageCs = @'
using System;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Navigation;

namespace @@NAMESPACE@@
{
    /// <summary>
    /// The start page of the application.
    /// </summary>
    public sealed partial class MainPage : Page
    {
        private int clicks;

        public MainPage()
        {
            this.InitializeComponent();
        }

        protected override void OnNavigatedTo(NavigationEventArgs e)
        {
        }

        private void HelloButton_Click(object sender, RoutedEventArgs e)
        {
            clicks++;
            MessageText.Text = string.Format("C# is working! Clicks: {0}", clicks);
        }
    }
}
'@

$assemblyInfo = @'
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("@@FULLNAME_CS@@")]
[assembly: AssemblyDescription("@@DESCRIPTION_CS@@")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("@@PUBLISHERNAME_CS@@")]
[assembly: AssemblyProduct("@@FULLNAME_CS@@")]
[assembly: AssemblyCopyright("Copyright")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]

[assembly: AssemblyVersion("@@VERSION@@")]
[assembly: AssemblyFileVersion("@@VERSION@@")]
[assembly: ComVisible(false)]
'@

# ---- .csproj ----

$platforms = @("x86", "x64", "ARM")
$configGroups = New-Object System.Text.StringBuilder

foreach ($platform in $platforms) {
    foreach ($configuration in @("Debug", "Release")) {
        $isDebug = ($configuration -eq "Debug")
        $defines = if ($isDebug) { "DEBUG;TRACE;NETFX_CORE" } else { "TRACE;NETFX_CORE" }
        $debugSymbols = if ($isDebug) { "true" } else { "false" }
        $debugType = if ($isDebug) { "full" } else { "pdbonly" }
        $optimize = if ($isDebug) { "false" } else { "true" }

        [void]$configGroups.AppendLine(
            "  <PropertyGroup Condition=`" '`$(Configuration)|`$(Platform)' == '$configuration|$platform' `">")
        [void]$configGroups.AppendLine("    <PlatformTarget>$platform</PlatformTarget>")
        [void]$configGroups.AppendLine("    <DebugSymbols>$debugSymbols</DebugSymbols>")
        [void]$configGroups.AppendLine("    <DebugType>$debugType</DebugType>")
        [void]$configGroups.AppendLine("    <Optimize>$optimize</Optimize>")
        [void]$configGroups.AppendLine("    <OutputPath>bin\$platform\$configuration\</OutputPath>")
        [void]$configGroups.AppendLine("    <DefineConstants>$defines</DefineConstants>")
        [void]$configGroups.AppendLine("    <NoWarn>;2008</NoWarn>")
        [void]$configGroups.AppendLine("    <UseVSHostingProcess>false</UseVSHostingProcess>")
        [void]$configGroups.AppendLine("    <ErrorReport>prompt</ErrorReport>")
        [void]$configGroups.AppendLine("    <WarningLevel>4</WarningLevel>")
        [void]$configGroups.AppendLine("  </PropertyGroup>")
    }
}

$contentItems = New-Object System.Text.StringBuilder
foreach ($image in $imageDefinitions) {
    [void]$contentItems.AppendLine(
        "    <Content Include=`"Assets\$($image.Name)`" />")
}

$values["@@CONFIGGROUPS@@"] = $configGroups.ToString().TrimEnd()
$values["@@CONTENTITEMS@@"] = $contentItems.ToString().TrimEnd()

$csprojTemplate = @'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">x86</Platform>
    <ProjectGuid>@@PROJECTGUID@@</ProjectGuid>
    <OutputType>AppContainerExe</OutputType>
    <AppDesignerFolder>Properties</AppDesignerFolder>
    <RootNamespace>@@NAMESPACE@@</RootNamespace>
    <AssemblyName>@@CSNAME@@</AssemblyName>
    <DefaultLanguage>@@LANG@@</DefaultLanguage>
    <TargetPlatformVersion>8.1</TargetPlatformVersion>
    <MinimumVisualStudioVersion>12</MinimumVisualStudioVersion>
    <FileAlignment>512</FileAlignment>
    <ProjectTypeGuids>{BC8A1FFA-BEE3-4634-8014-F334798102B3};{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}</ProjectTypeGuids>
  </PropertyGroup>
@@CONFIGGROUPS@@
  <ItemGroup>
    <!-- A reference to the entire .NET Framework and Windows SDK are automatically included -->
@@CONTENTITEMS@@
  </ItemGroup>
  <ItemGroup>
    <Compile Include="App.xaml.cs">
      <DependentUpon>App.xaml</DependentUpon>
    </Compile>
    <Compile Include="MainPage.xaml.cs">
      <DependentUpon>MainPage.xaml</DependentUpon>
    </Compile>
    <Compile Include="Properties\AssemblyInfo.cs" />
  </ItemGroup>
  <ItemGroup>
    <AppxManifest Include="Package.appxmanifest">
      <SubType>Designer</SubType>
    </AppxManifest>
  </ItemGroup>
  <ItemGroup>
    <ApplicationDefinition Include="App.xaml">
      <Generator>MSBuild:Compile</Generator>
      <SubType>Designer</SubType>
    </ApplicationDefinition>
    <Page Include="MainPage.xaml">
      <Generator>MSBuild:Compile</Generator>
      <SubType>Designer</SubType>
    </Page>
  </ItemGroup>
  <PropertyGroup Condition=" '$(VisualStudioVersion)' == '' or '$(VisualStudioVersion)' &lt; '12.0' ">
    <VisualStudioVersion>12.0</VisualStudioVersion>
  </PropertyGroup>
  <Import Project="$(MSBuildExtensionsPath)\Microsoft\WindowsXaml\v$(VisualStudioVersion)\Microsoft.Windows.UI.Xaml.CSharp.targets" />
</Project>
'@

# ---- build.bat (MSBuild 12.0, default C:\Program Files\MSBuild\12.0\Bin) ----

$buildBat = @'
@echo off
setlocal EnableExtensions
title @@FULLNAME_BAT@@ - Build
cd /d "%~dp0"

set "PROJECT=@@PROJECTFILE@@"
set "CONFIG=Debug"
set "PLATFORM=x86"

rem ------------------------------------------------------------------
rem MSBuild 12.0 folder. Default: C:\Program Files\MSBuild\12.0\Bin
rem To use another folder, edit the line below or set MSBUILD_DIR first.
rem ------------------------------------------------------------------
if not defined MSBUILD_DIR set "MSBUILD_DIR=C:\Program Files\MSBuild\12.0\Bin"

:findmsbuild
if exist "%MSBUILD_DIR%\MSBuild.exe" goto havemsbuild

echo.
echo MSBuild.exe was not found in:
echo   %MSBUILD_DIR%
echo.

rem Fallback: the (x86) location used on 64-bit Windows.
if exist "%ProgramFiles(x86)%\MSBuild\12.0\Bin\MSBuild.exe" goto usex86

set "MSBUILD_DIR="
set /p "MSBUILD_DIR=Enter the folder that contains MSBuild.exe (blank to quit): "
if not defined MSBUILD_DIR goto :eof
set "MSBUILD_DIR=%MSBUILD_DIR:"=%"
goto findmsbuild

:usex86
set "MSBUILD_DIR=%ProgramFiles(x86)%\MSBuild\12.0\Bin"
echo Using the (x86) MSBuild instead:
echo   %MSBUILD_DIR%
echo.
goto havemsbuild

:havemsbuild
:menu
cls
echo ============================================
echo   @@FULLNAME_BAT@@
echo ============================================
echo   MSBuild      : %MSBUILD_DIR%\MSBuild.exe
echo   Project      : %PROJECT%
echo   Configuration: %CONFIG%
echo   Platform     : %PLATFORM%
echo.
echo   [1] Build
echo   [2] Rebuild
echo   [3] Clean
echo   [4] Toggle configuration (Debug / Release)
echo   [5] Change platform (x86 / x64 / ARM)
echo   [6] Register built app for testing
echo   [7] Open output folder
echo   [Q] Quit
echo.
set "CHOICE="
set /p "CHOICE=Select an option: "

if /i "%CHOICE%"=="1" set "TARGET=Build" & goto runbuild
if /i "%CHOICE%"=="2" set "TARGET=Rebuild" & goto runbuild
if /i "%CHOICE%"=="3" set "TARGET=Clean" & goto runbuild
if /i "%CHOICE%"=="4" goto toggleconfig
if /i "%CHOICE%"=="5" goto chooseplatform
if /i "%CHOICE%"=="6" goto register
if /i "%CHOICE%"=="7" goto openfolder
if /i "%CHOICE%"=="Q" goto :eof
goto menu

:toggleconfig
if /i "%CONFIG%"=="Debug" goto setrelease
set "CONFIG=Debug"
goto menu
:setrelease
set "CONFIG=Release"
goto menu

:chooseplatform
set "PLATFORM_CHOICE="
set /p "PLATFORM_CHOICE=Platform (x86, x64 or ARM): "
if /i "%PLATFORM_CHOICE%"=="x86" set "PLATFORM=x86"
if /i "%PLATFORM_CHOICE%"=="x64" set "PLATFORM=x64"
if /i "%PLATFORM_CHOICE%"=="ARM" set "PLATFORM=ARM"
goto menu

:runbuild
echo.
echo Running MSBuild: %TARGET% ^(%CONFIG% / %PLATFORM%^)
echo.
"%MSBUILD_DIR%\MSBuild.exe" "%PROJECT%" /t:%TARGET% /p:Configuration=%CONFIG% /p:Platform=%PLATFORM% /p:VisualStudioVersion=12.0 /m /nologo /verbosity:minimal "/flp:logfile=build.log;verbosity=normal"
if errorlevel 1 goto buildfailed
echo.
echo ============================================
echo   %TARGET% succeeded.
echo   Output: %~dp0bin\%PLATFORM%\%CONFIG%\
echo ============================================
goto done

:buildfailed
echo.
echo ============================================
echo   %TARGET% FAILED. See build.log for details.
echo ============================================
goto done

:register
set "LAYOUT=%~dp0bin\%PLATFORM%\%CONFIG%\AppX\AppxManifest.xml"
if exist "%LAYOUT%" goto doregister
echo.
echo Not found: %LAYOUT%
echo Build this configuration and platform first.
goto done

:doregister
echo.
echo Registering %LAYOUT% ...
echo (Windows 8.1 needs a developer license once per user:
echo  powershell Show-WindowsDeveloperLicenseRegistration)
powershell -NoProfile -Command "Add-AppxPackage -Register '%LAYOUT%'"
if errorlevel 1 goto registerfailed
echo.
echo Registered. Find "@@FULLNAME_BAT@@" on the Start screen.
goto done

:registerfailed
echo.
echo Registration failed.
goto done

:openfolder
if not exist "%~dp0bin\%PLATFORM%\%CONFIG%" goto nofolder
explorer "%~dp0bin\%PLATFORM%\%CONFIG%"
goto menu

:nofolder
echo.
echo The output folder does not exist yet. Build first.
goto done

:done
echo.
pause
goto menu
'@

$readmeTemplate = @'
# @@FULLNAME_XML@@

Windows 8.1 Store app (WinRT, C# / XAML).

## Structure

- `@@PROJECTFILE@@`   MSBuild project (Windows Store 8.1)
- `Package.appxmanifest`  package manifest (Windows 8.1 / 2013 schema)
- `App.xaml` / `App.xaml.cs`  application entry point
- `MainPage.xaml` / `MainPage.xaml.cs`  start page
- `Assets\`  generated tile, logo and splash images
- `build.bat`  menu-driven MSBuild 12.0 build

## Build

Run `build.bat`. It looks for MSBuild in
`C:\Program Files\MSBuild\12.0\Bin` (falls back to the (x86) folder, then asks).
Output goes to `bin\<Platform>\<Configuration>\`. The app layout folder
`AppX` inside it contains `AppxManifest.xml`, so it can also be used with
`Pack-Appx.ps1` and `Register-Appx.ps1` from the AppMaker folder.

## Requirements

Visual Studio 2013 (or the Windows Store 8.1 build components) and the
Windows 8.1 SDK. MSBuild alone cannot compile XAML Store apps.

The manifest publisher is: @@PUBLISHER_XML@@
Sign packages with a certificate whose subject matches it.
'@

Write-TextFile (Join-Path $projectPath "$projectName.csproj") (Expand-Template $csprojTemplate $values)
Write-TextFile (Join-Path $projectPath "App.xaml") (Expand-Template $appXaml $values)
Write-TextFile (Join-Path $projectPath "App.xaml.cs") (Expand-Template $appCs $values)
Write-TextFile (Join-Path $projectPath "MainPage.xaml") (Expand-Template $mainPageXaml $values)
Write-TextFile (Join-Path $projectPath "MainPage.xaml.cs") (Expand-Template $mainPageCs $values)
Write-TextFile (Join-Path $projectPath "Properties\AssemblyInfo.cs") (Expand-Template $assemblyInfo $values)
Write-TextFile (Join-Path $projectPath "build.bat") (Expand-Template $buildBat $values) -Bom $false
Write-TextFile (Join-Path $projectPath "README.md") (Expand-Template $readmeTemplate $values)

}

# ============================================================
# FINISHED
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "        PROJECT CREATED SUCCESSFULLY" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project type : $typeLabel"
Write-Host "Project name : $projectName"
Write-Host "Full name    : $fullName"
Write-Host "Short name   : $shortName"
Write-Host "Package name : $identityName"
Write-Host "Publisher    : $publisher"
Write-Host "Version      : $version"
Write-Host "Color        : $backgroundColor (tile text: $foregroundText)"
Write-Host "Project path : $projectPath"
Write-Host ""
Write-Host "Generated structure:"
Write-Host "$projectName\"

$rootLength = $projectPath.TrimEnd('\', '/').Length + 1
Get-ChildItem -LiteralPath $projectPath -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
        Write-Host ("  " + $_.FullName.Substring($rootLength))
    }

Write-Host ""
if ($isWinRT) {
    Write-Host "Next: run build.bat in the project folder."
}
else {
    Write-Host "Next: run register.bat in the project folder to test the app."
}
Write-Host "Note: PNG branding images were generated from the entered names and selected color."
Write-Host "Note: The manifest publisher must match the certificate used to sign the app."
