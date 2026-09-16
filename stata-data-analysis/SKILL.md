---
name: stata-data-analysis
description: >
  Write, run, and debug Stata .do files for quantitative data analysis — data cleaning, merging,
  descriptive statistics, regressions, survival/duration models, or any other statistical task.
  Use this skill whenever the user asks to clean, merge, describe, tabulate, or analyze a dataset,
  run a regression or survival model, check for duplicates, QA a merge, or do any other
  quantitative/statistical work — especially in a directory that already contains .do or .dta
  files — even if they never say the word "Stata". Also use it when the user wants a results table
  exported for review, or a chart built from analysis output. Handles first-time setup (locating
  and verifying the user's Stata install) automatically the first time it runs on a machine — safe
  to invoke even if Stata has never been connected before. Never fall back to Python/pandas for the
  underlying analysis — Stata is the only tool used for cleaning, descriptives, and modeling in
  this workflow. For a dataset that hasn't been cleaned yet (raw client data, duplicates, missing
  data, multiple sources to merge), use the stata-data-cleaning skill first — it covers the
  cleaning checklist and verification loop in depth; come back here once a clean, modified dataset
  exists.
---

# Stata Data Analysis

This skill exists because the analysis itself — the cleaning, the merges, the models — has to be
done in Stata, not Python, and has to actually run before it's handed back. A `.do` file that
looks right but has never been executed isn't a deliverable; it's a guess. Everything below is in
service of two things: writing Stata code that follows the project's own conventions, and proving
it runs clean before calling it done.

**Before sending any response that touched Stata or project data, check this list.** These are
the specific ways this skill has actually been observed to slip — not hypothetical risks, real
ones from real sessions. A rule written once in a Step below is easy to lose track of mid-task;
this list exists to be re-scanned every single time, right before responding, not read once and
trusted to stick:
- Did any code touch real project data to answer a real question? → it belongs in `Programs/` as
  a saved, numbered script — never a scratch/tmp file, no matter how small the check felt.
