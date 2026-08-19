---
name: git-setup
description: >
  Set up git and GitHub for a quantitative analysis project — creating a new cost-coded project
  repo (e.g. under ~/Quantitative Analysis, named for its cost code like "ACH QA"), connecting it
  to GitHub, and teaching the
  branch/pull-request workflow for team collaboration. Use this whenever the user wants to start
  tracking a project with git, needs a new repo set up for a cost code, mentions GitHub,
  collaborating with a team on code, or wants to learn git basics (commits, branches, pull
  requests) — especially if they say they're new to git or have never connected Claude to GitHub
  before. Handles one-time machine setup (git identity, SSH keys) automatically the first time it
  runs, then skips straight to project setup on later runs. Pairs naturally with the
  stata-data-analysis skill: that skill handles the Stata code itself, this one handles getting
  that code under version control and onto GitHub.
---

# Git Setup

The point of this skill is to get a project from "just files in a folder" to "tracked by git,
backed up on GitHub, ready for a teammate to review changes" — and to actually teach the concepts
along the way if the user hasn't done this before, rather than just running commands at them.

A running theme worth keeping in mind: **git needs a plain local folder it fully controls.**
Google Drive (and similar sync tools) constantly touch files in the background in ways that
conflict with git's own bookkeeping, and can corrupt a repo. So the git-tracked folder for any
project should live outside any Drive-synced directory — e.g. `~/Quantitative Analysis/<CODE> QA`
— while the actual data and deliverables stay on Drive, referenced by path rather than duplicated.
This also has a second benefit for this kind of work specifically: analysis data is often
FERPA-sensitive (student/educator records), and GitHub is a code-hosting tool, not a place that
sensitive data should ever end up. Code goes to git; data stays on Drive. Always.

## Platform — this skill was written on a Mac; check before assuming

The paths and commands throughout are written in Unix shorthand (`~/`, forward slashes). That
reads fine on macOS and silently misleads on Windows, where a real user hit every one of the
gotchas below. **Check the platform first**, then translate.

