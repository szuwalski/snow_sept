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
    (`R/gmacs_io.R`), default **4**. Never substitute `detectCores()`. To raise it for one
    session: `$env:GMACS_MAX_WORKERS = 8`.

---

## Run order

`00_advance_model.R` runs **third**, despite the number. It consumes 01/02's output.

**Jitter (`05`) runs before the retrospective (`06`)** — they were renumbered on 2026-08-27 to make
that order follow the numbers. The jitter can find a better optimum and *promote* it into the model
directory, which invalidates any retrospective computed against the previous fit. Run the other way
round, an hour of peels is thrown away the moment a promotion lands.

| # | Script | Does |
|---|---|---|
| 1 | `01_prep_fishery_data.R` | ADFG removals + NORPAC → `data/derived/` |
| 2 | `02_prep_survey_data.R` | crabpack survey pull → comps, indices, maturity ogive |
| 3 | `00_advance_model.R` | writes `data/derived/` into a model `.DAT`/`.CTL` |
| 4 | *(GMACS)* | run `gmacs.exe` in the model dir, to convergence |
| 5 | `03_build_results_object.R` | model dirs → `Models/rda_ModelsResLst.RData` |
| 6 | `04`–`07` | numbers-at-length, **jitter, then retrospective** (+`06b`), Tier 4 |
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

**Match the file you're in.** `01`/`02`/`04`/`06` are dplyr + `%>%`. `00`/`03`/`05`/`07`/`R/` are
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
narrative prose** — match the register of `Reports/2025-09_SAFE_snow_crab.pdf`, which is what CPT and SSC expect.

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
  `Models/26_gmacs_update_newmat_plus_group/Gmacsall.out`; a `-nohess` peel reports 0. A run that
  used `-nohess` must never reach `retro_refpoints.csv` or a SAFE figure.
- **The 26 model moved to macOS and was then re-fit from a jitter winner, 2026-08-27.**
  The assessment runs on the Mac build (`gmacs`, arm64, GMACS 2.20.34) — see
  `docs/MACOS_GMACS.md`. **Current accepted fit** (promoted from `jitter/088`, seed 20260909;
  provenance in `jitter/PROMOTION.md`), npar 412:

  | nll | max\|grad\| | BMSY | OFL(tot) | Bcurr/BMSY | terminal MMB |
  |---|---|---|---|---|---|
  | -23546.3457934123 | 0.000931 | 144.97170891 | 85.64948279 | 1.32035026 | 141.52834 |

  This fit **meets** the 1e-3 gradient criterion and has a well-conditioned Hessian (smallest
  eigenvalue 34.6, condition 1.4e06). `gmacs.pin` is present and legitimate — it is the winner's
  parameter vector, and `jitter/PROMOTION.md` is what documents it. Do not delete it.

  Two superseded fits, both cold starts stuck in an inferior local optimum where `M_pars_est[15]`
  runs away to its bound (see backlog item 5b) — **do not treat either as evidence this directory
  is stale**: Windows nll -23545.5363970914 / BMSY 149.51794249 / MMB 144.27194, and macOS
  nll -23542.7677063715 / BMSY 149.67883570 / MMB 147.08343 (kept in `jitter/base_prepromotion/`).
  The two builds are numerically identical given the same parameter vector.
- **Peels have no reference points — this is GMACS, not the pipeline.** `gmacsbase.TPL` 2.20.34
  gates both call sites on the peel count:
  `if (CalcRefPoints!=0 && nyrRetroNo==0) calc_spr_reference_points2(1);` (`:5478`, `:13625`; the
  only ungated call, `:11779`, is in `write_eval`, the `-mceval` path). So every run with
  `nyrRetro > 0` returns all 18 derived quantities as exactly **0 in value**, not merely
  zero-variance. Verified 2026-08-27 against the 2.20.34 source in `GMACs/GMACS_tpl-cpp_code/`,
  and against the runs: the unpeeled base reports non-positive sdreport variance for exactly 6
  variables (`Fmsy(3,4)`, `Fofl(3,4)`, `Ofl(3,4)` — fleets that do not exist) while every peel
  reports 19 and zeroes the lot. **This was never a `-nohess` problem** — the peels run *with* the
  Hessian. The retrospective therefore reports MMB and recruitment only, and there is no
  `retro_refpoints.csv`. Applies to the 2025 SAFE too.
- **`spr_grow_yr` in `snow.prj`: the 2026-08-21 note was wrong on both counts** (corrected
  2026-08-27, with the real source in hand rather than inferred from a crash). The out-of-bounds
  shift **does** exist in 2.20.34 — `gmacsbase.TPL:4612` is
  `spr_grow_yr = spr_grow_yr - nyrRetroNo;`, and the bounds checks at `:4609-4610` run *before* it
  with nothing re-checking after; `snow.prj` sets 1982 = `syr`, so peel *p* asks for growth in
  1982 − *p*. And compensating does **not** crash: peel 5 re-run with `spr_grow_yr = 1987` exited
  134 (benign) with a bit-identical nll. Exit 1 is simply what `:4609-4610` return on a bounds
  failure. Still leave `snow.prj` alone and keep `FIX_PRJ_GROWTH_YEAR <- FALSE` — not because
  compensating breaks anything, but because it changes nothing: the quantities `spr_grow_yr` feeds
  are never computed for a peel.
- `README.md` still documents the hand-paste `.DAT` workflow that `00_advance_model.R` replaced,
  and omits `00` entirely. Trust `00`, not the README.
- Two figure filenames are written by two different places each — last writer wins, silently.
- **A freshly built model dir already contains the TEMPLATE's results.** `00_advance_model.R`
  regenerates `out_dir` by copying `template_dir`, which brings the template's `gmacs.par`,
  `gmacs.std`, `Gmacsall.out`, `gmacs.rep` and `Gmacsall.std` with it. Nothing marks them stale.
  On 2026-08-27 a build that had **failed at runtime** showed a complete, plausible fit (407 par,
  nll -19222.4892880162) that was the template's July fit, not the new model's. **Check
  `gmacs.par`'s mtime against the run before believing any number from a new model dir.** This is
  almost certainly how the stale-copy incident below happened. Backlog item 1e.
- The Rmd defends against missing models by substituting `NA`/`0`, so a stale model directory
  yields a plausible-looking table instead of an error. Check what actually loaded.
  **This has already happened once.** Until 2026-08-21 `Models/26_gmacs_update_newmat_plus_group/`
  held a byte-identical copy of the May 25-baseline run — terminal year 2024, `gmacs_files_in.dat`
  naming the *25* `.dat` — and reported BMSY 177.60767282. A genuine fit of the 26 model
  (terminal 2025, survey to 2026, npar 412) gives BMSY ≈ **149.5–149.7** depending on the build
  and starting point (see the macOS entry above), a 19% difference in the quantity the OFL is
  built on. It is the ~178 vs ~150 gap that identifies a stale directory, not the third decimal.
  The stale values are preserved in
  `_pre_run_backup/`. Before trusting any model directory, check `Year_range` in `Gmacsall.out` and
  the datafile named in `gmacs_files_in.dat` — a `.dat` filename from the wrong cycle is the tell.
- `07_calc_tier4.R` and `02_prep_survey_data.R` both pull crabpack with a hardcoded year range.
  They must be advanced together, by hand.
- A hard reset during `05`/`06` leaves a **half-written** peel/jitter directory that still looks
  plausible. After any crash, re-run with `--force` (05) or delete the affected `retro/<n>` /
  `jitter/<nnn>` dir rather than resuming onto it.
