<#
.SYNOPSIS
  Saubere Deinstallation ueber den internen Windows Package Manager.
  Liest die App direkt aus der Windows-Datenbank aus (wie "Apps & Features").
  Als User ausführen.
#>

Write-Host "=== Deinstallation ueber Windows Package Manager ==="

# Sucht nach beiden Namensvarianten
$package = Get-Package -Name "*Remotedesktop*" -ErrorAction SilentlyContinue

if (-not $package) {
    $package = Get-Package -Name "*Remote Desktop*" -ErrorAction SilentlyContinue
}

if ($package) {
    Write-Host "[FUND] Paket in der Windows-Datenbank gefunden!"
    Write-Host "Name: $($package.Name)"
    Write-Host "Version: $($package.Version)"
    Write-Host "Provider: $($package.ProviderName)"
    
    Write-Host "Starte offizielle Deinstallation..."
    try {
        # Führt die Deinstallation unsichtbar aus
        $package | Uninstall-Package -AllVersions -Force -ErrorAction Stop
        
        Write-Host "[ERFOLG] Deinstallations-Befehl erfolgreich an Windows uebergeben."
        
        # Startmenue aufraeumen (Sicherheitshalber)
        $startMenu = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Start Menu\Programs"
        Get-ChildItem -Path $startMenu -Filter "*Remote*Desktop*.lnk" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $startMenu -Filter "*Remotedesktop*.lnk" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        
        exit 1 # Erfolg für Tactical RMM
    } catch {
        Write-Host "[FEHLER] Windows konnte das Paket nicht deinstallieren."
        Write-Host "Fehlermeldung: $($_.Exception.Message)"
        exit 0
    }
} else {
    Write-Host "[INFO] Windows Package Manager konnte kein Paket mit diesem Namen finden."
    
    # Letzter WMI-Fallback (durchsucht die tiefe MSI-Datenbank)
    Write-Host "Pruefe tiefe WMI-Datenbank als Fallback..."
    $wmiApp = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Remote\s?desktop" }
    
    if ($wmiApp) {
        Write-Host "[FUND] App in WMI gefunden: $($wmiApp.Name)"
        $wmiApp.Uninstall() | Out-Null
        Write-Host "[ERFOLG] WMI Deinstallation ausgefuehrt."
        exit 1
    } else {
        Write-Host "[INFO] Keine Installation gefunden. System ist sauber."
        exit 0
    }
}