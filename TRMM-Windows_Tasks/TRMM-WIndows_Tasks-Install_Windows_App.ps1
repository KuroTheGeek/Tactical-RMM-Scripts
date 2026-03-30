<#
.SYNOPSIS
  Installiert die neue Microsoft "Windows App" via Winget (System-Kontext).
#>

Write-Host "=== Installation der neuen Microsoft 'Windows App' ==="

# Prüfen ob Winget verfügbar ist
$wingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -First 1

if (-not $wingetPath) {
    # Fallback, falls der direkte Pfad nicht gefunden wird, aber winget im Path liegt
    $wingetPath = "winget.exe"
}

Write-Host "Starte Download und Installation (dies kann einen Moment dauern)..."

try {
    # ID für die Windows App: Microsoft.WindowsApp (Store ID: 9N1F85V9T8BN)
    $installCommand = & $wingetPath install --id Microsoft.WindowsApp --exact --source msstore --accept-package-agreements --accept-source-agreements --silent
    
    if ($LASTEXITCODE -eq 0 -or $installCommand -match "Erfolgreich|Successfully") {
        Write-Host "[ERFOLG] Die Windows App wurde erfolgreich installiert."
        exit 0
    } else {
        Write-Host "[WARNUNG] Installation abgeschlossen, aber überprüfe den Output:"
        Write-Host $installCommand
        # Manchmal gibt Winget Codes > 0 aus (z.B. wenn schon installiert), was kein harter Fehler sein muss.
        exit 0
    }
} catch {
    Write-Host "[FEHLER] Konnte die Windows App nicht via Winget installieren. Prüfe, ob der App Installer auf dem System aktuell ist."
    Write-Host $_.Exception.Message
    exit 1
}