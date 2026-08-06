# run_do_gui.ps1
# Usage: powershell -File run_do_gui.ps1 -DoFile <path> -Flavor <StataBE|StataSE|StataMP|Stata>
#
# EXPERIMENTAL — not yet verified against a live Windows install. This is the Windows
# equivalent of run_do_gui.sh (which uses Mac AppleScript): it drives Stata's own OLE
# Automation interface so a .do file runs inside the actual Stata GUI, visible in the Results
# window, instead of headless. If this fails, report the exact error back — the ComObject
# name below (stata.<Flavor>OLEApp) is a best guess based on Stata's documented Automation
# interface, not something tested live yet the way the Mac version was.

param(
    [Parameter(Mandatory=$true)][string]$DoFile,
    [Parameter(Mandatory=$true)][string]$Flavor   # e.g. StataBE, StataSE, StataMP
)

if (-not (Test-Path $DoFile)) {
    Write-Error "Do-file not found: $DoFile"
    exit 2
}

$AbsPath = (Resolve-Path $DoFile).Path

try {
    $stata = New-Object -ComObject "stata.$($Flavor)OLEApp"
} catch {
    Write-Error "Could not create OLE Automation object 'stata.$($Flavor)OLEApp' - Stata Automation may not be registered, or the ProgID may be different on this install (try plain 'stata.StataOLEApp' as a fallback). Underlying error: $_"
    exit 2
}

$stata.UtilShowStata(1)   # 1 = show the Stata window, so this is actually visible

$rc = $stata.DoCommand("do `"$AbsPath`"")

if ($rc -ne 0) {
    Write-Output "Stata returned r($rc) - check the Results window for the error."
    exit 1
}

Write-Output "Clean run (r(0)) - see the Results window for output."
exit 0
