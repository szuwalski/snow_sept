# data/ reorganization + rename map (July 2026)

Old → new paths for every `data/` file moved or renamed during the July 2026 cleanup. Use this when
**porting figures/code from the archived reference Rmd** (`archive_2025/SAFE_snow_gmacs_2025_reference.Rmd`,
which still uses the OLD `data/<name>.csv` paths) and to trace any runtime "file not found" back to a rename.

**Provider-named files were deliberately NOT renamed** (they must keep matching each delivery): all
ADFG files (`total_catch`, `retained_catch`, `directed_total_composition`, `retained_catch_composition`,
`crab_bycatch_composition`, `bssc_discards`), the AKFIN export `EBSCrab_AB_Sizegroup.csv`,
`SnowCrabGrowthMaster.csv`, and everything in `data/derived/`.

**Correction (2026-07):** the male maturity array `SNOW_male_pmolt_array.csv` — the "new_mat" input read
by `02_prep_survey_data.R:245` — was **never actually present** in snow_sept (an earlier draft of this map
wrongly listed it as "kept as-is"). It was copied in from the authoritative `snow_crab/data/` (byte-identical,
md5 `bfbce95c…`, survey years 1989–2025) and now lives at `data/maturity/SNOW_male_pmolt_array.csv`,
provider name kept. For the September run this array still needs a **2026** update from E. Ryznar's maturity
workflow (the crabpack pull does not produce it). Separately, `data/maturity/crabpack_ptermmolt.csv` is a raw
`get_male_maturity()` dump left over from Cody's hybrid experiment — **no script reads it** (orphan); it is a
different shape and is NOT a substitute for the array above.

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
