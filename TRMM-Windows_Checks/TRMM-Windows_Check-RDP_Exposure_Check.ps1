<#
.SYNOPSIS
    Prüft die RDP-Konfiguration (Remote Desktop) auf Sicherheitsrisiken.
    
.DESCRIPTION
    Dieses Skript liest die Registry-Werte für die Remote Desktop Dienste aus.
    Es schlägt Alarm, wenn RDP aktiviert ist UND die Network Level Authentication 
    (NLA) deaktiviert wurde. Optional kann es auch alarmieren, wenn RDP 
    generell aktiv ist.

.EXITCODES
    0 = Sicher (RDP deaktiviert oder RDP mit NLA aktiv)
    1 = Sicherheitsrisiko (NLA fehlt oder RDP unerwünscht aktiv)
    2 = Fehler beim Auslesen der Registry

#>

# --- KONFIGURATION ---
# Setze diesen Wert auf $true, wenn auf diesen PCs RDP *generell* verboten sein soll.
# Bei $false ist RDP erlaubt, solange NLA (Network Level Authentication) aktiv ist.
$StrictRDPDisable = $false

try {
    $tsPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
    $rdpTcpPath = "$tsPath\WinStations\RDP-Tcp"

    # 1. Prüfen, ob RDP generell aktiviert ist (0 = Aktiviert, 1 = Deaktiviert)
    $fDenyTS = (Get-ItemProperty -Path $tsPath -Name "fDenyTSConnections" -ErrorAction Stop).fDenyTSConnections

    # 2. Prüfen, ob NLA erzwungen wird (1 = NLA aktiv, 0 = NLA aus)
    $nla = (Get-ItemProperty -Path $rdpTcpPath -Name "UserAuthentication" -ErrorAction SilentlyContinue).UserAuthentication

    # 3. Den aktuell genutzten RDP-Port auslesen (Standard: 3389)
    $port = (Get-ItemProperty -Path $rdpTcpPath -Name "PortNumber" -ErrorAction SilentlyContinue).PortNumber

    # --- PROFESSIONELLE AUSGABE FÜR DAS LOG ---
    Write-Host "===================================================="
    Write-Host "             RDP SECURITY ANALYSE                   "
    Write-Host "===================================================="
    
    # Auswertung
    if ($fDenyTS -eq 1) {
        Write-Host "ZUSTAND: RDP ist komplett deaktiviert."
        Write-Host "STATUS: Sicher."
        exit 0
    }
    
    # Ab hier wissen wir: RDP ist aktiv.
    Write-Host "WARNUNG: Remote Desktop ist auf diesem System AKTIVIERT!"
    Write-Host "Konfigurierter Port: $port"

    if ($StrictRDPDisable) {
        Write-Host "STATUS: SICHERHEITSRISIKO! RDP ist aktiv, aber laut Richtlinie verboten."
        exit 1
    }

    if ($nla -ne 1) {
        Write-Host "STATUS: KRITISCHES SICHERHEITSRISIKO!"
        Write-Host "Ursache: RDP ist aktiv, aber NLA (Network Level Authentication) ist DEAKTIVIERT."
        Write-Host "HINWEIS: Das System ist extrem anfällig für Brute-Force- und Netzwerk-Attacken."
        exit 1
    } else {
        Write-Host "ZUSTAND: RDP ist aktiv, aber durch NLA geschützt."
        Write-Host "STATUS: Akzeptabel (laut aktueller Richtlinie)."
        exit 0
    }

} catch {
    Write-Host "FEHLER: Die RDP-Konfiguration konnte nicht ausgelesen werden."
    Write-Host "Details: $($_.Exception.Message)"
    exit 2
}