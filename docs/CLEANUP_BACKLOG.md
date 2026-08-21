# Cleanup backlog

Ranked reproducibility and correctness debt. **Every item was verified against the working tree on
2026-08-21** — line numbers are real, not inferred.

**How to use this file.** Cleanup is *opportunistic*: fix an item when you're already editing that
file, in the same commit (`CLAUDE.md` rule 9). Don't run sweeps. When you find new debt, add a line
here instead of fixing it. Tick items off as they land.

Tier 0 breaks a fresh clone or silently corrupts output. Tier 1 is reproducibility. Tier 2 is
hygiene.

---

## Tier 0 — breaks a fresh clone or corrupts output silently

- [ ] **1. Nothing currently open at Tier 0.** Items land here when they break a fresh clone or
  corrupt output silently. See Done for what cleared.

  **Standing rule from the 2026-08-21 render blocker:** never put a backtick inside an inline
  `` `r ` `` expression, escaped or not. knitr's inline pattern stops at the first backtick, so the
  expression truncates mid-string and the whole document fails to knit — one bad line costs the
  entire PDF. To name a script in placeholder prose, write it bare (`run 06_run_jitter.R`). Cheap
  check before any render:

  ```r
  L <- readLines("SAFE_snow_gmacs.Rmd", warn = FALSE)
  m <- gregexpr("`r[ #][^`]*`", L)
  for (i in seq_along(L)) for (h in regmatches(L[i], m[i])[[1]])
    tryCatch(parse(text = sub("^`r[ #]", "", sub("`$", "", h))),
             error = function(e) cat("line", i, "FAILS:", conditionMessage(e), "\n"))
  ```

- [ ] **2. `README.md` documents a workflow that no longer exists.** `README.md:71` and `:77-78`
  describe hand-pasting `data/derived/` into the model `.DAT` — the step `00_advance_model.R`
  replaced. `README.md:35` repeats it. The script inventory (`:18-25`) and the run sequence
  (`:65-75`) **omit `00_advance_model.R` entirely**, and now also omit `05b_plot_historical_bias.R`
  and `R/`. A new user will hand-paste for nothing.
  Also stale: `README.md` cites `docs/HANDOFF_from_cody.md` and `docs/EMAIL_to_tyler.md`; neither
  exists in `docs/` any more.

- [ ] **3. `04_plot_numbers_at_length.R` reads two files that don't exist.** `:18` reads
  `data/survey/EBSCrab_Abundance_Biomass_female.csv`, `:39` the `_male` equivalent. `data/survey/`
  contains only `EBSCrab_AB_Sizegroup.csv`, `survey_large_male_index_derived.csv`, `README.txt`.
  The script cannot run as written. Decide whether to repoint it at the AKFIN size-group export or
  retire it.

- [ ] **4. `plots/size_bins_comp_Kodiak_m.png` is written by two scripts** —
  `02_prep_survey_data.R:156` and `04_plot_numbers_at_length.R:74`. Whichever ran last is what
  appears in the SAFE, silently. (Related: item 3 — `04` can't currently run at all, which is the
  only reason this hasn't bitten yet.)

---

## Tier 1 — reproducibility

- [ ] **5. One `END_YEAR`, in a `config.R`.** `00_advance_model.R` already takes it as a validated
  CLI arg (`:45-70`). Nothing else does. Still hardcoded at:
  `01_prep_fishery_data.R:229` (`use_yrs <- seq(1991, 2026)`) and the NORPAC date window;
  `02_prep_survey_data.R:69` (`years = c(1982:2026)`), plus the hardcoded 2020 gap-year drop;
  `07_calc_tier4.R:23` (`years = c(1982:2026)`), `:191`, `:235`, `:278` (B<sub>MSY</sub> averaging
  window `year < 2025`, three copies).
  **`07:23`'s crabpack year range must be kept in sync with `02:69` by hand** — nothing checks it,
  and they are two independent pulls of the same survey.
  Both `01:30` and `02:65` helpfully *document* their knobs in the header; they're still literals
  in the body.

- [ ] **6. Post-condition assertions in `01` and `02`.** These are the files whose silent errors
  propagate all the way into the OFL, and they have no validation. Add:
  - comp rows sum to 1 within tolerance
  - exactly 22 `m*` bin columns
  - `data/maturity/snow_ogives.csv` covers the survey terminal year — `02:28-29` *warns in a
    comment* that a mismatch silently misaligns Section 6, and nothing enforces it
  - the row-alignment assumption `01:94` flags in a comment (`filter(fems, fish=='QO')` assumed
    row-aligned by crab_year, with no join and no check)

- [ ] **7. Collapse `07_calc_tier4.R`'s three REMA/HCR blocks into one function.**
  `:177-220` (morphometric), `:221-265` (preferred), `:266-305` (large) are near-identical ~45-line
  copies — three `prepare_rema_input` → `fit_rema` → `tidy_rema` → HCR chains. Copy-paste drift is
  already visible:
  - `nat_m <- 0.27` assigned at `:37`, `:201`, `:247`, `:287`; bare `.27` at `:185`, `:228`, `:273`
  - `beta <- 0.25; alpha <- 0.1` at `:199-200`, `:245-246`, `:285-286`
  - the plot object is assigned twice in a row at `:217-218`/`:219-220`, `:262-263`/`:264-265`,
    `:302-303`/`:304-305` — the first is immediately overwritten. Dead code in triplicate.
  - `:295-296` rounds the whole accumulated vector where `:209-210` and `:255-256` don't
  - `OFL_dana` computed at `:214`, `:260`, `:300`, never used
  - stray scratch expression at `:242`: `22.63*exp(-(7/12)*nat_m)`
  One `tier4_hcr(biomass, cv, years, label)` replaces ~135 lines with ~50.
  **This one sets the OFL — the duplication is the risk, not the line count.**

- [ ] **8. `SAFE_snow_gmacs.Rmd:979` writes a CSV into the repo root at knit time.**
  `write.csv(tot_likes_t, file = paste0("tot_likes_t_", Sys.Date(), ".csv"))` — every render adds a
  new untracked, un-gitignored file. Write it to `data/derived/` or drop it.

- [ ] **9. The Rmd fails soft, not loud.** It defends against missing model results by substituting
  `NULL`/`NA`/`0` (e.g. `:966`, `tot_likes[is.na(tot_likes)] <- 0`). A stale or absent model
  directory therefore produces a plausible-looking table of zeros rather than an error. Convert the
  guards to `stop()` for the final render, or add an explicit "what loaded" summary the author must
  eyeball.

---

## Tier 2 — hygiene, as you pass through

- [ ] **10. Convert comment banners to `## ---`** in files you're already editing:
  `03_build_results_object.R`, `07_calc_tier4.R`, `0-models.R` still use Cody's `#--` / `#==`.
  Standard is in `R/gmacs_io.R` and `00_advance_model.R`. See `CLAUDE.md` → R style.
  (`05`/`06` were rewritten 2026-08-21 and already conform.)

- [ ] **11. Re-audit `05_run_retrospective.R` once the current rewrite lands.** It went 465 → 624
  lines on 2026-08-21 and now correctly sources `R/gmacs_io.R` and uses `on.exit(setwd(old))`. The
  old dead-code findings (undefined `retro_outs`/`mohnrho`, the `./retro/2018_s/` block, the
  duplicated `df_normalized`) were against the previous version and have **not** been re-checked
  against the rewrite. Do that before trusting a clean bill of health.

- [ ] **12. Stale cross-references.** `SAFE_snow_gmacs.Rmd:67` cites `05_buck_read_results.R`
  (now `03_build_results_object.R`). `0-models.R:11-12` carries `TODO(Phase 3)`: audit every
  positional `model_defs[N]` use in the Rmd before pruning the list to the September set.
  `SAFE_snow_gmacs.Rmd:98` — `>>> REVIEW: confirm comparison pairs once the 2026 results object exists`.

- [ ] **13. Package loading.** `03_build_results_object.R:4` uses `require(wtsGMACS)` — warns
  instead of failing — and never loads `wtsUtilities` despite calling it at `:26`.
  `04_plot_numbers_at_length.R:3-12` loads `reshape`; every other script uses `reshape2` (latent
  `melt()`/`cast()` conflict). `07_calc_tier4.R:2-13` loads `dplyr`, `ggplot2`, and `reshape2`
  twice each within 12 lines.

- [ ] **14. Dependency pinning.** ~40 packages, 5 GitHub-only (`wtsGMACS`, `wtsUtilities`,
  `crabpack`, `rema`, `gmr`) whose install instructions live only in comments
  (`SAFE_snow_gmacs.Rmd:44-52`, `07_calc_tier4.R:164`). No `renv.lock`, no `DESCRIPTION`, no
  version pinning; R 4.5.1 is documented in prose only. A `packages.R` would be the cheap version;
  `renv` the real one.

- **`SAFE_snow_gmacs.Rmd` — the max-gradient paragraph opening `## Model convergence and
  comparison` is still 2025 text.** It asserts that "only `Model 25.1d` fell below that threshold;
  the remaining 13 models had max |gradient| > 0.001, with `Model 25.3c` the largest at ~0.10" —
  hardcoded claims about a 14-model bracket that the September set does not contain. Left alone
  deliberately when the jitter paragraphs beside it were rewritten (2026-08-21, rule 9): fixing it
  properly depends on the `model_defs` prune, which is still open. Until then the paragraph names
  models the document no longer presents.

- **`data/derived/fishery_size_comps.csv` rows do not sum to 1.** 66 of 174 rows are off by up to
  3.0e-03. Cause is `01_prep_fishery_data.R:250-251`, which normalizes then rounds to 3 dp
  (`round(BycatchFem / sum(BycatchFem), 3)`); 55 of the affected rows are fleet 2 / type 2, matching
  that code exactly. Violates the "comps sum to 1" contract. Cheap fix is to drop the rounding, but
  it changes model inputs, so it needs the rule-3 identity check.

- **`plots/size_bins_comp_Kodiak_m.png` is written by two scripts.** `02_prep_survey_data.R:156`
  and `04_plot_numbers_at_length.R:74`. `04` runs later, so `02`'s version never survives.

- **All 44 male/immature CVs in `data/derived/survey_indices.csv` are `NA`.** Inert today —
  `00_advance_model.R:326` filters to `maturity == "mature"`, so those rows never reach the model.
  It becomes live the moment anyone acts on the SSC's immature-index suggestion.

- **`Models/25_gmacs` has no `gmacs.exe`.** It has results but cannot be re-run or peeled.

---

## Watch list

- **Thermal headroom on the Precision 5690.** `gmacs_max_workers()` now defaults to 4 (was 12 in
  `06`, 8 in `05`), which stopped the hard resets. If a reset ever recurs at 4, drop to 2 rather
  than assuming it was a one-off — the failure corrupts whatever run directory was mid-write, and
  a half-written peel still parses. Consider also running `gmacs.exe` at below-normal process
  priority; not done yet because it means changing the `system2()` invocation, which is on the
  path that produces the numbers (rule 3).

  **A reset did recur, 2026-08-21**, during `06`'s 100-run sweep. But note the cap is per-session
  and the hardware is not: `06` was at its 4 workers *and Grant was running two models by hand*,
  so ~6 `gmacs.exe` processes were pinned at once. So this is not evidence that 4 is unsafe on its
  own — it is evidence that **the cap needs to be global, not per-process-tree**. Until something
  enforces that, anyone starting a GMACS run should check whether another is already going.
  Damage: 18 of 44 jitter directories were left half-written; 26 survived and were reused.
  The sweep was resumed at `--cores 2`.

- **Crash-truncated output files parse.** The reset above produced `Gmacsall.out` files that stop
  mid-block and read fine for hundreds of lines. `06_run_jitter.R`'s resume guard now requires the
  file to end with GMACS's `>EOD<` terminator (`.ends_cleanly()`), and `prepare_run_dir()` wipes a
  directory's previous outputs before re-running it, so a stale file cannot be mistaken for the
  new run's result. **`05_run_retrospective.R` should carry the same terminator check** if it does
  not already — existence of `Gmacsall.out` is not evidence a peel finished.

## From the 2026-08-21 adversarial review — not yet triaged

Found by review of `832d034~1..HEAD`. Two were confirmed against run artifacts on disk, not just
read from the diff. Ranked; none fixed (they sit in in-flight work).

- [ ] **A. `05_run_retrospective.R:168` — `verify_run` never checks reference points are non-zero.**
  `retro/_diagnostic/prjfix_off/` has BMSY = OFL = `0.0` and is recorded `ok = TRUE`. Combined with
  the `-nohess` behaviour (see CLAUDE.md known traps), the same condition in the peels stage puts
  **zeros** into `retro_refpoints.csv` and the SAFE figure. Highest-consequence finding.
- [ ] **B. `05:343` / `06:228` — top-level `on.exit()` never fires** (verified). A worker error
  leaks N ADMB-holding Rsessions — exactly the condition rule 11 exists to prevent. Wrap the
  cluster in a function, or register the cleanup with `reg.finalizer`/explicit `tryCatch`.
- [ ] **C. `06:217` — `is_done()` calls `readLines()` on a possibly-absent `jitter.txt`.**
  `suppressWarnings` does not catch a connection error, so the resume scan aborts the run instead
  of re-running that directory.
- [ ] **D. `05:174` — `last_survey_year` is collected but never asserted**, so `drop_survey`'s
  defining property is unverified. A regression would make it silently identical to `standard`.
- [ ] **E. `05:465` — `rho_table`/`peel_rel` loop `1:N_PEELS`**, excluding the `drop_survey` peel-0
  run, which is the run that isolates the terminal survey's leverage.
- [ ] **F. `05:490` — Ralston's sigma divides by `n-1` where `n` counts non-NA `rel`**, not non-NA
  `lg` (which carries an extra guard), understating the RMSE.
- [ ] **G. `00_advance_model.R:701` — the (e2) check** compares survey comp years against an
  index-derived, male-only `expect_surv`, forcing two derived files to share a terminal year. A
  legitimate mismatch exits 1 and breaks every `drop_survey` peel.

**Cleared by the same review** (checked, no defect): `foreach` auto-export in `05`;
`read_gmacsall_summary` header/row token alignment (25/25 against the real `Gmacsall.out`); every
`refpoint()` name lookup; `gmacs_echo_value` keys vs `gmacs_files_in.dat`; `set_prj_growth_year`
round-trip on the real `snow.prj`; `infos[[run_ids[i]]]` on a missing name; Mohn's rho sign
convention and denominator.

## Done

- [x] ~~The SAFE did not render at all: escaped backticks inside inline `` `r ` `` expressions at
  `SAFE_snow_gmacs.Rmd:695` and `:804` truncated the expression, so knitr failed with
  `unexpected INCOMPLETE_STRING` and `08_render_report.R` produced no PDF.~~ Both fixed
  2026-08-21 (804 by Grant, 695 here). Verified by parsing every inline expression in the file:
  **29 expressions, 0 failing.** Still to confirm with an actual knit.
- [x] ~~`R/` untracked in git while three committed scripts hard-stop without it.~~ Tracked in
  `832d034` (`R/gmacs_io.R`, `R/gmacs_jitter.R`, 899 lines).
- [x] ~~`06`'s single `MAX_GRAD_TOL = 1e-3` gate marked every run non-converged (pilot runs sit at
  5.6e-3 to 1.59e-2, base at 2.54e-3), emptying the mode analysis while exiting 0.~~ Split into
  `GRAD_CONVENTIONAL` (1e-3, reported) and `GRAD_USABLE` (1e-2, the screen), `06:79-80`.
