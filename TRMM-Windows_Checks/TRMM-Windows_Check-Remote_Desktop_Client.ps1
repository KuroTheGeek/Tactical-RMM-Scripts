<#
.SYNOPSIS
  Reine Pruefung auf alte RD Clients (MSRDC / MSRDCW) als "Logged On User".
  Gibt Exit Code 1 zurueck, wenn die App gefunden wurde (fuer RMM-Alerts).
  Gibt Exit Code 0 zurueck, wenn das System sauber ist.
#>

$found = $false
Write-Host "=== Pruefung auf veraltete Remote Desktop Clients ==="

# 1. Pruefung ueber den Windows Package Manager (identisch zum Apps & Features Menue)
Write-Host "[INFO] Pruefe Windows Package Manager..."
$package = Get-Package -Name "*Remotedesktop*" -ErrorAction SilentlyContinue

if (-not $package) {
    $package = Get-Package -Name "*Remote Desktop*" -ErrorAction SilentlyContinue
}

if ($package) {
    Write-Host "[FUND] Paket in der Windows-Datenbank gefunden!"
    Write-Host "  - Name: $($package.Name)"
    Write-Host "  - Version: $($package.Version)"
    $found = $true
} else {
    Write-Host "[OK] Kein Paket im Windows Package Manager gefunden."
}

# 2. Direkte Pruefung im Dateisystem (AppData des Users)
Write-Host "`n[INFO] Pruefe lokale AppData-Verzeichnisse..."
$appData = $env:LOCALAPPDATA
$rdPathsToCheck = @(
    "$appData\Apps\Remote Desktop",
    "$appData\Programs\Remote Desktop"
)

foreach ($path in $rdPathsToCheck) {
    if ((Test-Path -Path "$path\msrdcw.exe") -or (Test-Path -Path "$path\msrdc.exe")) {
        Write-Host "[FUND] Installationsordner mit ausfuehrbarer Datei gefunden:"
        Write-Host "  - Pfad: $path"
        $found = $true
    }
}

# 3. WMI-Fallback (Nur zur Sicherheit, falls das Package-Management klemmt)
if (-not $found) {
    Write-Host "`n[INFO] Pruefe WMI-Datenbank als Fallback..."
    $wmiApp = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Remote\s?desktop" }
    
    if ($wmiApp) {
        Write-Host "[FUND] App in WMI gefunden: $($wmiApp.Name)"
        $found = $true
    } else {
        Write-Host "[OK] Keine Installation in WMI gefunden."
    }
}

Write-Host "------------------------------------------------------"

# 4. Fazit & Exit Code fuer Tactical RMM
if ($found) {
    Write-Host "ERGEBNIS: Veralteter Client entdeckt! (Exit 1)"
    exit 1  # Loest in Tactical RMM einen Alert aus
} else {
    Write-Host "ERGEBNIS: System ist sauber. (Exit 0)"
    exit 0  # Alles in Ordnung, kein Alert
}