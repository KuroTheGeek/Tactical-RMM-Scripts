<#
.SYNOPSIS
  Prüft auf veraltete Microsoft Remote Desktop Clients (Store App & MSRDC).
.DESCRIPTION
  Gibt Exit Code 1 zurück, wenn veraltete Clients gefunden wurden (für RMM-Alerts).
  Gibt Exit Code 0 zurück, wenn das System sauber ist.
#>

$foundDeprecatedClients = $false

Write-Host "Starte Überprüfung auf veraltete Microsoft Remote Desktop Clients..."
Write-Host "------------------------------------------------------------------"

# 1. Prüfung: Microsoft Store App (UWP)
try {
    # Benötigt Administrator/System-Rechte, um alle User zu prüfen
    $uwpApps = Get-AppxPackage -AllUsers -Name "Microsoft.RemoteDesktop" -ErrorAction SilentlyContinue
    if ($uwpApps) {
        Write-Host "[WARNUNG] Veraltete Microsoft Store-App gefunden:"
        $uwpApps | ForEach-Object { Write-Host "  - $($_.PackageFullName)" }
        $foundDeprecatedClients = $true
    }
} catch {
    Write-Host "[INFO] Appx-Pakete konnten nicht abgefragt werden."
}

# 2. Prüfung: Systemweiter MSI-Client (MSRDC)
$systemMsrdcPath = "${env:ProgramFiles}\Remote Desktop\msrdc.exe"
if (Test-Path $systemMsrdcPath) {
    $version = (Get-Item $systemMsrdcPath).VersionInfo.ProductVersion
    Write-Host "[WARNUNG] Systemweiter MSRDC-Client gefunden:"
    Write-Host "  - Pfad: $systemMsrdcPath (Version: $version)"
    $foundDeprecatedClients = $true
}

# 3. Prüfung: Benutzerbasierte MSRDC-Installationen (AppData)
# Oft installieren Nutzer den Client selbst ohne Admin-Rechte
$userPaths = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
$userInstallsFound = $false

foreach ($user in $userPaths) {
    $msrdcPath = Join-Path -Path $user.FullName -ChildPath "AppData\Local\Programs\Remote Desktop\msrdc.exe"
    if (Test-Path $msrdcPath) {
        if (-not $userInstallsFound) {
            Write-Host "[WARNUNG] Benutzerbasierte MSRDC-Installationen gefunden:"
            $userInstallsFound = $true
        }
        $version = (Get-Item $msrdcPath).VersionInfo.ProductVersion
        Write-Host "  - Benutzer: $($user.Name) (Version: $version)"
        $foundDeprecatedClients = $true
    }
}

Write-Host "------------------------------------------------------------------"

if ($foundDeprecatedClients) {
    Write-Host "ERGEBNIS: Veraltete Clients entdeckt. Bitte zur 'Windows App' migrieren."
    exit 1
} else {
    Write-Host "ERGEBNIS: Keine veralteten Remote Desktop Clients gefunden."
    exit 0
}