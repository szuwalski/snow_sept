# September 2026 EBS snow crab SAFE — build plan & gap review (v3)

**For:** Claude Code working in `snow_sept/`
**Supersedes:** v1 (`GUIDELINES_GAP_REVIEW.md`) and v2. v3 folds in an adversarial review that corrected two of the author's own earlier claims — see §0.
**Inputs reconciled:** `SAFE_snow_gmacs.Rmd` (working copy) · GitHub `szuwalski/snow_sept@main/SAFE_snow_gmacs.Rmd` (canonical Sept 2025 final) · `NOAA/Guidelines/2026_Stock Assessment Guidelines.docx` · `AssessmentRequestsFromPlanTeams_SSC_ToShare.xlsx`
**Date:** 2026-07-30

---

## 0. Adversarial-review corrections (read first)

Two claims in v1/v2 were wrong and have been fixed here:

1. **The base is NOT a "clean architecture swap."** The GitHub Sept-2025 final Rmd carries legacy `gmr`/`gmacsr` plumbing (it `source.all()`s Cody's local gmr/gmacsr, builds `M <- lapply(fn, read_admb)`, uses `mod_names`/`M[[chosen_ind]]`, and reads `Gmacsall.out` directly in many chunks). The working copy **deliberately removed** all of this when it ported to the portable `reslst`/`wtsGMACS` architecture. **Decision made:** the **working copy is the technical base**; port the *content* of the missing sections from the GitHub final into it. This still produces "a modified version of the GitHub Rmd" in content and outline, without re-introducing legacy plumbing.

2. **There is no "10× OFL scale error / units bug."** The GitHub 3.26 kt OFL is the **≥95 mm** currency; the working copy's 36–60 kt is the **morphometric** currency — and GitHub's *own* morphometric Tier-3 OFL reaches **44.29 kt** (same order of magnitude). B<sub>MSY</sub> is **not** discrepant either (GitHub implied B<sub>MSY</sub> ≈ 160.8/0.89 ≈ 181 kt sits inside the working copy's 168–185 kt range). The real, narrower points survive — see the corrected box in §1.

Also corrected: hybrids are **4 of ~14** working-copy candidates (not "the spine"); the working copy already contains Section B history, an author-recommendations section, and a Tier-4 narrative, so the task is **reconciliation**, not one-directional porting; and `0-models.R` (the folder→model-name map) is **not** in the staged copy, so that mapping is currently unverified (§5, hard prerequisite).

---

## 1. Direction

**Technical base = the working copy** (`snow_sept/SAFE_snow_gmacs.Rmd`): modern `reslst`/`wtsGMACS` architecture, de-hardcoded scripts, the May final model already staged. **Port the following complete sections from the GitHub Sept-2025 final** (they exist there and are dropped/stubbed in the working copy), converting each to the working copy's architecture as you go:

- `A. Summary of Major Changes` (numbered: Management / Input data / Methodology / Results)
- Numbered Executive Summary (1–7) **with** the `continuity/management_table.csv` status-&-catch tables (kt + lbs, ≥95 mm + morphometric) and the OFL/ABC basis tables
- `## History of modeling approaches for the stock`
- Projections wiring (GitHub runs `do_proj=1`; working copy has it at `0`)

**Model to roll forward = May 2026 final model = Model 25.2c** = `Models/25_gmacs_update_newmat_plus_group` = *"25.1 gmacs (update + compfix + plus group + new_mat)"*. It already carries the three mandated corrections (comp fix + expanded >135 mm plus group + Ryznar new maturity workflow). The Tier-3 currency is computed two ways in the base — ≥95 mm (`"25.3 gmacs (>=95mm)"`, folder `25_gmacs_func/`) and morphometric (`"25.3 gmacs"`, folder `25_gmacs/`); repoint both at the May-final-model 2026 run.

> **Corrected data-integrity caveat (not a units bug):** Do **not** carry any working-copy management quantities into the report — they come from a run that is *not yet final* (`docs/SESSION_HANDOFF.md`: blocked on the 2026 survey pull + exe). Repopulate every OFL/ABC/B<sub>MSY</sub>/status value from the real May-final-model 2026 run. Separately, note the **substantive** (non-bug) issue the assessment already raises: under the **morphometric** currency the directed OFL (~42–52 kt) exceeds the 2025 survey commercially-preferred (>101 mm) male biomass of 23.28 kt, because that currency "allows removal of all of the largest male crab" — this is the long-standing ≥95 mm-vs-morphometric currency debate (2024(10) CPT), not an error to silently correct. Present both currencies as the base does. (The ~63/~71 F<sub>OFL</sub>/F<sub>MSY</sub> extremes belong to Model 25.2d only — the immature-index model, which is **not** the recommended model — don't generalize them.)

---

## 2. What changed vs. earlier versions

- Base direction corrected (§0.1): working copy is the technical base; port GH content into it.
- Scale/"placeholder" flag corrected (§0.2): currency mismatch, not a units bug; B<sub>MSY</sub> agrees.
- **Hybrids removed from the model** (May 2026 CPT/SSC, §3 rows 424/425): remove the 4 hybrid runs (25.3a–d) and hybrid data streams from the *model*, but **retain a short audit-trail summary** of the May hybrid exploration and its disposition (so the record shows it was reviewed and set aside). Move hybrid uncertainty to the risk table / ABC buffer; note tech-memo (possibly REMA) monitoring and the genetic-ID/cross-agency-classification research priority.
- **Tier 4 = the harvest-spec basis for October 2026** (row 416); Tier 3 (25.2c) presented as the developing model, with a male-only sensitivity and a data-through-2019 run.
- **New maturity workflow adopted** (rows 414/421), not a candidate.

---

## 3. May 2026 CPT / June 2026 SSC comments → required actions

Source: `AssessmentRequestsFromPlanTeams_SSC_ToShare.xlsx`, sheet **Requests** (2026, months 5–6). Each needs a Section B response + the noted report change.

| Row | Source | Body | Report action |
|---|---|---|---|
| **413** | CPT May | Bring forward **three runs**: (1) Tier 4; (2) Model 25.2c; (3) 25.2c **male-only**. | Structure scenarios/results around these three. Male-only reviewed for specs only if CPT selects it in September. |
| **414** | CPT May | All future Tier 3 models **must** include all three error corrections. | Confirm 25.2c has all three; state it. |
| **415** | CPT May | **Outstanding:** run with **data only through 2019**; plus convergence-diagnosis approach (fix params, add sequentially, inspect covariance). | Add the through-2019 run + a short convergence-diagnosis write-up. |
| **416** | SSC Jun | **Bring forward only the Tier 4 model in October 2026**; develop a simpler stable Tier 3. Supports comp fix + plus group. | Make **Tier 4 the recommended 2026 spec basis**; present Tier 3 (25.2c) as developing. |
| **417** | SSC Jun | For a *new* Tier 3 (2027): focused **convergence** section — jitter-cloud parameter attribution, correlation diagnostics, **likelihood profiles for terminal MMB, recent recruitment, M, OFL**, targeted simplifications. Immature index is **not** a convergence fix. | Add Convergence & Diagnostics subsection + the 4 profiles; present simplification runs as forward-looking; drop any "immature index fixes convergence" framing. |
| **418** | SSC Jun | Continue **yield-per-recruit** analysis; add a **"Rebuilding Analysis and Update"** section (2021 overfished). | Add both (YPR done or documented deferral). |
| **419** | CPT May | Research update on **size-at-maturity** (female maturity beyond 55–65 mm; large-male exploitation feedback loop; eastern-Canada parallels; Ryznar). | Summarize in Introduction→Maturity / Data gaps. |
| **421** | CPT/SSC | **New maturity workflow endorsed** (Bernoulli + bootstrap); ogive-use differences → January Modeling Workshop; **missing-year issue** to investigate before final. | State adoption; flag the missing-year check. |
| **423** | CPT/SSC | **Crab Risk Table SOP** adopted for Sept 2026: two-tier (Tier 1 historical buffer = **avg of previous 5 assessments**, carried annually; Tier 2 current-year, rare), no score→buffer formula, collaborate with ESP authors, **full risk table as SAFE appendix**. | Build **Appendix B risk table** to this SOP; compute Tier-1 buffer from last 5 assessments. |
| **424** | CPT/SSC | **Do NOT include hybrid catch or survey data** in snow **or Tanner** models. Handle hybrid uncertainty via buffer/risk table/TAC; keep tech-memo monitoring; buffer direction not predetermined. | Remove hybrid model runs/data; relocate to risk table/buffer; retain audit-trail summary. |
| **425** | CPT/SSC | *(newly added)* **Modernized genetic ID** of hybrids is a high-priority research item; align hybrid **classification across ADF&G observer, EBS trawl survey, and federal fishery** data streams; continued hybrid population-dynamics/genetics/life-history research. | Add to Data gaps & research priorities (high priority); it is the research companion to row 424. |

**All-crab 2026 CPT rows that impose SAFE requirements (not snow-specific, but apply):**

| Row | Body | Report action |
|---|---|---|
| **411** | Provide **MMB for the just-completed fishing year** for all models brought forward, for the **stock-status table** (MSST = ½ B<sub>MSY</sub>). | Ensure the management/status table reports terminal-year MMB and MSST for each model. |
| **412** | Provide **stock projections for a range of F values**. | Add projection output across a range of F (ties to §4 Projections). |
| **410** | SAFE guidelines checklist / a shorter proposed-models document. | Note for author; align document to the crab guidelines checklist. |

**Carry forward older open items** the working copy's Section B already tracks (2024–2025), cross-referencing where the 2026 actions now satisfy them (standardized Tier-4 fallback; likelihood profiles; rebuilding; ≥95 mm-vs-morphometric definition).

*(Draft paste-ready Section B response prose retained from v2 — see §3a below.)*

### 3a. Draft Section B responses (data-independent, paste-ready — tune wording)

> **2026(5) CPT — three model runs.** The September assessment presents (1) a Tier 4 analysis, (2) Model 25.2c (total-male composition correction, expanded >135 mm plus group, new maturity workflow), and (3) a male-only sensitivity of Model 25.2c. Per the CPT's note, the male-only run is a sensitivity and is not proposed for specification unless selected in September.
>
> **2026(5) CPT — mandatory corrections.** Model 25.2c incorporates all three corrections; all Tier 3 configurations here include them.
>
> **2026(5) CPT — data through 2019.** A run truncating data to 2019 is included (Section F / Convergence) to test whether convergence difficulties stem from estimating recruitment after the crash and the missing 2020 survey; covariance-based diagnostics identify the most correlated parameters.
>
> **2026(6) SSC — Tier 4 for October 2026.** Agreed. The 2026 specification is based on the Tier 4 calculation while a simplified, stable Tier 3 is developed for 2027; the composition correction and expanded plus group are retained.
>
> **2026(6) SSC — convergence section.** Section F includes likelihood profiles for terminal MMB, recent recruitment, M, and OFL; correlation diagnostics; and targeted simplification runs (recruitment sex-ratio fixed 50:50; reduced growth/M/selectivity confounding; fewer selectivity parameters; external growth; earlier equilibrium start). The immature survey index is not treated as a convergence fix.
>
> **2026(6) SSC — rebuilding & YPR.** A "Rebuilding Analysis and Update" section is included (2021 overfished). [Include / note status of] the yield-per-recruit analysis.
>
> **2026(5/6) CPT/SSC — maturity workflow.** Adopted as the base maturity input; the missing-year discrepancy is [resolved / under investigation before the final].
>
> **2026(5/6) CPT/SSC — risk table.** A full risk table following the adopted crab Risk Table SOP is provided as Appendix B (Tier-1 historical buffer = average of the previous five assessments; Tier-2 current-year uncertainties).
>
> **2026(5/6) CPT/SSC — hybrids.** Per the recommendation, hybrid catch and survey data are not included in the model this cycle; hybrid uncertainty is addressed via the ABC buffer and risk table, and hybrids continue to be tracked in the NOAA survey technical memo. Modernized genetic identification and cross-agency classification alignment are flagged as high-priority research (Data gaps).

---

## 4. Section-by-section (guideline-reconciled)

Legend: **[PORT]** bring the complete version from the GitHub final into the working copy · **[FILL]** working copy has a stub/partial to complete · **[UPDATE]** rework for the new direction · **[ADD]** new · **[REMOVE]** delete per May 2026.

- **Title page (§4.1)** — [ADD] predissemination/predecisional disclaimer + "cite as" block. P1.
- **Exec summary (§4.2.2)** — [PORT] numbered 1–7 + `management_table.csv` tables + OFL/ABC basis tables. [UPDATE] repoint to May final model; **base OFL/ABC on Tier 4** (row 416); include terminal-year MMB + MSST=½B<sub>MSY</sub> (row 411); add current-year + current+1/+2 catch-extrapolation method; state overfishing/overfished/approaching. P1.
- **A. Summary of Major Changes (§4.2.1)** — [PORT]. [UPDATE] input-data = 2026 catch+survey + early-1990s retained-comp correction; methodology = new maturity adopted, plus group expanded, **hybrids excluded**. P1.
- **B. Comments & responses (§4.2.7)** — [UPDATE] add §3/§3a May 2026 responses; cross-reference sections; reconcile the full Section B against the spreadsheet for any missed prior-year items. P1.
- **C. Assessment scenarios** — [UPDATE] set = Tier 4 · 25.2c (Tier 3) · 25.2c male-only · data-through-2019. **[REMOVE] hybrid scenarios 25.3a–d** (keep a short audit-trail note). P1.
- **D. Introduction** — [FILL] the empty `Management history` stub; [UPDATE] add size-at-maturity research update (row 419). P2.
- **E. Data** — [UPDATE] roll to 2026 (blocked); **[REMOVE]** hybrid data streams; note new-maturity missing-year check (row 421). P1/P2.
- **F. Analytic approach + Results** — [PORT] `History of modeling approaches`. [ADD] **Convergence & Diagnostics** (jitter-cloud attribution, correlation diagnostics, 4 likelihood profiles, data-through-2019 result, simplification runs — rows 415/417). P1.
- **G. OFL** — [UPDATE] **Tier 4 = recommended spec basis** (row 416); recompute Tier 4 via REMA (`07_tier_4.R` + `rema`); keep Tier 3 methodology. P1.
- **H. ABC** — [UPDATE] tie to the risk table (Appendix B); fold hybrid uncertainty into the buffer rationale; **reconcile the 2025 buffer discrepancy** (GitHub final states 20%; working copy Section I lists 25%) before computing the Tier-1 historical average. P1.
- **Author recommendations** — [UPDATE] flip to: Tier 4 basis for 2026 specs; 25.2c developing Tier 3; simplification path for 2027; **drop the adopt-hybrids recommendation**. P1.
- **Rebuilding Analysis and Update** — [ADD] (rows 418, 2025(10) SSC). P1.
- **Yield-per-recruit** — [ADD] or documented deferral (row 418). P2.
- **Projections** — [PORT/UPDATE] turn projections on; add projections over a range of F (row 412). P1.
- **I. Data gaps** — [UPDATE] assign high/med/low; recast hybrid items as monitoring + genetic-ID/classification-alignment (row 425, high); add new-maturity missing-year + convergence/simplification. P2.
- **J. Ecosystem** — [PORT] keep brief with ESP (Appendix A). P3.
- **K/L Supplemental / References** — [UPDATE] reconcile in-text vs. reference list; complete truncated refs; drop vestigial. P2.
- **Status Determination** — [UPDATE] explicit three MSA answers against the recommended (Tier 4) basis. P1.
- **Appendix A (ESP) / Appendix B (risk table)** — [ADD] risk table per row-423 SOP; reference ESP. P1.
- **Acknowledgements / Auxiliary Files / Flimit** — [ADD] (missing in both lineages). P2/P3.
- **[N/A]** groundfish-only: 7-scenario spmR set, Amendment-56 female-SB reference points, BRD spatial apportionment, "no in-year survey in September." Don't add; don't "fix" crab reference-point terminology.

---

## 5. Implementation steps for Claude Code

**Hard prerequisite (do before any repointing):** locate `0-models.R` in the repo (it's `source()`d by the Rmd but was **not** in the staged copy) and run the **`model_defs` index audit** flagged in `docs/SESSION_HANDOFF.md` (still "not yet done"). The folder→case-name→"Model 25.2c" identity is currently asserted only in Rmd comments — verify it against `0-models.R` and the actual `Models/` directory before trusting any model reference. Do not proceed if the mapping doesn't check out.

**Phase 1 — restructure (data-independent, do now):**
1. Keep the working copy as the base. Port the missing complete sections from the GitHub final (§1 list), converting each chunk from the legacy gmr/`M[[]]`/`Gmacsall.out` idiom to the working copy's `reslst`/`wtsGMACS` idiom. Do **not** re-introduce `source.all()` of the local gmr/gmacsr forks.
2. Repoint model references (`"25.3 gmacs"`, `"25.3 gmacs (>=95mm)"`, folders `25_gmacs/`, `25_gmacs_func/`) to the May final model run (both currencies), **after** the prerequisite audit.
3. **Remove hybrid scenarios (25.3a–d) and hybrid data handling** (`01_update_catch_data_hybrids.R` path); leave a short audit-trail summary + move hybrid uncertainty to the risk table.
4. Set the scenario set: Tier 4 · 25.2c · 25.2c male-only · data-through-2019.
5. Add/port sections: Convergence & Diagnostics (4 likelihood profiles), Rebuilding Analysis, Appendix B risk table (row-423 SOP), title-page disclaimer + cite-as, projections-over-F, Acknowledgements, Auxiliary Files, Flimit.
6. Rewrite Section B (§3a) and flip Author Recommendations (drop adopt-hybrids; Tier 4 basis).
7. Reconcile references; fix any `\autoref{}`→`\@ref()` cross-refs in ported narrative; reconcile the 20%-vs-25% 2025 buffer before the risk-table historical average.
8. **Render guard:** new/ported chunks reference runs that don't exist yet (male-only, 2019, final 2026). Guard them with `eval=FALSE` or smoke-test against the existing results object so the Rmd still knits during Phase 1; don't leave the document unrenderable.

**Phase 2 — populate (blocked on 2026 survey pull + GMACS exe):**
9. Build the runs that **do not yet exist** — the May final model advanced to End year 2025, plus the **male-only** and **data-through-2019** variants (none are in `Models/` today). Then `01`/`02` → `.DAT` → gmacs → `03` → `05` retro → `06` jitter → `07` Tier 4 (REMA) → `08` render.
10. Repopulate every management quantity from the real runs (both currencies); report terminal-year MMB + MSST (row 411). Do not carry Phase-1 placeholders.

**Do not:** re-plumb in the legacy gmr code; keep hybrid model runs; treat the immature index as a convergence fix; generalize Model 25.2d's extreme F values; add the groundfish-only [N/A] sections.

---

## 6. Appendix B — Risk table scaffold (adopted Crab Risk Table SOP, row 423)

The May 2026 CPT/SSC adopted a **two-tier** crab risk table for implementation in September 2026, to be provided as an **appendix in each SAFE chapter**. Scoring stays "consistent with groundfish" (the four categories below), but the buffer is organized into a persistent Tier-1 row plus a rare current-year Tier-2 row, with **no prescriptive formula** linking scores to the buffer. Build Appendix B to this structure. (Draft Rmd is in the companion `PHASE1_SECTION_SKETCHES.md`, §"risk table"; the design is specified here.)

**Tier 1 — historical/persistent buffer (carried annually).**
- Seed value = **average ABC buffer of the previous five snow crab assessments.** From the working copy Section I the recorded buffers are 2025 = 25%, 2024 = 65%, 2023 = 50%, 2022 = *(unavailable)*, 2021 = 25%, 2020 = 25%.
- ⚠️ **Reconcile first:** the GitHub 2025 *final* actually applied a **20%** buffer (ABC 2.6 / OFL 3.26; `ABC_buffer <- 0.8`), but Section I records 2025 as **25%**. Resolve which is correct before averaging, and decide how to treat the missing 2022 value (drop it and average the five available years, or substitute). Document the choice. `[[TODO: author decision]]`
- Rationale = the long-term, persistent considerations that already justify a buffer for this stock (recurring convergence/bimodality, the ≥95 mm-vs-morphometric currency debate, retrospective/model-misspecification uncertainty).
- **Working decision (2026-07-30): use a 20% buffer for now** (consistent with the author's 2025 recommendation). ⚠️ This is a placeholder that under-shoots the SOP: the previous-five-assessment average is ≈ **37–38%** (25/65/50/25/25), and 2026 is on the Tier 4 fallback — both argue for a larger buffer. Reconcile the 20/25 for 2025 (likely author-recommended 20% vs SSC-adopted 25%; use the **SSC-adopted** value in the average) and finalize the buffer when this table is populated.

**Tier 2 — current-year considerations (used only when additional buffer is warranted).** Score each of the four categories at a level consistent with the groundfish table (Level 1 normal → Level 4 extreme concern), with a one-to-two-sentence evidence statement. For snow crab 2026, the likely content:

| Category | Snow crab 2026 evidence (draft) | Level |
|---|---|---|
| **Assessment considerations** | Persistent bimodality / multiple optima in the Tier 3 model; the 2026 spec is on Tier 4 while a simpler Tier 3 is developed. | `[[TODO]]` |
| **Population dynamics considerations** | Recruitment uncertainty after the 2018–19 collapse; mature-male M sensitivity; stock overfished / in rebuilding. | `[[TODO]]` |
| **Environmental/ecosystem considerations** | Marine-heatwave mortality signal; reference the snow crab ESP (collaborate with ESP authors per SOP). | `[[TODO]]` |
| **Fishery performance considerations** | Fishery closed 2022–23, small fishery 2024–25; hybrids retained under snow-crab IFQ without separation. | `[[TODO]]` |

**Hybrid uncertainty lands here, not in the model** (row 424): note it explicitly as a current-year consideration whose buffer direction is **not** predetermined (it could push either way), per the SOP's caution.

**Draft flextable scaffold (Appendix B):**

```{r risk-table, echo=FALSE}
risk <- data.frame(
  Tier = c("Tier 1 (historical)", rep("Tier 2 (current year)", 4)),
  Category = c("Persistent buffer",
               "Assessment", "Population dynamics",
               "Environmental/ecosystem", "Fishery performance"),
  Level = c("—", "[[TODO]]", "[[TODO]]", "[[TODO]]", "[[TODO]]"),
  Consideration = c(
    "Avg buffer of previous 5 assessments = [[value]]% (reconcile 20% vs 25% for 2025)",
    "Recurring bimodality/multiple optima; 2026 spec on Tier 4.",
    "Post-collapse recruitment uncertainty; mature-male M sensitivity; overfished/rebuilding.",
    "Heatwave mortality signal; see snow crab ESP.",
    "Recent closures/small fishery; hybrids in retained catch; hybrid uncertainty (direction not predetermined)."
  )
)
flextable::flextable(risk) |>
  flextable::autofit() |>
  flextable::set_caption(
    caption = "Appendix B. Snow crab risk table (adopted Crab Risk Table SOP).",
    autonum = officer::run_autonum(seq_id = "tab", pre_label = "Table ", bkm = "risktable"))
```

**Wiring:** the ABC buffer used in `H. Calculation of the ABC` and the Executive Summary item 7 must equal the buffer this table justifies (Tier 1, adjusted by any Tier 2). The CPT will also maintain a cross-stock buffer-history table in the full SAFE Introduction — the author only supplies this stock's row.
