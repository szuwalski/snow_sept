# Session handoff — September 2026 snow crab SAFE

Pick-up doc for the September 2026 EBS snow crab SAFE in `snow_sept`. See `../README.md` for the full
repo layout and run commands; this file tracks *state and next steps*.

> **Report build plan (added 2026-07-30):** planning + drafts for the SAFE *report* live in this folder —
> start with `SEPT2026_CLAUDE_CODE_HANDOFF.md` (build steps + canonical section outline), then
> `PHASE1_SECTION_SKETCHES.md` (draft Rmd per section) and `SEPT2026_SNOW_CRAB_BUILD_PLAN.md` (scope,
> direction, guideline reconciliation).

## TL;DR — where we are
**The assessment now runs on macOS** (GMACS 2.20.34 built from source; see `docs/MACOS_GMACS.md`), and
the 26 model's accepted fit was **replaced on 2026-08-27** by a jitter winner: **nll -23546.3457934123,
OFL(tot) 85.649 kt, terminal MMB 141.528**. Jitter, retrospective and Tier 4 have all been re-run
against it. Two OFL questions are open and must be settled before September (backlog 7d/7e). The
**male-only sensitivity now fits** (2026-08-28) — `Models/26_gmacs_male_only/`, converged and
well-conditioned; jitter and retrospective on it are the next step.

## Done & verified
- **macOS GMACS build.** `GMACs/GMACS_tpl-cpp_code/compile_gmacs_mac.sh` → `gmacs` (arm64, 2.20.34),
  installed beside the untouched `gmacs.exe` in the four 2.20.34 model dirs. Verified numerically:
  seeded with the Windows `gmacs.par` it reproduces **all 975 sdreport quantities** to the precision
  `gmacs.std` records. Machine setup + the two build fixes are in `docs/MACOS_GMACS.md`.
- **26 model re-fit and then promoted (2026-08-27).** 100-run jitter: 79/100 usable, **5.1% found the
  best mode**. Winner promoted (`jitter/088`, seed 20260909); provenance in `jitter/PROMOTION.md`.
  Accepted fit: nll **-23546.3457934123**, max|grad| **0.000931** (meets 1e-3, which neither prior fit
  did), BMSY **144.97170891**, OFL(tot) **85.64948279**, terminal MMB **141.52834**, Hessian condition
  **1.4e06**. `gmacs.pin` in that dir is legitimate and documented — do not delete it.
- **Retrospective re-run against the promoted fit.** 22/22 peels ok. Peel 0 reproduces the parent to
  **2.6e-09** max relative MMB difference over 44 years — it did *not* before peels were seeded.
  Mohn's rho MMB **-0.109** (standard) / **-0.110** (drop-survey), inside the Hurtado-Ferro bounds.
  Recruitment rho 7.9–9.5 is the usual terminal-recruitment artefact.
- **Peels are seeded from the accepted fit.** `write_peel_pin()` (`R/gmacs_io.R` §10) shapes each pin
  from a `.par` GMACS itself wrote for that peel — lengths are never inferred, because two blocks do
  not shrink by peel depth (the fishery was closed in 2022/23). Cold-started, peel 0 landed on the
  *rejected* optimum.
- **Tier 4 reorganised.** Three ~45-line REMA blocks → one `tier4_hcr()`. Proven identical to the
  pre-refactor run (**max |diff| 0.000e+00** on every numeric column of both CSVs). The OFL now
  **exists as data** — `data/tier4/tier4_by_currency.csv` — where before it was only text inside a PNG.
  Current: morphometric **OFL 22.867 kt**, status 0.769.