| | macOS | Windows |
|---|---|---|
| Home | `~/` | `C:\Users\<Name>\` (`$env:USERPROFILE` in PowerShell) |
| Project code folder | `~/Quantitative Analysis/<CODE> QA` | `C:\Users\<Name>\Quantitative Analysis\<CODE> QA` |
| Google Drive root | `~/Library/CloudStorage/GoogleDrive-<email>/` | a **drive letter**, usually `G:\` |
| Shell | bash/zsh | PowerShell (and Git Bash, if Git for Windows is installed) |

**Finding Google Drive on Windows — don't guess the letter.** It is not always `G:`. Run:

```
Get-PSDrive -PSProvider FileSystem
```

The Drive mount shows up with `Google Drive` in its `Description` column. Underneath it you'll
find `Shared drives\` and `My Drive\` — the same two containers as on Mac, just reached
differently. On macOS the equivalent is `ls ~/Library/CloudStorage/`.

**Everything on Windows has spaces in it** — `C:\Users\Libby Schwaner`, `Quantitative Analysis`,
`TEST QA`, `My Drive`, `Shared drives`. Quote every path in every command, without exception. This
bites harder on Windows than Mac because it's unavoidable rather than occasional.

**PowerShell specifics that will waste time otherwise:**

- **`~` is not reliably expanded when passed to a native `.exe`** (`ssh-keygen`, `ssh`, `git`).
  PowerShell cmdlets understand `~`; the programs being invoked often receive it literally and
  create a folder actually named `~`. Use `"$env:USERPROFILE\..."` for native commands.
- **An empty-string argument needs doubled quoting.** `-N ""` reaches the executable as nothing at
  all, so `ssh-keygen` prompts interactively for a passphrase and hangs. Write `-N '""'`.
- **`Get-ChildItem` on a path that doesn't exist returns exit code 1**, which reads as a failed
  command rather than a clean "no". Use `Test-Path` for existence checks.
- **`&&` and `||` don't work in Windows PowerShell 5.1.** Use `;` or `if ($?) { ... }`.

## Step -1 — Ask whether this project even wants git/GitHub

Not every project needs this. Before doing anything else for a **genuinely new** project (no
existing folder anywhere yet — see stata-data-analysis's discovery step), ask: *"Do you want this
project tracked with git/GitHub, or just working locally on Drive?"*

- **Git/GitHub** → continue to Step 0 below; the local code folder lives outside Drive, per the
  reasoning above.
- **Drive-only** → none of this skill applies. Tell the user to just use `Analysis/Programs`
  directly inside the project's Drive folder (the plain, no-git convention) — no separate local
  folder, no git commands, no branches or PRs. Hand off to stata-data-analysis for the actual
  analysis work; there's nothing further for this skill to do.

**Don't ask again for a project that's already answered this**, either way. The signal is
structural, not a setting to look up: if `~/Quantitative Analysis/<CODE> QA` already exists (with
a `.git` folder), it chose git. If a Drive project folder already has its own `Analysis/Programs`
(or similar) with `.do` files directly inside it, it chose Drive-only — that's exactly what
stata-data-analysis's own discovery step is already checking for.

## Step 0 — One-time machine setup

Check whether this machine already has:
- A global git identity: `git config --global user.name` and `user.email` both return something.
  **"Returns something" is not the same as "is correct."** Actually look at the value of
  `user.name` — a real user had it set to their *email address*, so every commit they'd ever made
  was attributed to `first.last@example.com` instead of a human name. If `user.name` contains an
  `@`, or is otherwise obviously not a person's name, flag it and offer to fix it. Note that
  correcting it only affects future commits; past ones keep the old attribution.
- **Working GitHub authentication** — test this directly with `ssh -T git@github.com` rather than
  just checking for a specific key filename. A reply like `Hi <username>! You've successfully
  authenticated...` means auth already works, full stop — regardless of what the key is named,
  where it lives, or how it got set up (a different filename, a key from another machine's setup,
  something configured outside this exact workflow). **Checking only for `~/.ssh/id_ed25519` or
  `id_rsa` is not sufficient** — a real user hit this exact false negative (had working GitHub
  auth already, got incorrectly told they needed to set it up from scratch). The `ssh -T` test is
  the ground truth; a missing default-named file is not evidence of anything on its own.
- **`gh auth status` failing does NOT mean GitHub is unconfigured.** The `gh` CLI keeps its own
  credentials, entirely separate from SSH. A real user had `gh auth status` reporting *"You are not
  logged into any GitHub hosts"* while `ssh -T git@github.com` succeeded and `git push` worked
  perfectly — because git over SSH never consults `gh` at all. This split is especially common on
  Windows, where Git for Windows and the GitHub CLI are two unrelated installers. Never report
  "GitHub isn't set up" on the strength of a `gh` failure; `gh` only matters if the user
  specifically wants commands like `gh pr create`, and it's worth saying so plainly rather than
  leaving a scary-looking error unexplained.

**If both are already set up** (identity configured AND `ssh -T git@github.com` succeeds), this
machine has done this before — skip straight to Step 1, and don't re-explain concepts or generate
a redundant new key.

**Also check and report this skill's own install scope**, the first time this runs on a machine:
is `git-setup` itself sitting in the user's global `~/.claude/skills/` (works in every project) or
inside one specific project's own `.claude/skills/` folder (works only there)? Tell them plainly
which — this is easy to get wrong when following install instructions, and nothing else in the
interface reliably surfaces it. See stata-data-analysis's Step 0 for the same check in more
detail; the reasoning is identical here.

**If not, walk through setup:**

1. **Git identity.** Ask what name and email to use for commits (usually their real name + work
   email — this is what teammates will see attached to every change). Set it globally so it's
   never asked again:
   ```
   git config --global user.name "Their Name"
   git config --global user.email "their.email@example.com"
   git config --global init.defaultBranch main
   ```
2. **SSH key**, so their machine can authenticate to GitHub without a password every time.

   **macOS/Linux:**
   ```
   ssh-keygen -t ed25519 -C "their.email@example.com" -f ~/.ssh/id_ed25519 -N ""
   ```

   **Windows (PowerShell)** — three separate differences, all of which have bitten someone:
   ```
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
   ssh-keygen -t ed25519 -C "their.email@example.com" -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
   ```
   The `.ssh` folder often doesn't exist yet on a fresh Windows profile and `ssh-keygen` will fail
   rather than create it. `~` must become `$env:USERPROFILE` because `ssh-keygen` is a native
   executable. And `-N ""` must become `-N '""'`, or the empty passphrase never arrives and the
   command sits waiting on an interactive prompt that a non-interactive tool call can't answer.

   Explain briefly: this creates a key *pair* — a private key that never leaves the machine, and a
   public key that's safe to share. GitHub uses the public key to verify it's really them, without
   the private key (or a password) ever crossing the network.
3. **Adding the key to GitHub is an account action the user must do themselves**, in their own
   logged-in browser — don't attempt this through an agent-controlled browser session, since it
   requires their authenticated GitHub session. Print the public key and direct them to
   `github.com/settings/keys` → **New SSH key** → paste it. Read the `.pub` file with whatever
   file-reading tool is at hand (`cat ~/.ssh/id_ed25519.pub` on macOS) — and paste the whole single
   line, `ssh-ed25519 AAAA… email` included, since GitHub rejects a partial key.

   Then **stop and wait for them to confirm they've added it.** Don't proceed to the verify step in
   the same breath; it will fail for the ordinary reason that they haven't finished yet, which is
   easy to misread as a broken key.
4. **Verify it worked:**
   ```
   ssh -T -o StrictHostKeyChecking=accept-new git@github.com
   ```
   A reply like `Hi <username>! You've successfully authenticated, but GitHub does not provide
   shell access.` is success — the "no shell access" part is expected, not an error (it exits
   non-zero, which is also normal here).

   The `-o StrictHostKeyChecking=accept-new` matters on any machine connecting to GitHub for the
   first time. Without it, ssh asks *"Are you sure you want to continue connecting (yes/no)?"* and
   waits — which hangs a non-interactive tool call until it times out, looking like a network
   problem rather than an unanswered prompt. The flag accepts GitHub's host key on first sight
   (printing `Warning: Permanently added 'github.com'…`, which is informational) while still
   refusing a *changed* key later, so it doesn't give up the protection that matters.

**Steps 1 and 2 below are a single unit of work, not sequential-but-separable tasks.** A project
isn't "set up" after Step 1 — a local `git init` with no GitHub remote is an unfinished setup that
looks finished (commits succeed, everything appears to work), which is exactly what makes it easy
to silently skip Step 2 and move on to real work on a repo nothing is backing up or making
reviewable. Do not consider setup done, and do not hand off to stata-data-analysis or
stata-data-cleaning for real work, until `git remote -v` on the new project shows an `origin`.

## Step 1 — Ask for the cost code, create the Drive data folder, create the local project folder

Ask the user what this project's **cost code** is (e.g. `EAE`, `SCS`, `ACH`) if it isn't already
clear from context. This becomes the project's name throughout: local folder `<CODE> QA`, GitHub
repo `<code>-qa` (lowercase, hyphenated — GitHub's convention, vs. the spaced local folder name).

**First, the Drive side.** Ask where this project's data should live on Drive if it isn't already
obvious (a Shared Drive the client/team already uses, or `My Drive/<CODE> - <short project name>`
for something more personal/exploratory) — don't guess at a location in a shared team Drive.

Before asking, **list the Shared drives and offer what's actually there** rather than asking in the
abstract. Shared drives are often already cost-coded (`AIK - Gates - Coalition for…`, `TAI - Texas
2036 - State AI Framework…`), so the right home is usually the one whose code matches — and that
puts the data where the client team is already looking. Windows: `Get-ChildItem "G:\Shared drives"`
(confirm the letter first, per the platform section). macOS: look under
`~/Library/CloudStorage/GoogleDrive-<email>/Shared drives/`.

Once you know where, create:

```
<Drive location>/
├── Data/
│   ├── raw/            untouched source files exactly as received
│   └── modified/       cleaned/derived .dta files
├── Logs/                .log files from batch runs
└── Output/
    ├── Unformatted/     fresh exports straight out of Stata, not yet reviewed
    └── Formatted/       exports that have been manually reviewed/polished — the real deliverable