- [x] ~~`05`/`06` duplicated the GMACS run-directory setup instead of using
  `set_retro_peel()`/`set_jitter()` from `R/gmacs_io.R`, and left `setwd()` unguarded.~~
  Fixed 2026-08-21: both now source `R/gmacs_io.R` (`05:67`, `06:97`) and use
  `on.exit(setwd(old), add = TRUE)` (`05:129`).
- [x] ~~`05:455` called `plot_layout()` with `patchwork` never loaded → runtime error.~~ Gone in
  the rewrite.
- [x] ~~`plots/retro_mmb.png` written twice within `05` (`:130`, `:154`), first figure destroyed.~~
  Now written once, `05:560`.
- [x] ~~An unrelated historical-bias analysis was bolted onto the end of `05`.~~ Extracted to
  `05b_plot_historical_bias.R`.

## Deliberately not changed

These look like bugs and aren't — they match the authoritative `snow_crab` repo, i.e. they are
long-standing and intentional. Ask Cody before touching any of them.

- `01_prep_fishery_data.R` — male total comp uses `right = TRUE` while retained and female use
  `right = FALSE`
- `01:33,53` — `bssc_discards.csv` read into `disc`, never used (ADFG no longer delivers it)
- `01:38,340` — `bycatch_dat_big[,-24]` drops a column by position (fragile, but matches upstream)
