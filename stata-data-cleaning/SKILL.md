---
name: stata-data-cleaning
description: >
  Clean a raw dataset before analysis — deduplicate, apply inclusion/exclusion criteria,
  standardize categorical coding and string formatting, label variables informatively, handle
  missing data, merge multiple sources, and validate the result with crosstabs/descriptives. Use
  this whenever the user has raw data that needs cleaning, a client "just sent" a file, they
  mention duplicates, inconsistent coding, missing data, merging multiple datasets, or want a
  dataset prepped/QA'd before analysis — even before they explicitly ask for "cleaning" by name.
  Companion to stata-data-analysis (inherits its Stata-only, annotate-line-by-line, run-until-clean
  rules) and git-setup (commits at logical cleaning checkpoints on a dedicated branch). Looks at
  the actual raw data first and tailors its proposed checklist to what's really wrong with it,
  rather than running through a generic list blindly.
---

# Stata Data Cleaning

Cleaning is where the most consequential, least visible decisions in an analysis get made — how
duplicates are resolved, what counts as missing, whether two variables from different years
actually mean the same thing. The point of this skill is to make those decisions visible and
checked, one at a time, rather than buried inside a single opaque script. It inherits the
mechanics (Stata-only, annotate line-by-line, run via Step 3's GUI-or-headless loop until clean,
discover project conventions) from **stata-data-analysis** — read that skill first if you
haven't. This skill adds
the cleaning-specific checklist and the "look, propose, write, verify" loop on top of it.

**Git/GitHub is optional here, same as in stata-data-analysis** — some projects are Drive-only by
deliberate choice, not by oversight. Check which this project already is (see stata-data-analysis's
discovery step): if it's Drive-only, skip straight to Step 1, and skip Step 4 (git checkpoints)
entirely later on.

**If this project did choose git, before Step 1, check `git remote -v` in its local repo.** If
there's no `origin`, setup was left half-finished (git-setup's Step 1 without its Step 2) — a
local-only repo will happily accept commits with no error, which is exactly why this is easy to
miss until someone goes looking for the work on GitHub and finds nothing there. Route back to
git-setup to connect the remote before starting real cleaning work, rather than building a
cleaning history that isn't backed up or reviewable anywhere.

## Step 1 — Look at the raw data before proposing anything

Never propose a cleaning checklist generically — tailor it to what's actually in this dataset.
Run (and read the output of):
- `describe` and `codebook` — variable types, labels (or lack of them), value ranges
- `count` and `duplicates report` — total observations, and whether duplication exists at all
- `misstable summarize` — which variables have missing values, and how much
- For string variables: `tab <var>` (or a sample of it) — eyeball spelling/capitalization
  inconsistency directly rather than assuming it's there or isn't

**If this is a merge of multiple raw sources**, do this for each source file, then build a simple
data dictionary before touching anything: variable name, type, meaning, and source file, side by
side. This is what catches "two files both have a `school_name` field, but formatted differently"
or "this file calls it `distcode`, that one calls it `district_id`" before a merge silently
mismatches or duplicates them.

## Step 2 — Propose a checklist based on what Step 1 actually found

