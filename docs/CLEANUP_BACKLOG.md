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

- [ ] **1. `.gitignore:22`'s `*.out` swallows every `Gmacsall.out`.** The rule is in the LaTeX
  block and is meant for `.out` build artifacts, but it also matches `Gmacsall.out` — the primary
  GMACS results file, and the one `03_build_results_object.R` and `06_run_retrospective.R` parse.
  Found 2026-08-26: `Models/26_gmacs_update_newmat_plus_group/` reached this machine with
  `gmacs.par`, `gmacs.std`, `Gmacsall.std` and `run.log` intact but **no `Gmacsall.out`**, so the
  accepted Windows fit's results were simply absent and stage `collect` could not run. `git
  check-ignore -v` confirms the match. Fix: scope the LaTeX rule (e.g. `/SAFE_snow_gmacs.out`) or
  add `!Gmacsall.out`. Until then, a Gmacsall.out never travels with a commit.

- [x] ~~**1c. `05`'s promotion rollback claimed success while doing nothing.**~~ Fixed 2026-08-24.
  The `!good` branch restored `jitter/base_prepromotion/` with an unchecked `file.copy()` and then
  asserted `"The model directory is as it was."` On the first real macOS jitter it left **seven of
  nine** files (`gmacs.par`, `gmacs.std`, `gmacs.rep`, `gmacs.rep1`, `gmacs.cor`, `Gmacsall.out`,
  `Gmacsall.std`) holding the output of the promotion run the script had *just judged invalid*, and
  left a stray `gmacs.pin` behind — which ADMB reads automatically, so every later run in that dir
  would have silently started from the rejected fit. Now copies, re-checks by md5, and either names
  the files it could not restore or reports how many it verified. **Root cause of the copy failure
  itself is still unexplained** — the same loop succeeds when re-run by hand, so treat it as
  non-deterministic and keep the checksum gate.

- [ ] **1d. An ADMB error in the sd phase is why that promotion was rejected.** The promotion re-fit
  reproduced the winning jitter run to 12 significant figures (-23546.3457934123 vs
  -23546.3457934122) and wrote a complete `gmacs.std`, but exited 1 with
  `Error reading stack identifer for b` on stderr, emitted during
  `Differentiating 4 derived quantities`. `is_benign_gmacs_exit()` correctly refused to excuse it
  (it is not one of the three known macOS FP teardown messages). Unresolved: whether the sdreport
  output from such a run is trustworthy. Until that is answered, **do not adopt a promoted fit whose
  log contains this message**, and do not widen the benign-exit allowlist to cover it.

- [ ] **1e. `00_advance_model.R` ships the TEMPLATE's results inside every new model dir.**
  Section 8 regenerates `out_dir` by copying `template_dir`, so a freshly built model directory
  arrives already containing the template's `gmacs.par`, `gmacs.std`, `Gmacsall.out`, `gmacs.rep`
  and `Gmacsall.std`. Nothing marks them as stale. On 2026-08-27 a male-only build that had
  **failed at runtime** presented a complete, plausible fit — 407 parameters, nll -19222.4892880162
  — which was the 25 model's July fit copied in, not the new model's. Caught only by checking
  mtimes (Jul 28 vs the run's own 22:23).

  This is the same failure CLAUDE.md's known-traps section records as having already happened once
  (`Models/26_gmacs_update_newmat_plus_group/` holding a byte-identical copy of the May baseline),
  and this is very likely the mechanism that produced it. Fix: delete the template's result
  artifacts after the copy, or copy only the input files. Until then, **check `gmacs.par`'s mtime
  before believing any number out of a freshly built model dir.**

- [ ] **1b. Nothing else currently open at Tier 0.** Items land here when they break a fresh clone
  or corrupt output silently. See Done for what cleared.

  **Standing rule from the 2026-08-21 render blocker:** never put a backtick inside an inline
  `` `r ` `` expression, escaped or not. knitr's inline pattern stops at the first backtick, so the
  expression truncates mid-string and the whole document fails to knit — one bad line costs the
  entire PDF. To name a script in placeholder prose, write it bare (`run 05_run_jitter.R`). Cheap
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
  (`:65-75`) **omit `00_advance_model.R` entirely**, and now also omit `06b_plot_historical_bias.R`
  and `R/`. A new user will hand-paste for nothing.
  Also stale: `README.md` cites `docs/HANDOFF_from_cody.md` and `docs/EMAIL_to_tyler.md`; neither
  exists in `docs/` any more.

- [x] ~~**3. `04_plot_numbers_at_length.R` reads two files that don't exist.**~~ Resolved
  2026-08-27 by retiring the script (per Grant). It could not run on four counts: the two missing
  CSVs; `plot_layout()`/`|` with `patchwork` never loaded; `snowad.rep`/`M`/`x` undefined anywhere
  in the repo; and hardcoded 1978-2017/1982-2019 year ranges. Its male ridgeline duplicated
  `02_prep_survey_data.R:156` (item 4) and the SAFE referenced neither figure. The female ridgeline
  moved to `02` section 6c and the recruitment comparison was rebuilt as
  `04_plot_recruitment_comparison.R`, reading the fit's own `Gmacsall.out` rather than the
  month-stale `rda_ModelsResLst.RData`. Original text: `:18` reads
  `data/survey/EBSCrab_Abundance_Biomass_female.csv`, `:39` the `_male` equivalent. `data/survey/`
  contains only `EBSCrab_AB_Sizegroup.csv`, `survey_large_male_index_derived.csv`, `README.txt`.
  The script cannot run as written. Decide whether to repoint it at the AKFIN size-group export or
  retire it.

- [x] ~~**4. `plots/size_bins_comp_Kodiak_m.png` is written by two scripts**~~ Resolved
  2026-08-27: `04` was retired, so `02_prep_survey_data.R` is the sole writer of both Kodiak
  figures. Original text: written by —
  `02_prep_survey_data.R:156` and `04_plot_numbers_at_length.R:74`. Whichever ran last is what
  appears in the SAFE, silently. (Related: item 3 — `04` can't currently run at all, which is the
  only reason this hasn't bitten yet.)

---

## Tier 1 — reproducibility

- [ ] **4f. Re-running `02` is not byte-reproducible, and that silently breaks the provenance
  check.** Run on 2026-08-28 against the same crabpack data, `02_prep_survey_data.R` rewrote
  `data/derived/survey_indices.csv` and `survey_size_comps.csv` with **different bytes but the same
  numbers** — max |diff| **1.0e-12** and **1.0e-15** respectively, identical dimensions, columns and
  year ranges. `male_maturity_ogive.csv` was byte-identical, and the three files `02` does not touch
  were untouched.
  **It matters because `00` writes derived values verbatim**, so those extra digits propagate into
  the model `.DAT`: after the re-run, rebuilding the 26 model no longer reproduced it
  byte-for-byte (first difference at line 245). That byte-identical rebuild is the provenance check
  this repo leans on everywhere — CLAUDE.md rule 3 — so losing it costs more than the 1e-12 is
  worth. The two files were restored from a pre-run backup and reproducibility was re-verified.
  Fix: have `02` write with a fixed format (e.g. `format(x, digits = 15)` or a set number of
  decimals) so repeated runs are byte-stable. **Until then, back up `data/derived/` before running
  `02`, and diff afterwards** — the numbers will match, the bytes may not.
  Note the two intended outputs of the run were kept: `data/survey/survey_recruit_index_derived.csv`
  and `survey_large_male_index_derived.csv`, plus the new §3b/§6c figures.

- [x] ~~**4e. `00_advance_model.R` could not build at an EARLIER end year.**~~ Fixed 2026-08-28
  while building the data-through-2019 run (Model 26.1b), the first time anything asked `00` for an
  end year below the template's. Two files carry year settings that `00` was passing through
  untouched, and both stopped GMACS before the first function evaluation:
  1. **`snow.prj` averaging windows.** The projection file is copied verbatim, so a 2019 model
     inherited windows ending 2023/2024. GMACS: *"Last year for computing Rbar must be nyr or
     earlier: STOPPING. spr_nyr = 2023 nyr = 2019"*. `00` now clamps every "first and last year"
     range to `END_YEAR`, leaving the projection HORIZON (2031) and the `0 = last year` sentinels
     alone.
  2. **Block group 1, the additional-mortality event periods** (2018, 2019, **2020**). A
     2019-terminal model cannot carry a 2020 period: GMACS died in `timevarparM()` with *"matrix
     bound exceeded -- row index too high ... value was 2020"*. Found by `lldb` backtrace. `00` now
     drops out-of-range periods together with their per-group parameter rows and decrements the
     per-group count. **It refuses to drop an ESTIMATED period** — that would be an assessment
     change, not a mechanical clamp. In the template all four 2020 rows are `phz -4`, ival 0, so
     nothing being fitted was removed.
  Both are no-ops at `END_YEAR = 2025`: the 2025 two-sex and male-only builds are **byte-identical**
  before and after (`.dat`, `.ctl`, `.prj`).
  **A caution recorded because it nearly slipped through:** the first "no-op confirmed" test on the
  `.prj` change passed *vacuously* — the script errored before reaching the new code (it called
  `read_gmacs_control(OUT_DIR)` before `gmacs.dat` had been patched), so nothing was exercised.
  The same failure mode as the vacuous filter in the 2026-08-28 adversarial review. A regression
  test that cannot fail is worse than none.

- [x] ~~**4c. `06_run_retrospective.R` rebuilt drop-survey peels as TWO-SEX models.**~~ Fixed
  2026-08-28. `prepare_peel()` replays `00_advance_model.R` to regenerate a drop-survey peel's
  `.DAT` with a shortened `survey_end`, and passed args 1-7 — **never arg 8, `male_only`**. Every
  drop-survey peel of `26_gmacs_male_only` was therefore a two-sex model: it parsed, converged, and
  returned plausible retrospective numbers (nll **-20673** against the male-only **-12664**, and
  ~40 extra female `T_pars_est` blocks). `write_peel_pin()`'s parameter-block check catches it on a
  **seeded** run — but a cold start has no shape to check against, so the first pass produced a
  silently two-sex retrospective for a male-only model, and cached two-sex shapes for next time.
  Fix: `06` now reads `# Number of sexes` from the model's own `.DAT` (`NSEX`/`MALE_ONLY`) and
  passes arg 8 accordingly, rather than taking a flag that can be forgotten; the run header prints
  the sex structure. The contaminated `retro/_shapes/drop_survey/` cache was deleted and rebuilt.
  `ADVANCE_TEMPLATE` needed no change — `Models/25_gmacs_update_newmat_plus_group` is the correct
  template for the male-only model too.
  **The `SHAPES_FOR.txt` stamp does not cover this**: it records the *model's* datafile name, md5
  and end year, none of which change when the *rebuilt* peel `.DAT` has the wrong sex structure.
  It is adequate now only because the male-only flag is read from the same datafile the stamp
  hashes. Any future `00_advance_model.R` argument that alters peel structure without altering the
  model `.DAT` would reopen the same hole.

