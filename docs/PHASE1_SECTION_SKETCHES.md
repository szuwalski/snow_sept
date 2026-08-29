# Phase-1 section-port sketches — September 2026 snow crab SAFE

**Companion to** `SEPT2026_SNOW_CRAB_BUILD_PLAN.md` (v3). These are **draft R Markdown chunks** for the data-independent Phase-1 work: port the missing sections from the GitHub Sept-2025 final into the working copy (converted to the working copy's `reslst`/`model_defs` idiom) and scaffold the new SSC-required sections.

**Conventions used below**
- Model references use the placeholders **`ACCEPTED_TIER3`** (= Model 25.2e (new data) = `26_gmacs_update_newmat_plus_group`) and **`REFERENCE`** (= rolled-forward 2025 accepted). Wire these to the real `model_defs`/case names **only after** the `0-models.R` audit (plan §5 prerequisite). Do not hard-code case strings until the audit confirms them.
- Management quantities reuse the working copy's existing `extract_mgmt_quantities()` helper (the `stepchange` chunk), **not** GitHub's inline `Gmacsall.out` parsing and **not** the legacy gmr `M[[]]` idiom.
- Chunks that depend on runs that don't exist yet (male-only, data-through-2019, final 2026, Tier-4 output) are marked `eval=FALSE` **# PHASE 2** so the document still knits during Phase 1. Flip to `eval=TRUE` when the run lands.
- `[[TODO]]` = author decision or data needed. `[[VERIFY]]` = confirm against source before trusting.

---

## 1. Title page — disclaimer + citation (YAML header)

Add to the YAML front matter / a first page block. Data-independent. (Guidelines §4.1.)

```yaml
# --- add under the existing title/author/date in the YAML ---
subtitle: |
  | DRAFT — distributed for pre-dissemination peer review
```

```r
# First-page block (place immediately after the YAML, before "# A. ..."):
```

```markdown
*This information is distributed solely for the purpose of pre-dissemination peer
review under applicable information quality guidelines. It has not been formally
disseminated by the National Marine Fisheries Service and should not be construed
to represent any agency determination or policy.*

This report may be cited as:

> Adams, G. and C. Szuwalski. 2026. Assessment of the snow crab stock in the
> Eastern Bering Sea. North Pacific Fishery Management Council, Anchorage, AK.
> Available from https://www.npfmc.org/library/safe-reports/
```

---

## 2. `# A. Summary of Major Changes` (port from GitHub final, updated for 2026)

GitHub structure kept (Management / Input data / Methodology / Results); content updated to the May-2026 direction (new maturity adopted; plus group; comp fix; **hybrids excluded**; Tier-4 basis). Guidelines §4.2.1.

```markdown
# A. Summary of Major Changes

1. **Management:** The eastern Bering Sea snow crab population was declared
overfished in October 2021; the directed fishery was closed for the 2022 and
2023 seasons and a small fishery occurred in 2024 [[TODO: add 2025/26 fishery —
ADFG retained ~4.1 kt in crab_year 2025, confirm]]. The stock remains under a
rebuilding plan (see Rebuilding Analysis and Update).

2. **Changes in input data:**
   - Added the 2025 NMFS summer survey and updated the catch time series through
     crab_year 2025 (retained, discard, and bycatch) from the revised ADF&G/AKFIN
     workflows that now deliver the full historical series each cycle.
   - Adopted a small early-1990s retained-composition correction arising from a
     crab-year offset fix in the ADF&G delivery [[VERIFY: docs/EMAIL_to_tyler.md]].
   - Total-male size-composition input corrected (comp fix).
   - Plus group expanded to include all crab > 135 mm carapace width.
   - **Hybrid catch and survey data are NOT included in the model this cycle**
     (per May 2026 CPT/SSC); hybrid uncertainty is addressed in the risk table /
     ABC buffer (Appendix B) and hybrids continue to be tracked in the NOAA survey
     technical memo.

3. **Changes in assessment methodology:**
   - Adopted the new maturity workflow (Ryznar, spatiotemporal `sdmTMB`; Bernoulli
     likelihood + bootstrap uncertainty) as the base maturity input, replacing the
     legacy design-based terminal-molt probabilities.
   - Given persistent convergence/bimodality in the Tier 3 model, the **Tier 4
     calculation is brought forward as the basis for the 2026 harvest
     specification** while a simplified, stable Tier 3 is developed for 2027.
   - The recommended currency of management is morphometrically mature male biomass,
     following the all-mature-male-biomass basis of the standardized Tier 4 fallback;
     the ≥95 mm currency recommended in 2024–2025 is retained for comparison.

4. **Changes in assessment results:** [[PHASE 2 — populate from the final runs]]
   The Tier 4 OFL is `[[value]]` kt and ABC `[[value]]` kt. The developing Tier 3
   model (Model 25.2e (new data)) is presented for review but is not the basis of the 2026
   specification.
```

---

## 3. `# Executive summary` — numbered 1–7 scaffold (Tier-4 basis)

Port GitHub's numbered structure. Items 1–4 are largely narrative (data-independent). Item 5 (management table) reuses `continuity/management_table.csv`. Items 6–7 (**Basis for OFL / ABC**) are **re-pointed to Tier 4** (row 416) — this is the biggest change from the GitHub base, which built these on Tier 3.

```markdown
# Executive summary

1. *Stock* — Eastern Bering Sea snow crab, *Chionoecetes opilio*.

2. *Catches* — [port GitHub item 2 verbatim; inline `r` catch pulls already target
   the accepted model's `Catch_fit_summary`. Repoint the case name to ACCEPTED_TIER3
   once the audit confirms it.]

3. *Stock Biomass* — [port GitHub item 3; repoint case name; update terminal year to 2025.]

4. *Recruitment* — [port GitHub item 4; update terminal-year language.]

5. *Management*
```

```{r mgmt-table, echo=FALSE}
## PHASE 1-safe: reads a static CSV; terminal-year cells are filled from the
## results object and guarded so the chunk still knits if the 2026 run is absent.
ManTable <- read.csv("continuity/management_table.csv")
PlotTab  <- data.frame(ManTable)
colnames(PlotTab) <- c("Year","MSST","Biomass (MMB)","TAC","Retained catch",
                       "Total catch","OFL","ABC")

## Terminal row for the 2025/2026 crab year (row 411: report terminal-year MMB & MSST)
PlotTab <- rbind(PlotTab, rep(NA, ncol(PlotTab)))
PlotTab$Year[nrow(PlotTab)] <- "2025/2026"

## [[PHASE 2]] fill MMB / MSST / OFL / ABC from the Tier-4 output + ACCEPTED_TIER3.
## MSST = 0.5 * BMSY-proxy.  Keep both currencies as separate tables as the base does.

PlotTab[is.na(PlotTab)] <- " "
pander::pander(PlotTab, split.cells = 10,
  caption = "\\label{managementtable}Historical status and catch specifications for
             snow crab (1,000 t). Terminal-year MMB and MSST = 1/2 B_MSY proxy.")
```

```markdown
6. *Basis for the OFL*

The 2026 overfishing level is calculated under **Tier 4** (per the June 2026 SSC
recommendation to bring forward only the Tier 4 model while a simplified Tier 3 is
developed). The Tier 4 OFL applies a constant target F (0.27, the median of the prior on natural mortality) to the
REMA-smoothed survey biomass. The **recommended currency is morphometrically mature
male biomass** — consistent with the October 2024 SSC recommendation that the
standardized crab Tier 4 fallback use *all mature male biomass*. For comparison, the
OFL is also reported for the **≥95 mm** and **>101 mm** size ranges (as in the 2025
Tier 4), and the developing Tier 3 model (Model 25.2e (new data)) is reported below.
```

```{r ofl-basis-tier4, echo=FALSE, eval=FALSE}
## PHASE 2 — wire to the Tier-4 output produced by 07_calc_tier4.R (rema).
## Report all three currencies (2025 precedent: morphometric 28.41, >=95mm 8.64,
## >101mm 6.11 kt), with MORPHOMETRIC as the recommended basis.
##   Currency | REMA biomass | M (=F proxy) | OFL | ABC(=0.8*OFL)
## Rows: Morphometric (recommended) / >=95 mm / >101 mm.
tier4 <- readRDS("Models/tier4_results.rds")   # [[VERIFY output path/object]]
# ...assemble 3-row table + pander(); flag the morphometric row as recommended...
```

```{r ofl-basis-tier3, echo=FALSE, eval=FALSE}
## PHASE 2 — Tier 3 (Model 25.2e (new data)), presented for context, both currencies.
## Reuse extract_mgmt_quantities() from the stepchange chunk rather than re-parsing.
## `accepted_model` is defined in the Rmd setup chunk and now resolves to Model 25.2e (new data).
## Do NOT leave the literal "ACCEPTED_TIER3" here -- it is not a key in model_defs
## and would error the moment this chunk is flipped to eval=TRUE.
t3 <- extract_mgmt_quantities(model_defs[[accepted_model]], "Model 25.2e (new data)")
# ...pander() BMSY / status / FOFL / OFL...
```

```markdown
7. *Basis for the ABC*

The ABC is the OFL reduced by a buffer for scientific uncertainty. **A 20% buffer is
applied here** (`ABC_buffer <- 0.8`), consistent with the buffer the author
recommended in the 2025 final assessment. [[NOTE: this is a working placeholder. The
adopted Crab Risk Table SOP (Appendix B) seeds the Tier-1 buffer at the *average of
the previous five assessments* (≈ 37–38% using the SSC-adopted buffers), and 2026 is
on the Tier 4 fallback — both point to a larger buffer than 20%. Revisit when
Appendix B is populated. See plan §6.]]
```

---

## 4. `## History of modeling approaches for the stock` (port from GitHub §F)

Straight port; data-independent. Insert as the first subsection under `# F. Analytic approach`.

```markdown
## History of modeling approaches for the stock

Historically, survey estimates of large males (>101 mm) were the basis for
calculating the Guideline Harvest Level (GHL) for retained catch. A harvest strategy
was developed using a simulation model that pre-dated the current stock assessment
model (Zheng et al. 2002), used by ADF&G to set the GHL (renamed total allowable
catch, 'TAC', since 2009) since the 2000/2001 fishery. Currently, NMFS uses an
integrated size-structured assessment to calculate the overfishing level (OFL),
which sets an acceptable biological catch (ABC) ≤ OFL, which in turn provides a
ceiling to the State-set TAC.
```

---

## 5. `### Convergence & Diagnostics` (NEW — SSC rows 415 & 417)

New subsection under Results. Scaffolds the four required likelihood profiles + the data-through-2019 run + correlation diagnostics + simplification runs. All run-dependent chunks are `eval=FALSE` for Phase 1.

```markdown
### Convergence and diagnostics

Convergence was assessed by successful inversion of the Hessian and the maximum
absolute gradient, supplemented by a 100-run jitter analysis and, where feasible,
Newton steps on the inverse Hessian (`-hess_step`) to drive the maximum gradient
below 1e-5 [[VERIFY the accepted model achieves this]]. Bimodality in management
quantities has recurred in this assessment; the diagnostics below identify the
parameters that separate the jitter clouds and evaluate targeted simplifications
(per the June 2026 SSC request).

**Data through 2019.** To test whether convergence difficulties stem from estimating
recruitment following the 2018–19 collapse and the absence of the 2020 survey, the
accepted model was refit with the terminal year set to 2019 (CPT May 2026, an
outstanding request).

**Parameter correlations.** The parameters most strongly correlated in the accepted
model are summarized below; the two–three most correlated pairs are examined for
their role in the multiple optima (SSC June 2026).

**Targeted simplifications (developing 2027 model).** Runs evaluated: recruitment
sex ratio fixed at 50:50; reduced confounding among growth, M, and selectivity;
fewer survey/fishery selectivity parameters; growth estimated externally; and an
earlier equilibrium start year to reduce initialization parameters. The immature
survey index is **not** treated as a convergence fix (it shifts the model toward
higher mature-male M and unstable reference points).
```

```{r lik-profiles, echo=FALSE, eval=FALSE, fig.cap="Likelihood profiles for (a) terminal MMB, (b) recent male recruitment, (c) natural mortality M, and (d) OFL, showing the total and by-component negative log-likelihood. Horizontal line at chi-square(0.95,1)/2."}
## PHASE 2 — one profile per SSC-requested quantity (terminal MMB, recent
## recruitment, M, OFL). Profile grid + component decomposition + the
## chisq(0.95,1)/2 = 1.92 reference line. Build with the accepted model's par/bounds.
```

```{r param-corr, echo=FALSE, eval=FALSE}
## PHASE 2 — pull the correlation matrix from the .cor / admodel.cov of the
## accepted model; report the top |correlation| parameter pairs (table).
```

```{r retro-2019, echo=FALSE, eval=FALSE, fig.cap="MMB from the accepted model fit to data through 2025 vs. through 2019."}
## PHASE 2 — overlay the through-2019 fit on the full fit. (05_retrospective... adjacent.)
```

---

## 6. `# Rebuilding Analysis and Update` (NEW — SSC rows 418 & 2025(10))

New top-level section. Data-independent scaffold; projections are Phase 2.

```markdown
# Rebuilding Analysis and Update

Eastern Bering Sea snow crab was declared overfished in October 2021 and is managed
under a rebuilding plan [[VERIFY current rebuilding plan / amendment and Tmax /
target year]]. This section summarizes progress toward rebuilding.

- **Current status.** Terminal-year MMB is `[[PHASE 2]]` kt, or `[[value]]` × B_MSY
  proxy; MSST (= 1/2 B_MSY) is `[[value]]` kt. The stock is [[above/below]] MSST.
- **Rebuilding trajectory.** [[PHASE 2 — projected MMB under F=0 and under F_OFL
  relative to the rebuilding target and horizon; ties to the Projections section and
  the range-of-F projections requested in all-crab row 412.]]
- **Yield-per-recruit.** [[TODO — the SSC (rows 350/418) has repeatedly requested a
  yield-per-recruit analysis toward an alternative control rule. Include it or state
  its status/limitations explicitly.]]
```

---

## 7. `## Author recommendations` (UPDATE — flip from the working copy)

Replace the working copy's "no recommendation / adopt hybrids" text.

```markdown
## Author recommendations

For the 2026 fishing year, the author recommends setting the OFL and ABC on the
**Tier 4** calculation, consistent with the June 2026 SSC recommendation, while a
simplified and stable Tier 3 model is developed for 2027. The composition correction,
the expanded (>135 mm) plus group, and the new maturity workflow are adopted as
technical improvements and are carried in all Tier 3 configurations.

The author does **not** recommend including hybrid catch or survey data in the
assessment model at this time (per the May 2026 CPT/SSC); hybrid-related uncertainty
is reflected in the risk table and ABC buffer (Appendix B), and hybrid abundance and
distribution continue to be monitored in the NOAA survey technical memo.

The developing Tier 3 model (Model 25.2e (new data)) and a male-only sensitivity are presented
for review; the male-only run is not proposed for specification unless selected by
the CPT in September. Priorities toward the 2027 Tier 3 are the targeted
simplifications and convergence diagnostics described in Section F.
```

---

## 8. `# Status Determination` (NEW — guidelines §4.14)

```markdown
# Status determination

Under the MSFCMA, three questions are addressed for the recommended (Tier 4) basis.
Questions 1 and 2 use the Tier 4 survey-based status (terminal MMB relative to MSST =
1/2 B_MSY); question 3 draws on the Tier 3 model projection (Section L), because the
Tier 4 calculation does not project the stock forward.

1. **Is the stock subject to overfishing?** [[PHASE 2 — compare the most recent
   complete year's total catch to that year's OFL.]] Overfishing is [[not]] occurring.
2. **Is the stock overfished?** Terminal-year MMB is [[above/below]] MSST (= 1/2
   B_MSY proxy); the stock is [[overfished / not overfished]] and remains under a
   rebuilding plan.
3. **Is the stock approaching an overfished condition?** [[PHASE 2 — from the
   projection under F_OFL.]]
```

---

## 9. `## Flimit` (NEW — guidelines §4.15, for SARA/SIS)

```{r flimit, echo=FALSE, eval=FALSE}
## PHASE 2 — F that would have produced a catch equal to last year's OFL.
## For GMACS: substitute last year's OFL for last year's catch, fix estimation
## (max phase 0), re-run from the .par, and read back the terminal-year F.
## Report as F_LIMIT for the SARA file. [[TODO: confirm GMACS switch for phase-0 rerun]]
```

```markdown
The fishing mortality that would have produced a catch equal to last year's OFL
(reported as F_LIMIT in the SARA/SIS output) is `[[PHASE 2]]`.
```

---

## 10. `# Acknowledgements` and `# Auxiliary Files` (NEW — §4.18, §4.20)

```markdown
# Acknowledgements

We thank T. Jackson and the Alaska Department of Fish and Game for the fishery
removal and composition data; E. Ryznar and the Kodiak laboratory for the maturity
workflow; the Bering Sea Fisheries Research Foundation for the survey-selectivity
experiments; the AFSC shellfish survey team and AKFIN for survey data; and
[[reviewers]] for review comments.

# Auxiliary Files

The following files accompany this assessment for archiving: the GMACS input files
(`*.DAT`, `*.CTL`, `*.PRJ`), the model executable (`gmacs.exe`), and the projection
input/output files for the accepted model. Model source and documentation:
https://github.com/GMACS-project. Assessment inputs/outputs:
https://github.com/szuwalski/snow_sept. New maturity workflow:
https://github.com/eryznar/Chionoecetes.maturity.workflow.
```

---

## 11. Hybrid audit-trail note (short — retain the record; do NOT silently delete)

Insert a brief note in `# C. Assessment scenarios` where the hybrid runs were, so the
record shows they were explored and set aside (rather than vanishing).

```markdown
Hybrid *Chionoecetes* (snow × Tanner) sensitivities were explored for the May 2026
CPT meeting (inclusion of hybrids in the fishery and/or survey time series). Following
the May 2026 CPT and June 2026 SSC recommendations, hybrid catch and survey data are
**not** included in the assessment model at this time, because including hybrids in
the removals of the parent population creates internal inconsistencies. Hybrid-related
uncertainty is instead handled through the ABC buffer and risk table (Appendix B), and
hybrid abundance and distribution are tracked in the NOAA survey technical memo.
Modernized genetic identification and alignment of hybrid classification across the
ADF&G observer program, the EBS bottom-trawl survey, and federal fishery data streams
are noted as high-priority research (Data Gaps).
```

---

## 12. `# C. Assessment scenarios` (full rewrite — voice-matched to the 2025 SAFE)

Replaces the working copy's hybrid-heavy `C` section. Written to read like the accepted 2025 document (dense, declarative, minimal formatting, bulleted only for the run list and the assumptions). Incorporates the hybrid note from §11 as one paragraph. `[[FLAG]]` marks the currency paragraph pending your confirmation.

```markdown
# C. Assessment scenarios
## Model summaries

The following are presented this year:

 * Tier 4: a calculation of the OFL from REMA-smoothed survey biomass, brought forward as the basis for the 2026 harvest specification.
 * 25.2e (new data): the 2025 accepted model updated to GMACS 2.20.34 [[VERIFY version]] with the corrected total-male size composition, the plus group expanded to include all crab greater than 135 mm carapace width, and the new maturity workflow, advanced to end year 2025. This is the developing Tier 3 model and the author-recommended model. It is the configuration the CPT accepted in May 2026 as Model 25.2c; the September cycle is renumbered 26.1 (settled 2026-08-28).
 * 26.2, males only: a sensitivity that removes the female data and dynamics from 25.2e (new data).
 * 26.3, data through 2019: 25.2e (new data) refit with the terminal year set to 2019.
 * 25.2e: 25.2c with the size-composition bin convention changed so a crab on a 5 mm cutoff goes to the upper bin, and a growth-data transcription error corrected (a 26.3 mm crab's increment 73 mm read as 7.3 mm).

The key assumptions of the Tier 3 model include:

 * the probability of terminally molting at size varies over time and size and is specified as input to the model; this year it is taken from the new maturity workflow (Ryznar, in prep) rather than the design-based method used previously

 * survey selectivity is estimated by era (1982-88; 1989-present) and sex as a non-parametric curve subject to priors based on the BSFRF survey efficiency experiment data

 * growth is a linear function of pre-molt carapace width with a specified variability around post-molt size

 * all immature crab molt

 * natural mortality is estimated by sex and maturity state with additional mortality events estimated in 2018 and 2019 and subject to a prior based on an assumed longevity of 20 years

 * total and retained fishery selectivity are estimated logistic curves

 * all non-directed bycatch (e.g. snow crab caught in the Tanner crab fishery or crab caught in the non-pelagic trawl fisheries) is lumped into a single 'fishery' for which a single selectivity is estimated; these removals are recorded for both sexes combined, so in the male-only sensitivity they are fit by the male population alone and the bycatch fishing mortality estimated for males is correspondingly inflated (the affected removals average 0.48 kt against a mean retained catch of 37.1 kt, and the fit to the series is essentially unchanged)

 * recruitment is estimated separately for females and males and allocated to the first three size bins; the male-only sensitivity estimates male recruitment only

The probability of terminal molt at size is taken this year from the maturity workflow developed by the Kodiak lab (Ryznar, in prep), which fits a spatiotemporal model to chela-based maturity classifications and produces a smoothed probability of maturity at size with associated uncertainty. The CPT and SSC endorsed this workflow in 2026 as an improvement over the design-based method and recommended its adoption for both snow and Tanner crab. It replaces the design-based terminal-molt probabilities used in previous assessments; the updated series has a weaker temporal trend in the probability of terminal molt at intermediate sizes. Some years are missing from the new workflow and are being resolved [[VERIFY resolved before final]].

Hybrid *Chionoecetes* (snow x Tanner) crab were explored for the May 2026 CPT meeting by adding them to the fishery and survey time series. The CPT and SSC recommended that hybrid catch and survey data not be included in the assessment model at this time because including hybrids in the removals of the parent population creates internal inconsistencies. Hybrids are not included in the models presented here. Hybrid-related uncertainty is instead carried in the ABC buffer and risk table (Appendix B), and hybrid abundance and distribution continue to be tracked in the survey technical memo.

The Tier 3 model continues to produce the bimodal jitter behavior seen in recent assessments. Following the May 2026 CPT and June 2026 SSC, the Tier 4 calculation is brought forward as the basis for the 2026 harvest specification while a simpler and more stable Tier 3 model is developed for 2027. The male-only sensitivity and the run truncated to 2019 are presented to isolate the source of the convergence problem: removing the females reduces the number of estimated parameters and the confounding among growth, natural mortality, and selectivity, and truncating the data tests whether the problem originates in estimating recruitment following the 2018-19 collapse and the missing 2020 survey.

<!-- CURRENCY: settled 2026-07-30 — morphometric recommended, >=95mm and >101mm shown.
Rationale documented in the paragraph itself so the switch from the 2024/2025
author-recommended >=95mm currency is defensible to the CPT/SSC. -->
Reference points are calculated using morphometrically mature male biomass as the currency of management. This follows the all-mature-male-biomass basis of the standardized Tier 4 fallback (SSC, October 2024), which is the basis for the harvest specification this year. Management quantities are also reported for male biomass greater than 95 mm — the author-recommended currency in the 2024 and 2025 assessments — and greater than 101 mm carapace width, for comparison.
```

**Style notes (why it reads this way):** carried your existing constructions verbatim where the base model is unchanged (the assumptions bullets, the bycatch/selectivity phrasings); kept it declarative and passive as in the 2025 SAFE; no mid-sentence bold, no "Notably/Importantly/Furthermore," no summary sentence. The only opinionated line (the convergence rationale) mirrors the register you already use ("nothing that has prevented using the model for advice in the past").

---

## Removal checklist (Phase 1, mechanical)

From the working copy, delete or `eval=FALSE` the hybrid machinery: model scenarios
25.3a–d (narrative + `model_defs` entries once audited), the `hybrid` fleet-relabel
branches in the size-comp chunk (~lines 124–131 of the working copy), hybrid columns
in the data/fit figures, and the `01_update_catch_data_hybrids.R` data path. Replace
with the §11 note. **Do not** delete the underlying hybrid data files (keep for the
possible future cycle noted in row 424).

---

## 13. `### Tier 4` — basis for the OFL (fleshed out; supersedes the stub in §3)

Goes under `# G. Calculation of the OFL`. The Tier-4 HCR math lives in `07_tier_4.R`; the Rmd **presents** its output (same division of labor as the working copy's `extract_mgmt_quantities()`), rather than re-implementing the control rule. Two author decisions are flagged: the F proxy and the reference period.

**Prose (under `### Tier 4`):**

```markdown
The Tier 4 calculation follows the standardized crab Tier 4 fallback (SSC, October
2024): a B_MSY proxy taken from the time series of REMA-smoothed survey biomass and an
F proxy set to the estimate of natural mortality. Survey mature-male biomass is smoothed
with a random-effects model (the `rema` package). The B_MSY proxy is the mean of the
smoothed series over 1982-2025, extending the 2025 assessment's 1982-2024 reference
period by the new survey year (the 2020 survey is absent), and status is the terminal-year
smoothed biomass relative to that proxy. The OFL is obtained by applying the target F to the terminal-year biomass. As
in the 2025 assessment, a constant target F is applied with no sloped control-rule
reduction (the 2025 document states "no kink exists in this harvest control rule");
status is used for the overfished determination rather than to scale F.

The target F is 0.27, the median of the prior on natural mortality, as in the 2025
assessment. The October 2024 SSC standardization specifies the best estimate of natural
mortality from the Tier 3 model; the prior median is retained here because the Tier 3
model estimates time-varying M with additional mortality in 2018 and 2019, and the prior
median provides a single stable proxy consistent with the base-level mature-male M.
[[VERIFY the base-level (non-event-year) mature-male M in Model 25.2e (new data) is close to 0.27,
so the departure from the literal standardization text is defensible to the SSC.]] The
recommended calculation uses morphometrically mature male
biomass (Section C); it is repeated for male biomass greater than 95 mm and greater than
101 mm carapace width, as in 2025.

A survey-based alternative is on record (2024 CPT): the unsmoothed vulnerable biomass
from the current survey, decremented by the natural mortality occurring between the
survey and the fishery. The REMA-smoothed calculation above is the standardized basis
used here; [[TODO: decide whether to also show the unsmoothed/decremented variant.]]
```

**Chunk — REMA fit figure (guidelines §4.10/§4.11.2 require the smoothed series with uncertainty):**

```{r tier4-rema, echo=FALSE, eval=FALSE, fig.cap="Design-based survey mature-male biomass (points, 95% CI) and the REMA-smoothed fit (line, shaded 95% CI). Panels: morphometric, >=95 mm, >101 mm."}
## PHASE 2 — plot the rema fits produced by 07_tier_4.R (one panel per currency).
```

**Chunk — OFL/ABC by currency (presents `07_tier_4.R` output; morphometric flagged recommended):**

```{r tier4-ofl, echo=FALSE, eval=FALSE}
## PHASE 2 — Tier 4 status + harvest specification, three currencies.
## Expected object from 07_tier_4.R [[VERIFY name/columns]]:
##   tier4$by_currency = data.frame(currency, Bmsy, B_curr, status, M, Fofl, OFL)
## 2025 OFL sanity check (kt): morphometric 28.41 | >=95mm 8.64 | >101mm 6.11.

tier4 <- readRDS("Models/tier4_results.rds")          # [[VERIFY path/object]]

t4 <- tier4$by_currency |>
  dplyr::mutate(
    currency = factor(currency,
                      levels = c("morphometric", "ge95mm", "gt101mm"),
                      labels = c("Morphometric (recommended)", "≥95 mm", ">101 mm")),
    ABC = ABC_buffer * OFL                              # ABC_buffer <- 0.8 (20% buffer)
  ) |>
  dplyr::arrange(currency) |>
  dplyr::transmute(Currency = currency,
                   `B_MSY proxy` = Bmsy, MMB = B_curr, Status = status,
                   `M (F proxy)` = M, `Target F` = Fofl, OFL, ABC)   # constant F, no ramp

flextable::flextable(t4) |>
  flextable::colformat_double(digits = 2) |>
  flextable::autofit() |>
  flextable::set_caption(
    caption = "Tier 4 status and harvest specification by currency (1,000 t). Biomass is
      REMA-smoothed survey mature-male biomass; B_MSY is the mean of the smoothed series
      over the reference period; the F proxy is natural mortality; ABC = 0.8 x OFL.
      Morphometric is the recommended basis for the 2026 specification.",
    autonum = officer::run_autonum(seq_id = "tab", pre_label = "Table ", bkm = "tier4"))
```

**Chunk — convenience objects for inline text / Executive Summary item 6:** *(DELETE at build — superseded by §15a `tier4-setup`, which defines the same `*_2026` names. Keeping both double-defines the scalars.)*

```{r tier4-vals, echo=FALSE, eval=FALSE}
## PHASE 2 — pull the recommended (morphometric) row for inline `r` references.
t4_rec      <- tier4$by_currency[tier4$by_currency$currency == "morphometric", ]
ofl_2026    <- t4_rec$OFL
abc_2026    <- ABC_buffer * t4_rec$OFL
status_2026 <- t4_rec$status
```

```markdown
The recommended 2026 OFL is `r round(ofl_2026, 2)` kt and the ABC is
`r round(abc_2026, 2)` kt, applying a 20% buffer to the morphometric Tier 4 OFL.
```

---

## 14. `# B.` — responses to the May/June 2026 CPT & SSC comments (finished prose)

Insert at the **top** of Section B (the document lists most-recent first; the existing 2024–2025 responses stay below). Labels follow the document convention `year(month) source`. Voice matched to the existing responses (plain, first-person plural, no preamble).

```markdown
## SSC and CPT comments + author responses from 2026

***2026(5) CPT.** For the September 2026 meeting, bring forward three model runs: a Tier 4 analysis, Model 25.2c (the composition and plus-group corrections with the new maturity workflow), and Model 25.2c with only males included.*

All three are presented. The Tier 4 calculation is the basis for the 2026 harvest specification (Section G). The model the CPT accepted in May as Model 25.2c, advanced to end year 2025, is presented as the developing Tier 3 model and is designated **Model 25.2e (new data)** in this document; the male-only run of it is **Model 26.1** and is presented as a sensitivity (Section F). The male-only run is not proposed for specification unless the CPT concludes it is the best available option in September.

***2026(5) CPT.** All future Tier 3 models must include the corrections to the total-male size composition and the plus group, and the new maturity workflow.*

Model 25.2e (new data), which builds on the configuration the CPT accepted in May as 25.2c, includes all three corrections, as do all Tier 3 configurations presented here.

***2026(5) CPT.** Provide a model run with data only through 2019 to test whether the convergence problems stem from estimating recruitment following the population crash and the missing 2020 survey.*

This run is presented in Section F. [[PHASE 2: state whether truncating the data to 2019 removes the bimodality.]] The parameters most strongly correlated in the accepted model are also reported to help identify the source of the multiple optima.

***2026(6) SSC.** Bring forward only the Tier 4 model in October 2026 to allow time to develop a simpler, more stable Tier 3 model.*

We agree. The 2026 harvest specification is based on the Tier 4 calculation. The composition correction and the expanded plus group are retained, and a simplified Tier 3 model is under development for 2027 (Section F).

***2026(6) SSC.** A future Tier 3 model should include a focused convergence section (the parameters separating the jitter clouds, correlation diagnostics, and likelihood profiles for terminal MMB, recent recruitment, M, and OFL) and targeted simplification runs.*

Section F reports likelihood profiles for terminal MMB, recent recruitment, natural mortality, and the OFL; the parameter correlations; and a set of simplification runs (fixing the recruitment sex ratio at 50:50, reducing the confounding among growth, natural mortality, and selectivity, reducing the number of selectivity parameters, estimating growth externally, and starting the model from an earlier equilibrium year). The immature survey index is not treated as a fix for convergence.

***2026(6) SSC.** Include a yield-per-recruit analysis toward an alternative control rule, and a 'Rebuilding Analysis and Update' section given the 2021 overfished determination.*

A Rebuilding Analysis and Update is included. [[author: a yield-per-recruit analysis is provided in the Rebuilding section / was not completed this cycle and will be provided in a future assessment.]]

***2026(5) CPT.** Continue research on snow crab size-at-maturity, including female maturity in size bins beyond 55-65 mm and whether high exploitation of large males drives a decline in male size-at-maturity, drawing on parallels with eastern Canada.*

This research was presented by E. Ryznar (NOAA Fisheries) and is summarized in the Introduction. It is external to the assessment model. The simulation presented indicated that increased exploitation decreases the proportion of males maturing at industry-preferred size.

***2026 CPT/SSC.** The new maturity workflow (a Bernoulli likelihood per data point with bootstrapped uncertainty) is endorsed for both snow and Tanner crab. Differences in how the maturity ogives are used across the two assessments should be discussed at a future January Modeling Workshop, and the missing years in the new workflow resolved before the final assessment.*

The new maturity workflow is adopted as the base maturity input (Section C). [[PHASE 2: the missing years have been resolved / are being resolved before the final.]] We will participate in the January Modeling Workshop discussion of maturity ogive use across the two stocks.

***2026 CPT/SSC.** Provide a full risk table following the adopted crab Risk Table SOP as an appendix.*

A risk table following the adopted SOP is provided as Appendix B. It carries a Tier-1 historical buffer and a second row for current-year considerations, and, per the SOP, is prepared in coordination with the ESP author.

***2026 CPT/SSC.** Do not include hybrid catch or survey data in the snow crab (or Tanner crab) assessment models at this time; handle hybrid-related uncertainty through the ABC buffer, risk table, or TAC-setting process, and continue tracking hybrids in the survey technical memo.*

Hybrid catch and survey data are not included in the models presented here. Hybrid-related uncertainty is carried in the ABC buffer and risk table (Appendix B), and hybrid abundance and distribution continue to be tracked in the survey technical memo.

***2026 CPT/SSC.** Modernized genetic identification of hybrids is a high priority, along with alignment of hybrid classification across the ADF&G observer program, the bottom-trawl survey, and federal fishery data.*

We agree and have added these as research priorities (Section J). The value of resolving hybrid identification for the snow crab assessment depends on hybrid abundance, which remains low relative to snow crab.

***2026 CPT/SSC.** For September 2026, use the recruitment DSEM (dynamic structural equation modeling) approach for the snow crab ESP risk table indicator categorization, replacing Bayesian Adaptive Sampling (BBRKC and Tanner crab continue with Bayesian Adaptive Sampling); include plots of the correlation between survey data and estimated recruitment.*

The snow crab ESP applies the recruitment DSEM approach for indicator categorization this cycle, and the risk table (Appendix B) draws on the resulting categories. [[Coordinate with the ESP author (E. Fedewa); confirm the survey–recruitment correlation plots are included in the ESP.]]

***2026(5) CPT (all crab).** Report MMB for the just-completed fishing year for the models brought forward, for use in the stock-status table (MSST = 1/2 B_MSY), and provide stock projections for a range of F values.*

Terminal-year MMB and MSST are reported in the management table (Executive Summary). Projections over a range of F values are provided in the Projections section.
```

**Voice check:** responses open with the answer, use "we", carry no "Importantly/Additionally/Furthermore", and cross-reference the section that satisfies each request (as the guidelines ask). Comment quotes are condensed from the spreadsheet the way the existing Section B condenses SSC minutes.

---

## 15. Executive Summary items 5–7 wired to Tier 4 (compute-once design)

Ports GitHub exec-summary items 5–7 to the working copy and switches the harvest-spec basis to Tier 4. **Design rule: compute the six management quantities once; every section references the scalars.** This supersedes the minimal `tier4-vals` chunk in §13.

### 15a. Shared setup chunk (goes in the global setup chunk at the top of the Rmd, after `ABC_buffer` is set and `07_tier_4.R` output is available)

```{r tier4-setup, echo=FALSE}
## Single source of truth for the 2026 harvest specification (Tier 4, morphometric).
## Every downstream section (Exec Summary items 5-7, Section G, Status Determination,
## Rebuilding, Appendix B) reads THESE scalars — do not recompute elsewhere.

if (file.exists("Models/tier4_results.rds")) {            # [[VERIFY path from 07_tier_4.R]]
  tier4  <- readRDS("Models/tier4_results.rds")
  t4_rec <- tier4$by_currency[tier4$by_currency$currency == "morphometric", ]  # recommended
  bmsy_2026   <- t4_rec$Bmsy          # mean of REMA-smoothed series, 1982-2025
  mmb_2026    <- t4_rec$B_curr        # terminal-year REMA-smoothed morphometric MMB
  status_2026 <- t4_rec$status        # mmb_2026 / bmsy_2026 (for overfished determination)
  ofl_2026    <- t4_rec$OFL           # F=0.27 applied to mmb_2026 (flat, no kink)
} else {
  ## PHASE-1 stub so the document knits before the 2026 Tier-4 run exists.
  bmsy_2026 <- mmb_2026 <- status_2026 <- ofl_2026 <- NA_real_
}
msst_2026 <- 0.5 * bmsy_2026
abc_2026  <- ABC_buffer * ofl_2026    # ABC_buffer <- 0.8 (20% buffer; single global)
```

### 15b. Item 5 — Management table, terminal-row rewiring

The ported `management_table.csv` chunk keeps the historical rows; only the terminal `2025/2026` row changes from the GitHub Tier-3/projection wiring to the Tier-4 scalars. Morphometric is the primary table (the ≥95 mm table becomes a comparison, not the basis).

```r
## Replace the GitHub terminal-row block (which read the Tier-3 "Derived quatities"
## OFL and proj_mmb_under_ofl) with the shared Tier-4 scalars:
last <- nrow(PlotTab)
PlotTab[last, "MSST"]          <- round(msst_2026, 1)
PlotTab[last, "Biomass (MMB)"] <- round(mmb_2026, 1)   # terminal REMA-smoothed morphometric MMB
PlotTab[last, "OFL"]           <- round(ofl_2026, 2)
PlotTab[last, "ABC"]           <- round(abc_2026, 1)
## TAC / Retained / Total catch: fill the 2025/26 observed removals from ADF&G as before.
## Do NOT use proj_mmb_under_ofl (a Tier-3 model projection; undefined for Tier 4).
```

Caption footnote changes to: *"Terminal-year MMB is the REMA-smoothed survey morphometrically mature male biomass; OFL and ABC are the Tier 4 specification."* (The management time series carries the 2024/2025 rows, which satisfies the guideline requirement to compare with last year — no separate two-column table needed.)

### 15c. Item 6 — Basis for the OFL (prose + table)

```markdown
6.  Basis for the OFL

The 2026 overfishing level is calculated under Tier 4, following the June 2026 SSC
recommendation to bring forward the Tier 4 model while a simpler Tier 3 model is
developed. The OFL is obtained by applying the target fishing mortality (F = 0.27, the
median of the prior on natural mortality) to the REMA-smoothed survey biomass; a constant
F is applied with no control-rule reduction, and status is used for the overfished
determination rather than to scale F. The recommended currency is morphometrically mature
male biomass; the OFL is also reported for male biomass greater than 95 mm and greater
than 101 mm carapace width (Table \@ref(tab:tier4)). The developing Tier 3 model (Model
26.1) is summarized in Section G for comparison.

The recommended 2026 OFL is `r round(ofl_2026, 2)` kt, at a stock status of
`r round(status_2026, 2)` relative to the B_MSY proxy.
```

The three-currency table is the `tier4-ofl` chunk from §13 (morphometric flagged recommended) — reference it here rather than duplicating it.

### 15d. Item 7 — Basis for the ABC

```markdown
7.  Basis for the ABC

The ABC is the OFL reduced by a buffer for scientific uncertainty, following the crab
Risk Table SOP (Appendix B). A `r round(100 * (1 - ABC_buffer))`% buffer is applied, giving an ABC of
`r round(abc_2026, 2)` kt. [[The buffer is a working value; the Tier-1 historical buffer
in Appendix B (average of the previous five assessments) may revise it — the number here
follows ABC_buffer so it updates automatically.]]
```

### 15e. Consistency map (what reads the shared scalars)

| Scalar (set in 15a) | Feeds |
|---|---|
| `bmsy_2026` | Item 6 status text; Rebuilding (B_MSY); Appendix B; Section G |
| `mmb_2026` | Item 5 terminal MMB; Status Determination; Rebuilding |
| `msst_2026` | Item 5 MSST; Status Determination (overfished test) |
| `status_2026` | Item 6 status text; Status Determination |
| `ofl_2026` | Item 5 OFL; Item 6; Section G Tier-4 table |
| `abc_2026` | Item 5 ABC; Item 7; Appendix B buffer justification |

Anything that needs a currency other than morphometric (the ≥95 mm / >101 mm comparison) reads `tier4$by_currency` directly, not these scalars.

---

## 16. `# Appendix B. Risk table` (built out — supersedes the plan §6 scaffold)

Implements the adopted Crab Risk Table SOP (2026 CPT/SSC, spreadsheet row 423): a two-tier table (Tier 1 = persistent historical buffer, seeded at the average of the previous five assessments; Tier 2 = current-year considerations, scored across the four groundfish-consistent categories), **no** prescriptive score→buffer formula, prepared in coordination with the ESP author. The computed Tier-1 value is surfaced so the buffer can be settled against the current 20% placeholder.

### 16a. Prose (opening)

```markdown
# Appendix B. Risk table

The acceptable biological catch is set by reducing the OFL by a buffer for scientific
uncertainty. Following the crab Risk Table standard operating procedure adopted by the
CPT and SSC for September 2026, the buffer is organized in two tiers. Tier 1 is a
persistent buffer reflecting long-term considerations for this stock, carried forward
annually and seeded at the average buffer applied over the previous five assessments.
Tier 2 evaluates current-year uncertainties not already captured by the assessment
model, the tier level, or the harvest control rule, and is used only when an additional
buffer is warranted. No formula links the tier scores to the buffer; the categories and
scoring are consistent with the groundfish risk table. The table is prepared in
coordination with the snow crab ESP author.
```

### 16b. Tier-1 historical buffer (computed, editable)

```{r risk-hist-buffer, echo=FALSE}
## Tier-1 historical buffer = mean of the previous five assessments' SSC-ADOPTED ABC
## buffers (SOP row 423). Editable so the author can correct values / period.
## [[RECONCILE: the 2025 FINAL applied 20% (author-recommended); the SSC-ADOPTED buffer
##   was 25% — the SOP uses the adopted value, so 0.25 is entered for 2025. Confirm.]]
## [[GAP: 2022 buffer unavailable (fishery closed; SSC report not online), so the five
##   most recent AVAILABLE assessment years are used. Confirm this is the intended set.]]
buffer_history <- data.frame(
  Year   = c(2020, 2021, 2023, 2024, 2025),
  Buffer = c(0.25, 0.25, 0.50, 0.65, 0.25)   # SSC-adopted fractions
)
hist_buffer <- mean(buffer_history$Buffer)    # = 0.38
```

```markdown
The average buffer over the previous five assessments is
`r paste0(round(100 * hist_buffer), "%")` (2020–2025, excluding 2022 for which no
buffer is available). This is the Tier-1 historical buffer.
```

### 16c. The two-tier table

```{r risk-table, echo=FALSE}
## Levels are author judgment (Level 1 = no increased concern; Level 2 = increased
## concern; Level 3 = major concern), consistent with the groundfish risk table.
## Fill the [[Level n]] cells once the ESP/current-year review is complete.
risk <- data.frame(
  Tier = c("Tier 1 — historical",
           "Tier 2 — current year", "Tier 2 — current year",
           "Tier 2 — current year", "Tier 2 — current year"),
  Category = c("Persistent buffer",
               "Assessment", "Population dynamics",
               "Environmental / ecosystem", "Fishery performance"),
  Level = c(paste0(round(100 * hist_buffer), "% buffer"),
            "[[Level 1?]]", "Level 1", "Level 1", "Level 1"),   # ESP scores pop-dyn/eco/fishery = Level 1 (Normal); Assessment row is author judgment
  Consideration = c(
    paste0("Average buffer of the previous five assessments (",
           paste0(round(100 * hist_buffer), "%"),
           "). Reflects persistent considerations: recurrent convergence/bimodality in the ",
           "Tier 3 model, the morphometric-vs-≥95 mm currency question, and ",
           "retrospective / model-misspecification uncertainty."),
    paste0("The Tier 3 model's convergence and bimodality are largely addressed by ",
           "specifying on the Tier 4 fallback this year; to avoid double-counting, only ",
           "residual current-year assessment uncertainty is scored here."),
    paste0("ESP population-dynamics indicators are favorable in 2026 (Level 1): juvenile ",
           "energetic condition remains elevated above lab-derived starvation thresholds, ",
           "occupied temperatures were sub-zero (favorable for survival and recruitment), and ",
           "record-high mature female abundance with ~97% full clutches indicates high ",
           "reproductive potential despite low large-male abundance. DSEM-supported recruitment ",
           "drivers (sea ice, energetic condition, cold-water habitat, occupied temperature) are ",
           "all favorable (ESP, Fedewa et al. 2026). The stock remains overfished and under ",
           "rebuilding, which is captured by the status and tier rather than an added buffer."),
    paste0("ESP/ESR ecosystem indicators are favorable in 2026 (Level 1): cool thermal ",
           "conditions with an extensive summer cold pool and above-average spring sea ice, ",
           "favorable feeding conditions for pelagic and benthic stages, and low competition for ",
           "prey (competition for space remains high). Indicators were categorized this cycle ",
           "with the recruitment DSEM approach, replacing Bayesian Adaptive Sampling ",
           "(ESP, Fedewa et al. 2026; ESR, Siddon 2026 in press)."),
    paste0("ESP fishery indicators are near normal in 2026 (Level 1): retained CPUE declined ",
           "(219 to 147 crab per potlift, below the long-term average) while effort rose; the ",
           "fishing distribution shifted south; about 50% of surveyed skippers reported over 10% ",
           "more industry-preferred males and about 47% noted more hybrid crab, with confidence ",
           "in sorting (ESP, Fedewa et al. 2026; ABSC Skipper Survey). Hybrid catch is retained ",
           "under the snow-crab IFQ and cannot yet be separated; hybrid-related uncertainty is ",
           "carried here rather than in the model, and its direction is not predetermined.")
  )
)
flextable::flextable(risk) |>
  flextable::merge_v(j = "Tier") |>
  flextable::autofit() |>
  flextable::set_caption(
    caption = "Appendix B. Snow crab risk table (adopted Crab Risk Table SOP). Tier 1 is
      the persistent historical buffer; Tier 2 lists current-year considerations by
      category. No formula links the scores to the buffer.",
    autonum = officer::run_autonum(seq_id = "tab", pre_label = "Table ", bkm = "risktable"))
```

### 16d. Recommended buffer + wiring note

```markdown
The recommended buffer for 2026 is `r paste0(round(100 * (1 - ABC_buffer)), "%")`. The ESP
scores all current-year (Tier 2) categories at Level 1 (Normal), so no additional current-year
buffer is indicated; the buffer therefore rests on the Tier-1 historical value.
[[DECISION: `ABC_buffer` (set in the global config, currently 0.8 = 20%) is the single
applied buffer that feeds the ABC in the Executive Summary, the management table, and
Section H. The Tier-1 historical buffer computed above is
`r paste0(round(100 * hist_buffer), "%")`. Reconcile the two: to adopt the SOP Tier-1
value set `ABC_buffer <- round(1 - hist_buffer, 2)` in the config; to keep 20% for now,
leave `ABC_buffer <- 0.8` and state the rationale for departing from the historical
average here. Any Tier-2 adjustment is applied by author judgment, not by formula.]]
```

**Design notes.** The buffer stays single-sourced in `ABC_buffer` (global config), so item 7, the management table, and this appendix never disagree; this chunk *justifies* and *displays* it and computes the SOP alternative (`hist_buffer`) beside it. Two data issues are surfaced, not hidden: the 20%-vs-25% 2025 value and the missing 2022 year — both change `hist_buffer`, so they are editable in `buffer_history`. The Assessment row explicitly avoids double-counting the convergence concern already captured by moving to Tier 4. Hybrid uncertainty is stated as bidirectional, per the SOP's caution against a predetermined direction.

---

## 17. `# Projections` (scaffold — closes the "Projections section" the drafts reference)

Referenced by §6 (Rebuilding trajectory), §8 (Status determination Q3), and §14 (all-crab row 412: "projections over a range of F"). Inherently Phase 2 — projections come from the GMACS projection module of the **developing Tier 3 model (26.1)**, not from Tier 4. Port the GitHub base's projection machinery (`do_proj`/`proj_dir`/`mcoutPROJSSB.REP`, currently `do_proj=0` in the working copy) and run it across a range of F.

**Interpretation caveat to state in the prose:** the 2026 specification is Tier 4, but the standard forward projections (for the overfished/approaching determination and the rebuilding trajectory) are produced by the Tier 3 model. Present them as model-based context, and note that Tier-4 status (§8 Q1/Q2) is determined from the survey-based `status_2026`, not from these projections.

```markdown
# Projections

Projections were produced with the developing Tier 3 model (Model 25.2e (new data)) to characterize
the stock's trajectory under a range of fishing mortality rates (per the May 2026 CPT
request). The 2026 harvest specification is set under Tier 4 (Section G); these
projections provide model-based context for the rebuilding outlook and the
approaching-overfished determination, and are not the basis of the specification.
```

```{r projections-Frange, echo=FALSE, eval=FALSE, fig.cap="Projected MMB (Model 25.2e (new data)) under a range of fixed F, with F=0 and F=F_OFL highlighted."}
## PHASE 2 — port the GitHub do_proj block (proj_dir -> mcoutPROJSSB.REP), then loop
## over an F grid (e.g. seq(0, F_OFL, length.out = k) plus F=0 and F=F_OFL).
## Outputs feed: §6 rebuilding trajectory, §8 status-determination Q3.
## [[VERIFY the .PROJ workflow / projection file paths for 26.1 in the repo.]]
## F_OFL_t3 is the Tier-3 (Model 25.2e (new data)) F_OFL from the projection module — NOT the
## Tier-4 target F (0.27). [[define F_OFL_t3 from the 26.1 projection output.]]
F_grid <- c(0, seq(0, F_OFL_t3, length.out = 6), F_OFL_t3)   # F=0 and F_OFL highlighted
# ...run projection per F, collect median projected MMB by year...
```

**Guideline note:** the AFSC groundfish 7-scenario spmR set is **not** used for crab (plan §4 [N/A]); this range-of-F projection plus the F=0 and F=F_OFL cases covers the crab overfished/approaching tests.

---

## 18. `# Appendix C. Description of the assessment model` (equations)

Data-independent. **These equations were reconciled against the R reimplementation of the assessment (`gmacs_model_r.R` in the `snow_crab` repo), which reproduces the ADMB objective function** for `25_gmacs_update_plus_group`. Model 25.2c shares this structure, differing only in the maturity-ogive input ($\Theta$) and the corrected composition data — so these equations apply to the September model. `[[add formal GMACS citation]]`. Equations render in PDF; check the Word (officedown) output renders the `aligned` blocks acceptably and simplify any that do not.

```markdown
# Appendix C. Description of the assessment model

The assessment is implemented in the Generalized Model for Assessing Crustacean Stocks
(GMACS), an integrated, size-structured model fit by maximum likelihood in AD Model
Builder. This appendix gives the population dynamics and observation model as configured
for eastern Bering Sea snow crab; the complete GMACS specification is in the GMACS
documentation (GMACS-project). Notation is defined in Table C-1.

## C.1 Structure and seasonal sequence

The model tracks numbers of crab $N_{s,m,y,\ell}$ by sex $s$ (male, female), maturity
state $m$ (immature, mature), year $y$, and carapace-width class $\ell$. Size classes span
27.5–132.5 mm in 5-mm bins ($n_\ell = 22$; the terminal class is a plus group). The crab
year is divided into three seasons, and a fixed fraction $\kappa = (0.62, 0.01, 0.37)$ of
annual natural mortality is applied in each. Events occur in the following order: in season
1 the summer survey is observed and season-1 natural mortality is applied; in season 2 the
fisheries operate (continuous fishing mortality) with season-2 natural mortality; in season
3 season-3 natural mortality is applied, immature crab molt and grow (with terminal molt to
maturity), and recruitment enters. Spawning biomass, growth, and recruitment are evaluated
in season 3.

## C.2 Recruitment

Total annual recruitment enters as immature crab:
$$ R_y = 2\,\bar{R}\,e^{\varepsilon_y}, \qquad \varepsilon_y \sim N(0,\sigma_R^2) $$
and is split between sexes each year through a logistic parameter:
$$ \pi_y = \frac{1}{1+e^{-\zeta_y}}, \qquad R^{m}_y = \pi_y R_y, \quad R^{f}_y = (1-\pi_y)R_y $$
Recruits are distributed over the first three size classes with proportions $p_\ell$ from a
gamma distribution (parameters $r_a, r_b$), normalized to sum to one. The year-specific
sex-ratio parameters $\zeta_y$ are the parameters the SSC recommends fixing at $\pi = 0.5$
(Section F).

## C.3 Growth and terminal molt

All immature crab molt each year; mature crab do not molt or grow (terminal molt). The molt
increment is a declining linear function of pre-molt width $x_{\ell'}$, so mean post-molt
width is
$$ \bar{\ell}\,(x_{\ell'}) = x_{\ell'} + \big(\alpha_s - \beta_s\,x_{\ell'}\big) $$
Post-molt size follows a gamma distribution with scale $g_s$ and shape
$\bar{\ell}/g_s$, integrated over the size bins to give the (upper-triangular) growth-
transition matrix $\mathbf{G}_s$ with elements $G_{s,\ell'\to\ell}$. The parameters
$(\alpha_s,\beta_s,g_s)$ are estimated by sex and fit to the molt-increment data.

At its molt, an immature crab of post-molt size $\ell$ undergoes terminal molt to maturity
with probability $\Theta_{s,y,\ell}$, the year- and size-varying probability of terminal
molt supplied as input (the new maturity workflow; Section C).

## C.4 Natural mortality

Mature natural mortality is estimated by sex, $M^{mat}_{s}$; immature mortality is a
log-scale offset, $M^{imm}_{s} = M^{mat}_{s}\,e^{o_s}$. Year-specific deviations apply in
the block years $b \in \{2018, 2019, 2020\}$:
$$ M_{s,m,y} = M_{s,m}\,\exp(\delta_{s,m,y}), \qquad \delta_{s,m,y}=0 \text{ unless } y \in b $$
$M^{mat}_{s}$ is subject to an informative prior based on an assumed longevity of 20 years
(Section D). (The 2018 and 2019 mortality events are emphasized in the main text; the model
defines a 2020 block as well.)

## C.5 Fishing mortality, selectivity, and removals

Fishing mortality for fleet $f$ (directed pot; trawl bycatch) is
$F_{f,y} = \exp(\bar{F}_f + \phi_{f,y})$, with a sex offset for the pot fishery. Fishery and
retention selectivities are logistic in size,
$$ S_{f,s}(\ell) = \frac{1}{1+\exp\!\big(-(x_\ell-\mu_{f,s})/\sigma_{f,s}\big)}, \qquad \mu=e^{\theta_1},\ \sigma=e^{\theta_2} $$
Survey selectivity is estimated as a free value per size class within era (1982–1988;
1989–present) and sex, $S^{surv}_{s}(\ell)=\exp(\eta_{s,\ell})$, subject to a smoothness
penalty and to normal priors from the BSFRF selectivity experiments (Section E). All
non-directed bycatch is combined into a single trawl fishery.

Pot-fishery vulnerability combines capture selectivity, retention $r(\ell)$, and the pot
discard-mortality rate $\xi_{pot}=0.3$; trawl vulnerability applies the trawl discard-
mortality rate $\xi_{trawl}=1.0$:
$$ V^{pot}_{s}(\ell)=S^{pot}_{s}(\ell)\big[r(\ell)+(1-r(\ell))\,\xi_{pot}\big], \qquad V^{trawl}_{s}(\ell)=S^{trawl}_{s}(\ell)\,\xi_{trawl} $$
Season-2 total mortality and Baranov catch-at-size are
$$ Z_{s,m,y,\ell}=\kappa_2 M_{s,m,y}+\sum_f F_{f,y}V_{f,s}(\ell), \qquad
C_{f,s,m,y,\ell}=\frac{F_{f,y}\,S_{f,s}(\ell)}{Z_{s,m,y,\ell}}\big(1-e^{-Z_{s,m,y,\ell}}\big)N_{s,m,y,\ell} $$
Retained catch uses $S^{pot}_s r$; pot discards use $S^{pot}_s(1-r)$.

## C.6 Numbers-at-length update

Let $\tilde{N}$ denote season-3 survivors (after all three seasons of natural mortality and
season-2 fishing). Surviving immature crab molt via $\mathbf{G}_s$ and either mature (via
$\Theta$) or remain immature; surviving mature crab are carried forward at size:
$$
\begin{aligned}
N^{imm}_{s,y+1,\ell} &= \sum_{\ell'} G_{s,\ell'\to\ell}\,\big(1-\Theta_{s,y,\ell}\big)\,\tilde{N}^{imm}_{s,y,\ell'} \;+\; R^{s}_{y+1}\,p_\ell \\[1ex]
N^{mat}_{s,y+1,\ell} &= \tilde{N}^{mat}_{s,y,\ell} \;+\; \sum_{\ell'} G_{s,\ell'\to\ell}\,\Theta_{s,y,\ell}\,\tilde{N}^{imm}_{s,y,\ell'}
\end{aligned}
$$
Numbers-at-size in the first year (1982) are estimated for each sex $\times$ maturity group
under a smoothness penalty; this initialization is one target of the simplification runs
discussed in Section F.

## C.7 Observation model

Weight-at-size $w_{s,\ell}$ is specified by sex (allometric). Predicted survey biomass
applies survey selectivity to the season-1 snapshot:
$$ \hat{I}_{y} = \sum_{\ell} S^{surv}_{s}(\ell)\,N_{s,m,y,\ell}\,w_{s,\ell} $$
Predicted fleet catch biomass is $\hat{C}_{f,y}=\sum_{s,m,\ell} C_{f,s,m,y,\ell}\,w_{s,\ell}$.
Predicted size compositions are the corresponding survey or catch numbers-at-size
normalized within each data block.

## C.8 Objective function

Parameters are estimated by minimizing the total negative log-likelihood, the sum of:

- **Index** (lognormal): $\tfrac{1}{2}(\log(I_y/\hat I_y)/s_y)^2 + \log s_y$, with
  $s_y^2=\log(1+cv_y^2)+\log(1+cv_{\text{add}}^2)$ and $cv_{\text{add}}\approx 10^{-4}$.
- **Catch** (lognormal): as above with $s=\sqrt{\log(1+cv^2)}$.
- **Size compositions**: the robust (Fournier) approximation to the multinomial, evaluated
  at the input sample sizes; no compositional reweighting is applied.
- **Growth** (lognormal): on the observed vs. predicted molt increment $\alpha_s-\beta_s x$.
- **Recruitment** (autoregressive): with $r_1=\varepsilon_1+\sigma_R^2/2$ and
  $r_y=\varepsilon_y-\rho\,\varepsilon_{y-1}+\sigma_R^2/2$, evaluated under a normal density
  with standard deviation $\sigma_R$; plus a normal prior on the logit sex-ratio deviations.
- **Penalties**: recruitment first-difference smoothness (weight 1), recruitment sex-ratio
  (weight 3), survey-selectivity smoothness (weight 3), and initial-numbers smoothness
  (weight 5).
- **Parameter priors**: on $\log\bar R$, initial numbers, growth, $M$, and selectivity.

Table C-1. Notation. `[[render as a table]]`

| Symbol | Definition |
|---|---|
| $s, m, y, \ell$ | sex; maturity state; year; carapace-width class (22 classes, 27.5–132.5 mm) |
| $N_{s,m,y,\ell}$ | numbers at size; $\tilde N$ = season-3 survivors |
| $\kappa=(0.62,0.01,0.37)$ | fraction of annual $M$ applied in seasons 1–3 |
| $R_y,\ \bar R,\ \varepsilon_y,\ \rho$ | total recruitment; mean; deviation; AR(1) coefficient |
| $\pi_y,\ \zeta_y$ | recruitment fraction male; its logit parameter (per year) |
| $p_\ell,\ (r_a,r_b)$ | recruit size distribution (gamma, first 3 classes) |
| $\alpha_s,\beta_s,g_s$ | growth increment intercept, slope; gamma scale |
| $G_{s,\ell'\to\ell}$ | growth-transition probability |
| $\Theta_{s,y,\ell}$ | probability of terminal molt at size (input) |
| $M^{mat}_s,\ o_s,\ \delta_{s,m,y}$ | mature $M$; immature log-offset; block deviation (2018–2020) |
| $F_{f,y},\ S_{f,s}(\ell),\ r(\ell)$ | fishing mortality; selectivity; retention |
| $\xi_{pot}=0.3,\ \xi_{trawl}=1.0$ | discard-mortality rates |
| $V_{f,s}(\ell),\ Z$ | vulnerability; total mortality |
| $S^{surv}_s(\ell),\ w_{s,\ell}$ | survey selectivity; weight-at-size |
```

**Handoff/outline note:** this is **Appendix C**. Add it to the canonical outline after Appendix B, and add `# Appendix C. Description of the assessment model` as a Phase-1 (data-independent) drafting task. It complements — does not replace — the narrative Model description in Section F. Provenance: equations reconciled against `snow_crab/gmacs_model_r.R` (reproduces the ADMB objective for `25_gmacs_update_plus_group`).
