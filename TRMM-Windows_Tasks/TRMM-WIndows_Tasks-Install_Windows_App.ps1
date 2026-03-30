<#
.SYNOPSIS
  Installiert die neue Microsoft "Windows App" via Winget (System-Kontext).
  Beinhaltet Fixes für "No package found" im RMM SYSTEM-Kontext.
  Muss als User augeführt werden.
#>

Write-Host "=== Installation der neuen Microsoft 'Windows App' ==="

# Sichere Suche nach der Winget-Exe
$wingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -First 1

if (-not $wingetPath) {
    Write-Host "[INFO] Direkter Pfad nicht gefunden, versuche Umgebungsvariable..."
    $wingetPath = "winget.exe"
}

Write-Host "Bereite Winget-Quellen für den SYSTEM-User vor..."
# Zwingend notwendig, da der SYSTEM-User oft keine aktuellen Store-Kataloge hat
& $wingetPath source update | Out-Null

Write-Host "Starte Download und Installation der Windows App..."
try {
    # Nutzung der eindeutigen Store-ID (9N1F85V9T8BN) anstelle des Textnamens
    $installCommand = & $wingetPath install --id 9N1F85V9T8BN --exact --source msstore --accept-package-agreements --accept-source-agreements --disable-interactivity --silent
    
    # Auswertung des Ergebnisses
    if ($LASTEXITCODE -eq 0 -or $installCommand -match "Erfolgreich|Successfully|schon installiert|already installed") {
        Write-Host "[ERFOLG] Die Windows App wurde erfolgreich installiert."
        exit 0
    } else {
        Write-Host "[FEHLER/WARNUNG] Die App konnte nicht gefunden oder installiert werden. Winget-Ausgabe:"
        $installCommand | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
} catch {
    Write-Host "[FEHLER] Ausführung fehlgeschlagen."
    Write-Host $_.Exception.Message
    exit 1
}