#!/bin/bash
# Usage: run_do.sh <stata_cmd> <path/to/script.do> [path/to/expected.log]
#
# Runs a Stata do-file in batch mode via the given Stata executable, then
# checks the resulting log for Stata's r(###) error markers. This is the
# single source of truth for "did the .do file actually run clean" — grep
# for errors here instead of eyeballing the log, since Stata error markers
# have a fixed, greppable format.
#
# Exit code 0 = clean run (no r(###) errors found in the log).
# Exit code 1 = errors found; the offending lines are printed to stderr.
# Exit code 2 = usage error or the expected log never appeared.

set -uo pipefail

STATA_CMD="${1:-}"
DOFILE="${2:-}"
LOGFILE="${3:-}"

if [[ -z "$STATA_CMD" || -z "$DOFILE" ]]; then
  echo "Usage: run_do.sh <stata_cmd> <path/to/script.do> [path/to/expected.log]" >&2
  exit 2
fi

if [[ ! -f "$DOFILE" ]]; then
  echo "Do-file not found: $DOFILE" >&2
  exit 2
fi

DODIR=$(cd "$(dirname "$DOFILE")" && pwd)
BASE=$(basename "$DOFILE" .do)

if [[ -z "$LOGFILE" ]]; then
  LOGFILE="$DODIR/$BASE.log"
fi

# Run from the do-file's own directory so relative paths inside the .do file
# (e.g. "use Data/raw/foo.dta") resolve the same way they would if the user
# ran it manually from that folder.
( cd "$DODIR" && "$STATA_CMD" -b do "$DOFILE" )

if [[ ! -f "$LOGFILE" ]]; then
  echo "Expected log not found at $LOGFILE — check whether the .do file calls 'log using' with a different path, and pass that path explicitly as the third argument." >&2
  exit 2
fi

if grep -qE '^r\([0-9]+\);' "$LOGFILE"; then
  echo "ERRORS FOUND in $LOGFILE:" >&2
  grep -B 8 -E '^r\([0-9]+\);' "$LOGFILE" >&2
  exit 1
fi

echo "Clean run: $LOGFILE"
exit 0
