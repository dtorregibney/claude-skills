# run_do_gui_cli.ps1
# Usage: powershell -File run_do_gui_cli.ps1 -DoFile <path> [-StataCmd <path>] [-TimeoutSec 300]
#
# Windows GUI mode that needs NO administrator rights. Runs a .do file inside Stata's
# real, visible window -- Results output appears live, and the data stays loaded when it
# finishes so the user can keep poking at it.
#
# Why this exists alongside run_do_gui.ps1: that script drives Stata's OLE Automation
# interface, which first has to be registered by running "StataBE-64.exe /Register" from
# an ELEVATED prompt. On a managed/work machine the user often simply cannot do that, which
# left them with no GUI option at all. This script needs nothing registered: Stata's own
# command line runs a do-file in the GUI whenever the batch flag (/e) is omitted.
#
# Verified live on Stata/BE 18.0, Windows 11.
#
# Tradeoff vs. OLE: launching the GUI this way does NOT hand back Stata's return code, so
# correctness is judged from the log -- exactly as the headless run_do.sh does, grepping for
# Stata's fixed r(###) error format. That makes an explicit "log using" in the .do file
# MANDATORY here (the skill's standard file shape already requires one). Without it Stata
# writes no log in GUI mode and there is nothing to verify against.
#
# Exit code 0 = clean run (log appeared, no r(###) errors).
# Exit code 1 = errors found; the offending lines are printed.
# Exit code 2 = usage error, or the log never appeared/updated before the timeout.

param(
    [Parameter(Mandatory=$true)][string]$DoFile,
    [string]$StataCmd,
    [string]$LogFile,
    [int]$TimeoutSec = 300,
    # Separate, much shorter budget for the log to first APPEAR. A run that's genuinely slow
    # keeps extending the main timeout as the log grows, but a .do file that dies before its
    # "log using" ever executes produces no log at all -- and waiting the full TimeoutSec to
    # discover that turns an instant, obvious failure into a five-minute hang. Hit live: a .do
    # file saved with a UTF-8 BOM failed on line 1, wrote nothing, and burned the whole timeout.
    [int]$LogAppearSec = 45
)

if (-not (Test-Path $DoFile)) {
    Write-Error "Do-file not found: $DoFile"
    exit 2
}

$AbsDo   = (Resolve-Path $DoFile).Path
$DoDir   = Split-Path $AbsDo -Parent
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($AbsDo)

# Fall back to the stata_cmd recorded by Step 0 setup, so callers don't have to pass it.
if (-not $StataCmd) {
    $cfgPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config.json"
    if (Test-Path $cfgPath) {
        $StataCmd = (Get-Content $cfgPath -Raw | ConvertFrom-Json).stata_cmd
    }
}
if (-not $StataCmd -or -not (Test-Path $StataCmd)) {
    Write-Error "Stata executable not found. Pass -StataCmd, or set stata_cmd in config.json. Got: '$StataCmd'"
    exit 2
}

if (-not $LogFile) { $LogFile = Join-Path $DoDir "$BaseName.log" }

# Note the existing log's timestamp rather than deleting it. A stale log from a previous run
# must not be mistaken for this run's output, but deleting files to achieve that is a bad
# trade -- so instead we wait for the timestamp to actually move.
$PrevWrite = $null
if (Test-Path $LogFile) { $PrevWrite = (Get-Item $LogFile).LastWriteTimeUtc }

# Omitting /e is the whole trick: Stata opens its normal window and runs the file in it.
# -WorkingDirectory matches run_do.sh's behaviour, so relative paths inside the .do file
# (and a relative "log using") resolve from the do-file's own folder.
Start-Process -FilePath $StataCmd -ArgumentList 'do',"$BaseName.do" -WorkingDirectory $DoDir | Out-Null

# Stata's GUI stays open after the run by design (that's the point -- the user keeps the
# loaded data), so we can't wait on process exit. Watch the log instead: it's finished when
# Stata's own "closed on:" footer appears, or an r(###) error aborted it, or it simply stops
# growing.
$started     = Get-Date
$deadline    = $started.AddSeconds($TimeoutSec)
$appearBy    = $started.AddSeconds($LogAppearSec)
$lastLen     = -1
$stableTicks = 0
$done        = $false
$appeared    = $false

while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500

    if (-not $appeared -and (Get-Date) -gt $appearBy) {
        Write-Error "No log at $LogFile after $LogAppearSec s, so the .do file almost certainly failed before its 'log using' line ever ran. Look at Stata's window -- the error is on screen. Two common causes: the .do file has no 'log using' at all (mandatory in GUI mode), or it was saved with a UTF-8 BOM, which makes Stata fail on line 1."
        exit 2
    }

    if (-not (Test-Path $LogFile)) { continue }
    $item = Get-Item $LogFile
    if ($PrevWrite -and $item.LastWriteTimeUtc -le $PrevWrite) { continue }  # still the old log
    $appeared = $true

    $text = Get-Content $LogFile -Raw -ErrorAction SilentlyContinue
    if ($null -eq $text) { continue }

    if ($text -match '(?m)^\s*closed on:' -or $text -match '(?m)^r\(\d+\);') { $done = $true; break }

    # Fallback for a .do file that errored out before reaching its "log close": once the
    # file has stopped growing for ~2.5s, treat the run as over.
    if ($item.Length -eq $lastLen) {
        $stableTicks++
        if ($stableTicks -ge 5) { $done = $true; break }
    } else {
        $stableTicks = 0
        $lastLen = $item.Length
    }
}

if (-not $done) {
    Write-Error "Log at $LogFile never appeared or never finished within $TimeoutSec s. Check that the .do file calls 'log using' (required in GUI mode -- Stata writes no automatic log here), and that Stata's window actually opened."
    exit 2
}

$errLines = Select-String -Path $LogFile -Pattern '^r\(\d+\);' -AllMatches
if ($errLines) {
    Write-Output "ERRORS FOUND in ${LogFile}:"
    Get-Content $LogFile | Select-String -Pattern '^r\(\d+\);' -Context 8,0 | ForEach-Object { $_.ToString() }
    exit 1
}

Write-Output "Clean run: $LogFile (ran in Stata's GUI -- window left open with data loaded)"
exit 0