- **Male-only sensitivity fits, jittered and retrospected (2026-08-28).**
  `Models/26_gmacs_male_only/`, built by `00_advance_model.R ... TRUE` (arg 8) from the 25
  template, `END_YEAR = 2025`, survey to 2026. **Accepted fit promoted from `jitter/095`**
  (seed 20260916; provenance in `jitter/PROMOTION.md`): npar **234**,
  nll **-14010.6635839271**, max|grad| **0.000705** (meets 1e-3), BMSY **131.34304372**,
  OFL(tot) **76.99559354**, Bcurr/BMSY **1.22784236**, terminal MMB **115.90186501**;
  Hessian smallest eigenvalue **42.5**, condition **9.2e05**, no non-positive eigenvalues.
  `Female Spr_rbar` is exactly 0.
  **Jitter:** 100 runs, 83 usable, 9 meet 1e-3, **25.3% reached the best mode** (the two-sex model
  manages 5.1% — the male-only likelihood is markedly better behaved).
  **Retrospective:** 22/22 peels, all seeded. Peel 0 reproduces the parent to a max relative MMB
  difference of **exactly 0** over 44 years. Mohn's rho MMB **-0.0915** (standard) / **-0.0835**
  (drop-survey), inside the Hurtado-Ferro bounds and tighter than the two-sex -0.109/-0.110.
  Recruitment rho 0.72/0.68, far tamer than the two-sex 7.9-9.5.
  Five file-reduction defects fixed plus the female F offset phased off — all detailed in backlog
  **5e**, which is now closed. **The nll is not comparable to the two-sex -23546.35** (different
  likelihood); compare reference points. The two-sex `.DAT`/`.CTL` are **byte-identical** after the
  change, verified with `cmp`. **Adversarially reviewed 2026-08-28** (findings in 5e): kept data
  proven byte-identical to the two-sex model frame by frame, two defects found and fixed in the
  fix itself, and one caveat for the write-up — **the trawl bycatch observation is sex-combined
  but is now predicted by males alone**; measured to be absorbed by the estimated trawl F (fit
  unchanged), so it is interpretive, not a fit problem.
- **Scripts renumbered (2026-08-27): jitter is `05`, retrospective is `06`, bias plot is `06b`.** The
  jitter can promote a better fit and invalidate a retrospective run before it. 56 references updated;
  both drivers smoke-tested; `.gitignore` and README order fixed.
- **`04_plot_numbers_at_length.R` retired.** Could not run (4 independent blockers) and duplicated
  `02`. Female ridgeline moved to `02` §6c; recruitment comparison rebuilt as
  `04_plot_recruitment_comparison.R`, reading the fit's own `Gmacsall.out`.
  **Neither new figure has been produced yet** — both need `02` to run (crabpack).
- **Written and parsed, NOT yet run:** `02`'s new §3b/§6c, `04_plot_recruitment_comparison.R`
  (its transformation logic was exercised against the real fit with a synthetic survey vector),
  and the male-only mode of `00`. `03` and `08` have never run on macOS.

## Model numbering — settled 2026-08-28

