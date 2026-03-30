<#
.SYNOPSIS
  Deinstalliert veraltete Microsoft Remote Desktop Clients (UWP & MSRDC).
#>

Write-Host "Starte Deinstallation veralteter Remote Desktop Clients..."

# 1. Entferne UWP App (Microsoft Store) für alle User und aus dem Windows-Image
Write-Host "Entferne UWP Store-App..."
Get-AppxPackage -AllUsers "*Microsoft.RemoteDesktop*" -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -match "Microsoft.RemoteDesktop" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

# 2. Entferne systemweite MSRDC Installation (MSI/EXE)
Write-Host "Entferne systemweite MSRDC Installation..."
$regPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
$installedApps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Remote Desktop" -and ($_.InstallLocation -match "Remote Desktop" -or $_.Publisher -match "Microsoft") }

foreach ($app in $installedApps) {
    if ($app.UninstallString -match "msiexec") {
        $msiArgs = "/x $($app.PSChildName) /qn /norestart"
        Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -NoNewWindow
    } elseif ($app.UninstallString) {
        $uninstallCmd = $app.UninstallString -replace '"', ''
        if (Test-Path $uninstallCmd) {
            Start-Process $uninstallCmd -ArgumentList "/S", "/SILENT" -Wait -NoNewWindow
        }
    }
}

# 3. Entferne benutzerbasierte MSRDC Installationen (AppData)
Write-Host "Entferne benutzerbasierte MSRDC Installationen..."
$userPaths = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue

foreach ($user in $userPaths) {
    $rdPath = Join-Path -Path $user.FullName -ChildPath "AppData\Local\Programs\Remote Desktop"
    if (Test-Path $rdPath) {
        $uninstaller = Join-Path -Path $rdPath -ChildPath "unins000.exe"
        if (Test-Path $uninstaller) {
            Start-Process $uninstaller -ArgumentList "/SILENT" -Wait -NoNewWindow
        }
        # Fallback: Ordner löschen, falls der Uninstaller fehlschlägt
        if (Test-Path $rdPath) {
            Remove-Item -Path $rdPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Deinstallation abgeschlossen."
exit 0