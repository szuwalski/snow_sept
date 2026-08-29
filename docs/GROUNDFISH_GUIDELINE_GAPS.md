# Groundfish guideline gaps — September 2026 snow crab SAFE

> **Status, 2026-08-29.** Tiers A and B are complete. Tier C is complete except
> where the source genuinely does not exist: the non-commercial removals table
> (no such data anywhere in the repo) and maxABC (the maximum permissible buffer
> for a Tier 4 crab stock is not in `Reports/`). Both carry markers rather than
> invented content.
>
> The October 2025 SSC report closed items 9, 10 (partly) and the buffer
> `[[VERIFY]]`, and produced one finding that was not anticipated: **the SSC
> applied the sloped control rule, not flat F = M**, and a **40 percent** ABC
> buffer. See §4, Tier C. The ESP/ESR risk table summary closed item 11.

Sources, both added to `Reports/` on 2026-08-29:

- `2026-04_guidelines_groundfish_assessment.pdf` — AFSC, April 2026, 32 pp.
- `2026_checklist_internal_SAFE_review.pdf` — the internal reviewer's form.

These are groundfish documents. Crab has its own FMP and its own SAFE guidelines, so
not everything transfers. What follows is what applies to a **Tier 4 crab assessment**
and is **not already** covered by `2026-08_checklist_crab_SAFE_review.pdf` or the
`General Reminders`. Items already known from the crab checklist are in
`docs/SESSION_HANDOFF.md`, not repeated here.

Section numbers below are the groundfish guidelines' own.

---

## 1. New requirements this document does not meet

### 1a. Title page — citation and disclaimer (§4.1)

Two elements, neither present. The guidelines give the exact wording:

> This report may be cited as: Authors., Year. Title. North Pacific Fishery Management
> Council, Anchorage, AK. Available from https://www.npfmc.org/library/safe-reports/

and, **required on drafts**:

> This information is distributed solely for the purpose of pre-dissemination peer
> review under applicable information quality guidelines. It has not been formally
> disseminated by the National Marine Fisheries Service and should not be construed to
> represent any agency determination or policy.

The second matters: this document circulates to the CPT and SSC before formal
dissemination, which is exactly the case the disclaimer exists for.

### 1b. Acknowledgements section (§4.18)

Absent entirely. Wants reviewers and affiliations, plus names and affiliations of
people who contributed data, advice or information without being on the assessment
team. For this cycle that plausibly includes the Kodiak lab (maturity workflow), ADF&G
(removals, hybrid identification), and the crabpack/GMACS maintainers.

### 1c. Auxiliary Files list (§4.20)

Absent. Wants a list *naming* the parameter and data/input files in the assessment
program's native code, the model executable, and any other electronic files archived
with the document. `Supplemental information` currently gives three GitHub URLs, which
is not the same thing.

### 1d. Status determination statement (§4.14)

Absent — no sentence in the document answers it. The determination is made by
**comparing the catch from the most recent complete year to the OFL specified for that
year**, and applies to Tiers 1–5, so it applies here. Both source documents also
require the overfished statement explicitly; groundfish scopes that to Tiers 1–3, but
the crab checklist does not, and this stock is in a rebuilding plan, so it belongs
regardless.

We have both numbers: 2025/26 retained catch 4.13 kt against the OFL specified for
that year. **The OFL actually specified for 2025/26 is not yet stated anywhere in this
repo** — it needs to come from the October 2025 SSC report, which is the same missing
source as the 2025 ABC buffer (see `[[VERIFY]]` in Section G).

### 1e. F_limit (§4.15)

For Tiers 4–5 this is simply **M** — "the weighted average estimate of M" for a
complex, M itself for a single stock. One sentence, and we have M = 0.27 yr^-1. Note
this is a *different* quantity from the reverse-engineered F that Tiers 1–3 report;
don't compute the Tier 3 version.

### 1f. maxABC (§4.11.2)

Absent. Both this and the crab checklist require the **maximum permissible ABC** to be
reported regardless of what the author recommends, with its calculation described. The
document currently reports only the recommended ABC at a 20% buffer.

### 1g. Biomass uncertainty for the harvest control rule (§4.11.2) — the substantive one