The September cycle is **renumbered 26.x** rather than carried on as 25.2c (Grant's call). The
letter-based shortnames are what the report shows; the long strings in `model_defs` /
`03_build_results_object.R` are internal case keys only and never reach a table or figure, which
go through `to_short()`. The five-model September set:

| Shortname | Folder | Role |
|---|---|---|
| Model 25 | `25_gmacs/` | 2025 rolled-forward reference |
| Model 25.2c | `25_gmacs_update_newmat_plus_group/` | May accepted, terminal 2024 |
| Model 25.2e | `25_gmacs_rightFALSE_growthfix/` | binning (right=FALSE) + growth-typo sensitivity |
| **Model 26.1** | `26_gmacs_update_newmat_plus_group/` | **RECOMMENDED**, terminal 2025 |
| Model 26.1a | `26_gmacs_male_only/` | male-only sensitivity of 26.1 |

`25.2e` because **`25.2d` was already the immature-index model**. The Rmd's `accepted_model` now
resolves to Model 26.1 — **it previously named the May folder**, which would have reported a
terminal-2024 fit as the September assessment.

**`0-models.R` was pruned to these five on 2026-08-28** (the old "TODO(Phase 3)"). Its precondition
— auditing every `model_defs[N]` use — was done first and found no positional indexing anywhere;
the results object is keyed by case name too. The May bracket lives in `../snow_crab/0-models.R`
and git history. `model_jittered` now sits beside the definitions instead of as a positional vector
in the Rmd. **Consequence still open:** the Rmd's Section C narrative (`:447`-`:477`) still
describes the eleven May models, directly under "A total of 5 models were explored" — the approved
replacement is `PHASE1_SECTION_SKETCHES.md` §12. Backlog **4d**.

**The May 2026 CPT minutes call the recommended run "Model 25.2c"**, so the mapping is stated
explicitly in `PHASE1_SECTION_SKETCHES.md` §C and in the CPT-response text. Verbatim CPT quotes
were deliberately left as "25.2c"; every reference that *means the September Tier 3 model* was
renumbered (14 lines). `Model 25.2c` remains a live designation for the May fit, so surviving
mentions of it are lineage statements, not stale text.

## Model 26.1b (data through 2019) — built, fitted, jittered, retrospected 2026-08-28

The May 2026 CPT asked for a run truncated to 2019 to test whether the convergence problems
originate in estimating recruitment after the 2018-19 collapse and across the missing 2020 survey.
**The answer is no — truncating makes the model markedly less stable, not more.**

`Models/26_gmacs_data2019/`, npar **386**, accepted fit promoted from `jitter/089`:
nll **-19740.5096858427**, max|grad| **0.00291** (does *not* meet 1e-3), BMSY **161.28609864**,
Bcurr/BMSY **1.0544**, OFL(tot) **147.27745429**, terminal MMB (2019) **86.90460802**.
Building it required two `00` fixes — see backlog **4e**.
> Corrected 2026-08-28: this row first read BMSY 168.35 / MMB 91.88, which were the
> **pre-promotion cold-start** values recorded next to the **post-promotion** nll. Two fits in one
> row is exactly the error the known-traps list is about. Values above are all from the promoted
> `jitter/089` fit in `Gmacsall.out`.

| | usable | meet 1e-3 | distinct modes | minor | OFL range across jitters |
|---|---|---|---|---|---|
| 26.1 | 79 | 10 | 6 | 58 | 82.1-90.8 kt |
| 26.1a | 83 | 9 | 6 | **4** | 74.0-95.5 kt |
| **26.1b** | 89 | 12 | **10** | 55 | **0.1-159.3 kt** |

More runs converge usably (89) and more meet 1e-3 (12) — it is not that the model fails to fit, it
is that it fits **many different answers**: ten distinct optima, only **3.4%** reaching the best
one (26.1 manages 5.1%), and a directed OFL spanning three orders of magnitude with two runs
collapsing to ~0. Caveat for the write-up: fewer years means less information, so *some*
degradation is expected on principle — but not a 159 kt spread.

**Retrospective** (22 peels, all seeded; peel 0 reproduces the parent to 1.02e-08 over 38 years):

| | Mohn's rho MMB (std / drop-survey) | recruitment rho |
|---|---|---|
| 26.1 | -0.109 / -0.110 | 7.89 / 9.51 |
| 26.1a | -0.091 / -0.083 | 0.72 / 0.68 |
| 26.1b | **+0.056 / +0.069** | 4.62 / 3.55 |

All three sit inside the Hurtado-Ferro bounds. Note the nuance: 26.1b has the **smallest**
retrospective pattern and the **worst** multimodality, so the two diagnostics disagree — the
retrospective is computed at one optimum and says nothing about how many optima there are.

**Side finding:** 26.1a (male-only) is the best-behaved of the three — only **4** runs scatter into
minor modes against 55-58 for the others. Independent support for the SSC's suggestion to strip the
model toward a minimal parameter set.

**Promotion caveat:** run 089's gradient (0.00291) fails 1e-3, and unlike the male-only case this is
a real tradeoff rather than floating-point noise — only one run lies within `NLL_TOL` of the best
nll, and the best run that *does* meet 1e-3 (run 021) is **1.05 nll units worse**. Left as
promoted because 26.1b is a diagnostic run, not a specification model. Flag it in the write-up.

**Artifacts are NOT at the default paths** (backlog 4b): `Models/rda_jitter_data2019.RData`,
`plots/_data2019_jitter/`, `plots/_data2019_retro/`. Two-sex originals restored and verified.

## Model 25.2c — accepted fit is now jitter run 078 (2026-08-28)

Per Grant: *use 078 if `-hess_step` gets its gradient below 0.001, otherwise keep the macOS
re-fit.* It does — **max|grad| exactly 0**, nll **-19227.1626835733**. Installed; provenance in
`jitter/PROMOTION.md`. All three earlier fits preserved (`_may_fit_backup/`, `_pre078_backup/`).

**A 1.27 nll improvement moved the OFL by -12.81%** (50.266 -> 43.827 kt) while BMSY moved +0.62%
and status -0.33%. That is the multimodality problem stated as a management number, and it is now
written into the convergence section of the Rmd.

**Retrospective re-run against 078** (it is a different optimum, not a polish, so the old one
measured the wrong fit). Mohn's rho also moved with the optimum:

| | macOS re-fit | 078 |
|---|---|---|
| MMB rho standard / drop-survey | -0.105 / -0.174 | **-0.124 / -0.197** |
| recruitment rho standard / drop-survey | 0.86 / 1.24 | **3.92 / 4.55** |

Both MMB values remain inside the Hurtado-Ferro bounds, but drop-survey **-0.197** is now close to
the -0.22 limit, and recruitment rho quadrupled. Worth reporting: the retrospective diagnostic is
itself sensitive to which optimum is adopted.

**Known cosmetic warning:** collect now reports *"peel 0 does not reproduce the parent fit (max rel
diff 2e-06)"*. This is an artefact of the parent being `-hess_step` polished while the peels are
not — peel 0 lands on the unpolished optimum, 2e-06 away in relative MMB, which is immaterial. It
will appear for any model whose retrospective is re-run after polishing. Either accept it, or
polish peel 0 as well for consistency.

