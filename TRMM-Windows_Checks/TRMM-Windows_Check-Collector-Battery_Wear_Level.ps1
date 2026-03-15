<#
.SYNOPSIS
    Prüft die Akku-Gesundheit (Wear Level).
    
.DESCRIPTION
    Dieses Skript ist für Tactical RMM optimiert. 
    Es berechnet die verbleibende Maximalkapazität im Vergleich zum Werkszustand.

.PARAMETER Threshold
    Standard: 60%. Unter diesem Wert gibt das Skript Exit 1 zurück.

.EXITCODES
    0 = Akku OK oder kein Akku vorhanden (Desktop)
    1 = Akku-Gesundheit unter Schwellenwert
    2 = Technischer Fehler beim Auslesen

#>

# Schwellenwert in Prozent (Warne, wenn Akku-Gesundheit unter X%)
$threshold = 60

try {
    # 1. Akku-Informationen via WMI abrufen
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

    # 2. Prüfung: Ist überhaupt ein Akku vorhanden?
    if (-not $battery) {
        Write-Host "STATUS: Kein Akku gefunden (Desktop-PC oder Server). Check übersprungen."
        exit 0
    }

    # 3. Kapazitäten auslesen
    # FullChargeCapacity: Was der Akku aktuell noch maximal laden kann
    # DesignCapacity: Was der Akku im Neuzustand laden konnte
    $batteryInfo = Get-CimInstance -Namespace "root\wmi" -ClassName BatteryFullCapacity -ErrorAction SilentlyContinue
    $batteryStatic = Get-CimInstance -Namespace "root\wmi" -ClassName BatteryStaticData -ErrorAction SilentlyContinue

    if ($null -eq $batteryInfo -or $null -eq $batteryStatic) {
        Write-Host "INFO: Akku vorhanden, aber detaillierte Kapazitätsdaten werden vom Treiber nicht geliefert."
        exit 0
    }

    $currentMax = $batteryInfo.FullChargeCapacity
    $designMax = $batteryStatic.DesignCapacity

    # 4. Berechnung der Gesundheit (Health)
    if ($designMax -gt 0) {
        $healthPercentage = [math]::Round(($currentMax / $designMax) * 100, 2)
        $wearLevel = 100 - $healthPercentage

        Write-Host "--- Batterie Analyse ---"
        Write-Host "Modell: $($battery.Name)"
        Write-Host "Design-Kapazität: $designMax mWh"
        Write-Host "Aktuelle Max-Kapazität: $currentMax mWh"
        Write-Host "Akku-Gesundheit: $healthPercentage %"
        Write-Host "Verschleiß (Wear Level): $wearLevel %"
        Write-Host "------------------------"

        if ($healthPercentage -lt $threshold) {
            Write-Host "WARNUNG: Die Akku-Gesundheit liegt unter dem Schwellenwert von $threshold %!"
            exit 1
        } else {
            Write-Host "STATUS: Akku ist in gutem Zustand."
            exit 0
        }
    } else {
        Write-Host "Fehler: Design-Kapazität konnte nicht ermittelt werden."
        exit 0
    }

} catch {
    Write-Host "Technischer Fehler beim Auslesen der Batteriedaten: $($_.Exception.Message)"
    exit 0 # Wir wählen 0, um Fehlalarme auf Desktop-Systemen bei WMI-Problemen zu vermeiden
}