> For stocks managed under Tiers 4-5, in addition to estimates of stock size based on
> last year's estimation procedure, include stock size estimates using the random
> effects model code provided in the rema R package. Also, **for the biomass estimate
> used in the harvest control rule, include at least one measure of uncertainty** such
> as standard error, CV, or 95% confidence interval. **Document how this measure of
> uncertainty is calculated.**

We already use `rema`, so the fit is right. But `07_calc_tier4.R:329` keeps only
`pred$pred` and drops the interval columns `tidy_rema()` returns, so
`data/tier4/rema_predictions.csv` has no uncertainty at all — and the entire Tier 4
OFL rests on that single terminal-year number (B_curr = 113.94 kt on the morphometric
currency).

This is the one item that requires a **script change and a re-run**. See §3.

### 1h. Risk table (§4.12)

Four categories, each with a stated risk level and supporting evidence, plus a summary
table of scores and an explanation of whether the scores support reducing the ABC below
maximum permissible. The template itself lives in the SAFE Introduction document, which
is **not in `Reports/`** — it needs to be obtained.

The June 2026 SSC has already said what it expects for crab: categories consistent with
groundfish, a tiered structure (Tier 1 = persistent/long-term uncertainty, assessment
and population-dynamics categories only, justifying a base/historical buffer; Tier 2 =
year-specific risk, for rare cases needing an additional buffer), coordination with
Ecosystem Status Report and ESP staff, and a **draft risk table this fall**.

### 1i. Appendix of non-commercial catches (§4.23)

Described as "the required appendix of non-commercial catches". Absent.

---

## 2. Requirements we partly meet, where the guidelines sharpen what is needed

### 2a. Convergence (§4.9.5) — we are ahead of this, and should say so

The guidelines specifically endorse the approach already taken:

> Use Newton steps with the inverse Hessian to reduce maxgrad<1e-5. … This can be
> invoked in bespoke ADMB and SS3 models by calling '-hess_step' … It thus serves as
> **stronger evidence of convergence** compared to a maximum gradient or invertible
> Hessian. … It is not expected to change the estimates or uncertainties calculated,
> and also fails to diagnose a local minimum.

Every model that can be polished now reports a maximum gradient of zero, which clears
the 1e-5 bar by a wide margin. **State the criterion and the result explicitly** — the
document currently reports gradients without naming the standard they are being judged
against.

Two things follow that we do *not* currently do:

1. **"Indicate whether any parameters were inestimable or hit pre-specified bounds."**
   We know `M_pars_est[15]` runs away to its bound in the inferior optima
   (`docs/CLEANUP_BACKLOG.md` item 5b). That is exactly this disclosure and it is
   undocumented in the SAFE.
2. The guidelines' framing of jitter is cleaner than ours: *"Models that do converge
   must be at the base model MLE as there would never be a better solution than at the
   MLE. Models that fail to return to the MLE are not useful for statistical
   inference."* Our multimodality discussion should be re-framed against that standard —
   it makes the 5.1%-return-rate finding sharper, not softer.

### 2b. Historical retrospective (§4.9.8) — already computed, never wired in

> Provide a figure comparing the time series of biomass from the last several
> assessments accepted for management and the proposed base model, **with uncertainty
> intervals**. Provide a brief summary of how the current assessment compares to the
> historical perception of the stock, **and the cause of any obvious differences**.

`06b_plot_historical_bias.R` already does this and both outputs exist
(`plots/historical_est.png`, `plots/historical_mating_mmb_est.png`), reading
`data/historical/historical_mmb_{at_survey,mating}_by_assessment.csv`. Neither is
referenced anywhere in the Rmd. This is a **wiring job plus narrative**, not new
analysis — the cheapest large gap on the list.

Missing relative to the guideline: uncertainty intervals on the vintages, and the
"cause of any obvious differences" text. The script's own header already records a
worked example (the 2020 assessment's 486.5 against the 2021 assessment's 40.95 for the
same year, a 92% revision) that belongs in that narrative.

### 2c. Parameters estimated independently (§4.10)

For Tiers 4–6, list the parameters estimated *outside* the assessment and how, with the
note that the method need not be statistical — citing a published value is acceptable.
For the Tier 4 basis that means at minimum M = 0.27 (prior median), the maturity ogive
(Kodiak `sdmTMB` workflow), growth, and weight-at-length. The document mentions this
once in passing and does not present it as a list.