- [x] ~~**4d. `model_defs` was the retained May bracket, not the models this cycle ran.**~~
  Fixed 2026-08-28. `length(model_defs)` had reached **17** against **5** existing folders, and six
  narrative sentences interpolated it directly (`:278`, `:442`, `:717`, `:906`, `:920`, `:930`) —
  "A total of `r length(model_defs)` models were explored" would have printed **17** in a document
  that ran 5. It was already wrong before the September models were added (14 against 2 populated
  folders); those three made it louder, not new. Three table-building chunks also iterated the full
  bracket, and their extractors return `NA`/zero rows for a missing folder, so
  Table \@ref(tab:max-grad) would have rendered 17 rows with 12 blank, the likelihood tables 12
  all-zero columns, and Table \@ref(tab:stepchange) — **the table the OFL/B<sub>MSY</sub>
  comparison is read from** — 12 rows of NA management quantities.

  Resolved by **pruning `0-models.R` to the five-model September set** (per Grant), which is what
  the old port note's "TODO(Phase 3)" called for. Its precondition — "audit every `model_defs[N]`
  use in the Rmd" — was done first and found **no positional indexing anywhere**: every reference
  is by name (`model_defs[accepted_model]`), by loop, or whole-vector, and the results object is
  keyed by case name (`reslst$repsLst[[accepted_model]]`) rather than position. The only
  `model_defs[1]` is a comment recording an already-removed reference. The May bracket survives in
  `../snow_crab/0-models.R` and in git history.

  Also folded in: `model_jittered` now lives in `0-models.R` keyed by label, replacing the
  positional `jittered` vector in the model-overview chunk (a positional list misaligns silently,
  and R only errors when lengths do not divide evenly — 14 against 28 would have recycled without
  complaint); `models_present`/`n_models` remain as a guard so an unbuilt model drops out of the
  tables and the count instead of rendering blank; and `0-models.R` warns by shortname when a
  folder is missing.

  **Still open — the Rmd's Section C narrative now contradicts the model set.** Eleven bullets at
  `:447`-`:477` still describe Models 25.1a-25.1e, 25.2a/b/d and 25.3a-d, which no longer exist in
  `model_defs`, immediately under a sentence that now reads "A total of 5 models were explored".
  The approved replacement is already written — `PHASE1_SECTION_SKETCHES.md` §12, a full
  voice-matched rewrite of Section C — and `SEPT2026_SNOW_CRAB_BUILD_PLAN.md:107` specifies
  **[REMOVE] hybrid scenarios 25.3a–d (keep a short audit-trail note)**. Left for the author: it is
  a substantial piece of SAFE prose, not a mechanical edit.

