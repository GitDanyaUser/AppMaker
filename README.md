# Interactive Windows 8.1 SDK APPX scripts

These scripts prompt for the information they need when you launch them; you do not need to supply command-line arguments. The default SDK path is:

`C:\Program Files\Windows Kits\8.1\bin\x86`

Extract this folder, open PowerShell in it, and run a script directly, or start the menu:
```powershell
.\AppMaker.ps1
```

If PowerShell blocks local scripts, check your organization's execution-policy rules. Do not change a machine-wide policy just to run these scripts.

## Creating projects: New-Project.ps1

Asks for a project type, then names, publisher, version, color, theme and capabilities.

| Type | What you get |
| --- | --- |
| **HTML/JS** | WinJS 2.0 Store app: `AppxManifest.xml`, `default.html`, `js\default.js`, `css\default.css`, `images\`, `register.bat`, `unregister.bat` |
| **WinRT** | C# / XAML Store app: `.csproj`, `Package.appxmanifest`, `App.xaml`, `MainPage.xaml`, `Assets\`, and a menu-driven `build.bat` |

Both use the Windows 8.1 manifest schema (2013): wide/large/small tiles with a short name, splash screen, capabilities, `OSMinVersion` 6.3.0, and (HTML/JS) the WinJS 2.0 package dependency. Tile text turns dark automatically on light background colors.

### build.bat (WinRT projects)

Defaults to `C:\Program Files\MSBuild\12.0\Bin`. If `MSBuild.exe` is not there it tries the `(x86)` folder, then asks you for a folder. You can also set `MSBUILD_DIR` before running it. Menu: build, rebuild, clean, switch Debug/Release, switch x86/x64/ARM, register the built app for testing, open the output folder. A `build.log` is written next to it.

Compiling XAML Store apps needs Visual Studio 2013 (or its Store build components) plus the Windows 8.1 SDK; MSBuild alone is not enough.

## What the scripts do

Project and manifest
- `New-Project.ps1`: generates an HTML/JS or WinRT project.
- `Test-AppxManifest.ps1`: checks identity name, version, publisher, referenced images (and their pixel sizes) and the start page.
- `Get-AppxInfo.ps1`: shows manifest details from a folder, manifest file or `.appx`.
- `Update-AppxVersion.ps1`: changes the package version (default: bump the last part).

Package, sign, verify
- `Pack-Appx.ps1`: packages a prepared folder containing `AppxManifest.xml`.
- `Unpack-Appx.ps1`: extracts a package.
- `Make-Cert.ps1`: creates a self-signed code-signing certificate.
- `Sign-Appx.ps1`: signs an APPX using a PFX certificate.
- `Verify-AppxSignature.ps1`: checks signature validity/trust.
- `Make-AppxBundle.ps1`: bundles APPX packages in a folder.
- `Build-Appx.ps1`: guided pack, optional sign and optional verify workflow.
- `Clean-AppxOutput.ps1`: interactively removes package files from a selected output folder.

Install and run
- `Install-Certificate.ps1`: adds a certificate to LocalMachine\TrustedPeople (run as Administrator).
- `Install-Appx.ps1`: installs an `.appx` / `.appxbundle`, with optional dependency packages.
- `Register-Appx.ps1`: registers an app folder (loose files) for testing. For WinRT use the `bin\<Platform>\<Configuration>\AppX` folder.
- `Start-App.ps1`: starts an installed app.
- `Uninstall-Appx.ps1`: lists and removes an installed app.

Other
- `AppMaker.ps1`: menu that launches all of the above.
- `Test-AppxTools.ps1`: checks SDK tools (and MSBuild, optionally).
- `Set-AppxSdkPath.ps1`: helper for checking the SDK path.

## Typical workflows

HTML/JS: `New-Project.ps1` -> `register.bat` in the project -> edit and re-run -> `Test-AppxManifest.ps1` -> `Make-Cert.ps1` -> `Build-Appx.ps1` -> `Install-Certificate.ps1` -> `Install-Appx.ps1`.

WinRT: `New-Project.ps1` -> `build.bat` -> option 6 to register for testing -> for a package, run `Pack-Appx.ps1` on the `AppX` output folder, then sign it.

## Notes

`Pack-Appx.ps1` and `Build-Appx.ps1` package an already-built application; they do not compile source code. Your package source folder must have `AppxManifest.xml` at its root. Signing requires a suitable PFX certificate whose identity/publisher matches the package. Signature verification does not automatically install a certificate into a trusted store. The exact SignTool options available can vary by SDK build.
