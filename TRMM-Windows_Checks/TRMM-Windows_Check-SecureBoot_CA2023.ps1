<#
.SYNOPSIS
    Prüft den Secure Boot Status und die Windows UEFI CA 2023.
    Behandelt den Fehler 0xC0000100 (Variable nicht definiert).
#>

try {
    # 1. Prüfen, ob wir im UEFI-Modus sind
    $isUEFI = $false
    if (Test-Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State") {
        $isUEFI = $true
    } elseif ($env:firmware_type -eq "UEFI") {
        $isUEFI = $true
    }

    if (!$isUEFI) {
        Write-Host "STATUS: System läuft im Legacy (BIOS) Modus. Kein Secure Boot möglich."
        exit 0 # Oder 2, falls du Legacy-Systeme als Fehler markieren willst
    }

    # 2. Secure Boot Status ermitteln
    $sbActive = $false
    try { $sbActive = Confirm-SecureBootUEFI } catch { $sbActive = $false }
    $sbStatusText = if ($sbActive) { "AKTIVIERT" } else { "DEAKTIVIERT" }

    # 3. UEFI-Datenbank (db) sicher auslesen
    $has2023CA = $false
    $dbError = $null

    try {
        $sig = Get-SecureBootUEFI -Name db -ErrorAction Stop
        if ($sig -and $sig.Bytes) {
            $content = [System.Text.Encoding]::ASCII.GetString($sig.Bytes)
            if ($content -match "Windows UEFI CA 2023") {
                $has2023CA = $true
            }
        }
    } catch {
        $dbError = $_.Exception.Message
    }

    # 4. Ergebnisausgabe
    Write-Host "--- Secure Boot Analyse ---"
    Write-Host "Secure Boot Status: $sbStatusText"

    if ($has2023CA) {
        Write-Host "Windows UEFI CA 2023: VORHANDEN"
        exit 0
    } elseif ($dbError -match "0xC0000100") {
        Write-Host "Windows UEFI CA 2023: NICHT DEFINIERT (BIOS-Keys fehlen oder Secure Boot nie initialisiert)"
        exit 1
    } else {
        Write-Host "Windows UEFI CA 2023: FEHLT (Zertifikat nicht in der DB gefunden)"
        exit 1
    }

} catch {
    Write-Host "KRITISCHER FEHLER: $($_.Exception.Message)"
    exit 2
}