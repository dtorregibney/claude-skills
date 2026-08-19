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
- An SSH key: `~/.ssh/id_ed25519` (or `id_rsa`) exists.

**If both are already set up**, this machine has done this before — skip straight to Step 1, and
don't re-explain concepts the user has clearly already been through.

**If not, walk through setup:**

1. **Git identity.** Ask what name and email to use for commits (usually their real name + work
   email — this is what teammates will see attached to every change). Set it globally so it's
   never asked again:
   ```
   git config --global user.name "Their Name"
   git config --global user.email "their.email@example.com"
   git config --global init.defaultBranch main
   ```
2. **SSH key**, so their machine can authenticate to GitHub without a password every time:
   ```
   ssh-keygen -t ed25519 -C "their.email@example.com" -f ~/.ssh/id_ed25519 -N ""
   ```
   Explain briefly: this creates a key *pair* — a private key that never leaves the machine, and a
   public key that's safe to share. GitHub uses the public key to verify it's really them, without
   the private key (or a password) ever crossing the network.
3. **Adding the key to GitHub is an account action the user must do themselves**, in their own
   logged-in browser — don't attempt this through an agent-controlled browser session, since it
   requires their authenticated GitHub session. Print the public key (`cat ~/.ssh/id_ed25519.pub`)
   and direct them to `github.com/settings/keys` → **New SSH key** → paste it.
4. **Verify it worked:**
   ```
   ssh -T git@github.com
   ```
   A reply like `Hi <username>! You've successfully authenticated, but GitHub does not provide
   shell access.` is success — the "no shell access" part is expected, not an error (it exits
   non-zero, which is also normal here).

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

**Then, the local (code) side.** Create the local skeleton at `~/Quantitative Analysis/<CODE> QA/`:

```
<CODE> QA/
├── .gitignore        (ignores data/output/log file types & folders — see below)
├── README.md         (explains the code-only convention + where this project's Drive data lives)
└── Programs/
    └── 00_master.do   (path-globals header pointing at the Drive folder above; see
                        stata-data-analysis skill — fill in the real Drive paths now, don't leave
                        them as placeholders, since you already know them from this step)
```

`.gitignore` should exclude at minimum: `*.dta *.log *.xlsx *.xlsm *.csv *.docx *.gph *.png Data/
Output/ Logs/ .DS_Store` — this is a safety net, since data/output should never even be created in
this folder in the first place, only referenced from Drive via the globals in `00_master.do`.

Then:
```
git init
git add .gitignore README.md Programs/
git commit -m "Initial project skeleton"
```

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
