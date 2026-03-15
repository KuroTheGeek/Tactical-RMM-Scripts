# BitLocker Recovery Key für C: als Collector Task
$ErrorActionPreference = 'Stop'

try {
    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw "Get-BitLockerVolume ist auf diesem System nicht verfügbar."
    }

    $vol = Get-BitLockerVolume -MountPoint 'C:'

    if ($null -eq $vol) {
        throw "Get-BitLockerVolume hat kein Volume für C: zurückgegeben."
    }

    # Recovery-Key-Protector suchen
    $recoveryProtectors = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }

    if (-not $recoveryProtectors) {
        throw "Kein RecoveryPassword-KeyProtector für C: gefunden."
    }

    # Falls mehrere vorhanden sind, nimm den ersten
    $recoveryKey = $recoveryProtectors[0].RecoveryPassword

    if ([string]::IsNullOrWhiteSpace($recoveryKey)) {
        throw "RecoveryPassword-Eigenschaft ist leer."
    }

    # OPTIONAL: Wenn du einen Prefix willst, z.B. "C: " davor:
    # $result = "C: $recoveryKey"
    # Für reinen Key nur das:
    $result = $recoveryKey

    # WICHTIG: letzte Zeile = Collector-Wert
    Write-Output $result
}
catch {
    Write-Output "Fehler beim Auslesen des BitLocker Recovery Keys: $($_.Exception.Message)"
}
