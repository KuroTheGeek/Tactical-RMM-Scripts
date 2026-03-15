<#
.SYNOPSIS
    Sammelt die Anzahl ausstehender Software-Updates via Winget (User Context).
    
.DESCRIPTION
    Dieses Skript läuft als "Logged In User". Es ignoriert Spalten-Formatierungen 
    komplett. Stattdessen nutzt es die Trennlinie (---) als Startpunkt und 
    filtert am Ende gezielt den Zusammenfassungs-Satz heraus.
#>

$wingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | 
              Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty Path -First 1

if (!$wingetPath) { $wingetPath = Get-Command "winget.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }

if (!$wingetPath) {
    Write-Host "FEHLER: Winget wurde nicht gefunden."
    exit 2
}

try {
    # Quellen-Update erzwingen
    &$wingetPath source update --accept-source-agreements | Out-Null

    # Out-String und das Splitten nach \r?\n entfernt alle unsichtbaren Umbrüche sicher!
    $rawText = &$wingetPath upgrade --source winget --accept-source-agreements 2>$null | Out-String
    $lines = $rawText -split "\r?\n"

    $updateCount = 0
    $isTableContent = $false

    foreach ($line in $lines) {
        # Entfernt ANSI-Farbcodes (falls Winget diese mitsendet) und Leerzeichen am Rand
        $line = $line -replace "`e\[[0-9;]*m", ""
        $line = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # ANKER: Sobald eine Zeile aus vielen Bindestrichen besteht, startet die Liste!
        if ($line -match "^-{10,}") {
            $isTableContent = $true
            continue
        }

        # Wir befinden uns im Bereich der Apps
        if ($isTableContent) {
            
            # 1. FILTER: Den Footer aussortieren (z.B. "13 Aktualisierungen verfügbar.")
            # Wir blockieren Zeilen, die mit einer Zahl beginnen, gefolgt von einem Leerzeichen und einem Text.
            # (Echte Apps wie "7-Zip" haben nach der 7 kein Leerzeichen, werden also nicht blockiert!)
            if ($line -match "^\d+\s+(Aktualisierung|upgrade|Update|verf|avail|Paket|package)") { continue }
            
            # 2. FILTER: Rechtliches / Disclaimer
            if ($line -match "^(Urheber|Copyright|Haftung|---)") { continue }

            # Wenn wir hier ankommen, IST es eine App. Egal wie lang, egal welche Spalten.
            $updateCount++
            
            # Wir trennen die Zeile nur optisch für das Log (beim ersten großen Leerzeichen-Block)
            $cols = $line -split '\s{2,}'
            $appName = $cols[0]
            Write-Host "Update gefunden: $appName"
        }
    }

    # --- ZUSAMMENFASSUNG ---
    Write-Host "===================================================="
    if ($updateCount -gt 0) {
        Write-Host "STATUS: $updateCount System-Update(s) stehen aus."
        $summary = "$updateCount Updates ausstehend"
    } else {
        Write-Host "ZUSTAND: Alle Applikationen sind aktuell."
        $summary = "Alle Apps aktuell"
    }
    Write-Host "===================================================="

    # Wert für das Tactical Custom Field (Umlaut-frei)
    Write-Output $summary

} catch {
    Write-Host "FEHLER: $($_.Exception.Message)"
    exit 1
}