## Model 25.2c — the earlier three-way choice (superseded by the above)

Run at Grant's request. **`05` re-fit the base automatically** because the preflight found it stale:
`gmacs.dat` names `snow.ctl` but the run record named `25_snow_update_newmat_plus_group.ctl`, which
no longer exists. Before letting that happen the stored par was checked against the *current* files
(pin + `-maxfn 0`): **-19222.4892880158 vs the stored -19222.4892880162**, agreement to 4e-10 — so
the ctl had simply been renamed and the May fit was valid.

**Three candidate fits now exist for 25.2c. Grant's call which is the step-change baseline:**

| fit | nll | max\|grad\| | where |
|---|---|---|---|
| May / Windows | -19222.4892880162 | 0.00146 | `_may_fit_backup/` (preserved) |
| **macOS cold re-fit** | **-19225.8954975112** | 0.00569 | currently in the model dir |
| jitter run 078 | -19227.1627 | 0.0103 | `jitter/078`, NOT promoted |

The May fit was **3.41 nll units** below what a macOS cold start finds, and the jitter found another
1.27 beyond that. None meets 1e-3, and they trade likelihood against gradient in opposite
directions. `--no-promote` was used so run 078 is reported only. The retrospective below was run
against the **macOS re-fit** (same platform as the rest of the set, better optimum); restoring the
May fit and redoing it is a `cp _may_fit_backup/* .` away.

**Jitter:** 82/100 usable, only **7** meet 1e-3, 6.1% reached the best mode, 6 modes + **60**
scattered runs, directed OFL **21.2-73.2 kt**. Comparable instability to 26.3.
**Retrospective:** 22 peels, all seeded, peel 0 reproduces the parent to 9.09e-11 over 43 years.

