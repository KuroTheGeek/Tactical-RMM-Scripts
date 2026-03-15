<#
.SYNOPSIS
    Prüft die lokale Administratoren-Gruppe auf unerlaubte Mitglieder.
    
.DESCRIPTION
    Dieses Skript liest die Mitglieder der lokalen Admin-Gruppe sprachunabhängig aus.
    Es toleriert standardmäßig den integrierten Administrator (-500) und Domänen-Admins (-512).
    Unbekannte Benutzer oder Standard-User lösen einen RMM-Alarm aus.

.EXITCODES
    0 = Sauber (Nur erlaubte Admins)
    1 = Sicherheitsrisiko (Unerlaubte Admins gefunden)
    2 = Technischer Fehler

.NOTES
    Version: 1.0 (Neutral Edition)
#>

# --- KONFIGURATION: DEINE WHITELIST ---
# Trage hier Benutzernamen ein, die Admin sein DÜRFEN (z.B. spezielle LAPS-Accounts oder AzureAD-Admins).
# Der Standard-Administrator und Domänen-Admins müssen hier NICHT rein, die erkennt das Skript automatisch!
$AllowedNames = @(
    "DeinSpezialLAPSUser",
    "AzureAD\DeinName",
    "IT-Support"
)

# Erlaubte System-Präfixe (Dienste, die Windows für sich selbst als Admin anlegt)
$AllowedPrefixes = @("NT AUTHORITY", "NT VIRTUAL MACHINE", "Window Manager")

try {
    # 1. Lokale Admin-Gruppe sprachunabhängig (über die SID) finden
    # S-1-5-32-544 ist weltweit IMMER die lokale Administratoren-Gruppe
    $AdminGroup = Get-LocalGroup | Where-Object { $_.SID.Value -eq "S-1-5-32-544" }
    
    if (!$AdminGroup) {
        Write-Host "FEHLER: Lokale Administratoren-Gruppe nicht gefunden."
        exit 2
    }

    # 2. Alle Mitglieder der Gruppe abrufen
    $Members = Get-LocalGroupMember -Group $AdminGroup -ErrorAction Stop

    $UnauthorizedAdmins = @()

    # 3. Jedes Mitglied durch den "Türsteher" prüfen
    foreach ($Member in $Members) {
        $isAllowed = $false
        $sid = $Member.SID.Value
        $name = $Member.Name

        # REGEL 1: Der eingebaute Administrator (Oft von LAPS gemanagt) -> Endet immer auf -500
        if ($sid -match "-500$") { $isAllowed = $true }
        
        # REGEL 2: Domänen-Admins (On-Premises AD) -> Endet immer auf -512
        if ($sid -match "-512$") { $isAllowed = $true }

        # REGEL 3: Lokale System-Accounts ignorieren
        foreach ($prefix in $AllowedPrefixes) {
            if ($name -match "^$prefix\\") { $isAllowed = $true }
        }

        # REGEL 4: Deine persönliche Whitelist von oben prüfen
        foreach ($allowed in $AllowedNames) {
            # Prüft, ob der erlaubte Name am Ende des Benutzernamens steht (ignoriert Domänen-Präfixe)
            if ($name -match "(^|\\)$allowed$") { $isAllowed = $true }
        }

        # REGEL 5: Intune / Azure AD Global Administrator Rollen
        # Azure AD pusht oft SIDs in die lokale Admin-Gruppe, die nicht in Namen aufgelöst werden können.
        # Wenn der Name leer ist oder eine reine SID ist, aber zu Azure AD gehört (S-1-12-1-...), 
        # kann man diese hier wahlweise erlauben (auskommentieren, falls gewünscht):
        # if ($sid -match "^S-1-12-1-") { $isAllowed = $true }

        # Wenn keine Regel gegriffen hat -> Alarm!
        if (!$isAllowed) {
            $UnauthorizedAdmins += $name
        }
    }

    # --- PROFESSIONELLE AUSGABE FÜR DAS LOG ---
    Write-Host "===================================================="
    Write-Host "          LOCAL ADMIN SECURITY CHECK                "
    Write-Host "===================================================="
    
    if ($UnauthorizedAdmins.Count -gt 0) {
        Write-Host "STATUS: SICHERHEITSRISIKO! Unerlaubte Admins gefunden:"
        foreach ($badAdmin in $UnauthorizedAdmins) {
            Write-Host " -> $badAdmin"
        }
        Write-Host "----------------------------------------------------"
        Write-Host "HINWEIS: Bitte sofort prüfen, ob dieser User Admin-Rechte benötigt."
        exit 1
    } else {
        Write-Host "ZUSTAND: Sauber. Nur autorisierte Administratoren vorhanden."
        exit 0
    }

} catch {
    Write-Host "FEHLER: Die Administratoren-Gruppe konnte nicht geprüft werden."
    Write-Host "Möglicher Grund: Ein gelöschter Domänen-Benutzer steht noch als 'Toter Eintrag' in der Gruppe."
    Write-Host "Details: $($_.Exception.Message)"
    exit 2
}