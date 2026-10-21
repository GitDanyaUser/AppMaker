# Shared helper. Dot-source this file from another script if you want its function.
$script:DefaultAppxSdkBin = 'C:\Program Files\Windows Kits\8.1\bin\x86'

function Read-AppxSdkBin {
    $answer = Read-Host "SDK bin folder [$script:DefaultAppxSdkBin] (Enter to use default)"
    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $script:DefaultAppxSdkBin }
    if (-not (Test-Path -LiteralPath $answer -PathType Container)) {
        throw "SDK directory not found: $answer"
    }
    return $answer
}

function Get-AppxSdkTool {
    param(
        [Parameter(Mandatory=$true)][string]$SdkBin,
        [Parameter(Mandatory=$true)][string]$Name
    )
    $path = Join-Path $SdkBin $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required SDK tool not found: $path"
    }
    return $path
}
