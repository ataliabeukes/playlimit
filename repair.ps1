# PlayLimit one-click repair / forced update.
# Use on a machine stuck on an old version (e.g. "Failed to load Python DLL").
# repair.bat downloads this file and runs it elevated.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$data = Join-Path $env:ProgramData "AlbionLimiter"
New-Item -ItemType Directory -Force -Path $data | Out-Null
$logFile = Join-Path $data "repair.log"

function Log($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line
    try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch { }
}
function Fail($msg) {
    Log "FAILED: $msg"
    Write-Host ""
    Write-Host "Repair failed. Run diag.bat and send repair.log + the diagnostics." -ForegroundColor Red
    throw $msg
}

Write-Host "PlayLimit REPAIR / FORCED UPDATE" -ForegroundColor Green
Log "=== repair start ==="
Log ("user=" + [System.Security.Principal.WindowsIdentity]::GetCurrent().Name)

$isAdmin = ([Security.Principal.WindowsPrincipal] [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
Log "admin=$isAdmin"
if (-not $isAdmin) { Fail "Run as Administrator (repair.bat does this automatically)." }

$base = "https://raw.githubusercontent.com/beukes2/playlimit/master"
$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$live = Join-Path $data "PlayLimit.exe"
$tmpExe = Join-Path $env:TEMP "PlayLimit_repair_$stamp.exe"

try {
    Log "downloading version.txt"
    $ver = (Invoke-WebRequest -Uri "$base/version.txt?t=$stamp" -UseBasicParsing -TimeoutSec 30).Content.Trim()
    if (-not $ver) { Fail "remote version.txt is empty" }
    Log "remote version: $ver"

    Log "downloading dist/PlayLimit.exe"
    Invoke-WebRequest -Uri "$base/dist/PlayLimit.exe?t=$stamp" -OutFile $tmpExe -UseBasicParsing -TimeoutSec 180

    Log "downloading dist/PlayLimit.exe.sha256"
    $shaText = (Invoke-WebRequest -Uri "$base/dist/PlayLimit.exe.sha256?t=$stamp" -UseBasicParsing -TimeoutSec 30).Content
    $expected = ($shaText -split '\s+')[0].Trim().ToLower()
    $actual = (Get-FileHash -LiteralPath $tmpExe -Algorithm SHA256).Hash.ToLower()
    if (-not $expected -or $actual -ne $expected) {
        Fail "SHA256 mismatch (downloaded $actual, expected $expected)"
    }
    Log "SHA256 verified: $actual"

    $exeVer = (Get-Item -LiteralPath $tmpExe).VersionInfo.FileVersion
    Log "downloaded exe version: $exeVer"
    if ("$exeVer".Trim() -ne "$ver".Trim()) {
        Fail "version mismatch: version.txt=$ver but exe FileVersion=$exeVer"
    }

    Log "stopping PlayLimit"
    $procs = Get-Process -Name PlayLimit -ErrorAction SilentlyContinue
    if ($procs) {
        Log ("stopping pids: " + ($procs.Id -join ", "))
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    for ($i = 0; $i -lt 20; $i++) {
        if (-not (Get-Process -Name PlayLimit -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 500
    }
    if (Get-Process -Name PlayLimit -ErrorAction SilentlyContinue) {
        Fail "PlayLimit is still running and cannot be replaced"
    }

    if (Test-Path -LiteralPath $live) {
        $backup = "$live.bak"
        Copy-Item -LiteralPath $live -Destination $backup -Force
        Log "backup: $backup"
    }

    Log "replacing live exe"
    $replaced = $false
    for ($i = 0; $i -lt 20; $i++) {
        try {
            Copy-Item -LiteralPath $tmpExe -Destination $live -Force -ErrorAction Stop
            $replaced = $true
            break
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $replaced) { Fail "could not replace $live (file locked / access denied)" }

    $liveHash = (Get-FileHash -LiteralPath $live -Algorithm SHA256).Hash.ToLower()
    if ($liveHash -ne $expected) { Fail "post-copy SHA256 mismatch on $live" }
    Log "live exe verified: $liveHash"

    Remove-Item -LiteralPath "$data\PlayLimit.staged.exe" -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$data\PlayLimit.staged.ver" -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$data\PlayLimit.bad.ver" -Force -ErrorAction SilentlyContinue

    # Stale PyInstaller extraction dirs can make the next launch load a missing
    # python3xx.dll. The running app cleans these at startup; do it here too.
    Log "cleaning stale PyInstaller _MEI dirs"
    Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter "_MEI*" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # The old app's helper leaks PyInstaller's private onefile variables into the
    # replacement process. Never pass them to the repaired exe.
    Get-ChildItem Env: | Where-Object { $_.Name -like '_PYI_*' } | Remove-Item -ErrorAction SilentlyContinue
    $env:PYINSTALLER_RESET_ENVIRONMENT = "1"

    Log "starting $live"
    Start-Process -FilePath $live
    Start-Sleep -Seconds 5
    $p = Get-Process -Name PlayLimit -ErrorAction SilentlyContinue
    if ($p) {
        Log ("running pids: " + ($p.Id -join ", "))
        Log ("installed version: " + (Get-Item -LiteralPath $live).VersionInfo.FileVersion)
        Log "=== repair OK ==="
        Write-Host ""
        Write-Host "Repair complete. PlayLimit is running the latest version." -ForegroundColor Green
    } else {
        Fail "the repaired exe did not stay running - run diag.bat and send repair.log"
    }
} catch {
    Log ("repair error: " + $_.Exception.Message)
    throw
} finally {
    Remove-Item -LiteralPath $tmpExe -Force -ErrorAction SilentlyContinue
}
