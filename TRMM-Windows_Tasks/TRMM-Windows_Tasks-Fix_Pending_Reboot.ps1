<#
.SYNOPSIS
    Bereinigt hängende Neustart-Einträge komplett (PendingFileRenameOperations).
#>

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
$regName = "PendingFileRenameOperations"

try {
    # WICHTIG: Wir löschen den Eintrag KOMPLETT (Remove), anstatt ihn nur zu leeren.
    Remove-ItemProperty -Path $regPath -Name $regName -Force -ErrorAction Stop
    
    Write-Host "ERFOLG: Der 'PendingFileRenameOperations' Eintrag wurde restlos gelöscht!"
    exit 0
} catch {
    Write-Host "FEHLER: Konnte den Schlüssel nicht bereinigen."
    Write-Host "Details: $($_.Exception.Message)"
    exit 1
}