Share this as a plain-language draft (per stata-data-analysis's Step 2 convention) before writing
any code — cleaning decisions are exactly the kind of judgment call worth surfacing early. Pull
only the categories that actually apply to this dataset; don't propose fixing something that isn't
broken.

**General cleaning**
- Duplicates — run `duplicates report` first to understand the shape of duplication before
  deciding how to resolve it; an exact full-row duplicate is a different problem than two rows
  sharing an ID with different values in other fields.
- Inclusion/exclusion criteria — confirm with the user what these actually are; don't infer or
  assume them from the data.
- Irrelevant observations or variables — flag candidates, but confirm before dropping anything the
  user might still want.
- Spelling and capitalization inconsistency in string variables — e.g. `"Male"`, `"male"`, `"MALE"`
  all meaning the same category.

**Formatting and consistency**
- Categorical coding consistency — e.g. a binary variable coded `0/1` in some places and `1/2`
  elsewhere; flag and standardize.
- Data type mismatches — numbers stored as strings (or vice versa); flag anything that needs
  `destring`/`tostring`.
- Variable and value labeling — propose informative names (`attendance_2324`, not `attend`), and
  for groups of related variables, a shared prefix or suffix (`q1_selfefficacy`, `q2_selfefficacy`,
  ...) so later code can loop over them with a wildcard instead of naming each one individually.
- **Every variable gets a label, and labels are sentence case** — check with `describe` for
  variables with no label at all (common on an import — raw source labels are often missing, or
  in `ALL_CAPS`/`SCREAMING_SNAKE_CASE` straight from whatever system exported the file, e.g.
  `INSTN_NUMBER` or `SCHOOL_DSTRCT_NM`). Assign an informative sentence-case label
  (`label variable instn_number "Institution number"`) to anything missing one, and normalize
  existing ALL-CAPS labels to sentence case rather than leaving the export system's formatting.
- New/derived variables the upcoming analysis will need.

**Missing data**
- Characterize the missingness pattern before picking a method — this matters because the *right*
  method depends on *why* data is missing, not just what's easiest:
  - **MCAR** (missing completely at random): missingness is unrelated to anything — e.g. a
    survey response lost because of a printer error. Safest to handle simply (drop, or any
    reasonable imputation) since nothing systematic is lost.
  - **MAR** (missing at random): missingness relates to something you can observe and control for
    — e.g. a treatment-group school had lower attendance data availability, but you know why and
    can condition on it. Handle by controlling for the observed driver, not by ignoring it.
  - **MNAR** (missing not at random): missingness relates to the value itself — e.g. students who
    don't know an answer skip the question. This is the dangerous case: dropping or naively
    imputing will bias results, because the missing values are systematically different from the
    observed ones.
  - Propose a method (drop, mean/dummy replacement, imputation) *with the reasoning attached*, and
    get confirmation — don't silently default to one.

**Merging multiple sources** (skip if there's only one source file)
- Confirm the merge key(s): same variable name, same type (string vs. numeric), same format,
  across every file being merged.
- Confirm each variable means the same thing across sources/years, not just that it's named the
  same — check documentation; naming conventions and definitions drift across years more often
  than they stay put.
- Confirm shape (wide vs. long) matches across files, or reshape first.
- Drop variables that won't be needed *before* merging, not after — merging unnecessary columns
  just multiplies the surface area for mismatches.
- After merging: always inspect the `_merge` variable's frequency distribution, and look at
  missingness patterns by source/year — a merge that "worked" (ran without error) can still have
  silently dropped or duplicated rows.

**Validation**
- Crosstabs and descriptives on every variable that was touched — does the distribution make
  sense, not just "did the code run."
- Explicit implausible-value/outlier check: `assert` statements for known invariants (e.g.
  `assert inrange(age, 0, 100)`) catch violations immediately and loudly, rather than relying on
  eyeballing a `summarize` table.

## Step 3 — Write and verify, one step at a time

- Write annotated Stata code for one accepted checklist item at a time, following
  stata-data-analysis's conventions (line-by-line comments, run via Step 3's GUI-or-headless
  loop until clean).
- **After every step, output a verification specific to that step** — this is the concrete meaning
  of "verification along the way": the user should be able to see exactly what changed, not take it
  on faith. Concretely:
  - After a duplicates drop: report N before and after, and how many were removed.
  - After a recode: `tab` the new coding against the old one.
  - After handling missing data: `misstable summarize` again to confirm the intended variables
    changed and nothing else did.
  - After a merge: the `_merge` frequency table.
- Never edit `Data/raw` in place — raw data is immutable. Every cleaning step reads from `raw` (or
  the previous step's output) and writes to `Data/modified`, so the original client file is always
  recoverable exactly as received.
- Keep a running log of N (observations) at each step, in the script's own comments or a printed
  table at the end — this is the audit trail that answers "how did we go from 50,000 to 48,200
  rows" without having to re-derive it later.

## Step 4 — Git checkpoints (via the git-setup skill's workflow) — skip entirely for Drive-only projects

If this project chose Drive-only (no git), there is no Step 4 — just keep writing, running, and
verifying scripts per Step 3, and move on once validation passes. Everything below applies only to
a project that chose git/GitHub.

- Do the cleaning work on its own branch, named for the dataset — e.g. `clean-milestones`, not on
  `main` directly.
- Commit at each logical checkpoint, not one giant commit for the whole pass — e.g. "Remove exact
  duplicates," "Standardize gender coding to 0/1," "Handle missing test scores (MAR — control for
  cohort)." This gives a readable history of what cleaning decisions were made and in what order,
  and makes it possible to revert one decision without undoing the rest.
- Open a pull request once the cleaned dataset passes validation, so a teammate can review the
  actual cleaning decisions — not just that code ran, but that the *judgment calls* were reasonable
  — before the cleaned file is treated as final.

## Whenever a new cleaned dataset is finished, export a data dictionary alongside it

This happens every time, not on request — as soon as a `.dta` file in `Data/modified` is the
final output of a cleaning pass, export a companion data dictionary to the same folder (e.g.
`milestones_clean_dictionary.xlsx` next to `milestones_clean.dta`), so anyone who opens the file
later can understand every variable without re-deriving it from the cleaning scripts. One row per
variable: name, label, storage type, value label (if any), observation count, missing count,
unique-value count, and min/max (for numeric variables). A reliable pattern for building this
while the actual data is loaded (needed for the missing/unique/range columns, which plain
`describe` doesn't give you):

```stata
tempname dict
postfile `dict' str32 varname str244 varlabel str20 vartype str32 valuelabel ///
    double n_obs double n_missing double n_unique double min_val double max_val ///
    using "$datapath/modified/<dataset>_dictionary_temp", replace

foreach v of varlist _all {
    local lbl : variable label `v'
    local vtype : type `v'
    local vallbl : value label `v'
    quietly count
    local nobs = r(N)
    quietly count if missing(`v')
    local nmiss = r(N)
    quietly levelsof `v', missing
    local nuniq = r(r)
    capture confirm numeric variable `v'
    if !_rc {
        quietly summarize `v'
        post `dict' ("`v'") ("`lbl'") ("`vtype'") ("`vallbl'") (`nobs') (`nmiss') (`nuniq') (r(min)) (r(max))
    }
    else {
        post `dict' ("`v'") ("`lbl'") ("`vtype'") ("`vallbl'") (`nobs') (`nmiss') (`nuniq') (.) (.)
    }
}
postclose `dict'

preserve
use "$datapath/modified/<dataset>_dictionary_temp", clear
export excel "$datapath/modified/<dataset>_dictionary.xlsx", firstrow(variables) replace
restore
```

## Step 5 — Hand off to analysis

Once validation passes (and the PR is merged, if this project uses git) — say so plainly and
distinctly: **"I'm done cleaning the data — you're ready for analysis."** This is a real milestone;
don't let it slide by buried in the middle of other output.

Then ask for the research questions or analytic plan, since that should drive what happens next,
not be assumed:

- **If the user has research questions or a plan already**: draft a plain-language proposed
  approach — which analysis maps to which question, which variables/subgroups are involved, what
  method fits (descriptive comparison, regression, survival model, etc.) — and share it for
  approval or revision *before* writing any analysis code. Same principle as
  stata-data-analysis's Step 2 "share the plan first," just one level up, at the level of the whole
  analysis rather than a single script.
- **If the user doesn't have research questions or a plan yet**: ask whether they want to supply
  one, or want a recommendation instead. If they want a recommendation, base it on what cleaning
  actually revealed about this specific dataset — which subgroups exist, what's suppressed and to
  what degree, what the unit of analysis is, what merges are possible — not a generic template.
  The cleaning pass already did the work of learning what this dataset can and can't support;
  use that, don't waste it.

Once a plan is agreed on, hand off to **stata-data-analysis** for the actual work.
