# data/ reorganization + rename map (July 2026)

Old → new paths for every `data/` file moved or renamed during the July 2026 cleanup. Use this when
**porting figures/code from the archived reference Rmd** (`archive_2025/SAFE_snow_gmacs_2025_reference.Rmd`,
which still uses the OLD `data/<name>.csv` paths) and to trace any runtime "file not found" back to a rename.

**Provider-named files were deliberately NOT renamed** (they must keep matching each delivery): all
ADFG files (`total_catch`, `retained_catch`, `directed_total_composition`, `retained_catch_composition`,
`crab_bycatch_composition`, `bssc_discards`), the AKFIN export `EBSCrab_AB_Sizegroup.csv`,
`SnowCrabGrowthMaster.csv`, and everything in `data/derived/`.

**Maturity array (updated 2026-08):** the male maturity array `SNOW_male_pmolt_array.csv` — the "new_mat"
input read by `02_prep_survey_data.R:245` — was **never present** in the original snow_sept (an earlier draft
of this map wrongly listed it as "kept as-is"). It was first copied from `snow_crab/data/` (1989–2025), then
**replaced** with the September 2026 version built from `data/maturity/snow_ogives.csv` (the smoothed maturity
ogive, 1989–**2026**, emailed to Grant by **Emily Ryznar**, Aug 2026; the provenance input — an already-fitted
product, not an API pull). Build = pure **reshape** of `PROP_MATURE` onto the
`27.5–132.5` model grid — **no re-GAM** (the ogive is already the smoothed output, so Cody's per-year
`gam()` at `snow_crab/02_make_DAT_file_hybrid.R:389` is NOT re-run). vs the snow_crab array on 32 shared
years: max |Δ|≈0.02, mean≈0.005 (new smoothing model); it also adds real values for 2008/2012/2014/2016
(previously mean-filled) plus 2026. Reshape/validation script: `scratchpad/build_pmolt_array.R`.
GATE: the survey pull (`get_specimen_data`) must also reach 2026 or Section 6's `MaleNew*in_mat` misaligns
(maturity `in_mat` = 44 rows). Separately, `data/maturity/crabpack_ptermmolt.csv` is a stale raw
`get_male_maturity()` dump — **no script reads it** (orphan), different shape, NOT a substitute.

## Folder relocations (loose data/ root → domain subfolders)
| Old | New |
|---|---|
| `data/catch 2026 ADFG/` | `data/adfg_removals/2025_26/` |
| `data/new_catch/bssc_202425 (8 4 2025)/` | `data/adfg_removals/2024_25/` |
| `data/<growth files>` | `data/growth/` |
| `data/<maturity files>` | `data/maturity/` |
| `data/<survey files>` | `data/survey/` |
| `data/<spatial files>` | `data/spatial/` |
| `data/<historical files>` | `data/historical/` |

## File renames
| Old path | New path | Pipeline ref |
|---|---|---|
| `data/cie_dat.csv` | `data/ecosystem/sea_ice_extent.csv` | (none; was mis-filed — it's sea-ice extent, not "CIE") |
| `data/grow_dat.csv` | `data/growth/growth_increments_observed.csv` | Rmd |
| `data/growth_ass.csv` | `data/growth/growth_increments_base.csv` | 01 (read) |
| `data/newgrowth.csv` | `data/growth/growth_increments_from_master.csv` | 01 (write) |
| `data/newgrowth2.csv` | `data/growth/growth_increments_final.csv` | 01 (write) |
| `data/median_ogive.csv` | `data/maturity/maturity_ogive_median.csv` | (none) |
| `data/snow_unweighted_propmature.csv` | `data/maturity/proportion_mature_unweighted.csv` | archived Rmd (commented) |
| `data/fem_prob_term_molt.csv` | `data/maturity/female_prob_terminal_molt.csv` | (none) |
| `data/survey_lg_males.csv` | `data/survey/survey_preferred_male_index.csv` | Rmd (read; `preferred_male`) |
| `data/lg_male_surv_obs.csv` | `data/survey/survey_large_male_index_derived.csv` | 02 (write); archived Rmd `bigguys` fig reads it (port TODO) |
| `data/historical_crab_management_2.csv` | `data/historical/historical_management_quantities.csv` | (none) |
| `data/historical_mmb_estimates_survey.csv` | `data/historical/historical_mmb_at_survey_by_assessment.csv` | 05 (read) |
| `data/historical_mmb_estimates_MMB_mating.csv` | `data/historical/historical_mmb_mating_by_assessment.csv` | 05 (read) |

## Kept at data/ root (already clear)
`wt_at_size.csv`, `dat_comparison.xlsx`.
