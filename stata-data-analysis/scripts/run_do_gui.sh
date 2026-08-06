#!/bin/bash
# Usage: run_do_gui.sh <path/to/script.do> <stata_app_name>
#
# Runs a Stata do-file inside the actual Stata GUI (not headless), via Stata's Mac AppleScript
# automation interface (DoCommand) — so the user can watch it execute live in Stata's own Results
# window, and we get Stata's real _rc return code back directly, no log-grepping needed.
#
# <stata_app_name> is the .app name AppleScript needs (e.g. "StataBE", "StataSE", "StataMP") —
# comes from the "flavor" field in config.json (see stata-data-analysis SKILL.md Step 0).
#
# Exit code 0 = Stata returned r(0) (clean run).
# Exit code 1 = Stata returned a nonzero rc; the code is printed so the offending r(###) is visible.
# Exit code 2 = usage error, missing do-file, or Stata never became reachable.

set -uo pipefail

DOFILE="${1:-}"
STATA_APP="${2:-}"

if [[ -z "$DOFILE" || -z "$STATA_APP" ]]; then
  echo "Usage: run_do_gui.sh <path/to/script.do> <stata_app_name>" >&2
  exit 2
fi

if [[ ! -f "$DOFILE" ]]; then
  echo "Do-file not found: $DOFILE" >&2
  exit 2
fi

ABSPATH=$(cd "$(dirname "$DOFILE")" && pwd)/$(basename "$DOFILE")

# Make sure the GUI is actually running before sending it a command — DoCommand has nothing to
# talk to otherwise.
if ! pgrep -f "$STATA_APP" >/dev/null; then
  open -a "$STATA_APP"
  sleep 4
fi

RC=$(osascript -e "tell application \"$STATA_APP\" to DoCommand \"do \\\"$ABSPATH\\\"\"" 2>&1)

# DoCommand executes fully and updates the underlying document even without this, but the visible
# Results pane doesn't reliably repaint on its own afterward — an explicit activate forces it to,
# which is the whole point of GUI mode (the user watching it happen, not just it having happened).
osascript -e "tell application \"$STATA_APP\" to activate" >/dev/null 2>&1

if ! [[ "$RC" =~ ^-?[0-9]+$ ]]; then
  echo "AppleScript call failed (Stata may not have been ready): $RC" >&2
  exit 2
fi

if [[ "$RC" != "0" ]]; then
  echo "Stata returned r($RC) — check the Results window for the error." >&2
  exit 1
fi

echo "Clean run (r(0)) — see the Results window for output."
exit 0
