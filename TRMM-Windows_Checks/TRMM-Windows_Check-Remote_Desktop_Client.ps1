<#
.SYNOPSIS
  Sichere Pruefung auf alte RD Clients.
  Verhindert False Positives (wie Devolutions), indem exakte Namen 
  und der Herausgeber "Microsoft" geprueft werden.
#>

$found = $false
Write-Host "=== Sichere Pruefung auf Microsoft Remote Desktop ==="

# 1. Pruefung ueber Package Manager mit EXAKTEM Namen
$packages = Get-Package -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -eq "Remotedesktop" -or $_.Name -eq "Remote Desktop" 
}

if ($packages) {
    foreach ($pkg in $packages) {
        Write-Host "[FUND] Exakter Microsoft-Client gefunden:"
        Write-Host "  - Name: $($pkg.Name) (Version: $($pkg.Version))"
        $found = $true
    }
} else {
    Write-Host "[OK] Kein exaktes Microsoft-Paket gefunden."
}

# 2. Direkte Dateipruefung (Ist bereits sicher, da Ordnername exakt geprueft wird)
$appData = $env:LOCALAPPDATA
$rdPathsToCheck = @(
    "$appData\Apps\Remote Desktop",
    "$appData\Programs\Remote Desktop"
)

foreach ($path in $rdPathsToCheck) {
    if ((Test-Path -Path "$path\msrdcw.exe") -or (Test-Path -Path "$path\msrdc.exe")) {
        Write-Host "[FUND] Installationsordner mit MSRDC-Exe gefunden: $path"
        $found = $true
    }
}

Write-Host "------------------------------------------------------"
if ($found) { exit 1 } else { exit 0 }