- [ ] **4b. `06_run_retrospective.R` writes its figures to model-independent filenames.**
  `:770`, `:776`, `:783`, `:793` write `plots/retro_mmb.png`, `retro_recruitment.png`,
  `retro_mmb_drop_survey.png` and `retro_terminal_mmb.png` with no model qualifier, while the
  script takes `model_dir` as an argument. Running the retrospective on any second model therefore
  **silently overwrites the accepted model's retrospective figures** — the ones the SAFE uses —
  with no warning and no way to tell from the file which model produced it. The CSVs are safe;
  they go to `<model_dir>/retro/`. Hit on 2026-08-28 running the retrospective on
  `26_gmacs_male_only`; the two-sex figures were copied to `plots/_twosex_retro_backup/` first and
  the male-only outputs renamed `*_male_only.png` afterwards, by hand. Fix: derive the filename
  from `basename(model_dir)`, or take an output prefix. Same class as the two-writers-one-filename
  item on the watch list, but worse — here the two writers are the same script on different models.

  **`05_run_jitter.R` has the identical defect, and it is worse there** because one of the outputs
  is data, not a figure. Despite taking `--model`, it writes `Models/rda_jitter.RData` (the object
  the SAFE Rmd loads) plus `plots/jittered_results_{ofl,rec,ssb}.png`,
  `plots/jitter_convergence.png` and `plots/jitter_param_attribution.png` under model-independent
  names. Running the jitter on `26_gmacs_male_only` on 2026-08-28 overwrote the accepted two-sex
  model's jitter artifacts twice. They are **untracked by git**, so there was no VCS recovery; they
  were rebuilt by re-running `05 --model 26_gmacs_update_newmat_plus_group --no-promote`, which
  resumes over the intact 100 run directories without re-fitting and reproduced the documented
  values exactly (79/100 usable, 5.1% best mode, winner run 088, base nll -23546.3457934123).
  Male-only copies now sit at `Models/rda_jitter_male_only.RData` and
  `plots/_male_only_jitter/*_male_only.png`. **Until this is fixed, any jitter or retrospective run
  on a non-default model silently destroys the accepted model's artifacts** — back them up first.

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

- [ ] **5b. `M_pars_est[15]` is unidentified in the base fit and drags the whole model with it.**
  Measured 2026-08-24/27 on the macOS build. `snow.ctl`'s natural-mortality block, row 15 —
  **Females (Immature), Block 2**, phase 4, bounds `[-1, 10]`, `Block_fn = 1` (exponential).

  | | base fit (nll -23542.77) | jitter run 088 (nll -23546.35) |
  |---|---|---|
  | `M_pars_est[15]` | **8.707 ± 5351.8** (CV 615) | 1.826 ± 0.581 |
  | smallest Hessian eigenvalue | **1.08e-06** | 34.6 |
  | Hessian condition number | **4.6e13** | 1.4e06 |
  | max\|grad\| | 7.4e-3 | 9.3e-4 |

  In the base fit that parameter runs to its upper bound with an effectively infinite standard
  error. It is the single near-zero eigenvalue (next smallest is 19.78 — a seven-order gap), so the
  likelihood has one flat direction and a cold start lands wherever floating-point noise takes it.
  That, not the platform, is what made the Windows and macOS cold starts disagree by 1.95% on
  terminal MMB. In run 088's optimum the parameter is identified and consistent with its Block-1
  sibling (`M_pars_est[14]` = 1.80 ± 0.21), and the flat direction disappears entirely.

  **Open question for the CPT:** whether an exponential time-varying M block on immature females is
  identifiable at all here, or whether row 15 should be fixed (`phz = -4`) like rows 4, 8, 12 and 16
  already are. A parameter the data cannot inform, free to reach a bound, is what put the base fit
  in an inferior optimum.

- [ ] **5c. `05`'s promotion should retry the sd phase before declaring failure.** The
  `Error reading stack identifer for b` that rejected the 2026-08-24 promotion is
  **non-deterministic**: the identical fit (same binary, same pin, same inputs) re-ran cleanly,
  exiting 134 with only the three known macOS teardown messages and a complete `gmacs.std`. One
  transient ADMB stack error currently discards a valid promotion. Retry once or twice before
  rolling back. Do **not** instead add the message to `GMACS_FP_TEARDOWN_MSGS` — an unrecognised
  ADMB error must never be waved through.

- [ ] **5d. `06b_plot_historical_bias.R` — three open items.** The script itself works: verified
  end-to-end 2026-08-27, reads both `data/historical/*_by_assessment.csv`, writes a correct
  three-panel `plots/historical_mating_mmb_est.png` (10 vintages, 1982-2025). The
  "Removed 45/55 rows" warnings are structural — each vintage covers 1982 through its own
  assessment year, no interior gaps. What is left is not code:

  1. **A `2026` column is missing from both files**, so the figure shows vintages through 2025 and
     is not current for the September 2026 SAFE. The script already warns about this. Appending it
     needs the mapping from the accepted fit's `Gmacsall.out` summary block to the two quantities:
     `historical_mmb_at_survey_by_assessment.csv` is MMB **at survey** (subject to selectivity),
     `historical_mmb_mating_by_assessment.csv` is MMB **at mating** (not subject to it). They are
     ~1.8x apart on the median and 2.3-2.4x recently, so they are not interchangeable. Candidate
     columns are `SSB`, `SSA`, `Dynamic_B0`. **Grant's call — do not guess the mapping.**

  2. **The 2025 vintage records `0.00` for MMB-at-survey in 2020** — the COVID no-survey year, and
     the only exact zero anywhere in that file. Every other vintage covering 2020 has a real value
     (2024: 100.5, 2023: 76.12, 2022: 25.4, 2021: 40.95, 2020: 486.5), and the same assessment's
     mating series puts 2020 at 191.09. It plots as a real point, diving panel 1 to the axis and
     reading as "zero mature male biomass". Almost certainly a missing-data placeholder written as
     a number — rule 1, and it collides with the standing "2020 has no survey; never fill the gap
     silently" convention. If it is a placeholder it should be `NA`, which breaks the line the way
     the other structural gaps already do. **Source data behind a SAFE figure — Grant's call.**

  3. **Nothing consumes the output.** `SAFE_snow_gmacs.Rmd` has no reference to
     `historical_mating_mmb_est.png`. The old header claimed it was included "see the 2025
     reference Rmd, line 2631", but `Reports/` holds only published PDFs — no Rmd — so that
     citation pointed at nothing and was removed. Either add an include chunk (needs a section and
     a caption) or accept the figure as a standalone diagnostic.

