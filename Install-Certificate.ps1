$ErrorActionPreference = 'Stop'
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) { throw "Run PowerShell as Administrator to add a certificate to the machine store." }

    $path = (Read-Host "Enter full path to the .cer or .pfx certificate").Trim('"')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Certificate not found: $path" }

    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -eq '.pfx') {
        $securePassword = Read-Host "Enter PFX password (leave blank if none)" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $loaded = New-Object Security.Cryptography.X509Certificates.X509Certificate2($path, $plain)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            Remove-Variable plain -ErrorAction SilentlyContinue
        }
    } else {
        $loaded = New-Object Security.Cryptography.X509Certificates.X509Certificate2($path)
    }
    # Only the public part is installed.
    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$loaded.RawData)

    Write-Host "`nSubject    : $($cert.Subject)"
    Write-Host "Thumbprint : $($cert.Thumbprint)"
    Write-Host "Expires    : $($cert.NotAfter)"

    Write-Host "`nWhere should the certificate be installed?"
    Write-Host "  [1] TrustedPeople  (recommended - enough for installing your own signed apps)"
    Write-Host "  [2] Root           (Trusted Root Certification Authorities - broader trust)"
    $storeChoice = Read-Host "Select store [1]"
    switch ($storeChoice.Trim()) {
        ''  { $storeName = 'TrustedPeople' }
        '1' { $storeName = 'TrustedPeople' }
        '2' { $storeName = 'Root' }
        default { throw "Invalid selection: $storeChoice" }
    }

    Write-Host "`nThis makes packages signed with this certificate installable on this PC." -ForegroundColor Yellow
    if ($storeName -eq 'Root') {
        Write-Host "WARNING: Root makes this PC trust anything issued by this certificate, for any purpose." -ForegroundColor Red
    }
    Write-Host "Only trust certificates you created or fully trust." -ForegroundColor Yellow
    $confirm = Read-Host "Add to LocalMachine\$storeName? (y/N)"
    if ($confirm -notin @('y','Y','yes','YES')) { Write-Host 'Cancelled.'; Read-Host "Press Enter to close"; exit 0 }

    $store = New-Object Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
    $store.Open('ReadWrite')
    try { $store.Add($cert) } finally { $store.Close() }
    Write-Host "`nCertificate added to $storeName." -ForegroundColor Green
} catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
}
Read-Host "Press Enter to close"