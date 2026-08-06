* Smoke test used only during first-time setup, to confirm Claude can drive
* this machine's Stata install end to end: launch, load data, run a real
* command, and exit clean. Not part of any actual analysis.
display "Stata connection OK"
sysuse auto, clear
summarize price mpg
display "SMOKE TEST PASSED"
