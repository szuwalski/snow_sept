# CLAUDE.md — EBS snow crab, September SAFE

This repo produces the September EBS snow crab SAFE. It sets federal OFL/ABC.
**A wrong number here becomes a wrong regulation.** Accuracy beats speed, every time.

## Read first

1. `docs/SESSION_HANDOFF.md` — current state, blockers, resume-here list.
2. `docs/SEPT2026_CLAUDE_CODE_HANDOFF.md` — the report build steps + settled direction.
3. `README.md` — repo layout, toolchain, data provenance.
4. `docs/CLEANUP_BACKLOG.md` — known debt. Add to it; don't fix it unasked.

---

## Hard rules

1. **Never invent a number.** Every quantity in the SAFE comes from a model run, a derived CSV, or
   a cited source. Not computed yet? Write `NA` and flag it. A plausible placeholder that survives
   to print is the worst failure mode this repo has.
2. **Never hand-edit a model `.DAT`/`.CTL`.** Use `00_advance_model.R`. And never
   `readLines()`/`writeLines()` a GMACS file — they silently rewrite the CRLF line endings and
   non-ASCII comment glyphs those files carry. Use `read_raw_lines()` / `write_raw_lines()` from
   `R/gmacs_io.R`.
3. **Refactors that touch numbers must be proven identical.** Save the outputs, re-run, diff, state
   the diff in the commit message. "Looks right" is not verification. Precedent: the July 2026
   01/02 refactor was verified by parse/deparse identity before it was trusted.
4. **cwd is the repo root, always.** Repo-relative forward-slash paths. No `setwd()` outside the
   peel/jitter loops — and those need `on.exit(setwd(orig_wd))` so a GMACS crash doesn't strand the
   session inside a peel folder.
5. **One source of truth per quantity.** OFL, ABC, `ABC_buffer`, MMB, and M come from the shared
   scalars defined once in the Rmd setup chunk. Never recompute one locally in a chunk — that's how
   two tables in one document end up disagreeing.
6. **Don't relitigate settled decisions.** The "Non-negotiable direction" list in
   `docs/SEPT2026_CLAUDE_CODE_HANDOFF.md` is settled. `[[TODO]]`, `[[VERIFY]]`, and `[[author]]`
   markers are Grant's calls — surface them, never guess them.
7. **No `Co-Authored-By: Claude` trailer in commits.** Subject ≤72 chars, imperative mood. Body
   says *why*, and gives the numbers that changed.
8. **Never edit `Reports/`** (2025 SAFE, the format reference), **`archive_2025/`** (prior cycle,
   dead), or **`data/adfg_removals/`** (immutable dated ADFG snapshots).
9. **Opportunistic cleanup only.** Fix the file you were already asked to touch, in the same
   commit. Everything else becomes a line in `docs/CLEANUP_BACKLOG.md`, not an edit.
10. **Model runs and renders are consequential.** A GMACS run, a 10-peel retrospective, a 100-run
    jitter, or a knit takes real time and overwrites artifacts in place. Confirm before launching.
11. **Never widen GMACS parallelism.** Each worker is a full ADMB process holding a core at 100%.
    On this machine (Precision 5690 / Core Ultra 9 185H) a wide fan-out draws more sustained power
    than the chassis can shed and the machine **hard-resets mid-run**, corrupting the peel or
    jitter directory being written. Worker counts come from `gmacs_max_workers()`
    (`R/gmacs_io.R:7`), default **4**. Never substitute `detectCores()`. To raise it for one
    session: `$env:GMACS_MAX_WORKERS = 8`.

---

## Run order

`00_advance_model.R` runs **third**, despite the number. It consumes 01/02's output.