- [x] ~~**5e. Male-only sensitivity: builds and parses, does not yet fit.**~~ **It fits, 2026-08-28.**
  `00_advance_model.R male_only=TRUE` (arg 8, added 2026-08-27) now produces `nsex = 1` files that
  GMACS runs to convergence. Built into `Models/26_gmacs_male_only/` from the 25 template,
  `END_YEAR = 2025`, survey to 2026 — same data vintage as the accepted 26 model.

  **Accepted male-only fit**, npar **234**, run 2026-08-28 (2 m 37 s, 2061 function evaluations):

  | nll | max\|grad\| | BMSY | OFL(tot) | Bcurr/BMSY | terminal MMB (2025) |
  |---|---|---|---|---|---|
  | -14010.3631618208 | 0.000661 | 131.10074452 | 73.99840011 | 1.20788789 | 113.52167470 |

  Meets the 1e-3 gradient criterion; Hessian well-conditioned (smallest eigenvalue **40.06**,
  condition **9.7e05**, no non-positive eigenvalues — the two-sex base is 34.6 / 1.4e06).
  `Female Spr_rbar` is exactly 0, confirming the female population is genuinely gone rather than
  merely unweighted. **The nll is NOT comparable to the two-sex model's -23546.35** — the female
  comps and indices are absent from the likelihood and one F penalty is gone. Compare reference
  points, not likelihoods.

  What the mode does, all verified against `gmacsbase.TPL` 2.20.34 or GMACS's own echo:
  - `.DAT`: `nsex` 2->1; `nSizeSex` `22 22`->`22`; catch frames 4->3 (drop discard-female);
    comp matrices 13->7 (keep 1,2,5,8,9,12,13); indices 4->2 (keep 3,4, **renumbered** 1,2 since
    GMACS keys q and selectivity off the index id); growth rows 294->161 (Sex column).
  - `.CTL`: theta 98->52 (44 female deviations + the female recruitment expected-value/scale pair);
    `3 3`->`3`; weight-at-length, proportion mature, proportion legal halved; growth/molt/mature
    type rows and growth alpha/beta/scale male-only; FEMALES molt matrix (45 rows) dropped;
    M 4->2 relative rows and 16->8 parameters; selectivity/retention sex flags zeroed with female
    rows and 3 female gear blocks dropped; catchability and additional-CV 4->2 rows; the eight
    13-wide comp vectors -> 7 with the splicer **renumbered** 1..7.

  **Males are always the first half** of any `n_grp`/`nsex`-dimensioned block: GMACS echoes
  `# 1 : male Mature / # 2 : male Immature / # 3 : female Mature / # 4 : female Immature`, loop
  order sex -> maturity -> shell (`:486-488`). Read, not assumed.

  **The five defects that stood between "parses" and "fits"** — recorded because four of them are
  the same mistake, and any future `nsex`-reducing work will hit it again. **A GMACS control file
  is one undelimited token stream: a block left at its two-sex length is not an error, it is an
  offset**, and the symptom always surfaces somewhere unrelated.
  1. **Catchability *parameters* left at 4 rows.** `keep_index_rows()` reduced only the first
     numeric run under each anchor — the *specifications* — but both q and additional CV have a
     second `nSurveys`-dimensioned run, the *parameters* (`:3688`/`:3774`, `:3834`/`:3936`). It
     also kept the wrong two: rows 1-2 are the FEMALE q priors.
  2. **Additional-CV *parameters* left at 4 rows**, same cause. Together these made GMACS read the
     two leftover male q parameter rows AS the additional-CV specifications, see `mirror = 1` on
     both, compute `n_addcv_par = 0`, and die on a zero-row matrix with
     `matrix bound exceeded -- row index too high` — the failure 5e was originally filed under.
     Nothing about the message points at catchability.
  3. **Effective-sample-size parameters left at 13 rows.** `log_vn_pars(1,nSizeComps,1,7)`
     (`:4084`) is one row per size-comp matrix, so 13 -> 7. GMACS read the first 7 and the
     remaining **42 numbers** were swallowed by every later read. Symptom: `eof_ctl` came back
     `999` instead of `9999`, i.e. "Error reading control file" — 40 lines from the real cause.
     Token arithmetic through the leftovers lands exactly on that `999`, which is how it was
     confirmed rather than guessed.
  4. **Catch emphasis left at 4 values.** `catch_emphasis(1,nCatchDF)` (`:4439`) must lose the
     discard-female weight exactly as the `.DAT`'s catch frames did.
  5. **The index id was renumbered in one column of two.** Every `.DAT` survey row carries the id
     *twice* — column 1 (which q to use) and column 11, `dSurveyData(jj,10)`, the
     relative-abundance-index id. Only column 1 was remapped 3,4 -> 1,2. This one clears the whole
     file-reading stage and dies in *phase 1* at `calc_relative_abundance` (`:9219`), where
     `SurveyType(rai_id)` is an ivector of range [1,2]:
     `Invalid index 3 used for array range [1, 2]`. Found from an `lldb` backtrace on the `-g`
     build (break on `exit`; `ad_exit` is a data symbol and will not take a breakpoint), not by
     reading. The build now asserts column 11 == column 1 before remapping.

  Plus one that was a modelling choice rather than a bug: **the female F offset was still being
  estimated.** `log_foff(1,nfleet)` is switched on by `f_controls` column 6 (`:4030`, `:4993`), and
  the Pot fishery had it at phase 1. With `nsex = 1` nothing informs it — it sat at its initial
  value with a standard error of **2.9e+04** and drove the Hessian condition number to **1.5e14**
  (smallest eigenvalue 2.7e-07). The mode now phases it off for every fleet, which is what takes
  the fit from max\|grad\| 0.0042 / condition 1.5e14 to 0.00066 / 9.7e05.

  **The two-sex path is unchanged**: rebuilt from the same template, the `.DAT` and `.CTL` are
  **byte-identical** (`cmp`) to `Models/26_gmacs_update_newmat_plus_group/`. Every fix sits inside
  an `if (MALE_ONLY)` branch.

  **Adversarial review, 2026-08-28** — what it checked and what it found:
  - Verified against GMACS's own echo, not against the build script: `eof_ctl` reads **9999**
    (clean token stream, no residual offset); `foff_phz` is `-1 -1 -1 -1` while `f_phz` stays
    `1 1 -1 -1` (male F phases untouched); `nSizeComps` = 7; GMACS labels all seven surviving comp
    matrices **M**; the only four occurrences of "female" in `gmacs_out.ctl` are static label text.
  - **Data integrity of the kept frames.** All 201 male size-comp rows and all 128 catch rows are
    **byte-identical** to the two-sex 26 model. The 44 index rows differ in **exactly two fields** —
    columns 1 and 11, both 3,4 -> 1,2 — with every observation and CV character-identical. The 161
    male growth rows are identical to the two-sex model's, differing from the raw template in the
    one documented `73` -> `7.3` typo row.
  - **A caveat for the write-up, not a bug: the trawl bycatch observation is sex-combined.**
    The kept frame is `sex = 0` (44 rows, mean 0.481 kt) and GMACS predicts a sex-0 catch by
    summing over `nsex` (`:8601`) — which is now males alone, while the observation still counts
    both sexes. Measured, rather than assumed: the fit is **unaffected** (predicted 0.4811 vs the
    two-sex 0.4812, same mean residual -0.0015, same 27% positive), because the estimated trawl F
    absorbs it. The consequence is interpretive — male trawl-bycatch F is inflated to cover what
    was female removal — and it is small: bycatch is 1.3% of the 37.1 kt mean retained catch.
    **Worth a sentence in the sensitivity write-up; ask CPT whether the male-only variant should
    instead carry a male-only bycatch series.**
  - **Exit 134 is normal here.** SIGABRT with `Detected division by zero / invalid argument /
    underflow` on shutdown — the **accepted two-sex fit produces the identical stderr** on this
    machine. `gmacs.std` is complete and scales the same way in both (975 rows / 412 par vs
    575 / 234).
  - Two defects were found **in the review's own new code** and fixed: a malformed `sprintf` in the
    column-1-vs-11 assertion (a format string split as if it were `paste0`, so the continuation
    became the first `%d` argument — it would have raised "invalid format" instead of the
    diagnostic), and two unbounded block searches. The searches now take an `end_anchor`, because
    in both cases the block that would be grabbed by mistake has the **same field count** as the
    intended one — a missing q-parameters block would have silently halved the additional-CV
    specifications, and a missing catch-emphasis row would have silently rewritten the first
    by-fleet fdev penalty. Neither is reachable with the current template; both are the
    "silent wrong answer" class the assertion rule exists for. All defensive; the `.DAT`/`.CTL`
    are byte-identical before and after, and the refit reproduces to the last digit.

  **Jitter and retrospective, 2026-08-28.** Both run; only the SAFE write-up is left.
  - **Jitter** (100 runs, sd 0.1, seeds 20260822-20260921): 83 usable, 9 meet 1e-3, **25.3%
    reached the best mode** against the two-sex model's 5.1%. A winner was promoted — see the
    tie-break defect below. Accepted fit is now `jitter/095`, seed 20260916:
    nll **-14010.6635839271**, max|grad| **0.000705**, BMSY **131.34304372**,
    OFL(tot) **76.99559354**, Bcurr/BMSY **1.22784236**, terminal MMB **115.90186501**,
    smallest Hessian eigenvalue **42.5**, condition **9.2e05**.
  - **Retrospective** (22 peels, all seeded): peel 0 reproduces the parent to a max relative MMB
    difference of **exactly 0** over 44 years. Mohn's rho MMB **-0.0915** standard /
    **-0.0835** drop-survey — inside the Hurtado-Ferro bounds and tighter than the two-sex
    -0.109/-0.110. Recruitment rho 0.72/0.68 vs the two-sex 7.9-9.5.
  - **The first promotion was decided by floating-point noise** — `05_run_jitter.R:387` ordered
    candidates by `order(objFun, maxGrad)`, intending the gradient to break nll ties, but `objFun`
    is a continuous double so exact ties never occur and the tiebreaker never fired. Five runs
    agreed to **2e-09** in nll and **1.6e-05 kt** in OFL; the winner was picked on a 1.6e-09 nll
    difference and happened to be the worst-conditioned of the five (max|grad| 0.00166, *failing*
    the 1e-3 criterion the SAFE reports), over a numerically identical run at 0.000712. Fixed by
    bucketing nll by the script's own `NLL_TOL` (0.001, already defined as "the same optimum")
    before ordering on gradient. Re-promoted from run 095; the two-sex model's outcome is
    unchanged by the fix (still run 088, 79/100 usable, 5.1%).
  - See **4c** for the drop-survey peels being rebuilt as two-sex models, and **4b** for the
    artifact-clobbering that both `05` and `06` cause on any non-default model.

  Not yet done: inclusion as a SAFE sensitivity (`0-models.R`, `03_build_results_object.R`, the
  scenario table and the section text).

