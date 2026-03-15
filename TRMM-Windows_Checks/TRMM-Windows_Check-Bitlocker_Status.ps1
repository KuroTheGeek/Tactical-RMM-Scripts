# BitLocker-Status für C: als Collector Task
$ErrorActionPreference = 'Stop'

try {
    $statusString = $null

    # Erst versuchen wir das moderne Cmdlet Get-BitLockerVolume
    if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        $vol = Get-BitLockerVolume -MountPoint 'C:'

        if ($null -eq $vol) {
            throw "Get-BitLockerVolume hat kein Volume für C: zurückgegeben."
        }

        $protectionStatus = switch ($vol.ProtectionStatus) {
            0 { "Off" }
            1 { "On" }
            2 { "Suspended" }
            default { $vol.ProtectionStatus }
        }

        $conversionStatus = $vol.VolumeStatus
        $percentEncrypted = $vol.EncryptionPercentage
        $encryptionMethod  = $vol.EncryptionMethod

        $statusString = "BitLocker C:: $conversionStatus (Protection: $protectionStatus, Encrypted: $percentEncrypted%, Method: $encryptionMethod)"
    }
    else {
        # Fallback: manage-bde -status
        $output = manage-bde -status C: 2>$null

        if (-not $output) {
            throw "manage-bde -status lieferte keine Ausgabe."
        }

        $conversion = ($output | Where-Object { $_ -match 'Conversion Status' }) -replace '.*:\s*',''
        $protection = ($output | Where-Object { $_ -match 'Protection Status' }) -replace '.*:\s*',''
        $percent    = ($output | Where-Object { $_ -match 'Percentage Encrypted' }) -replace '.*:\s*',''
        $method     = ($output | Where-Object { $_ -match 'Encryption Method' }) -replace '.*:\s*',''

        $statusString = "BitLocker C:: $conversion (Protection: $protection, Encrypted: $percent, Method: $method)"
    }

    if ([string]::IsNullOrWhiteSpace($statusString)) {
        $statusString = "Unbekannter BitLocker-Status für C:"
    }

    # WICHTIG: letzte Zeile = Collector-Wert
    Write-Output $statusString
}
catch {
    Write-Output "Fehler beim Ermitteln des BitLocker-Status: $($_.Exception.Message)"
}