**All four retrospectives (Mohn's rho, standard / drop-survey):**

| model | MMB rho | recruitment rho |
|---|---|---|
| 25.2c | -0.105 / **-0.174** | 0.86 / 1.24 |
| 25.2e (new data) | -0.109 / -0.110 | 7.89 / 9.51 |
| 26.2 (male-only) | **-0.091 / -0.083** | **0.72 / 0.68** |
| 26.3 (2019) | +0.056 / +0.069 | 4.62 / 3.55 |

All inside the Hurtado-Ferro bounds; 25.2c's drop-survey -0.174 is the largest. Artifacts at
`Models/rda_jitter_25.2c.RData`, `plots/_25.2c_jitter/`, `plots/_25.2c_retro/`.

## Polishing a fit's gradient — `-hess_step` (verified 2026-08-28)

Several models sit above the 1e-3 gradient criterion. ADMB can polish an existing solution with
Newton steps using the inverse Hessian, which removes the gradient concern without moving the fit.
**Verified working on Model 26.3**: max|grad| **0.00291 -> 0.00000000000000**, nll changed by
**3.8e-7**, BMSY 161.28610 vs 161.28610 and OFL 147.27748 vs 147.27745 — same optimum, polished.
Standard errors are preserved and the full sdreport (`gmacs.std`, `Gmacsall.out`, `admodel.hes`)
is regenerated.

```
./gmacs -binp gmacs.bar -hess_step 5 -nox      # run IN the fitted model directory
```

Requirements, both learned the hard way — the first attempt failed with *"Error reading
admodel.hes file to get MLE values"*:
- the directory must already hold the **fitted `admodel.hes`** (it reads the MLE from it), so run
  this after a normal fit, in place;
- pass **`-binp gmacs.bar`**. ADMB warns that without it *"inactive parameters (and thus gradients)
  may not initialize correctly"*.

**`-nr N` is NOT the flag** — despite the name, `gmacs -help` lists it under *"Random effects
options if applicable"*, i.e. the inner Newton-Raphson for random-effects models. GMACS is not
using random effects here.

One caveat: on 26.3 a single parameter moved by 0.042 while the likelihood moved 3.8e-7. That is
`M_pars_est[12]` (immature-female M, block 2), the near-unidentified parameter — a flat direction,
so polishing slides along it freely. Harmless for reported quantities, but it means `-hess_step`
does not fix a poorly-identified parameter, it only zeroes the gradient. Backlog **5b** still
stands.

**APPLIED to all five models that could take it, 2026-08-28** (per Grant). Every gradient is now
exactly zero and every reference point is preserved to **7e-8 or better**:

| model | nll before -> after | max\|grad\| | BMSY rel diff | OFL rel diff |
|---|---|---|---|---|
| 25.2c | -19225.8954975112 -> -19225.8954979337 | 0.00569 -> **0** | 7.3e-08 | 1.9e-08 |
| 25.2e | -22836.0068920176 -> -22836.0068920175 | 0.00120 -> **0** | *(no pre-polish file)* | |
| 25.2e (new data) | -23546.3457934123 -> -23546.3457934121 | 0.000931 -> **0** | 6.9e-11 | 1.8e-08 |
| 26.2 | -14010.6635839271 -> -14010.6635843467 | 0.000705 -> **0** | 9.9e-10 | 1.1e-08 |
| 26.3 | -19740.5096858427 -> -19740.5096862256 | 0.00291 -> **0** | 1.5e-08 | 2.1e-07 |

Pre-polish fits are in each model's `_prehess_backup/`. **Model 25 could NOT be polished** — it has
no macOS executable (GMACS 2.20.22), so it keeps max|grad| 0.00134 and remains the one
platform-mixed model in the set.

**Model 25.2e was missing `Gmacsall.out`** (a complete fit whose run never wrote that file). Since
`-hess_step` starts from the existing MLE it regenerated every output as a side effect, which is
what fixed it. That missing file had killed the render at chunk 18 of 93 with an opaque
`auto_copy(): ... y is NULL`; the `like-index-tot` chunk now names the model instead, because
`dir.exists()` does not catch a folder whose fit merely failed to finish writing.

**`03` must be re-run after polishing** — the results object reads `Gmacsall.out`. Done.

## SAFE checklist gap analysis — 2026-08-28

Audited `SAFE_snow_gmacs.Rmd` against `Reports/2026-08_checklist_crab_SAFE_review.pdf` and
`Reports/2026-08_reminders_crab_SAFE_review.pdf`.

**The section lettering does not match the guidelines, and two required sections are absent.**
The checklist requires *"Every section is present (A-K; even if not applicable to the stock)"* with
a fixed lettering. The Rmd uses its own:

| Required | Rmd today |
|---|---|
| *(Executive Summary, unlettered)* | `# A. Executive summary` |
| **A. Summary of Major Changes** | **MISSING** |
| B. Responses to SSC and CPT Comments | `# B.` ✔ |
| C. Introduction | `# D.` |
| D. Data | `# E.` |
| E. Analytic approach | `# F.` (+ `# C. Assessment scenarios` and `# G. Results`, which the guidelines fold in as *Model Selection and Evaluation* and *Results*) |
| F. Calculation of the OFL | `# H.` |
| G. Calculation of the ABC | `# I.` |
| **H. Rebuilding Analyses** | **MISSING** |
| I. Data Gaps and Research Priorities | `# J.` |
| J. Ecosystem Considerations | `# K.` |
| K. Literature Cited | `# M. References` |

**Both missing sections already have drafted text** — `PHASE1_SECTION_SKETCHES.md` §2
(`# A. Summary of Major Changes`) and §6 (`# Rebuilding Analysis and Update`). **Snow crab is under
a rebuilding plan**, and the checklist says that even in a non-reporting year the heading must be
kept with a note on when the next analysis occurs — so H cannot simply be omitted.

**Other checklist items not yet satisfied:**
- **Tier designation must include the subtier** (a/b/c). "Tier 4a" etc. appears nowhere.
- **Buffer history (5 years) + risk table appendix** is required for EBS snow crab. "buffer history"
  appears nowhere in the Rmd or the sketches.
- **Mention appendices in the Executive Summary** — it currently does not.
- Executive Summary items **1-10** are prescribed (stock, catches, data sources, biomass,
  recruitment, management performance table, basis for the OFL table, OFL pdf, ABC basis,
  rebuilding summary). `# A.` is narrative prose, not those items.
- Exec Summary tables 1-3 **for all model options**, including the Tier 4 fallback.
- `BMSY` in the OFL table is the **current season projection minus 1 (t-1)**; relabel
  **'Current MMB' → 'Projected MMB'**; add a **table of projected MMB at realistic catch values**.
- Table captions must carry **units and model number**.

**Model numbering — the checklist states the convention explicitly:** *"If major changes, then
'Model yy.j' … If minor, then 'Model yy.jx' where x is a letter distinguishing from other minor
change models"*, and the parenthetical form is sanctioned only for a **GMACS version** change
(*"26.0 (v34.0)"*). Current shortnames are `Model 25.2e (new data)` — a parenthetical used for a
data update, not a version — and `Model 26.2` / `Model 26.3` (major-change form) for what are
variants of one base. Under the stated convention those would be `26.1`, `26.1a`, `26.1b`.
**Grant's call**, but a reviewer checks numbering against both this convention and the
SSC-endorsed numbers.

## June 2026 SSC report + SAFE review docs — cross-reference, 2026-08-28

Read from `Reports/2026-06_SSC_report.pdf`, `Reports/2026-08_checklist_crab_SAFE_review.pdf` and
`Reports/2026-08_reminders_crab_SAFE_review.pdf` (all three are text-extractable; the latter
two are CID-encoded and need the ToUnicode CMap, not a naive stream dump).

**Scope — read this before planning the October package.**
> *"The SSC recommends that the author **only bring the Tier 4 model forward in October**, to allow
> more time for development of a simpler, viable Tier 3 model."*

The SSC also says *"a Tier 4 model will likely be needed for specifications until convergence
issues are satisfactorily addressed"*. The Tier 3 runs are still wanted as development (the SSC
asks for a stripped-down minimal-parameter model), but the October **specification** package may be
Tier 4 only. This sits alongside the May CPT's three-run request, which is earlier.

