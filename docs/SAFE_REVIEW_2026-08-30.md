# SAFE review — September 2026 EBS snow crab

**Reviewer pass:** 2026-08-30. Covers the five requests: (1) claims vs. the reports folder, (2) numbers vs. the model runs, (3) language/conciseness, (4) logic consistency, (5) required sections vs. the crab + groundfish checklists.

**Scope note.** Deep verification was concentrated on the sections that set the regulation — Executive Summary, F (OFL), G (ABC), H (Rebuilding), status determination, and Section B — cross-checked against `data/tier4/tier4_by_currency.csv`, the accepted-fit values recorded in `CLAUDE.md`, and the staged SSC reports and 2025 SAFE. The Introduction/Data/Analytic prose (C–E) was checked for presence and register but not exhaustively number-verified; the historical/biological citations there are lower-risk. Nothing below was hand-computed — the document's own single-source-of-truth design was audited, not re-derived.

---

## Verdict

**This is a strong, submission-grade draft.** Numeric integrity is excellent and the citation discipline is near-perfect. The remaining work is almost entirely the set of decisions the document already flags as `[[author:]]` — several of which are *required* checklist items, not polish. Only one genuine numeric-attribution error was found (§F, line 1760). Prioritized punch-list is in §5 below.

---

## 1. Claims vs. reports — PASS

Fifteen hardcoded external values were checked against their cited sources; **all 15 match exactly** (Oct 2025 SSC, June 2026 SSC, Oct 2024 SSC, 2025 SAFE):

- 2025/26 spec OFL 20.11 / ABC 12.07 / buffer 40% / F_OFL 0.19 / B_MSY 142.79 / MMB 105.213 / status 0.74 ✓
- 2024/25 overfished, MMB 60.08 vs MSST 71.40 ✓; Oct-2024 2023/24 status 0.56 ✓; 2024 buffer 65% ✓
- The SSC "full implementation … requires a harvest control rule" quote ✓; the "survey time, not mating" MMB footnote ✓; the standardized-Tier-4 wording ✓
- 2025 author-preferred 3.26 kt @ F_OFL 0.18 (Tier 3, ≥95 mm) ✓; 2025 Tier-4 28.41 / 8.64 / 6.11 kt ✓; the 2025-SAFE 2023/24 = 155.91 / 95.90 values the document flags as an error ✓ (values confirmed as printed)
- **Buffer-history table (Table \@ref(tab:buffer-history)) fully verified — all five years match their cited October SSC reports:** 2021 = 25% (2025 SAFE) ✓, 2022 = 25% (Oct 2022 SSC) ✓, 2023 = 50% (Oct 2023 SSC) ✓, 2024 = 65% (Oct 2024 SSC) ✓, 2025 = 40% (Oct 2025 SSC) ✓; the 41% five-year mean is correct. (Incidental: the Oct 2023 SSC Table 2 snow-crab row also carries MMB = 155.91 kt, corroborating the source of the value the draft flags as an erroneous 2023/24 MMB.)

Section B comment responses are faithful to the SSC/CPT reports and correctly scoped (two most-recent sets from each body, plus retained open items). The risk-table population/ecosystem/fishery cells match the ESP/ESR risk-table summary.

## 2. Numbers vs. model runs — PASS (one attribution error)

The specification scalars all resolve from `data/tier4/tier4_by_currency.csv` (morphometric row) and are mutually consistent: OFL **18.45 kt**, ABC **14.76 kt** (20% buffer), MMB **113.94 kt**, B_MSY **146.56 kt**, status **0.777**, MSST **73.28 kt**, CV **14.8%**, biomass 95% interval **85.4–152.1 kt**, OFL interval **10.11–31.73 kt**, status interval **0.58–1.04**. The `stopifnot` guards (OFL brackets, single morphometric row, 5-year tables) are appropriate and the single-source design does prevent the two-tables-disagree failure mode. Tier-3 figures in the Exec Summary (MMB 141.5, status 1.32, B_MSY 145.0, OFL 85.6) match the accepted fit documented in `CLAUDE.md`, and the terminal-MMB-vs-projected-Bcurr trap is handled correctly (they are separated and each named where used).

**Finding 2a (fix) — §F, line ~1760, catch-equation comparison conflates two changes.** The prose isolates the Baranov-vs-linear catch equation, but the printed comparison is `ofl_2026_linear` (= `OFL_flat_linear` = **30.77 kt**, the *flat* rule + linear equation) against `ofl_2026` (= ramp + Baranov = **18.45 kt**), giving "**67 percent**." That 67% includes the control-rule change as well as the catch equation. The "setting F_OFL = M makes fishing exactly half of Z" argument is about the flat rule, so the clean isolation is flat-linear vs flat-**Baranov** (30.77 vs 23.77 = **+29%**); or, to hold the recommended rule, ramp-linear vs ramp-Baranov (`ofl_2026_ramp_linear` 23.16 vs 18.45 = **+25%**). As written the sentence overstates the catch-equation effect. **Fix:** change the denominator to `ofl_2026_flat` (23.77) or the numerator to `ofl_2026_ramp_linear` (23.16), and make the sentence say which pair it holds fixed.

## 3. Language & conciseness — STRONG

Register matches the 2025 SAFE — declarative, precise, no AI tells, no gratuitous formatting. It errs toward thoroughness rather than verbosity, which is defensible given the contested tier-change and buffer. Minor, optional:

