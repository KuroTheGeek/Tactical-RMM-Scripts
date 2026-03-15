# Collector-geeignetes Script: letzte Ausgabezeile = Wert fürs Custom Field
$ErrorActionPreference = 'Stop'

try {
    # OS-Infos holen
    $os = Get-CimInstance Win32_OperatingSystem

    # Zusätzliche Versionsinfos aus der Registry holen
    $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

    # 24H2 / 22H2 / 21H2 / etc.
    $displayVersion = $cv.DisplayVersion
    if (-not $displayVersion) {
        # Fallback für ältere Windows 10 Builds
        $displayVersion = $cv.ReleaseId
    }
    if (-not $displayVersion) {
        $displayVersion = 'Unbekannt'
    }

    # Build inkl. UBR (Update Build Revision), z.B. 26100.2033
    $build = $cv.CurrentBuild
    $ubr   = $cv.UBR
    if ($ubr -is [int] -and $ubr -gt 0) {
        $buildFull = "{0}.{1}" -f $build, $ubr
    } else {
        $buildFull = $build
    }

    # String so formatieren, wie du ihn im Custom Field sehen willst
    # Beispiel: "Microsoft Windows 11 Pro 24H2 (Version 10.0.26100, Build 26100.2033, 64-bit)"
    $result = "{0} {1} (Version {2}, Build {3}, {4})" -f `
        $os.Caption.Trim(), `
        $displayVersion, `
        $os.Version, `
        $buildFull, `
        $os.OSArchitecture

    # WICHTIG: letzte Zeile ist der Collector-Wert
    Write-Output $result
}
catch {
    # Falls irgendwas schiefgeht: trotzdem verständlichen Text zurückgeben
    Write-Output "Fehler beim Ermitteln der Windows-Version: $($_.Exception.Message)"
}
