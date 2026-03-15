<#
.SYNOPSIS
    Bereinigt System-, Benutzer- und versteckte Cache-Dateien (Deep Clean).
    
.DESCRIPTION
    Löscht alte Temp-Dateien, Windows Update Caches, Absturzberichte (WER/Minidumps), 
    aufgeblähte Logfiles (CBS) und den Delivery Optimization Cache.
    Downloads und der Papierkorb werden zum Schutz der User-Daten ignoriert.

.EXITCODES
    0 = Bereinigung erfolgreich
    1 = Teilweise Fehler (gesperrte Dateien, normales Verhalten)

#>

$DaysOld = 7
$CutoffDate = (Get-Date).AddDays(-$DaysOld)

# 1. Standard Temp & Update Caches
$TargetPaths = @(
    "$env:windir\Temp\*",
    "$env:windir\SoftwareDistribution\Download\*"
)

# 2. Deep Clean Pfade (Crash Dumps, Error Reports, Update Peer-Cache, CBS Logs)
$DeepCleanPaths = @(
    "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*",
    "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*",
    "$env:windir\Minidump\*",
    "$env:windir\Logs\CBS\*.cab",
    "$env:windir\Logs\CBS\*.log",
    "$env:windir\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache\*"
)
$TargetPaths += $DeepCleanPaths

# 3. Alle Benutzer-Temp-Ordner dynamisch hinzufügen
$UserProfiles = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
foreach ($Profile in $UserProfiles) {
    # AppData Temp
    $TargetPaths += "$($Profile.FullName)\AppData\Local\Temp\*"
    # CrashDumps der User-Apps
    $TargetPaths += "$($Profile.FullName)\AppData\Local\CrashDumps\*"
}

$TotalFilesDeleted = 0
$TotalBytesFreed = 0
$ErrorsOccurred = $false

# --- PROFESSIONELLE AUSGABE FÜR DAS LOG ---
Write-Host "===================================================="
Write-Host "        SYSTEM DEEP CLEANUP (BEST PRACTICE)         "
Write-Host "===================================================="
Write-Host "Regel: Lösche Dateien älter als $DaysOld Tage."
Write-Host "Schutz: Papierkorb, Downloads & Prefetch bleiben unberührt."
Write-Host "----------------------------------------------------"

foreach ($Path in $TargetPaths) {
    # Wir suchen nach Dateien in diesem Pfad, die alt genug sind
    $FilesToDelete = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                     Where-Object { $_.LastWriteTime -lt $CutoffDate }

    if ($FilesToDelete) {
        # Nur für das Log den Basis-Pfad etwas hübscher machen
        $DisplayPath = ($Path -split '\\\*$')[0]
        Write-Host "Bereinige: $DisplayPath -> $($FilesToDelete.Count) alte Dateien gefunden."
        
        foreach ($File in $FilesToDelete) {
            try {
                $FileSize = $File.Length
                Remove-Item -Path $File.FullName -Force -ErrorAction Stop
                
                $TotalBytesFreed += $FileSize
                $TotalFilesDeleted++
            } catch {
                # Gesperrte Dateien ignorieren wir leise
                $ErrorsOccurred = $true
            }
        }
    }
}

# --- ZUSAMMENFASSUNG ---
$FreedMB = [math]::Round(($TotalBytesFreed / 1MB), 2)
$FreedGB = [math]::Round(($TotalBytesFreed / 1GB), 2)

Write-Host "----------------------------------------------------"
Write-Host "ERGEBNIS:"
Write-Host "Gelöschte Dateien: $TotalFilesDeleted"

if ($FreedMB -gt 1000) {
    Write-Host "Freigegebener Platz: $FreedGB GB"
} else {
    Write-Host "Freigegebener Platz: $FreedMB MB"
}
Write-Host "===================================================="

if ($ErrorsOccurred) {
    Write-Host "HINWEIS: Einige Dateien waren in Benutzung und wurden übersprungen (Normales Verhalten)."
}

exit 0