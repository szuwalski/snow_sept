# Handoff — September 2026 EBS snow crab SAFE, mechanical build

**For:** Claude Code, working in the `snow_sept` repo on Grant's machine.
**Goal:** produce the September 2026 snow crab SAFE by editing the working-copy `SAFE_snow_gmacs.Rmd`, porting/ drafting the sections specified below. Phase 1 is data-independent and can be done now; Phase 2 waits on the 2026 model runs.

## Source documents (read these first)
- `SEPT2026_SNOW_CRAB_BUILD_PLAN.md` (v3) — scope, direction, guideline reconciliation, risk-table SOP.
- `PHASE1_SECTION_SKETCHES.md` — draft R Markdown for each section, referenced below as §1–§17.
- Project memory: `project_sept2026_direction.md`, `sept2026_tier4_and_comments.md` — settled decisions.
- Reference (do not edit): GitHub `szuwalski/snow_sept@main/SAFE_snow_gmacs.Rmd` = the accepted Sept-2025 final (source of ported sections); the working copy's own `stepchange` chunk (the `extract_mgmt_quantities()` idiom to reuse).

## Non-negotiable direction (from prior decisions — do not relitigate)
- **Base = the working copy** (modern `reslst`/`wtsGMACS` architecture). Port section *content* from the GitHub final; **do not** reintroduce the GitHub base's legacy `gmr`/`gmacsr` plumbing (`source.all()` of local forks, `M <- lapply(read_admb)`, direct `Gmacsall.out` reads outside `extract_mgmt_quantities()`).
- **Recommended model = Model 25.2c** = `Models/25_gmacs_update_newmat_plus_group`.
- **2026 harvest spec basis = Tier 4** (developing Tier 3 = 25.2c presented for context).
- **Currency = morphometric recommended**; ≥95 mm and >101 mm reported for comparison.
- **Tier 4 uses a constant target F = 0.27 (prior median), no control-rule ramp ("no kink")**; reference period 1982–2025.
- **ABC buffer = 20% placeholder** (`ABC_buffer <- 0.8`); Appendix B (§16) computes the SOP alternative (~38%) — leave the applied value at 0.8 unless Grant changes it.
- **Hybrids removed from the model** (keep an audit-trail note; move uncertainty to the risk table).

---

## STEP 0 — Hard prerequisite (do before touching any model reference)
`0-models.R` (defines `model_defs` and the folder→case-name map) was **not** in the staged copy, and `docs/SESSION_HANDOFF.md` says the `model_defs` index audit is "not yet done." **Locate `0-models.R`, and verify** that:
1. the case name/string for `Models/25_gmacs_update_newmat_plus_group` is what the Rmd's `accepted_model` and the sketches call "Model 25.2c";
2. `model_defs[[...]]` indices used in the Rmd resolve to the intended folders after the hybrid models are removed.
Do not proceed to any model-reference repointing until this resolves. If it doesn't, stop and report.

---

## STEP 1 — Adopt the canonical section outline (fixes the mixed-lettering blocker)
The working copy and the GitHub base use different section letters; the sketches mix them. **Reletter the document to this single canonical outline** and update every cross-reference (prose "Section X" and `\@ref`) to match:

```
# Executive summary            (items 1–7: §3 prose + §15b mgmt table + §15c OFL basis + §15d ABC basis)
# A. Summary of Major Changes  (§2)
# B. SSC and CPT comments + author responses   (§14 at top, then existing 2024–25 responses)
# C. Assessment scenarios       (§12)
# D. Introduction               (fill the empty "Management history" stub; add size-at-maturity update)
# E. Data                       (remove hybrid data streams)
# F. Analytic approach          (## History of modeling approaches §4; ## Model description; ## Model selection;
#                                ## Results [### Convergence and diagnostics §5; ### Model fits; ### Estimated
#                                population processes; ### MMB and management quantities])
# G. Calculation of the OFL      (### Tier 3 methodology; ### Tier 4 §13)
# H. Calculation of the ABC      (buffer from Appendix B; consumes abc_2026; ## Author recommendations §7)
# I. Rebuilding analysis and update   (§6; ## Yield-per-recruit)
# J. Status determination        (§8)
# K. Flimit                      (§9)
# L. Projections                 (§17)
# M. Ecosystem considerations
# N. Data gaps and research priorities   (add hybrid genetic-ID / classification, row 425)
# O. Acknowledgements            (§10)
# P. Supplemental information / Auxiliary Files   (§10)
# Q. References
# R. Tables
# S. Figures
# Appendix A. Ecosystem and Socioeconomic Profile (reference)
# Appendix B. Risk table         (§16)
```