- The "currency moves the OFL by more than a factor of four" point recurs in the Exec Summary, §B, §F and §G. Each recurrence is locally justified, but once the currency is *settled* (§5) you may want one canonical statement in §F and cross-references elsewhere.
- A few very long sentences in §F/§G (e.g. the ABC "opposite directions" passage, ~line 1838) could be split without loss.

No substantive language issues.

## 4. Logic consistency — STRONG

The Tier-3/Tier-4 status contrast, the overfished-but-not-rebuilt reasoning (above MSST, below B_MSY on the point estimate, upper CI reaches rebuilt), and the as-specified vs. current-estimate conventions in the management-performance table are all internally coherent and clearly explained. Two items to settle (both already self-flagged in the draft):

- **4a — Table 1 / status-determination catch convention (line ~1783).** The 2024/25 figure the SSC carried is directed-fishery catch only (2.81 kt), while the 7.10 kt reported for 2025/26 includes 0.42 kt non-directed bycatch. The determination is unaffected (catch ≪ OFL either way), but the column mixes conventions between rows. Pick one and state it in the caption.
- **4b — see Finding 2a** (catch-equation attribution) — it's also a logic point: the sentence claims to isolate one variable and doesn't.

## 5. Required sections — structurally complete; a defined set of required items are still open

Every required section exists. What remains are items the draft has correctly left as `[[author:]]` decisions — but several are **required by the checklist**, not optional. Split into "must resolve before submission" and "author judgement / polish":

### Must resolve (required by the crab/groundfish checklist)

1. **Maximum permissible ABC (maxABC).** Required regardless of the recommendation (groundfish 4.11.2; crab checklist). Currently absent — §G, line ~1799 explains the max-permissible buffer basis for a Tier-4 crab stock couldn't be established from the documents to hand. **Needs the maxABC basis and the value reported alongside the recommended ABC**, plus the Exec-Summary item-9 line.
2. **"Approaching an overfished condition" determination.** The third MSA question is unanswered (Exec Summary line ~737 and §F line ~1781). Required, and pointed for a stock in a rebuilding plan.
3. **Author recommendation — currency and buffer.** Control rule is settled (ramped FMP). Currency (morphometric vs ≥95 mm — moves the OFL >4×) and the buffer (20% recommended vs a 41% five-year average and 40% last year) are the two decisions the whole document turns on, and both are open (§G ~1797/1838, Author recs ~1927, Exec Summary ~611). The 20%-vs-40% ABC reversal in a year the marketable stock fell is, as the draft itself says, "the number the CPT will arrive at" — it needs the explicit argument.
4. **Risk-table assessment-related category — unscored.** The evidence is assembled (multimodality, 1.3% jitter recovery, overparameterization) but the *level* is blank, and that cell is what carries the buffer justification for this stock (§G ~1856/1917).
5. **Acknowledgements** — entire section is a placeholder (line ~1993). Required.
6. **Appendix of non-commercial removals** — required; repo has no such data (line ~2017). Either the amounts or an explicit "negligible, on this basis" statement.
7. **List of Tables / List of Figures** — not generated; only `toc: true` in the YAML. Add `\listoftables` / `\listoffigures`.
8. **Executive Summary item 8 (OFL probability distribution)** and the full 10-numbered-item layout, including the new "Current Status" MMB-in-February-after-fishing column the May 2026 CPT describes (line ~811). Item 8 and the after-fishing MMB are not yet computed.
9. **Summary of Major Changes item 4 (Assessment results)** — placeholder (line ~823); needs the recommended OFL/ABC/tier/currency stated, and *which* 2025 comparison is meant.

### Author judgement / lower priority

- Model-equations content: the Model Description points to the GMACS repo rather than including equations, and there is no equations appendix (the one drafted earlier in `PHASE1_SECTION_SKETCHES.md §18` was not incorporated). The groundfish guideline permits referencing standardized-software docs, so this may pass — **confirm against the crab checklist**; if it wants equations in-document, lift §18.
- Yield-per-recruit: acknowledged as not done (§B, Author recs) — needs a reason + date (the SSC's spec is detailed: YPR vs F, reductions in MMB and ≥95 mm biomass, F_0.1, an F_65% interim proxy, two-sex fertilized-egg SPR).
- Several §B responses deferred with `[[author: give a date]]` — the checklist wants dates on outstanding items.
- Recruitment survey-comparison figure (line ~1957) not yet a numbered figure; the negative model-vs-survey recruitment correlation "deserves comment."
- Historical-analysis cause/uncertainty notes (~1620); Ecosystem placement note (~1979); Literature-cited `[[VERIFY]]` on one reference (~2029); Auxiliary-files list to confirm (~2009); title-page author list + draft disclaimer (~504).

---

## Bottom line

Nothing in the numbers or the citations should hold up submission — those are clean, with the single §F line-1760 attribution fix. The gate to submission is the **author-decision punch-list in §5** (items 1–9), of which **maxABC, the approaching-overfished determination, the currency/buffer recommendation, the risk-table assessment score, acknowledgements, the non-commercial-removals appendix, and the lists of tables/figures** are the hard requirements. The document already knows about every one of them — they are flagged in place — so this is a finishing pass, not a rework.
