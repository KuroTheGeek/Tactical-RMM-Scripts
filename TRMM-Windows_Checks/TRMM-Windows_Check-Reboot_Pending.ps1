<#
.SYNOPSIS
    Prüft, ob ein Systemneustart ausstehend ist (Pending Reboot).
    
.DESCRIPTION
    Dieses Skript scannt die bekannten Windows-Registry-Schlüssel, um herauszufinden, 
    ob das System auf einen Neustart wartet. Dies kann durch Windows Updates, 
    Software-Installationen oder Server-Rollen ausgelöst werden.

.EXITCODES
    0 = Kein Neustart erforderlich
    1 = Neustart ausstehend (Alarm)
    2 = Technischer Fehler beim Auslesen der Registry

.NOTES
    Autor: Dein Name
    Version: 1.0
#>

$rebootPending = $false
$reasons = @()

try {
    # 1. Component Based Servicing (CBS) - Oft bei tiefgreifenden Windows Updates
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $rebootPending = $true
        $reasons += "Component Based Servicing (Windows System Updates)"
    }

    # 2. Windows Update - Klassische Updates
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $rebootPending = $true
        $reasons += "Windows Update (Patch Management)"
    }

    # 3. Pending File Rename Operations - Oft bei Drittanbieter-Software (Installer/Updater)
    $sessionManager = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($null -ne $sessionManager.PendingFileRenameOperations) {
        $rebootPending = $true
        $reasons += "Pending File Rename Operations (Software Installation/Update)"
    }

    # 4. Server Manager - Nur relevant für Windows Server (Rollen/Features)
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentInstall\RebootRequired") {
        $rebootPending = $true
        $reasons += "Server Manager (Rollen/Features)"
    }

    # --- PROFESSIONELLE AUSGABE FÜR DAS LOG ---
    Write-Host "===================================================="
    Write-Host "             PENDING REBOOT ANALYSE                 "
    Write-Host "===================================================="

    if ($rebootPending) {
        Write-Host "STATUS: Ein Neustart ist zwingend erforderlich!"
        Write-Host "AUSLÖSER:"
        foreach ($reason in $reasons) {
            Write-Host " -> $reason"
        }
        Write-Host "----------------------------------------------------"
        Write-Host "HINWEIS: Bitte den Rechner zeitnah neu starten, um Probleme zu vermeiden."
        exit 1
    } else {
        Write-Host "ZUSTAND: Kein Neustart ausstehend. Das System ist sauber."
        exit 0
    }

} catch {
    Write-Host "FEHLER: Die Registry-Schlüssel konnten nicht geprüft werden."
    Write-Host "Details: $($_.Exception.Message)"
    exit 2
}