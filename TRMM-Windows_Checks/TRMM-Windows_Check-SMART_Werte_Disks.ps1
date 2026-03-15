<#
.SYNOPSIS
    Prüft die SMART-Werte und den Gesundheitsstatus aller physischen Laufwerke.
    
.DESCRIPTION
    Dieses Skript scannt alle angeschlossenen physischen Datenträger (HDD, SSD, NVMe).
    Es wertet den 'HealthStatus' und die 'OperationalStatus' aus.
    Bei SSDs wird zusätzlich die verbleibende Lebensdauer (Wear Indicator) geprüft.

.PARAMETER LifeThreshold
    Standard: 10%. Wenn die verbleibende Lebensdauer einer SSD unter diesen Wert fällt, gibt das Skript Exit 1 aus.

.EXITCODES
    0 = Alle Laufwerke sind gesund (Healthy)
    1 = Mindestens ein Laufwerk meldet Fehler oder niedrige Lebensdauer
    2 = Technischer Fehler beim Auslesen der Speicherdaten

#>

$lifeThreshold = 10
$globalHealth = $true
$report = @()

try {
    # Alle physischen Disks abrufen
    $disks = Get-PhysicalDisk | Sort-Object DeviceId

    foreach ($disk in $disks) {
        $diskInfo = [PSCustomObject]@{
            ID          = $disk.DeviceId
            Model       = $disk.FriendlyName
            Type        = $disk.MediaType
            Status      = $disk.HealthStatus
            Operational = $disk.OperationalStatus -join ", "
            Remaining   = "N/A"
        }

        # Statusprüfung
        if ($disk.HealthStatus -ne "Healthy") {
            $globalHealth = $false
        }

        # Zusätzliche Prüfung für SSD/NVMe Lebensdauer (falls unterstützt)
        if ($disk.MediaType -eq "SSD") {
            $storageReliability = $disk | Get-StorageReliabilityCounter
            if ($null -ne $storageReliability.Wear) {
                $remainingLife = 100 - $storageReliability.Wear
                $diskInfo.Remaining = "$remainingLife %"
                
                if ($remainingLife -lt $lifeThreshold) {
                    $globalHealth = $false
                }
            }
        }

        $report += $diskInfo
    }

    # Ergebnisausgabe für das Tactical RMM Log
    $report | Format-Table -AutoSize | Out-String | Write-Host

    if ($globalHealth) {
        Write-Host "STATUS: Alle Laufwerke sind in einem gesunden Zustand."
        exit 0
    } else {
        Write-Host "WARNUNG: Mindestens ein Laufwerk meldet Probleme oder erreicht das Lebensende!"
        exit 1
    }

} catch {
    Write-Host "FEHLER: Die SMART-Werte konnten nicht vollständig gelesen werden."
    Write-Host "Details: $($_.Exception.Message)"
    exit 2
}