**Structural change — demote Results:** the working-copy base has `# G. Results` as a **top-level** section. Under this outline Results is a `## Results` subsection of `# F. Analytic approach`, and `G` becomes the OFL section. **Demote** `# G. Results` → `## Results` under F before relettering, or you will end up with two `# G.` headings.

**Cross-reference remaps** (the sketch prose was written before this outline; fix these literals):
- "Section J" (data gaps, in the §14 hybrid genetic-ID response) → **Section N**.
- "the Projections section" (§14 all-crab response) → **Section L**.
- "the Rebuilding section" (§14 YPR response) → **Section I**.
- "Section F" (convergence/diagnostics), "Section G" (OFL/Tier 4), "Section H" (ABC), "Section C" (scenarios), "Appendix B" — already correct under this outline; leave them.

---

## STEP 2 — Phase 1 build tasks (data-independent; order matters)

1. **Global setup.** Add the `tier4-setup` chunk (§15a) to the top-level setup chunk, after `ABC_buffer` is defined. It is the single source for `bmsy_2026 / mmb_2026 / msst_2026 / status_2026 / ofl_2026 / abc_2026`. **Delete the `tier4-vals` chunk in §13** (it double-defines the same names — §15a supersedes it).
2. **Title page** (§1): add the predissemination disclaimer + "cite as" block.
3. **Port the missing GitHub sections** into the working copy, converting each chunk from the legacy idiom to `reslst`/`extract_mgmt_quantities()`:
   - `# A. Summary of Major Changes` (§2)
   - `# Executive summary` items 1–7. Use §3 for items 1–4; **use §15b/c/d as the authoritative drafts for items 5–7 and delete §3's item-5/6/7 duplicates** (they are earlier and less complete — e.g. §3's static "20%" would contradict §15d's dynamic buffer, and §3's `mgmt-table` chunk is superseded by §15b). Item 5 management table: rewire the terminal `2025/2026` row to the Tier-4 scalars per §15b (do **not** use `proj_mmb_under_ofl`, a Tier-3 projection that is undefined for Tier 4). Morphometric table is primary; ≥95 mm becomes a comparison.
   - `## History of modeling approaches` under F (§4).
4. **New sections** (draft from sketches): `### Convergence and diagnostics` (§5), `### Tier 4` under G (§13), `# H. Calculation of the ABC` (prose consuming `abc_2026`) **plus its `## Author recommendations` subsection (§7) — REPLACE the working copy's existing pro-hybrid recommendation (base line ~726: "a snow crab only and snow crab + hybrid … models be adopted") with the flipped §7 text (Tier 4 basis; no hybrids)**, `# I. Rebuilding analysis and update` incl. yield-per-recruit (§6), `# J. Status determination` (§8), `# K. Flimit` (§9), `# L. Projections` (§17), `# O. Acknowledgements` + `# P. Auxiliary Files` (§10), `# Appendix B. Risk table` (§16).
5. **Section B** (§14): insert the 2026 CPT/SSC responses at the top of B; keep the existing 2024–25 responses below.
6. **Section C** (§12): replace the working copy's hybrid-heavy scenarios with the four-run set (Tier 4 / 25.2c / 25.2c male-only / data-through-2019); keep the §11 hybrid audit-trail note.
7. **Remove hybrids** (mechanical checklist in §11 / plan): delete scenarios 25.3a–d, the `hybrid` fleet-relabel branches (~working copy lines 124–131), hybrid columns in data/fit figures, and the `01_update_catch_data_hybrids.R` path. **Keep** the underlying hybrid data files. Replace with the §11 note.
8. **References**: reconcile in-text citations against the bibliography (Zacher 2025, Fedewa 2025, Richar & Foy 2022, Ryznar in prep, etc.); complete truncated entries; drop vestigial ones. Convert any ported `\autoref{}` cross-refs to bookdown `\@ref()`.
9. **Buffer prose consistency:** the applied buffer is `ABC_buffer`. Where prose prints a literal "20%" — **§3 item 7** and the **§13 caption** ("ABC = 0.8 x OFL") — render it as `` `r round(100*(1-ABC_buffer))`% `` (and `1 - ABC_buffer` in the caption) so it can't drift from the computed ABC. (§15d and §16 already do this; note §3 item 7 is deleted per task 3, so its literal disappears with it — the §13 caption is the one to fix.)