**Model numbering — the review guidance cuts against the 26.x renumbering.**
- Checklist: *"Model numbers are consistent … **with those previously endorsed by SSC**"*
- Reminders: *"cross-validated with those **endorsed by the most recent SSC Report**"*
- Checklist: *"if just GMACS update and no model updates, **include in parentheses but do not
  change model number**, e.g., 26.0 (v34.0)"*

The most recent SSC report calls the accepted configuration **Model 25.2c**. Ours is that same
configuration plus a year of data, renumbered 26.1. Either revert or document the rationale — a
reviewer checks this explicitly. (Counterpoint: the same SSC report uses 26.0 for Tanner's
new-cycle model, so cycle renumbering is not unheard of.)

**Standing requests not yet met.**
- *"The SSC continues to request a **yield-per-recruit analysis** that could be used to inform
  development of an alternative harvest control rule."*
- For 2027 Tier 3 models: a focused **convergence section** — which parameters separate the jitter
  clouds, correlation diagnostics, likelihood profiles for terminal MMB / recent recruitment / M /
  OFL, and targeted simplification runs (examples given: fix the recruitment sex ratio at 50:50,
  reduce confounding among growth, M and selectivity). Model 26.1a already speaks to the last one.

**Checklist items affecting tables.** Executive Summary tables 1-3 for **all** model options
including Tier 4 fallbacks; tier designation must show the subtier (a/b/c); BMSY is the current
season projection minus 1 (t-1); relabel 'Current MMB' to 'Projected MMB'; add a table of projected
MMB at realistic catch values.