| # | Script | Does |
|---|---|---|
| 1 | `01_prep_fishery_data.R` | ADFG removals + NORPAC → `data/derived/` |
| 2 | `02_prep_survey_data.R` | crabpack survey pull → comps, indices, maturity ogive |
| 3 | `00_advance_model.R` | writes `data/derived/` into a model `.DAT`/`.CTL` |
| 4 | *(GMACS)* | run `gmacs.exe` in the model dir, to convergence |
| 5 | `03_build_results_object.R` | model dirs → `Models/rda_ModelsResLst.RData` |
| 6 | `04`–`07` | numbers-at-length, retrospective (+`05b`), jitter, Tier 4 |
| 7 | `08_render_report.R` | `SAFE_snow_gmacs.Rmd` → PDF |

`R/` holds the shared function libraries (`gmacs_io.R`, `gmacs_jitter.R`). Nothing there runs on
`source()`; `00`, `05`, and `06` all depend on it.

```powershell
$RS = "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe"   # run from repo root
& $RS 00_advance_model.R <template_dir> <out_dir> <end_year> <out_dat_name> [growth_fix] [repo_root] [survey_end]
```

`SAFE_snow_gmacs.Rmd` sources `0-models.R` (model labels) and loads
`Models/rda_ModelsResLst.RData`. Case names must match across all three — see
`03_build_results_object.R:16-21`.

---

## R style

**Banner comments.** File header states purpose / inputs / outputs / terminal-year knobs / notes;
body is split by numbered section rules. Copy the shape from `R/gmacs_io.R` or `00_advance_model.R`:

```r
## ============================================================================
## 01_prep_fishery_data.R
##
## ADFG fishery removals -> data/derived/. Weights in metric tons.
## Crab-year convention: year N = the N/N+1 season.
##
## TERMINAL-YEAR KNOBS: use_yrs (:229), NORPAC date window (:290)
## ============================================================================

## ---------------------------------------------------------------------------
## 3. Directed-fishery size composition
## ---------------------------------------------------------------------------
```

Convert older `#--` / `#==` banners only in files you're already editing (rule 9).

**Match the file you're in.** `01`/`02`/`04`/`05` are dplyr + `%>%`. `00`/`03`/`06`/`07`/`R/` are
pure base R. Don't mix idioms within a file. No `data.table`, no native `|>` in `.R` files.

**Other conventions, already established — follow them:**

- Plots: `ggplot2` + `theme_bw()`, written as `png("plots/<name>.png", ...); print(p); dev.off()`.
  Not `ggsave()`. Check the filename isn't already written elsewhere before adding one.
- CSV: `read.csv()` / `write.csv(..., row.names = FALSE)`. No `readr`.
- Names: snake_case verb-first functions (`read_raw_lines`, `bin_to_model_sizes`), `is_*` for
  predicates, leading dot for internal helpers, SCREAMING_SNAKE for CLI constants (`END_YEAR`).
- Assertions: `stopifnot()` with a named message. Add one wherever a silent wrong answer is
  possible — bin counts, row alignment, year-range agreement between files.
- Never write output to the repo root. `data/derived/` or `plots/`.

---

## Comments: write for a fisheries scientist, not a programmer

The reader knows crab and knows management. They may not know R idiom, and they were not in the
room when the decision was made. So:

- **Explain the assessment reason, not the R.** State *why this bin edge, why this year window,
  why this constant*.
- **Always give units and the year convention.** "metric tons", "crab-year", "model units".
- **Date and attribute non-obvious decisions**: `(2026-08, per Grant)`.
- **One or two lines.** If it needs a paragraph, it belongs in `docs/`.

```r
# Bad — narrates the code
bin_edges[length(bin_edges)] <- 999   # set last element to 999

# Good — states the assessment reason
# Top edge 999 folds all crab >132.5 mm into the plus group. Without it the
# comps silently DROP large crab (this was a real bug, fixed 2026-07).
bin_edges[length(bin_edges)] <- 999
```

```r
# Bad
nat_m <- 0.27   # natural mortality

# Good
# Base mature-male M (yr^-1), the prior median. Also the Tier-4 target F, so
# OFL = M * MMB with no control-rule ramp (2026 basis, per CPT).
nat_m <- 0.27
```

This terse style applies to code comments and to project docs. **It does not apply to SAFE
narrative prose** — match the register of `Reports/2025 snow.pdf`, which is what CPT and SSC expect.

