# claude-skills

This directory is a git repo tracking Claude Code skills (`stata-data-analysis/`,
`stata-data-cleaning/`) — and it's also each user's live, working copy: whatever's here is what
Claude Code actually reads when these skills trigger. There is no separate "real" copy elsewhere.

## When asked to update, fix, or improve any of these skills

This applies whether the request is specific ("fix the GUI detection bug") or general ("update
the skill based on what went wrong today," "improve this based on our errors") — either way,
follow the same process used to build these skills in the first place, every time, no exceptions
for small changes:

1. **Branch off `main`** — name it for what it does (`fix-windows-detection`,
   `clarify-skill-scope`), never commit directly to `main`.
2. **Make the change**, and explain *why* in the commit message, not just what changed — the
   reasoning is what keeps this maintainable as more people touch it.
3. **Push the branch and give the user the PR link** — don't merge it yourself unless they
   explicitly say to. Walk them through the actual GitHub buttons if they haven't done this
   before (Create pull request → Merge pull request → Confirm merge).
4. **Once they confirm it's merged**, sync `main` locally (`git checkout main && git pull`) and
   delete the merged branch, both locally and on GitHub.

This is the same branch → commit → push → PR → merge cycle used for every other git-tracked
project these skills help set up — it applies to the skills' own source just as much as it does
to a client analysis project. Never skip it because a fix feels small or the user is working
alone; that's specifically the case this rule is for.

## If the request is vague ("update based on our errors," "fix what went wrong")

Ask what actually happened — what they typed, what the skill did, what they expected instead —
before writing any fix. Don't guess at what broke from a vague description when the real details
are one question away.