- [ ] **5f. Why fixing female phases does NOT give a male-only model.** Recorded because it is the
  obvious approach and it is wrong. Two couplings survive it (`gmacsbase.TPL` 2.20.34):
  - `:8600-8602` a **combined-sex (sex = 0) catch observation is predicted by summing over both
    sexes**, and the `.DAT` has 44 such bycatch rows. The female population therefore drives that
    residual, hence F, hence male mortality — whatever is done to female parameters or
    female-specific data.
  - `logRbar` and `rec_dev` are **not sex-indexed**, so female likelihood contributes gradient to
    the shared recruitment scale and deviations.
  Only `nsex = 1` removes the female population; GMACS then disables the sex-ratio parameter
  itself (`:1653`) and drops the recruitment split (`:8424`).

- [ ] **6. Post-condition assertions in `01` and `02`.** These are the files whose silent errors
  propagate all the way into the OFL, and they have no validation. Add:
  - comp rows sum to 1 within tolerance
  - exactly 22 `m*` bin columns
  - `data/maturity/snow_ogives.csv` covers the survey terminal year — `02:28-29` *warns in a
    comment* that a mismatch silently misaligns Section 6, and nothing enforces it
  - the row-alignment assumption `01:94` flags in a comment (`filter(fems, fish=='QO')` assumed
    row-aligned by crab_year, with no join and no check)

