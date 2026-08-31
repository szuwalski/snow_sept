# September 2026 SAFE — port map (May 2026 Rmd → September SAFE)

Tracks porting the September EBS snow crab SAFE onto the **portable May 2026 Rmd architecture**,
staying faithful to the September 2025 SAFE format/content/style.

- **Base (new `2026_snowcrab_safe_draft.Rmd`)** = May 2026 Rmd: `pacman::p_load`, `wtsGMACS`/`wtsUtilities`,
  `source("scripts/0-models.R")`, results from `Models/rda_ModelsResLst.RData`. Portable, already renders.
- **Port source** = `archive_2025/2026_snowcrab_safe_draft_2025_reference.Rmd` (archived old Sept 2025 Rmd) — has the
  September-only sections but on the old sourced-gmr architecture (`.get_catch_df`, `read_admb`, …).
- **Format reference** = `Reports/2025-09_SAFE_snow_crab.pdf` (+ `2025-09_SAFE_snow_crab_appendix.pdf`, `2025-09_ESP_snow_crab.pdf`).

Legend: ✅ present in base · 🔁 present but needs rewiring/2026 update · ➕ missing, must port in · ⛔ blocked on 2026 data/results

---

## Section-by-section (September 2025 SAFE outline → status in May base)

| September 2025 section | In May base? | Action |
|---|---|---|
| Executive summary | ✅ (A) | 🔁 update numbers to 2026 accepted model; SAFE exec-summary table format |
| A. Summary of Major Changes | ➕ | Port in — data/model/management changes for 2026 cycle |
| B. Comments (SSC/CPT) + responses | ✅ (B) | 🔁 replace May's June-2025 comments with the Sept-2026 CPT/SSC comments |
| C. Assessment scenarios / Model summaries | ✅ (C) | 🔁 collapse May bracket → single accepted model vs 2025 reference |
| **D. Introduction** (Distribution, Natural Mortality, Maturity, Mating ratio, Growth, Management history, ADFG harvest strategy, History of BMSY, Fishery history) | ➕ | **Port whole section** from reference; mostly narrative + a few figures |
| **E. Data** (Catch data, Survey biomass & size comp, Spatial distribution, Experimental survey selectivity) | ➕ | **Port whole section**; rewire figure/table code to portable arch ⛔ |
| F. Analytic approach (History, Model description, Model selection/eval) | ✅ (D) | 🔁 align headings to SAFE letter scheme; carry 2026 model description |
| Results (convergence, fits, population processes, MMB & mgmt quantities) | ✅ (E) | 🔁 update to accepted model ⛔ |
| G. Calculation of the OFL (Tier 3, Tier 4) | ✅ (F) | 🔁 final single-model OFL; Tier-4/REMA from `scripts/07_calc_tier4.R` ⛔ |
| Calculation of the ABC + Author recommendations | ✅ (G) | 🔁 buffer 0.8; final ABC ⛔ |
| Data gaps and research priorities | ✅ (H) | 🔁 refresh for 2026 |
| Ecosystem considerations | ➕ | Port in (May folds minimal; Sept has full section) — ESP: `Reports/2025-09_ESP_snow_crab.pdf` |
| Supplemental information | ✅ (I) | 🔁 |
| References | ✅ (J) | 🔁 merge reference lists |
| Tables | ✅ (K) | 🔁 update; add Sept-only tables (management, status determination) ⛔ |
| **Projections** | 🔁 stub in base (chunk ~L170–240, `do_proj`/`make_proj_fig` switches) | Wire up; needs converged model + MCMC draw ⛔ |
| **Retrospective analysis** | ➕ | Port; run `scripts/06_run_retrospective.R` (10 peels) ⛔ |
| **Jitter** | ✅ (base has jitter fig chunks) | 🔁 run `scripts/05_run_jitter.R` (100 runs) ⛔ |
| Figures appendix (size comps, maturity, CPUE, BSFRF, etc.) | partial | 🔁 many `include_graphics("plots/*.png")`; regenerate PNGs ⛔ |

---

## Code rewiring (old → portable)

Old Sept Rmd figures/tables that use the sourced-gmr API must be re-expressed on the portable one:

| Old call (reference Rmd) | Portable replacement |
|---|---|
| `M <- read_admb(.MODELDIR)` then `.get_catch_df(M)` | `wtsGMACS::extractRep1Results(reslst, ...)` / `reslst$repsLst[[case]]` |
| `.get_cpue_df`, `.get_M_df`, `.get_sizeComps_df`, `.get_selectivity_df`, `.get_molt_prob_df`, `.get_gi_df` | wtsGMACS extractors (see how May base builds each figure) |
| `compareFitsZCs(...)` | May base's size-comp comparison chunk |
| Hardcoded `.MODELDIR = "../snow_2025_9/24_gmacs_sq/"` | `model_defs[...]` from `scripts/0-models.R` |

If exact reproduction of a specific old figure proves hard, that's when Cody's `gmr`/`gmacsr` source
(EMAIL §2) becomes worth pulling.

---

## Config state (already set in the ported base)
- `accepted_model` = `"25.1 gmacs (update + compfix + plus group + new_mat)"` → `Models/25_gmacs_update_newmat_plus_group/`
- `reference_model` = `"25.1 gmacs"` → `Models/25_gmacs/`
- `report_model`, `case_for_resids`, `case_for_data_table`, `case_for_mat_plot` repointed to these.
- `scripts/0-models.R` keeps the full May list (index stability) with a TODO to prune after the results audit.

## Hard dependencies still needed before a full render
1. ⛔ `Models/rda_ModelsResLst.RData` regenerated for the 2 September models (`scripts/03_build_results_object.R`).
2. ⛔ Model advanced to End year 2025 + run (needs 2026 data + executable pin — EMAIL §1).
3. ⛔ Regenerated `plots/*.png` (retros, projections, jitter, size comps, n-at-len, tier-4).
4. Audit every `model_defs[N]` / `reslst$repsLst[[...]]` index in the Rmd body against the 2-model set.

## Open design questions (for Grant/CPT)
- Does the **2025 reference** stay at End year 2024, or also advance to 2025 for the comparison?
- Output format: PDF (SAFE standard) vs. Word+PDF (May setup keeps both).
- Which Sept-2026 CPT/SSC comments replace the May June-2025 comment set.
