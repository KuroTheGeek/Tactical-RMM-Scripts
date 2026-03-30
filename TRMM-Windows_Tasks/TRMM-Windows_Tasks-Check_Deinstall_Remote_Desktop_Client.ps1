<#
.SYNOPSIS
  Prüft auf alte RD Clients, deinstalliert diese bei Fund und gibt einen Bericht aus.
#>

$foundItems = @()
$actionsTaken = @()

Write-Host "=== Prüfung auf veraltete Remote Desktop Clients ==="

# 1. UWP App prüfen
$uwpApps = Get-AppxPackage -AllUsers "*Microsoft.RemoteDesktop*" -ErrorAction SilentlyContinue
if ($uwpApps) {
    $foundItems += "UWP Store-App (Microsoft.RemoteDesktop)"
    $uwpApps | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -match "Microsoft.RemoteDesktop" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    $actionsTaken += "UWP Store-App wurde deinstalliert."
}

# 2. Systemweite Installation prüfen
$regPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
$systemApps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Remote Desktop" -and $_.InstallLocation -match "Remote Desktop" }

if ($systemApps) {
    $foundItems += "Systemweiter MSRDC-Client"
    foreach ($app in $systemApps) {
        if ($app.UninstallString -match "msiexec") {
            Start-Process msiexec.exe -ArgumentList "/x $($app.PSChildName) /qn /norestart" -Wait -NoNewWindow
        }
    }
    $actionsTaken += "Systemweiter MSRDC-Client wurde deinstalliert."
}

# 3. Benutzerbasierte Installation prüfen
$userPaths = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
$userInstalls = 0

foreach ($user in $userPaths) {
    $rdPath = Join-Path -Path $user.FullName -ChildPath "AppData\Local\Programs\Remote Desktop"
    if (Test-Path $rdPath) {
        $userInstalls++
        $uninstaller = Join-Path -Path $rdPath -ChildPath "unins000.exe"
        if (Test-Path $uninstaller) {
            Start-Process $uninstaller -ArgumentList "/SILENT" -Wait -NoNewWindow
        }
        if (Test-Path $rdPath) { Remove-Item -Path $rdPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

if ($userInstalls -gt 0) {
    $foundItems += "Benutzerbasierte MSRDC-Installation ($userInstalls Profil(e))"
    $actionsTaken += "Benutzerbasierte MSRDC-Installationen wurden gelöscht."
}

Write-Host "------------------------------------------------"
if ($foundItems.Count -gt 0) {
    Write-Host "[MELDUNG] Folgende veraltete Clients wurden gefunden und entfernt:"
    $foundItems | ForEach-Object { Write-Host " - $_" }
    Write-Host "`nStatus der Aktionen:"
    $actionsTaken | ForEach-Object { Write-Host " + $_" }
    exit 1 # Exit 1, damit Tactical RMM anzeigt, dass hier eingegriffen wurde
} else {
    Write-Host "[MELDUNG] Das System ist sauber. Keine alten RD-Clients gefunden."
    exit 0 # Exit 0 = alles okay, kein Eingriff nötig
}