- [x] ~~**7. Collapse `07_calc_tier4.R`'s three REMA/HCR blocks into one function.**~~ Done
  2026-08-27. One `tier4_hcr()` + one vectorised `tier4_fofl()`; constants (`NAT_M`, `BETA`,
  `ALPHA`, `BMSY_WINDOW_END`) declared once. Every listed drift item removed, plus five dead
  imports and the `dplyr` dependency (`07` is a base-R file per CLAUDE.md). **Proven identical**
  against a pre-refactor run: `rema_predictions.csv` and `observed_exploitation.csv` both
  max |diff| = 0.000e+00 on every numeric column, labels identical, same row counts.
  Two further fixes: the OFL is now written to `data/tier4/tier4_by_currency.csv`
  (`currency/Bmsy/B_curr/status/M/Fofl/OFL`, the interface the Rmd's `tier4-setup` chunk expects) —
  it previously existed ONLY as text inside a PNG annotation, with `keep_status`/`keep_fofl`/
  `keep_bmsy` accumulated then discarded; and the two repo-root CSVs plus the `Rplots.pdf` from two
  base `plot()` calls are gone (status is now `plots/tier4_status.png`).
  Original text:
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

- [x] ~~**7b. Tier 4 decrements the comparison currencies but not the recommended one.**~~
  Resolved 2026-08-27, per Grant: **no currency is decremented by M**. The >101 mm and >95 mm
  series had `* exp(-NAT_M/2)` applied before the OFL was formed while the morphometric series --
  the recommended basis -- did not, so the three were not comparable. Measured effect, all three
  predicted in advance and confirmed:
  - `tier4_by_currency.csv` **unchanged** (max |diff| 0.000e+00 on every column, OFL still
    22.867 kt): status is `B/mean(B)` so the constant factor cancels, and Section 6's REMA always
    used the undecremented series anyway.
  - `rema_predictions.csv` **unchanged** (0.000e+00).
  - `observed_exploitation.csv` biomass x **1.144537** for >101 mm and >95 mm (= exp(+0.135)),
    x1.000000 for morphometric; exploitation rate falls correspondingly for the two comparison
    currencies. `plots/tier_4.png` moves with it.

- [ ] **7c. `07_calc_tier4.R` can half-complete on a network hiccup.** It pulls crabpack live with
  no fallback, and writes its three CSVs at separate points. A run on 2026-08-27 died mid-pull on
  `Timeout was reached [apex.psmfc.org]` — harmlessly, because it failed before any write, but a
  timeout between the first and second `write.csv` would leave `data/tier4/` holding a mix of two
  runs with nothing recording it. Same class as the jitter rollback (item 1c): an operation that
  can half-complete silently. Fix: build all outputs first, write them last, or stage to a temp
  dir and move on success.

- [~] **7d. Ramp vs flat M — implemented flat, but the justification is NOT in the June SSC
  minutes.** Per Grant (2026-08-28) the reported basis is **flat F_OFL = M**, with the ramp
  retained as a sensitivity. Implemented: `HCR_RAMP <- FALSE` selects the basis, `tier4_fofl_flat()`
  and `tier4_fofl_ramp()` both exist, both are computed every run, and `tier4_by_currency.csv`
  gained `Fofl_ramp`/`OFL_ramp` (the Rmd's `currency/Bmsy/B_curr/status/M/Fofl/OFL` interface is
  unchanged and now holds the reported basis).

  **Basis, per Grant 2026-08-28: it follows the GROUNDFISH TIER 5 FMP**, where the OFL is F = M
  applied to the biomass with no status-based ramp. That is the citation to carry in Section F.
  Recorded because it was checked and is *not* in the June SSC report: cross-referenced against
  `Reports/2026-06_SSC_report.pdf`, **the word "ramp" does not appear anywhere in the 30-page
  document**, and the only HCR-adjacent sentence is a standing request — *"The SSC continues to
  request a yield-per-recruit analysis that could be used to inform development of an alternative
  harvest control rule."* So do not cite the June SSC minutes for this; cite the FMP.

  "No ramp" was implemented as *the linear ramp between beta and 1 is removed, the beta closure is
  retained*. That reading changes nothing in 2026 — all three currencies sit above beta — but
  **>101 mm clears beta by only 0.005** (0.2554 vs 0.25), so the two readings could diverge in a
  future year. Note also that dropping the ramp raises F_OFL for the comparison currencies from
  ~0.047-0.054 to the full 0.27.

- [x] ~~**7e. Two OFL formulas in one script.**~~ Resolved 2026-08-28, per Grant. **Reported:
  `OFL = F_OFL * B`** (linear), for consistency with how other BSAI crab Tier 4 assessments compute
  it — comparability across stocks won, not approximation quality. **Baranov
  `(F/Z)*B*(1-exp(-Z))`, `Z = F + M`, is reported alongside as `OFL_baranov` and is the author
  recommendation for future cycles**, because F_OFL is an instantaneous rate (the same scale as M,
  which is why Tier 4 can set F_OFL = M) and natural mortality acts over the same year; `F*B` is
  only its first-order approximation and always overstates the catch.

  One `tier4_ofl()` now serves Sections 4 and 6, selected by `OFL_EQN` ("linear"). All four
  combinations of {flat, ramp} x {linear, Baranov} are computed so each reported column isolates a
  single choice — morphometric 2026: reported **30.765**, ramp **22.867**, Baranov **23.772**, both
  **18.239 kt**. Unit-tested at all four corners and at the closure boundary.

  **The gap between linear and Baranov is at its widest precisely here**, because F_OFL = M means
  fishing is exactly half of total mortality — worth saying in the write-up, since it makes the
  choice look more consequential than it would be at a lower F.

  **Two things the write-up must carry** (`Reports/2026-08_checklist_crab_SAFE_review.pdf`
  requires both): *"Specification of total catch OFL, including **Equations on which OFL is to be
  based**"*, and *"**Basis for projecting MMB to the time of mating** (documented in peer-review
  publication or technical appendix)"* — B here is MMB at mating, so the timing convention behind
  applying a full-year removal fraction to it needs stating. The same checklist also demands a
  *"rationale for time period used to define proxy BMSY (Tier 4)"*, which is `BMSY_WINDOW_END`
  (2025) — currently a code comment, not a documented rationale.

- [ ] **8. `SAFE_snow_gmacs.Rmd:979` writes a CSV into the repo root at knit time.**
  `write.csv(tot_likes_t, file = paste0("tot_likes_t_", Sys.Date(), ".csv"))` — every render adds a
  new untracked, un-gitignored file. Write it to `data/derived/` or drop it.

- [ ] **9. The Rmd fails soft, not loud.** It defends against missing model results by substituting
  `NULL`/`NA`/`0` (e.g. `:966`, `tot_likes[is.na(tot_likes)] <- 0`). A stale or absent model
  directory therefore produces a plausible-looking table of zeros rather than an error. Convert the
  guards to `stop()` for the final render, or add an explicit "what loaded" summary the author must
  eyeball.

---

## Tier 1 — reproducibility (added 2026-08-29)

- [ ] **1f. `26_gmacs_update_newmat_plus_group/jitter/base_prepromotion/` holds TWO different
  fits.** Its `gmacs.par`, `gmacs.std` and `Gmacsall.out` are the genuine cold start — a fresh
  cold-start run on 2026-08-29 reproduced them exactly (nll **-23542.7677063715**, max|grad|
  **0.00739405322922705**). Its `admodel.hes`, `admodel.cov` and `gmacs.eva` are **not**: they
  invert to min eigenvalue **34.6442**, condition **1.42e06** and an SE of **0.077** for
  `M_pars_est[15]`, which are the *promoted* fit's values, while the `.std` sitting beside them
  reports **5351.76** for the same parameter. The true cold-start Hessian is min eigenvalue
  **1.08126e-06**, next-smallest **19.7795**, condition **4.6e13**.
  **Mechanism:** `05_run_jitter.R:466` runs the promotion with `run_gmacs(MODEL_DIR, ...)`, i.e.
  inside the model directory, so the promote run's Hessian output landed in the directory the
  backup was taken from. `gmacs_promote_run.log` is present inside `base_prepromotion/`, which is
  the tell. Same family as **1c**.
  **Consequence:** the eigenvalues quoted in the SAFE's convergence section are CORRECT (verified
  against the fresh run) but cannot be checked against this directory, and anyone who tries will
  conclude the opposite. Either re-run the cold start and store its Hessian here, or rename the
  directory to make clear it holds parameters only.
  **To reproduce:** copy the model dir without `gmacs.pin`, run `./gmacs -nox -verbose 0`, and read
  `admodel.hes`; the pin is what makes the difference between a cold start and the accepted fit.

## Tier 2 — hygiene, as you pass through