---

## Domain conventions

- **Crab year.** `End year N` = the N/N+1 fishery **plus the N+1 summer survey**. Fishery data
  through `END_YEAR`; survey data through `END_YEAR + 1`.
- **Size bins.** 22 bins, `seq(27.5, 132.5, by = 5)` midpoints, columns named `m27.5` … `m132.5`.
- **Binning: `right = FALSE` everywhere.** A crab on a 5-mm cutoff goes to the **upper** bin (the
  previous survey convention). The plus group is a top edge of 999 and is independent of `right=`.
- **Comps sum to 1.** Every row, every file. If one doesn't, something upstream is wrong.
- **2020 has no survey** (COVID). Handle the gap; never interpolate across it silently.
- **M = 0.27** yr⁻¹ base mature-male. Tier 4 is the 2026 harvest-spec basis, flat F = 0.27, no ramp.
- **Currency:** morphometric maturity is the recommendation; ≥95 mm and >101 mm are shown for
  comparison only.

## Data contract

`data/derived/` is the interface between data prep and the model. **Six tidy files**, each with a
header row, an explicit `year` column, and **values already in model units**:

`directed_catch.csv` · `bycatch_catch.csv` · `fishery_size_comps.csv` · `survey_size_comps.csv` ·
`survey_indices.csv` · `male_maturity_ogive.csv`

Changing this schema means changing `00_advance_model.R` too. Provider-delivered files keep their
delivery names (ADFG, `EBSCrab_*`, `SnowCrabGrowthMaster.csv`); everything else is snake_case.

---

## Known traps

Verified against source, 2026-08. Details and line numbers in `docs/CLEANUP_BACKLOG.md`.

- **Reference points need the Hessian.** `-nohess` skips ADMB's sd phase, so BMSY/Fmsy/Fofl/OFL
  come back as exactly `0.0` — not missing, *zero*. Verified 2026-08-21 against
  `Models/26_gmacs_update_newmat_plus_group/Gmacsall.out`: base fit BMSY 149.51794249,
  OFL(tot) 86.95426329; a `-nohess` peel reports 0. A run that used `-nohess` must never reach
  `retro_refpoints.csv` or a SAFE figure.
- **Never rewrite `spr_grow_yr` in `snow.prj`.** A one-byte change (1982→1983) kills GMACS with
  "Memory allocation error" while reading the control file. The folder `gmacsbase.TPL` is 2.20.32b
  but the exe is 2.20.34 and does not behave like it (measured 2026-08-21).
- `README.md` still documents the hand-paste `.DAT` workflow that `00_advance_model.R` replaced,
  and omits `00` entirely. Trust `00`, not the README.
- Two figure filenames are written by two different places each — last writer wins, silently.
- The Rmd defends against missing models by substituting `NA`/`0`, so a stale model directory
  yields a plausible-looking table instead of an error. Check what actually loaded.
  **This has already happened once.** Until 2026-08-21 `Models/26_gmacs_update_newmat_plus_group/`
  held a byte-identical copy of the May 25-baseline run — terminal year 2024, `gmacs_files_in.dat`
  naming the *25* `.dat` — and reported BMSY 177.60767282. The genuine first fit of the 26 model
  (terminal 2025, survey to 2026, npar 412, nll -23545.5364) gives **149.51794249**, a 19%
  difference in the quantity the OFL is built on. The stale values are preserved in
  `_pre_run_backup/`. Before trusting any model directory, check `Year_range` in `Gmacsall.out` and
  the datafile named in `gmacs_files_in.dat` — a `.dat` filename from the wrong cycle is the tell.
- `07_calc_tier4.R` and `02_prep_survey_data.R` both pull crabpack with a hardcoded year range.
  They must be advanced together, by hand.
- A hard reset during `05`/`06` leaves a **half-written** peel/jitter directory that still looks
  plausible. After any crash, re-run with `--force` (06) or delete the affected `retro/<n>` /
  `jitter/<nnn>` dir rather than resuming onto it.
