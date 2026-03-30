<#
.SYNOPSIS
  Kombiniertes Pruef- und Deinstallations-Script fuer Tactical RMM.
  Ausfuehrung ZWINGEND als "Logged On User"!
  Sicher gegen False Positives (z. B. Devolutions). Keine Umlaute.
#>

$actionTaken = $false
Write-Host "=== Sicherer Check & Uninstall: Microsoft Remote Desktop ==="

# 1. Pruefung und Deinstallation ueber Package Manager
Write-Host "[INFO] Pruefe Windows Package Manager auf exakte Uebereinstimmungen..."

# Wir suchen OHNE Wildcards nur nach den exakten Namen
$packages = Get-Package -ErrorAction SilentlyContinue | Where-Object { 
    $_.Name -eq "Remotedesktop" -or $_.Name -eq "Remote Desktop" 
}

if ($packages) {
    foreach ($pkg in $packages) {
        Write-Host "[FUND] Zu deinstallierendes Paket gefunden: $($pkg.Name) (Version: $($pkg.Version))"
        try {
            # Deinstalliert nur das exakt gefundene Paket
            $pkg | Uninstall-Package -AllVersions -Force -ErrorAction Stop
            Write-Host "[ERFOLG] Paket erfolgreich deinstalliert."
            $actionTaken = $true
        } catch {
            Write-Host "[FEHLER] Deinstallation via Package Manager fehlgeschlagen: $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "[OK] Keine exakten Treffer im Package Manager."
}

# 2. Direkte Dateipruefung und Fallback-Deinstallation (AppData)
Write-Host "`n[INFO] Pruefe lokale AppData-Verzeichnisse auf verwaiste Installationen..."
$appData = $env:LOCALAPPDATA
$rdPathsToCheck = @(
    "$appData\Apps\Remote Desktop",
    "$appData\Programs\Remote Desktop"
)

foreach ($path in $rdPathsToCheck) {
    # Prueft exakt auf den Ordner und die spezifischen Exe-Dateien
    if ((Test-Path -Path "$path\msrdcw.exe") -or (Test-Path -Path "$path\msrdc.exe")) {
        Write-Host "[FUND] Installationsordner mit MSRDC-Exe gefunden: $path"
        $actionTaken = $true
        
        # Versuche eigenen Uninstaller im Ordner zu finden
        $uninstaller = Get-ChildItem -Path $path -Filter "unins*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $uninstaller) {
            $uninstaller = Get-ChildItem -Path $path -Filter "uninstall.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        }

        if ($uninstaller) {
            Write-Host "Starte lokalen Uninstaller..."
            $process = Start-Process -FilePath $uninstaller.FullName -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-Host "[ERFOLG] Lokaler Uninstaller erfolgreich durchgelaufen."
            } else {
                Write-Host "[WARNUNG] Lokaler Uninstaller meldet Exit-Code $($process.ExitCode)."
            }
        } else {
            Write-Host "[WARNUNG] Kein Uninstaller gefunden. Loesche den Ordner hart."
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 3. Startmenue aufraeumen (Sucht gezielt nur nach den exakten Microsoft-Verknuepfungen)
if ($actionTaken) {
    Write-Host "`n[INFO] Raeume Startmenue auf..."
    $startMenu = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Start Menu\Programs"
    $links = Get-ChildItem -Path $startMenu -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue
    
    foreach ($link in $links) {
        # Loescht die Verknuepfung nur, wenn der Name zu 100% passt
        if ($link.Name -eq "Remote Desktop.lnk" -or $link.Name -eq "Remotedesktop.lnk") {
            Remove-Item -Path $link.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "  - Verknuepfung geloescht: $($link.Name)"
        }
    }
}

Write-Host "------------------------------------------------------"

# 4. Fazit & Exit Code fuer Tactical RMM
if ($actionTaken) {
    Write-Host "ERGEBNIS: Veraltete Clients wurden gefunden und entfernt! (Exit 1)"
    exit 1
} else {
    Write-Host "ERGEBNIS: System ist sauber. Keine Aktion notwendig. (Exit 0)"
    exit 0
}