## STEP 3 — Knit guard (must stay green through Phase 1)
Many new chunks depend on runs that don't exist yet. Keep the document knitting:
- The `tier4-setup` chunk (§15a) has an `if(file.exists(...))` stub that sets the `_2026` scalars to `NA`; keep it.
- Guard every chunk that reads a not-yet-existing object (male-only run, 2019 run, `tier4_results.rds`, projection files, likelihood profiles) with `eval=FALSE` and a `## PHASE 2` marker.
- After each editing block, **knit the document** and confirm it still builds. A green knit with `NA`/placeholder numbers is the Phase-1 done state.

---

## STEP 4 — Phase 2 (data pipeline DONE 2026-08; models built, need RUNNING)
The old blockers are **RESOLVED**: the 2026 summer-survey crabpack pull runs (`02`), the GMACS exe is present, and `01`/`02` now write clean `data/derived/*` (6 tidy files) that **`00_advance_model.R`** transcribes into the model `.DAT`/`.CTL` — no more hand-paste (see the `snow-sept-2026-model-pipeline` project memory).

**Already built (End year 2025, GMACS-valid — but NOT yet run to convergence):**
- `Models/26_gmacs_update_newmat_plus_group` — the recommended 25.2c advanced to End year 2025 (right=FALSE binning, growth-typo fix, 2026 data). Terminal MMB 114.576.
- **Two methodology sensitivities** on the accepted 2025 endpoint: `25_gmacs_rightFALSE` (size-comp binning switched right=TRUE→FALSE alone) and `25_gmacs_rightFALSE_growthfix` (adds the growth-typo fix on top).

⚠️ Those three new dirs currently hold **STALE run artifacts** copied from the template (they show the *accepted* model's results) and have **no committed `gmacs.exe`**. Before running, refresh each with `Rscript 00_advance_model.R <template_dir> <out_dir> <end_year> <out_dat_name> [growth_fix]` (it copies a runnable dir), then run GMACS.

**Still to build:** the **male-only** and **data-through-2019** variants of 25.2c.

**Run the pipeline** — for each model dir: GMACS to convergence → `03_build_results_object.R` (advance `model_defs` to add the 2026 case + the sensitivity cases) → `05` retrospective → `06` jitter → `07_tier_4.R` → projections → `08_render_report.R`. Flip the `PHASE 2` chunks to `eval=TRUE`. Verify `07_tier_4.R`'s output matches the sketches' interface (`tier4$by_currency` with `currency/Bmsy/B_curr/status/M/Fofl/OFL`); adapt **only** the `tier4-setup` chunk if columns differ. Repopulate every management quantity from the real runs.

**Report the two methodology sensitivities in `# A. Summary of Major Changes`** — each isolates one change's effect vs the accepted May model: (1) the size-comp edge convention (right=TRUE→FALSE, "a crab on a 5-mm cutoff goes to the upper bin" — the previous survey convention; this is why terminal MMB is 114.6 and not the rejected right=TRUE value 107.5), and (2) the growth-data fix (a 26.3 mm crab's molt increment `73`→`7.3`, a `.DAT` transcription typo confirmed against the specimen master).

## STEP 5 — Verification / acceptance criteria
- Document knits cleanly at the end of Phase 1 (placeholders allowed) and Phase 2 (real numbers).
- **Number cross-check:** the OFL and ABC are identical in the Executive Summary management table (item 5), the OFL basis (item 6), the ABC basis (item 7), Section G, and Appendix B — because all read the §15a scalars / `ABC_buffer`. Grep for any independent recomputation and remove it.
- No hybrid model run remains in the scenario set; the audit-trail note is present.
- Every "Section X" / `\@ref` resolves under the STEP 1 outline (no dangling refs).
- Tier-4 prose describes a flat F=0.27 (no ramp); currency is morphometric-recommended with ≥95/101 shown.

## Open decisions to surface to Grant (do not guess)
- **ABC buffer:** 20% placeholder vs. the SOP ~38% (Appendix B). Applied value stays `ABC_buffer <- 0.8` until Grant decides; also confirm the 2025=25% and 2022-excluded assumptions behind the 38%.
- **`[[VERIFY]]` base M:** confirm the base-level (non-event-year) mature-male M in 25.2c is near 0.27, so retaining the prior median is defensible.
- Any `[[TODO]]`/`[[VERIFY]]`/`[[author]]` marker left in the sketches is a Grant decision, not a Claude Code guess.

## Do NOT
- Re-plumb the legacy gmr/gmacsr code; keep any hybrid model run; treat the immature index as a convergence fix; use `proj_mmb_under_ofl` for the Tier-4 management row; hard-code an OFL/ABC/buffer that bypasses the shared scalars; add the groundfish-only 7-scenario spmR projection set (crab uses the range-of-F projection in §17).
