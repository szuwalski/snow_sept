# Session handoff — September 2026 snow crab SAFE

Pick-up doc for the September 2026 EBS snow crab SAFE in `snow_sept`. See `../README.md` for the full
repo layout and run commands; this file tracks *state and next steps*.

## TL;DR — where we are
Porting the September SAFE onto the portable May 2026 Rmd (not the old sourced-gmr Sept 2025 Rmd),
faithful to the 2025 SAFE format/style. Environment, portability, model staging, and the
results-object step are **done and verified**. **ADFG 2026 fishery removals are in and staged.** Still
**blocked** on the 2026 summer-survey crabpack pull + Cody's GMACS executable pin before the accepted
model can be advanced to End year 2025 and run. Narrative-section port is the next data-independent work.

## Done & verified
- **Toolchain**: R 4.5.1; `gmr`, `wtsGMACS`, `wtsUtilities`, `crabpack`, `rema`, bookdown/officedown/
  flextable/pacman. pandoc via Positron bundle (3.6.3) — `render_report.R` wires it in.
- **Models** in `Models/`: `25_gmacs` (2025 reference) + `25_gmacs_update_newmat_plus_group` (accepted).
- **Scripts** de-hardcoded / advanced to 2025/26 windows; all parse. `03_read_model_results.R`
  (renamed from `03_buck_read_results.R`) runs headless and **verified** to build
  `Models/rda_ModelsResLst.RData` with the two correct case names matching the Rmd selectors.
- **ADFG catch data (this session)**: Tyler's 5 CSVs (through crab_year 2025) staged into
  `data/new_catch/` (working copy) + archived at `data/adfg_removals/2025_26/`. Verified prior-year
  integrity; found a real **1990–1993 retained-composition correction** (see below). Draft
  `docs/EMAIL_to_tyler.md` asks Tyler to confirm it's intentional.
- **Repo reorg (this session)**: stale prior-cycle files moved to `archive_2025/`; catch snapshots
  renamed under `data/adfg_removals/`; docs moved to `docs/`; real `README.md` + expanded `.gitignore`
  written. Verified no live pipeline file references any moved/renamed path.

## Known flags / gotchas
- **retained_catch_composition** (RESOLVED): the 2026 delivery genuinely differs from ADFG's 8/4/2025
  delivery (779 prior-year lines) — an early-1990s crab_year offset fix (fishery QO91 = 1990 season was
  tagged crab_year 1992, etc., so 1990/1991 read empty). Three-way reconciliation confirmed our archived
  `data/adfg_removals/2024_25/` == Tyler's authentic 8/4/2025 delivery (content-identical), so the change
  is ADFG's, not ours; and the 2026 version is CORRECT (matches the retained-totals file: 1990/1991 had
  real landings). Adopted. Note the small historical correction in the SAFE "Summary of Major Changes".
  `data/bssc_202425 (8 4 2025)/` (Grant's forwarded original) duplicates `adfg_removals/2024_25/` —
  candidate to consolidate. See `docs/EMAIL_to_tyler.md`.
- **`bssc_discards.csv`** is read at `01:15` but the variable `disc` is **unused** — Tyler didn't
  deliver it; harmless (stale 2024 copy kept in `data/new_catch/`).
- **Reference model** `Models/25_gmacs` has results but **no `gmacs.exe`** — fine at End year 2024;
  needs the exe if advanced to 2025 for the comparison (open design Q).
- **`model_defs[N]` index audit** not yet done — Rmd references models by position in the full May
  list; `0-models.R` keeps the full list. Audit before pruning to the 2-model set.
- Survey-year vectors in `07_tier_4.R` (`c(seq(1982,2019),seq(2021,2026))`) must match the actual 2026
  crabpack pull length — flagged in-file.

## Blocked on data / Cody (critical path)
1. 2026 **summer-survey** crabpack pull (script 02 runs the pull; needs the survey loaded/available).
2. Cody's exact **GMACS executable/TPL** to pin + confirmation of the accepted model / any post-May
   CTL/PRJ changes. (An `EMAIL_to_cody.md` was referenced in earlier notes but never actually written
   — draft it from `docs/HANDOFF_from_cody.md` §C when ready.)

## Resume here (prioritized)
1. **Port narrative sections** onto the new Rmd (data-independent): Introduction (Distribution,
   Natural Mortality, Maturity, Mating ratio, Growth, Management history, ADFG harvest strategy,
   History of BMSY, Fishery history), Data, Ecosystem considerations — from
   `archive_2025/SAFE_snow_gmacs_2025_reference.Rmd`, matching `Reports/2025 snow.pdf`. See
   `docs/PORT_MAP.md`.
2. Send `docs/EMAIL_to_tyler.md`; draft + send the Cody email (exe pin).
3. When 2026 survey + exe land: run `01`/`02` → paste derived inputs into the `.DAT` → run gmacs →
   `03_read_model_results.R` → `04`–`07` → `render_report.R`; then the `model_defs` index audit.
