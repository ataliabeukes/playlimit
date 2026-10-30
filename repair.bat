@echo off
REM PlayLimit one-click repair / forced update.
REM Download this file and double-click it on a machine stuck on an old version.
setlocal
echo ============================================================
echo  PlayLimit REPAIR / FORCED UPDATE
echo ============================================================
echo.
echo Downloading the latest repair script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/beukes2/playlimit/master/repair.ps1?t=%RANDOM%' -OutFile (Join-Path $env:TEMP 'PlayLimit-repair.ps1') } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
    echo.
    echo Could not download repair.ps1. Check the internet connection.
    pause
    exit /b 1
)
echo.
echo Accept the UAC prompt to run the repair as Administrator.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',(Join-Path $env:TEMP 'PlayLimit-repair.ps1'))"
echo.
echo A new Administrator window is running the repair. Follow it there.
pause
