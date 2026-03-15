<#
.SYNOPSIS
    Antivirus Health Check für Tactical RMM.
    Prüft: Echtzeitschutz-Status und Alter der Signaturen.
    
.DESCRIPTION
    Gibt Exit 0 bei grünem Status, Exit 1 bei veralteten Signaturen 
    oder deaktiviertem Schutz aus.
#>

# Schwellenwert für das Alter der Signaturen in Tagen
$maxSignatureAgeDays = 3

try {
    # 1. Antivirus Informationen via WMI abrufen (SecurityCenter2)
    # 0x1100 = Aktiv & Aktuell (für Drittanbieter oft unterschiedlich, daher Defender Fokus)
    $avProduct = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction SilentlyContinue

    if (!$avProduct) {
        Write-Host "KRITISCH: Kein Antivirus-Produkt im SecurityCenter registriert!"
        exit 1
    }

    # 2. Spezifische Prüfung für Windows Defender (Standard unter Windows)
    if ($avProduct.displayName -eq "Windows Defender" -or $avProduct.displayName -eq "Microsoft Defender Antivirus") {
        $defenderStatus = Get-MpComputerStatus
        $sigAge = (Get-Date) - $defenderStatus.AntivirusSignatureLastUpdated

        Write-Host "Produkt: $($avProduct.displayName)"
        Write-Host "Echtzeitschutz: $($defenderStatus.RealTimeProtectionEnabled)"
        Write-Host "Signatur-Datum: $($defenderStatus.AntivirusSignatureLastUpdated)"
        Write-Host "Signatur-Alter: $($sigAge.Days) Tag(e)"

        if (!$defenderStatus.RealTimeProtectionEnabled) {
            Write-Host "FEHLER: Echtzeitschutz ist DEAKTIVIERT!"
            exit 1
        }

        if ($sigAge.Days -gt $maxSignatureAgeDays) {
            Write-Host "FEHLER: Signaturen sind älter als $maxSignatureAgeDays Tage!"
            exit 1
        }
    } 
    else {
        # 3. Fallback für Drittanbieter (SentinelOne, Sophos, Crowdstrike etc.)
        # Hier prüfen wir den Status-Code aus dem SecurityCenter
        # Das erste Byte gibt oft den Status an (Aktiv/Inaktiv)
        $statusHex = "{0:x}" -f $avProduct.productState
        $isActive = $statusHex.Substring(1,2) -in ("10","11") # 10/11 bedeutet meist aktiv

        Write-Host "Drittanbieter erkannt: $($avProduct.displayName)"
        
        if (!$isActive) {
            Write-Host "WARNUNG: Drittanbieter-AV scheint inaktiv zu sein (State: $statusHex)"
            exit 1
        }
    }

    Write-Host "STATUS: Antivirus ist gesund."
    exit 0

} catch {
    Write-Host "FEHLER beim Auslesen des AV-Status: $($_.Exception.Message)"
    exit 2
}