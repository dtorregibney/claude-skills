# claude-skills

Three Claude Code skills for doing quantitative analysis work in Stata, with optional git/GitHub
support built in: `git-setup`, `stata-data-analysis`, `stata-data-cleaning`. See each folder's
`SKILL.md` for what it actually does.

## Install — read this carefully, the wrong method silently breaks updates

**Clone this repo directly into your Claude Code skills folder — do not clone it somewhere else
and then move the subfolders into place.** Git tracking (the `.git` folder) only lives at the
root of a clone. If you clone to one location and then move `git-setup/`, `stata-data-analysis/`,
and `stata-data-cleaning/` out into a *different* folder, those moved folders are just plain files
now — no git history, no way to `git pull` updates later, even though everything looks fine at a
glance. This has actually happened and cost someone a confusing debugging session — don't repeat
it.

**Correct way:**

```bash
# macOS/Linux
mkdir -p ~/.claude/skills
cd ~/.claude/skills
git clone git@github.com:dtorregibney/claude-skills.git .

# Windows (PowerShell)
mkdir "$env:USERPROFILE\.claude\skills" -Force
cd "$env:USERPROFILE\.claude\skills"
git clone git@github.com:dtorregibney/claude-skills.git .
```

The trailing `.` clones directly into the current (skills) directory, rather than creating a new
`claude-skills` subfolder inside it. If that folder already has content in it (e.g. other skills,
or an earlier non-git copy of these same three), `git clone` will refuse to run — move anything
conflicting aside first (see "If you already have a non-git copy" below).

**If you don't have `git` installed yet**: on Windows, install "Git for Windows" first (a normal
installer). macOS usually already has it.

**If you don't have SSH access to GitHub set up yet**: use the HTTPS URL instead —
`https://github.com/dtorregibney/claude-skills.git` — or ask your Claude Code session to use the
`git-setup` skill's own SSH key walkthrough first.

## If you already have a non-git copy of these skills

This means someone previously followed the broken "clone elsewhere, then move subfolders" method.
Fix it without losing anything:

1. Copy `git-setup/`, `stata-data-analysis/`, and `stata-data-cleaning/` out of your skills folder
   to a backup location first — don't skip this.
2. Remove those same three folders from your skills folder (clearing the way for a clean clone).
3. Run the correct clone command above.
4. Compare the freshly cloned files against your backup. They should match closely (or exactly);
   if you'd made local edits that never made it into a commit, this is the point to notice and
   manually reapply them before deleting the backup.

## Keeping this up to date

Once installed correctly, `cd` into your skills folder and run `git pull` any time you want the
latest version — there's no automatic sync. If you want to contribute a fix or improvement
yourself, see `CLAUDE.md` in this repo for the process (branch → commit → PR → merge, every time,
even for small changes).