**What the SSC did NOT say:** nothing about the Tier 4 ramp — see backlog 7d.

## Known flags / gotchas
- **A new model dir already contains the TEMPLATE's results.** `00_advance_model.R` §8 copies
  `template_dir`, bringing its `gmacs.par`/`Gmacsall.out`/etc. A male-only build that had *failed at
  runtime* showed a complete, plausible fit (407 par, nll -19222.489) that belonged to the 25 model.
  **Check `gmacs.par`'s mtime before believing any number from a new model dir.** Backlog 1e.
- **Peels never produce reference points.** `gmacsbase.TPL:5478` and `:13625` gate the calculation on
  `nyrRetroNo == 0`, so every peel returns all 18 derived quantities as exactly 0. `retro_refpoints.csv`
  no longer exists; the retrospective reports MMB and recruitment only. Applies to the 2025 SAFE too.
- **`M_pars_est[15]`** (immature-female M, block 2) was **8.707 ± 5351.8** in the pre-promotion fit —
  unidentified, at its bound, and the sole near-zero Hessian eigenvalue. It is why the two platforms'
  cold starts disagreed. In the accepted fit it is 1.826 ± 0.581. Whether it should be fixed
  (`phz = -4`) is a CPT question — backlog 5b.
- **`05`'s promotion rollback silently lied once** (2026-08-24), leaving 7 of 9 files holding a
  rejected fit. Now md5-verified and refuses to promote if the backup is incomplete. **Root cause of
  the copy failure is still unexplained** — backlog 1c.
- **`07_calc_tier4.R` pulls crabpack live with no fallback** and writes three CSVs at separate points;
  a timeout between two writes leaves a mixed `data/tier4/`. Backlog 7c.
- `Models/25_gmacs` was fit with GMACS **2.20.22** and has no executable — it cannot be reproduced by a
  current binary and got no macOS build.
- **`model_defs[N]` index audit** still not done — audit before pruning `0-models.R`.