- Was it actually *run* (via Step 3's GUI-or-headless loop), not just written and described?
- If GUI mode is available for this machine, was it used — not headless — unless the user asked
  for headless specifically?
- Once the run was clean, was the finished `.do` file actually shown to the user (inline or
  linked) — not just left on disk while only the results got reported?
- If GUI mode was used, is there actual confirmation the user saw it happen (not just that the
  return code was `0`) — a silent success on my end is not the same as them watching it happen.

## Step 0 — First-time setup (only runs once per machine)

Check whether `~/.claude/skills/stata-data-analysis/config.json` exists.

**If it exists:** read the `stata_cmd` field and skip straight to Step 1. Don't re-verify or ask
about setup again — that would be annoying for a returning user.

**If it doesn't exist, this is the first time this skill has run on this machine.** Tell the user
briefly what's about to happen, then:

1. **Locate Stata.** Try, in order:
   - `which stata`, `which stata-mp`, `which stata-se`, `which StataBE`, `which StataMP`, `which StataSE`
   - Common macOS install locations: `/Applications/Stata*/*.app/Contents/MacOS/*`, `/Applications/StataNow/*.app/Contents/MacOS/*`
   - Common Windows/Linux locations if relevant: `C:\Program Files\Stata*`, `/usr/local/stata*`
   - If nothing is found automatically, ask the user for the path to their Stata executable, or the command they normally type to launch Stata.
2. **Confirm the flavor with the user** if more than one candidate turns up (BE/SE/MP matter — they're different binaries with different licenses/speed, not interchangeable). The flavor's app name (e.g. `StataBE`) is also what drives GUI automation below — it has to be the actual `.app` name, not just any label.
3. **Run the headless smoke test.** Use `scripts/run_do.sh <stata_cmd> scripts/smoke_test.do <path-to-a-scratch-log>` (a temp directory is fine — this isn't a real analysis). Confirm the log contains `SMOKE TEST PASSED` and no `r(###)` error lines.
   - If it fails, troubleshoot with the user before going further — common causes are a wrong path, a missing license, or the binary needing to run from a specific working directory. Don't silently retry with guesses; explain what failed and ask.
4. **Also check for GUI automation, branching by OS** (this is what lets the user watch output
   live in Stata's own Results window instead of reading a log file — worth setting up even if not
   asked, since it's strictly better once confirmed working). The mechanism is completely
   different per OS — detect which platform this is first, don't assume Mac:

   **macOS** (well-tested — this path has been verified live, not just written from docs):
   - Check for a scripting dictionary: `find /Applications -iname "*.sdef" -path "*Stata*"`. If one
     exists, the app supports AppleScript automation via a `DoCommand` verb.
   - **Tell the user what to expect before running the test, not after it fails**: the very first
     time any app sends Stata a command this way, macOS will very likely pop up a one-time system
     dialog — something like *"Terminal" wants to control "StataBE"* — with Allow/Don't Allow.
     This is normal and expected, not a bug; say so up front (*"macOS may show a permission popup
     in the next few seconds — click Allow if it does"*) so the user recognizes it immediately
     instead of wondering why nothing seems to be happening.
   - Test it: launch the GUI (`open -a "<flavor>"`, give it a few seconds to start), then run
     `scripts/run_do_gui.sh scripts/smoke_test.do <flavor>` and confirm it reports a clean run
     (exit 0). Ask the user to glance at the Results window and confirm they see
     `SMOKE TEST PASSED` — the return code alone isn't quite proof the window is actually visible.
   - **A distinct failure mode, easy to mistake for the permission issue above**: the exit code
     comes back `0` (a real, successful run — check the log, it's genuinely there) but the user
     reports seeing nothing update in the Results pane, even with the window open and visible.
     This isn't a permission problem — `DoCommand` executes and updates Stata's underlying
     document fully, but the visible Results pane doesn't reliably repaint on its own afterward.
     `run_do_gui.sh` already sends an `activate` call right after `DoCommand` to force this (fixed
     during testing — if working from an older copy of this script, add it). If it's still not
     showing after that, check two things before assuming something's broken: (1) is Stata's
     window actually frontmost, or is the user's attention (and hence window focus) on the chat
     window instead — side-by-side window placement avoids this entirely; (2) is there more than
     one Stata process (`pgrep -fla <flavor>`) — commands could be reaching an instance the user
     isn't looking at.
   - If it fails outright (nonzero exit, no log entry at all), the most common cause is a fixable
     macOS permission, not a Stata problem: headless batch mode needs no special permission (it's
     a plain subprocess), so "headless works but GUI doesn't" almost always means macOS's
     "Automation" permission hasn't been granted yet. Point the user at System Settings → Privacy
     & Security → Automation, to check that whatever app is
     running their terminal/Claude Code session is allowed to control Stata's flavor app. Running
     the test once is often what triggers macOS to show that permission prompt in the first place.

   **Windows — try `run_do_gui_cli.ps1` FIRST; it needs no admin rights** (verified live on
   Stata/BE 18.0, Windows 11). Stata's own command line runs a do-file inside the visible GUI
   whenever the batch flag is omitted — no COM registration, no elevation, nothing to configure:
   ```
   powershell -File scripts/run_do_gui_cli.ps1 -DoFile scripts/smoke_test.do
   ```
   It reads `stata_cmd` from `config.json`, so there's usually nothing else to pass. Ask the user
   to confirm they can see the Stata window and its Results output — the exit code alone isn't
   proof the window is visible to them.

   **One hard requirement in this mode: the `.do` file MUST call `log using` explicitly.** Stata
   writes no automatic log when running in the GUI, and since launching the GUI doesn't hand back a
   return code, that log is the only way to tell a clean run from a failed one (grepped for
   `r(###)`, exactly as headless does). The skill's standard file shape already includes
   `log using`, so this costs nothing — but a `.do` file without one will simply produce nothing to
   check, and the script bails after `-LogAppearSec` (45s default) telling you so.

   **`run_do_gui.ps1` (OLE Automation) is the fallback, not the first choice.** It's a genuinely
   nicer mechanism — it returns Stata's real `_rc` rather than inferring success from a log — but it
   requires `StataBE-64.exe /Register` from an **elevated** prompt before the ProgID exists at all.
   On a managed work machine the user frequently *cannot* do that, and an unelevated `/Register`
   fails silently: it writes nothing, creates no `HKCU\Software\Classes` fallback, and reports no
   error (confirmed live). If Automation isn't registered, every candidate ProgID fails with
   `0x80040154 REGDB_E_CLASSNOTREG` and `HKEY_CLASSES_ROOT` holds only file associations
   (`Stata18Do`, `Stata18Data`, …) with no Automation class — that's the signature, and it means
   "needs admin", not "wrong ProgID". Don't send the user chasing ProgID guesses in that state, and
   don't offer to run `/Register` on their behalf; it's an elevated system change that's theirs to
   make. Only if Automation *is* registered and the object still won't create is the ProgID guess
   (`stata.<Flavor>OLEApp`, fallback `stata.StataOLEApp`) worth investigating.

   **Writing `.do` files on Windows: never emit a UTF-8 BOM.** PowerShell 5.1's
   `Out-File -Encoding utf8` (and `>`/`>>`) prepend one, and Stata fails on line 1 of a BOM'd file
   — which in GUI mode means no log at all, so the failure looks like a hang rather than a syntax
   error. Hit live during this script's own testing. Write `.do` files with a tool that emits plain
   UTF-8, or `Set-Content -Encoding ascii`.

   **Either OS**, once you have an answer:
   - Record whether GUI mode worked in `config.json` (`"gui_available": true/false`, plus
     `"os": "mac"` or `"os": "windows"` so Step 3 knows which script to invoke) — if it didn't,
     that's fine, just fall back to headless (`run_do.sh`) for all runs and don't bring it up again
     *unless the user explicitly asks about GUI mode later*.
   - On Windows, also record **which** GUI mechanism worked, since there are two and they aren't
     interchangeable: `"gui_mode": "cli"` (the admin-free `run_do_gui_cli.ps1`) or
     `"gui_mode": "ole"` (`run_do_gui.ps1`). Step 3 needs this to pick the right script.
   - **If the user explicitly asks to enable or retry GUI mode** (e.g. after fixing a permission,
     or after a Windows ProgID correction), re-run this check regardless of what's currently cached
     in `config.json` — a cached `false` is a past result, not a standing decision the user can't
     revisit. Update `config.json` if the retry succeeds.
5. **Save the verified config.** Write `~/.claude/skills/stata-data-analysis/config.json`:
   ```json
   {
     "stata_cmd": "/full/path/to/the/verified/executable",
     "flavor": "StataBE",
     "os": "mac",
     "gui_available": true
   }
   ```
   On Windows, add `"gui_mode": "cli"` or `"gui_mode": "ole"` per the note above, and use forward
   slashes in `stata_cmd` (e.g. `"C:/Program Files/Stata18/StataBE-64.exe"`) so the value works
   unchanged from both PowerShell and Git Bash.
6. **Check and report this skill's own install scope, since nothing else surfaces this and it's
   easy to end up in the wrong one without noticing.** Skills can live in two different places:
   - `~/.claude/skills/` (or the Windows equivalent, `%USERPROFILE%\.claude\skills\`) — **global**,
     works in every project the user opens.
   - A specific project's own `.claude/skills/` folder — **project-scoped**, only works there.

   Check which one this actually is (e.g. is this file under the user's home directory, or under
   a project folder?) and tell the user plainly which they have — don't assume they already know,
   and don't let a UI element be the only place this information could come from. If they expected
   global but got project-scoped (or vice versa), that's worth flagging explicitly so they can
   decide whether to move it, rather than discovering the mismatch later when the skill doesn't
   trigger somewhere they expected it to.
7. Let the user know setup is done and they won't be asked again on this machine, then continue on to their actual request.

## Step 1 — Discover the project's conventions

Never assume a folder layout — every project this skill touches may be organized differently, and
the whole point of looking first is to blend into whatever pipeline already exists rather than
impose a new one. Before writing anything:

- Find existing `.do` files. What naming/numbering pattern do they use (`00_`, `01_`, `01b_`,
  descriptive suffixes)? New scripts should follow the same pattern, not invent a new one.
- Is there a dedicated folder for scripts (`Analysis/Programs`, `Programs/`, `Code/`)?
- Is there a `Data/raw` vs `Data/modified`-style split?
- Where do `.log` files land — next to the `.do` files, or in a separate `Logs` folder? Check
  whether existing `.do` files call `log using` explicitly (and where they point it) or rely on
  Stata's default batch-mode log.
- Is there a separate `Output` folder for finished deliverables, distinct from the working
  analysis code? Deliverables (tables, exports) never belong mixed in with the `.do` files.
- Read one or two existing `.do` files in full to pick up header style, comment density, and how
  they reference data (absolute paths vs. relative + `cd`).

**If none of this exists** (a genuinely new project), ask what this project's **cost code** is
(e.g. `ACH`, `GLB`) if it isn't already clear from context — this becomes the project folder's
name (`<CODE> QA`), so a colleague opening the same drive later can tell at a glance what belongs
to what. Then create this default layout and say so explicitly to the user rather than silently
inventing it:

```
<CODE> QA/
├── Programs/      .do files, numbered 00_, 01_, 02_... (00_master.do + 00_paths.do live here too)
├── Data/
│   ├── raw/       untouched source files
│   └── modified/  cleaned/derived .dta files
├── Logs/          .log files from batch runs
└── Output/
    ├── Docs/      Word/PowerPoint deliverables (memos, slide decks)
    └── Tables/    Excel deliverables (comparison tables, backing tables for a memo, etc.)
```

`Programs/` sits directly under the project root — **not** nested under an `Analysis/` folder.
`Output` splits by file type (`Docs` for Word/PowerPoint, `Tables` for Excel), not by review
status — there's no separate "reviewed" vs. "unreviewed" folder in this convention; a finished
export goes straight into whichever of `Docs`/`Tables` matches its format.

### Keep `00_master.do` wired up — and never let it call anything that calls it back

- Path globals belong in their own small file (`00_paths.do` or equivalent) that does nothing but
  define globals. Never define them in `00_master.do` itself if `00_master.do` *also* runs the
  pipeline scripts. Reason this matters, from a real failure: if each script self-bootstraps by
  sourcing `00_master.do` to get those globals (so it can still run standalone), and `00_master.do`
  also calls that same script as part of its pipeline, you get infinite mutual recursion — master
  calls the script, the script calls master, master calls the script again — until Stata hits a
  real resource ceiling (`system limit exceeded`, r(1000)) instead of a clean, obvious error.
  Master's only jobs should be: clear/cd/source-paths, then call each pipeline script in order.
  Every individual script sources the paths file directly, never `00_master.do`.
- **Whenever a new numbered script is added to the pipeline, add it to `00_master.do`'s call list
  in that same step** — don't leave it as an orphaned file that only ever runs standalone. An
  unwired script is easy to forget ever existed, and "does master.do actually reproduce the full
  pipeline" is exactly the kind of question that should never come up later because the answer is
  always yes.
- Each line in `00_master.do`'s pipeline list gets a short inline comment describing what that
  script actually *does* — not just its filename. The point: `00_master.do` should be readable as
  a one-glance summary of the whole pipeline, without opening every individual file to remember
  what step 04 was for.

### Every real investigation is a saved script — never a disposable scratchpad file

If code reads or manipulates the project's actual data to answer a real question — checking
whether a flag is accurate, deriving a comparison, anything that informs an actual decision or
finding — it goes in `Programs/` as a properly numbered file, gets run through the normal
write → run → verify cycle, and stays there, exactly like every other step. It does not belong
in a scratch/tmp file that nobody but the immediate moment ever sees again. The test isn't "is this
quick" — a one-line `count if` can be a real investigation; the test is whether it touches the
actual project data to inform a real answer. (Truly disposable scratch use is for testing the
*tooling itself* — e.g. confirming an AppleScript quoting pattern works — never for touching the
project's data.) Reason this matters: a finding nobody can trace back to the code that produced it
isn't reproducible, which defeats the entire point of doing this in Stata `.do` files at all.

## Step 2 — Plan, then write the .do file

**Before writing any code, share a short plain-language summary with the user**: what steps you're
about to take, and — just as important — any assumptions or analytical/methodological choices
being made along the way (how missing data is handled, what counts as an outlier, which variables
define a merge key, a model specification choice, a sample restriction, etc.). This is a summary of
intent, not the code itself — the point is to surface judgment calls before they're buried in
syntax, since that's the point where redirecting is cheap. Do this for every task, not just complex
ones. Once the user's seen the plan, proceed to writing the file:

- Follow the discovered (or default) numbering and naming convention.
- **Annotate line by line.** Every meaningful line or block gets a comment explaining what it does
  and why — not just a header block at the top. The reason this matters: this code gets revisited
  months later, sometimes by someone else, and the logic needs to be followable without
  re-deriving it from scratch.
- Standard shape: header comment (purpose, inputs, outputs) → `log using` → commands → `log close`.
- If the task ends in a results table, write it out with Stata's own export commands
  (`export excel`, `putexcel`) so the pipeline stays Stata-only end to end — don't hand off to
  Python for this part.

## Step 3 — Run it and iterate until clean

**If `config.json` has `"gui_available": true`, use the GUI script by default** — it runs the file
inside Stata's actual Results window, so the user watches it happen live instead of reading a log
file afterward, and it hands back Stata's real `_rc` return code directly (more reliable than
pattern-matching a log, since there's no matching involved at all). **Which script depends on the
`"os"` field in `config.json`** — the two platforms use completely different mechanisms, not just
different syntax for the same thing:

```bash
# macOS — AppleScript via run_do_gui.sh
scripts/run_do_gui.sh <path/to/script.do> <flavor>

# Windows, "gui_mode": "cli" — GUI via Stata's command line, no admin needed (the usual case)
powershell -File scripts/run_do_gui_cli.ps1 -DoFile <path/to/script.do>

# Windows, "gui_mode": "ole" — OLE Automation, only if /Register has been run as admin
powershell -File scripts/run_do_gui.ps1 -DoFile <path/to/script.do> -Flavor <flavor>
```

(`<flavor>` — e.g. `StataBE` — comes from `config.json`.) Exit code `0` means a clean run;
anything else is a failure, visible right there in the Results window. The two Windows modes reach
that verdict differently, which matters when one disagrees with the log: `ole` returns Stata's real
`_rc` directly, while `cli` infers it by grepping the log for `r(###)` — so under `cli`, **the
`.do` file must call `log using`** or there's nothing to grep and the run can't be verified at all.

Under `cli`, Stata's window is deliberately left open with the data still loaded when the run
finishes — that's the main reason a user asks for GUI mode in the first place. The flip side is
that each run launches a *new* instance rather than reusing the open one, so close the previous
window between runs or they accumulate.

**Otherwise** (no GUI available, or a context without a display), fall back to the headless
script, which greps the resulting log for Stata's fixed `r(###);` error format:

```bash
scripts/run_do.sh <stata_cmd> <path/to/script.do> [path/to/expected.log]
```

(`<stata_cmd>` comes from `config.json`.)

- Either way: if it reports errors, read them (from the Results window or the flagged log lines),
  fix the `.do` file, and rerun. Repeat until the script reports a clean run. Don't narrate each
  failed intermediate attempt in the chat — that's just noise; iterate until clean, then report the
  result. (The GUI mode makes every attempt visible on screen regardless, which is the point.)
- A `.do` file that hasn't been run to a clean log is not a finished deliverable in this workflow —
  don't hand it back untested, even for a "quick" exploratory task.
- **Once the run is clean, always show the user the finished `.do` file** — either inline in the
  response or as a linked file — rather than leaving it sitting silently on disk. The file existing
  in `Programs/` isn't the same as the user actually having seen it.

## Step 4 — Route outputs correctly

- Finished deliverables — tables for review, formatted exports — go in the discovered (or default)
  `Output` folder, never mixed into `Programs` alongside the working code.
- Route by file type: Excel exports go to `Output/Tables/`, Word/PowerPoint deliverables go to
  `Output/Docs/` (or whatever equivalent split the project already uses).
- The `.do` file, its `.log`, and any intermediate `.dta` files stay in their respective
  Programs/Logs/Data folders.
- **The table is the deliverable that matters most.** Get the underlying analysis correct and the
  table well-formatted before anything else — that's the actual work product being reviewed;
  charts are secondary polish, not a substitute for a correct table.

## Step 5 — Charts (last step, and only once the table is confirmed correct)

Don't build a chart before the user has confirmed the underlying table is right — charting on top
of a table that's still being corrected just means redoing the chart later.

- The table: exported from Stata (`export excel` / `putexcel`) into the `Output` folder, per Step 4.
- The chart: build it as a **native Excel chart object** on top of that exported table — not a
  Stata `.gph`, not a static image pasted in. This is a presentation step, not quantitative
  analysis, so lean on the `xlsx` skill (openpyxl) to construct it rather than doing it in Stata.
- Don't guess the chart type, series, or framing. Ask the user what the chart needs to show (a
  trend over time, a comparison across groups, a single distribution, etc.) before building it.

## Exploratory / diagnostic visuals are exempt from all of this

A quick plot used only to check your own work — eyeballing a distribution, diagnosing a merge,
spotting an outlier during cleaning — is not a deliverable and never gets shared. For these, use
whatever's fastest: a Stata `graph`/`.gph`, a throwaway script, anything. This exemption is about
visuals only — it does not extend to the underlying cleaning, descriptives, or modeling, which
stays in Stata always, even when the visual double-checking it doesn't.