- [ ] **9b. A flextable caption is emitted twice for any table that breaks across a page, so its
  label is multiply defined.** The mechanism, from the generated LaTeX: flextable writes
  `\caption{...}\label{tab:x}\\` in the first head and again in `\endhead`, which longtable
  typesets on every continuation page. So the reader sees the table number twice with no
  "(continued)", and LaTeX reports `Label 'tab:x' multiply defined`. Only tables that actually
  break are affected — `\endhead` never fires for a table that fits.
  **There is no `caption_repeat` option in the installed flextable (0.10.0)**; `opts_pdf` supports
  only `tabcolsep`, `arraystretch` and `float`, and `float = "float"` still emits a longtable
  inside the `table` environment, so it does not help. Do not "fix" it by removing the
  `autonum`/`bkm` — that is what makes `\@ref()` resolve at all.
  Found on the 2026-08-29 render, which reported four: `tab:jitter-attribution`,
  `tab:survey-currencies`, `tab:risk-table`, `tab:obscatch`. Three were addressed the same day by
  making the tables fit: the attribution table is capped at its top 10 rows of 15, and
  `survey-currencies` (three rows, breaking only on placement) is guarded with
  `\Needspace{9\baselineskip}` — `needspace` was added to the YAML `header-includes` for this.
  **Still open: `tab:risk-table` and `tab:obscatch`.** The risk table is four rows of dense text
  and `obscatch` is 44 crab years, so neither can be made to fit; both may shrink on their own
  once the `[[author]]` placeholders in the risk table are replaced with scored levels. If it has
  to be solved properly, the lever is a Lua filter or a post-processing pass over the `.tex` that
  strips the `\label` from the `\endhead` block.

- [ ] **10. Convert comment banners to `## ---`** in files you're already editing:
  `03_build_results_object.R`, `07_calc_tier4.R`, `0-models.R` still use Cody's `#--` / `#==`.
  Standard is in `R/gmacs_io.R` and `00_advance_model.R`. See `CLAUDE.md` → R style.
  (`05`/`06` were rewritten 2026-08-21 and already conform.)

- [ ] **11. Re-audit `06_run_retrospective.R` once the current rewrite lands.** It went 465 → 624
  lines on 2026-08-21 and now correctly sources `R/gmacs_io.R` and uses `on.exit(setwd(old))`. The
  old dead-code findings (undefined `retro_outs`/`mohnrho`, the `./retro/2018_s/` block, the
  duplicated `df_normalized`) were against the previous version and have **not** been re-checked
  against the rewrite. Do that before trusting a clean bill of health.

- [ ] **11b. `R/gmacs_io.R:7` is a stale line reference in three places.** `gmacs_max_workers()`
  is at `R/gmacs_io.R:379`, not `:7` — line 7 is inside the file header banner. Cited wrongly by
  `CLAUDE.md` rule 11, `05_run_jitter.R:19` and `05_run_jitter.R:63`. Found 2026-08-24 while
  adding the macOS platform section.

- [ ] **11c. Rule 11's worker budget is justified by Windows-laptop thermals only.** The
  `gmacs_max_workers()` default of 4 exists because a wide fan-out hard-resets the Precision 5690
  (`R/gmacs_io.R:366-378`). That rationale does not transfer to the Apple Silicon machine, where
  the constraint is different hardware entirely. The budget is currently applied to both. Decide
  whether macOS should have its own ceiling before anyone runs a 100-run jitter there — do not
  just raise it. Raised 2026-08-24; see `docs/MACOS_GMACS.md`.

- [ ] **12. Stale cross-references.** `SAFE_snow_gmacs.Rmd:67` cites `05_buck_read_results.R`
  (now `03_build_results_object.R`). `0-models.R:11-12` carries `TODO(Phase 3)`: audit every
  positional `model_defs[N]` use in the Rmd before pruning the list to the September set.
  `SAFE_snow_gmacs.Rmd:98` — `>>> REVIEW: confirm comparison pairs once the 2026 results object exists`.

- [ ] **13. Package loading.** `03_build_results_object.R:4` uses `require(wtsGMACS)` — warns
  instead of failing — and never loads `wtsUtilities` despite calling it at `:26`.
  (The `reshape` vs `reshape2` conflict in `04_plot_numbers_at_length.R:3-12` went away with that
  script on 2026-08-27; `reshape` is now unused repo-wide.) `07_calc_tier4.R:2-13` loads `dplyr`,
  `ggplot2`, and `reshape2`
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

- ~~**`plots/size_bins_comp_Kodiak_m.png` is written by two scripts.**~~ Closed 2026-08-27 with
  Tier 0 item 4: `04` was retired and `02_prep_survey_data.R` is now the sole writer.

- **All 44 male/immature CVs in `data/derived/survey_indices.csv` are `NA`.** Inert today —
  `00_advance_model.R:326` filters to `maturity == "mature"`, so those rows never reach the model.
  It becomes live the moment anyone acts on the SSC's immature-index suggestion.

- **`Models/25_gmacs` has no `gmacs.exe`.** It has results but cannot be re-run or peeled. It was
  also fit with GMACS **2.20.22**, not the 2.20.34 every other model dir used, so a current binary
  would not reproduce it even if one were dropped in. It got no macOS binary for that reason
  (2026-08-24).

- **A macOS cold start is a different fit from the Windows one, on the same inputs.** Terminal MMB
  147.08 vs 144.27 (+1.95%), OFL(tot) 86.69 vs 86.95. Not a porting defect: seeded with the Windows
  `gmacs.par`, the macOS binary reproduces all 975 sdreport quantities to the precision `gmacs.std`
  records. It is the model's flat likelihood — both platforms stop at stationary points above the
  1e-3 gradient target. Full measurements in `docs/MACOS_GMACS.md`. **Any SAFE number must state
  which platform and which starting point produced it**, and a macOS re-run of an existing SAFE
  figure must be pinned, not cold-started.

---

## Watch list

- **Thermal headroom on the Precision 5690.** `gmacs_max_workers()` now defaults to 4 (was 12 in
  `06`, 8 in `05`), which stopped the hard resets. If a reset ever recurs at 4, drop to 2 rather
  than assuming it was a one-off — the failure corrupts whatever run directory was mid-write, and
  a half-written peel still parses. Consider also running `gmacs.exe` at below-normal process
  priority; not done yet because it means changing the `system2()` invocation, which is on the
  path that produces the numbers (rule 3).

  **Two resets recurred on 2026-08-21**, both during `05`'s 100-run jitter sweep.

  - *First:* `06` at 4 workers **plus two models Grant was running by hand** — ~6 `gmacs.exe`
    pinned at once. Confounded, so not evidence about 4 on its own. 18 of 44 run directories were
    left half-written.
  - *Second:* `06` at 4 workers with **nothing else running**. Clean conditions, still reset.
    10 of 44 directories damaged.

  So **4 is not safe on this machine** and `gmacs_max_workers()`'s default of 4 should drop to 2.
  Not changed here because it is shared with `06_run_retrospective.R`, whose peel timings were set
  against 4 — raise it with Grant rather than editing unilaterally. The jitter sweep completed at
  `--cores 2`.

  The separate point still stands: the cap is **per-session and the hardware is not**. Two agent
  sessions plus a manual run each pass their own check independently. A global guard (a lockfile,
  or counting live `gmacs.exe` before launching) is the real fix.

  Untried mitigation, in order of cheapness: below-normal process priority for `gmacs.exe`; a
  fixed inter-launch delay so workers don't all hit the optimiser's hottest phase together.