```

Tell the user the path (and, if useful, that they can also find it by searching the folder name in
the Drive web UI) so they know where to drop the raw file(s) they've received.

**Then, the local (code) side.** Create the local skeleton at `~/Quantitative Analysis/<CODE> QA/`
(on Windows, `C:\Users\<Name>\Quantitative Analysis\<CODE> QA\`):

```
<CODE> QA/
├── .gitignore        (ignores data/output/log file types & folders — see below)
├── README.md         (explains the code-only convention + where this project's Drive data lives)
└── Programs/
    ├── 00_paths.do    (defines the path globals pointing at the Drive folder above — and NOTHING
    │                   else; fill in the real Drive paths now, don't leave them as placeholders,
    │                   since you already know them from this step)
    └── 00_master.do   (sources 00_paths.do, then calls each pipeline script in order; the call
                        list starts empty)
```

**Two files, not one.** Path globals go in `00_paths.do`; `00_master.do` sources it and runs the
pipeline. Don't collapse them, even though one file looks simpler at this stage — every pipeline
script sources `00_paths.do` directly so it can still run standalone, and if the globals lived in
`00_master.do` instead, master would call a script that calls master that calls the script, until
Stata dies with `system limit exceeded` (r(1000)). This is stata-data-analysis's rule and the
reason is spelled out there; create the two files that way from the start so the project never
has to be untangled later.

Have `00_paths.do` **fail loudly if Drive isn't reachable**, so a later "file not found" doesn't get
misdiagnosed as a data problem when the real cause is that Drive isn't mounted:

```
capture confirm file "$drive/Data/raw"
if _rc {
    display as error "Cannot reach $drive -- is Google Drive mounted?"
    exit 601
}
```

**Use forward slashes in the Stata globals even on Windows** — `"G:/My Drive/<CODE> - <name>"`.
Stata accepts them on every platform, whereas backslashes in Stata string literals invite escaping
bugs that surface as baffling file-not-found errors.

`.gitignore` should exclude at minimum: `*.dta *.log *.xlsx *.xlsm *.csv *.docx *.gph *.png Data/
Output/ Logs/ .DS_Store` — this is a safety net, since data/output should never even be created in
this folder in the first place, only referenced from Drive via the globals in `00_paths.do`. On
Windows also add `Thumbs.db` and `desktop.ini`, which are the local equivalents of `.DS_Store` and
will otherwise show up as mystery untracked files.

Then:
```
git init
git add .gitignore README.md Programs/
git commit -m "Initial project skeleton"
```

On Windows this prints `warning: in the working copy of '.gitignore', LF will be replaced by CRLF
the next time Git touches it` for every file. **It's harmless** — git is storing Unix line endings
and handing back Windows ones — but it looks like something went wrong to anyone new to git, so say
so before they ask. Committing a `.gitattributes` containing `* text=auto` silences it if the noise
is bothersome.

**Then tell the user, explicitly, that `Programs/` will not appear on Drive.** They will go looking
for it there — a real user did, and reasonably concluded that setup had half-failed. The split is
the least intuitive thing about this whole arrangement, so state both locations plainly, say which
one holds the `.do` files, and suggest pinning the local `Programs\` folder to Quick Access or the
Finder sidebar. It's the one folder they'll use constantly that can't be found by searching Drive.

## Step 2 — Create and connect the GitHub repo

Have the user create a new, **empty** repo themselves at `github.com/new` (their own authenticated
action): owner their username, name `<code>-qa`, and — importantly — leave "Add a README",
".gitignore", and "license" all **unchecked**, since those files already exist locally and
checking them creates conflicting content before the first push even happens.

Once created, connect and push:
```
git remote add origin git@github.com:<username>/<code>-qa.git
git push -u origin main
```
(`-u` sets up tracking, so future `git push`/`git pull` need no arguments.)

Adding the remote works offline and proves nothing, so it's fine to set it up *before* they've
finished creating the repo — but confirm the repo exists before declaring success. `git ls-remote
origin` is a read-only way to check without pushing anything.

**Reading the failures correctly**, since they're easy to misattribute:

- `ERROR: Repository not found.` — authentication succeeded; the repo just isn't there yet, or the
  name doesn't match the remote exactly (`test-qa` vs `test_qa`, wrong owner). It is *not* a
  permissions or key problem. Note that GitHub deliberately returns this same message for a private
  repo you can't access, so it can't distinguish "doesn't exist" from "exists but not visible to
  you."
- `Permission denied (publickey)` — this one *is* the key. Go back to the `ssh -T` check.
- `! [rejected] main -> main (fetch first)` — you have write access and the remote has commits you
  don't. Auth is fine; `git fetch` then reconcile.

## Step 3 — Teach (or remind) the branch / pull request workflow

**Always use a branch + PR, even when working completely alone — never commit directly to `main`.**
This is a deliberate choice: the user is building the habit now, on low-stakes work, so it's already
automatic once a teammate is actually in the loop. Don't skip straight to `main` just because no one
else is on the project yet.

This is the part that matters most once more than one person touches the repo. Explain the concepts
in plain terms if the user hasn't done this before:

- **`main`** is the project's official line of history — not a file, a branch (a name for a line
  of commits).
- A **branch** is an independent copy of that line, for making changes without touching `main`
  until they're reviewed. Nothing on a branch affects `main` until it's explicitly merged.
- A **pull request (PR)** is a request, made on GitHub, to merge one branch into another — the
  checkpoint where a teammate reviews the diff before it becomes official.

The day-to-day loop, once a repo exists:
```
git checkout -b <descriptive-branch-name>
# ... edit files ...
git add <files>
git commit -m "What changed and why"
git push -u origin <branch-name>
```
Pushing a new branch prints a direct link to open a PR on GitHub — open it, review the diff, click
**Create pull request**, then **Merge pull request** (after a teammate's review if one's involved;
otherwise merge it yourself once you've looked over the diff — but always through this PR step,
not a direct commit to `main`).

Bring the merge back down locally, and clean up the now-merged branch:
```
git checkout main
git pull
git branch -d <branch-name>
git push origin --delete <branch-name>
```

For a user who's clearly done this before (git identity and SSH already configured, or they've
been through this flow earlier in the same session), skip the explanations and just execute the
commands — don't re-teach what's already landed.

## Relationship to the stata-data-analysis skill

That skill handles writing, running, and iterating on the actual `.do` files. This skill handles
getting a project onto git/GitHub in the first place. When starting a genuinely new cost-coded
project, run this skill first to establish the repo, then use stata-data-analysis for the analysis
work itself — its own folder-discovery step will find the `Programs/` convention this skill set up
and follow it.