## Blocked on decisions (critical path)
1. **Which Tier 4 basis is correct — ramp or flat M?** `07` ramps (status 0.769 → F_OFL 0.201 →
   **22.867 kt**); `CLAUDE.md:169` says the 2026 basis is *flat F = 0.27, no ramp* → **30.765 kt**.
   A **7.90 kt / 26%** difference on the catch limit, and the two are mutually exclusive. Backlog 7d.
2. **Which OFL formula?** `07` §4 uses `B*(1-exp(-F))`, §6 (the reported one) uses `F*B` — **9.4%**
   apart. Backlog 7e.
3. **The three `25_*` comparison models are still Windows fits.** Any SAFE table comparing them with
   the 26 model mixes platforms. ~30 min to re-fit on macOS.
4. `data/historical/` needs a **2026 column** before the vintage-bias figure is current, and the 2025
   vintage records `0.00` for 2020 MMB-at-survey (COVID, no survey) which plots as real. Backlog 5d.
5. ~~`03` does not include the 26 model.~~ **Resolved 2026-08-28** — see "Model numbering" below.

## Resume here (prioritized)
1. **Settle the Tier 4 basis (blocked #1).** Every OFL/ABC number in the SAFE depends on it, and
   `PHASE1_SECTION_SKETCHES.md:80` has `[[value]]` placeholders waiting on it.
2. **Re-run what the promotion invalidated:** `03_build_results_object.R` (its
   `Models/rda_ModelsResLst.RData` is dated **2026-07-28**, a month older than the accepted fit), then
   `08_render_report.R`. `05`/`06`/`07` are already current.
3. **Run `02`** to produce the two new figures and `data/survey/survey_recruit_index_derived.csv`, then
   `04_plot_recruitment_comparison.R`. Needs crabpack (works; `07` used it 2026-08-27).
4. **Male-only sensitivity: wired into the report, needs `03` re-run.** Fit, jitter, retrospective
   and the report wiring are all done (backlog **5e** closed). Added 2026-08-28 as
   **`Model 25.2c (males only)`** — it keeps the 25.2c designation because the CPT asked for it as
   a *sensitivity of* 25.2c, not a new candidate:
   - `0-models.R` — appended to `model_defs`/`model_shorts` (**appended, not inserted**, so the
     positional `model_defs[N]` references the port note warns about keep their indices; 1-14 are
     unchanged, male-only is 15).
   - `03_build_results_object.R` — third folder/label, plus a new guard that fails loudly if the
     labels here, in `0-models.R`, and the folders on disk ever disagree. Negative-tested.
   - `SAFE_snow_gmacs.Rmd` — scenario table (`model-overview`; its `Jittered` column is a
     **positional** vector, now 15 long and assertion-guarded), a `Model 25.2c (males only)` entry
     under Model scenarios, the two assumption bullets, and a convergence/retrospective results
     paragraph. `accepted_model`/`reference_model` are untouched.
   Remaining: **re-run `03`** (see blocker 5), then resolve the `[[VERIFY]]` on the
   B<sub>MSY</sub>/OFL comparison, which is deliberately left to `Table \@ref(tab:stepchange)`
   rather than hardcoded. **5f** records why fixing female phases instead would *not* work; **5b**
   (whether `M_pars_est[15]` should be fixed) does not arise here — there is no female M.
   **Its artifacts are NOT at the default paths** — `05`/`06` write model-independent filenames
   (backlog **4b**), so the male-only copies were moved to `Models/rda_jitter_male_only.RData`,
   `plots/_male_only_jitter/` and `plots/_male_only_retro/`, and the two-sex originals restored.
   **Back those up before running `05` or `06` on any non-default model again.**
5. **Port narrative sections** onto the new Rmd (data-independent) — see `docs/PORT_MAP.md`.
6. Install the 6 missing R packages if `04`/`07` are run on a fresh machine (`rema` is GitHub-only).