- **Crash-truncated output files parse.** The reset above produced `Gmacsall.out` files that stop
  mid-block and read fine for hundreds of lines. `05_run_jitter.R`'s resume guard now requires the
  file to end with GMACS's `>EOD<` terminator (`.ends_cleanly()`), and `prepare_run_dir()` wipes a
  directory's previous outputs before re-running it, so a stale file cannot be mistaken for the
  new run's result. **`06_run_retrospective.R` should carry the same terminator check** if it does
  not already — existence of `Gmacsall.out` is not evidence a peel finished.

## From the 2026-08-21 adversarial review — not yet triaged

Found by review of `832d034~1..HEAD`. Two were confirmed against run artifacts on disk, not just
read from the diff. Ranked; none fixed (they sit in in-flight work).

- [ ] **A. `06_run_retrospective.R:168` — `verify_run` never checks reference points are non-zero.**
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
- [x] ~~`05`'s single `MAX_GRAD_TOL = 1e-3` gate marked every run non-converged (pilot runs sit at
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
  `06b_plot_historical_bias.R`.

### 10. `05_run_jitter.R` writes six artifacts to fixed paths regardless of `--model`

`05:627-647` and `05:707` write `Models/rda_jitter.RData` and the five `plots/jitter*.png`
to hardcoded names, so a jitter of ANY model silently overwrites the last one's results. The
SAFE reads `Models/rda_jitter.RData` unconditionally, so a jitter run on a side model leaves
the report quoting that model's convergence statistics under the accepted model's name --- with
nothing to mark them as belonging to a different fit. The hand-kept `rda_jitter_25.2c`,
`_data2019` and `_male_only` copies exist because of this; there are no per-model copies of the
five PNGs at all. Reported 2026-08-29 by a parallel session that hit it while jittering
`Models/26_gmacs_eqmdevs`. Fix is to suffix all six by model shortname, as `06` already does for
its retrospective plots.

### 11. `pct_at_best_mode` is not the recovery rate of the reported fit

`classify_modes()` (`R/gmacs_jitter.R`) letters a cluster only once at least three runs share it,
so a solution found by one or two runs is bucketed `minor`. For the recommended model the accepted
fit IS such a solution: it is the best nll any run reached, while lettered mode A is 0.81 units
worse and holds the 5.1 percent the field reports. The name invites the field to be quoted as
"percent of runs that recovered the reported fit", which overstates it by about fourfold (the true
figure is 1 of 79 converged runs). The SAFE now computes the recovery rate directly and asserts
that no lettered mode beats the reported fit; the field itself should be renamed
`pct_at_largest_mode` so the trap does not reappear elsewhere.

### Reference MMBs in the known-traps table are precision-limited, not wrong (2026-08-30)

**Resolved --- do not chase further.** `CLAUDE.md:209` and `docs/MACOS_GMACS.md:85,97,127` record
terminal MMB for the superseded Windows fit as 144.27194, where the jitter's mode A (the same
optimum: nll agrees to 13 significant figures) gives 144.27733. The 3.7e-05 relative gap looked
alarming because the four mode A runs reproduce MMB among themselves to 1.9e-07, i.e. the gap was
~200x the within-mode spread, and because BMSY and OFL agreed to 7 figures.

The cause is a log-and-exponentiate round trip through `gmacs.std`, which prints only **5
significant figures**:

| | true (Gmacsall.out SSB) | log | gmacs.std prints | exp() | docs record |
|---|---|---|---|---|---|
| 26 model | 141.53436861 | 4.95254258 | 4.9525 | 141.52834287 | 141.52834 |
| mode A | 144.27733 | 4.97173735 | 4.9717 | 144.27194132 | 144.27194 |

Both land within ~1e-06 of the recorded figures, which is the docs' own print precision. That also
explains why only MMB disagreed: nll, BMSY and OFL are recorded directly at full precision, while
MMB alone went through the round trip.

**The fix, when someone is next in these docs:** source reference MMB from the `Gmacsall.out` SSB
series (`R/gmacs_jitter.R:562` does this) rather than `exp(sd_log_ssb)`. **This does not weaken the
stale-directory test** those numbers exist for --- that test keys on the ~178 vs ~150 BMSY gap, 19%,
and a 4e-05 error is nowhere near it.

Related trap found alongside: `sd_last_ssb` in `gmacs.std` is the **projected** MMB, not the
terminal one (26 model: 1.9141e+02 against a terminal 141.53). Pairing a terminal MMB with a status
computed off the projected value produced a false "biomass is above B_MSY" sentence in the
Executive Summary. Both numbers are individually correct, which is why it survived review.

Diagnosed jointly with the parallel multimodality-diagnosis session.

### 05_run_jitter.R writes six shared paths regardless of --model (2026-08-30)

`05_run_jitter.R:627-647` and `:707` write `Models/rda_jitter.RData` and five fixed plot names
(`plots/jittered_results_{ofl,rec,ssb}.png`, `jitter_convergence.png`,
`jitter_param_attribution.png`) **whatever model was jittered**. Every run overwrites the previous
one. The SAFE reads that shared path for the ACCEPTED model throughout --- Section E, Table 8, the
risk table, and the first row of Appendix C.

**This fired on 2026-08-30.** A jitter of `26_gmacs_combined` left that model's results at the
shared path. A render in that window would have relabelled the combined model's diagnostics as the
author-recommended model's, in the section the June 2026 SSC specifically asked for, with nothing on
the page looking wrong. It was caught by a verification pass, not by anything in the pipeline, and
the only reason it was recoverable is that the run directories under
`Models/26_gmacs_update_newmat_plus_group/jitter/` survived.

Two mitigations are already in:
- `SAFE_snow_gmacs.Rmd` asserts `jitter$summary$model` is `26_gmacs_update_newmat_plus_group`, so a
  clobbered file now fails the knit loudly instead of printing another model's numbers.
- Durable per-model copies exist for all seven configurations, `Models/rda_jitter_26.RData` included.

**The defect itself is unfixed.** `05` should write `Models/rda_jitter_<model>.RData` and per-model
plot names, with the Rmd selecting by name, so correctness stops depending on a human remembering to
restore. Note the general lesson from the same day: the earlier md5 baseline lived in a
`/private/tmp` scratch directory that is wiped on process exit, so the check silently degraded into
comparing against nothing --- a guard that cannot fire on the case it protects is worse than no
guard. Verify against literals held in the repo or in the command itself.

## Deliberately not changed

These look like bugs and aren't — they match the authoritative `snow_crab` repo, i.e. they are
long-standing and intentional. Ask Cody before touching any of them.

- `01_prep_fishery_data.R` — male total comp uses `right = TRUE` while retained and female use
  `right = FALSE`
- `01:33,53` — `bssc_discards.csv` read into `disc`, never used (ADFG no longer delivers it)
- `01:38,340` — `bycatch_dat_big[,-24]` drops a column by position (fragile, but matches upstream)