---

## 3. Model numbering — informational only, not a proposal to renumber

The numbering was settled with the Plan Team and is **not reopened here**. Recording
the convention only because it gives an objective justification if one is ever asked
for.

§4.8.2 Option A defines an *average difference in spawning biomass* (ADSB) between the
candidate and the original base model, both run with data through the base model's
introduction year: ADSB < 0.1 makes it a minor change (`Model yy.jx`), ADSB >= 0.1 a
major one (`Model zz.i`). Directly relevant clause: **"For Tiers 4-5, survey biomass
may be used in place of spawning biomass in the above."**

---

## 4. Sequencing

Grouped by what blocks each item, not by importance.

### Tier A — no decision, no re-run, no new analysis

Can be done immediately and none of it depends on the currency or control-rule
decisions.

| # | Item | Where |
|---|---|---|
| 1 | Citation block and pre-dissemination disclaimer | title page (§1a) |
| 2 | Acknowledgements section | new, before Literature cited (§1b) |
| 3 | Auxiliary Files list | extend `Supplemental information` (§1c) |
| 4 | F_limit = M statement | Section F (§1e) |
| 5 | Parameters-estimated-independently list | Section F, Tier 4 (§2c) |
| 6 | Convergence criterion named; bounds/inestimable disclosure; jitter re-framed | Section E, Results (§2a) |
| 7 | Historical retrospective wired in + narrative | Section E, Results (§2b) |

Item 7 is the largest of these and the highest value — it closes a checklist gap that
has been open since the 2025 cycle, using analysis that already exists.

### Tier B — needs a script change and a re-run

| # | Item | Blocker |
|---|---|---|
| 8 | REMA uncertainty carried through to the CSV and reported | `07_calc_tier4.R:329` keeps only `pred$pred`; fix is small, but **re-running `07` re-pulls crabpack and overwrites `data/tier4/`**, and `07` carries a hardcoded year range that must be advanced with `02` (CLAUDE.md, Known traps). Confirm before running. |

Fix shape: keep `pred_lci`/`pred_uci` (and the log-scale SD if `tidy_rema()` returns it)
in the `rema` data frame, add the terminal-year interval to `tier4_by_currency.csv`, and
document in the SAFE that the interval is REMA's process-error-based prediction interval
on the smoothed series — *not* the survey's own sampling CV, which is an input to the
fit. Those are different quantities and conflating them would misstate the uncertainty
on the OFL.

### Tier C — needs a source we do not have

| # | Item | Missing source |
|---|---|---|
| 9 | Status determination (overfishing) | the OFL **specified** for 2025/26 — October 2025 SSC report, not in `Reports/` |
| 10 | maxABC | the maximum permissible buffer basis for a Tier 4 crab stock |
| 11 | Risk table | the SAFE Introduction risk-table template, not in `Reports/` |
| 12 | Non-commercial catches appendix | scope needs confirming against what `01_prep_fishery_data.R` already pulls |

Items 9 and 10 share a source with the `[[VERIFY]]` already standing in Section G on the
2025 ABC buffer. **One retrieval closes three gaps** — worth doing first in this tier.

### Tier D — blocked on decisions that are the author's

Not new from these documents, listed so the sequencing is complete: the currency, the
flat-versus-sloped control rule, and which Tier 4 configuration becomes the October
management model. The Executive Summary tables (crab checklist items 6 and 7) cannot be
finalised until the currency is fixed, because every number in them changes with it.

---

## 5. What these documents did *not* add

Worth recording so the same ground is not re-covered:

- **13-year projections and standard harvest scenarios** (§4.11.3) are Tiers 1–3 only.
- **Overfished and approaching-overfished statements** are scoped to Tiers 1–3 in the
  groundfish guidelines. They stay on our list because the *crab* checklist requires
  them and the stock is in a rebuilding plan — not because of these documents.
- Most of the Quick Start Checklist's Results block (numbers-at-age, conditional
  age-at-length, stock-recruit fits) is Tiers 1–3 and does not apply to the Tier 4
  basis, though much of it remains relevant to the Tier 3 models presented for progress.
