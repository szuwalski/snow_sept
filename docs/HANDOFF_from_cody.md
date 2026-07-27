# Snow crab September 2026 SAFE — handoff checklist

What we need from Cody (and decisions to lock) to advance the September 2026 EBS snow crab
assessment. Context: `snow_crab` = May 2026 CPT/model-selection work; `snow_sept` (this repo)
= the September SAFE, still templated from **2025** (title, dates, models, and the built PDF are
all 2025-vintage). The designated final model
`snow_crab/Models/25_gmacs_update_newmat_plus_group` is the correct **structure** but was last
run **May 11, 2026 on 2024 crab-year data (End year = 2024, 2025 survey)**. The job is to advance
it one crab year to **End year 2025** (2025/26 fishery + bycatch + the new **2026 summer survey**),
re-run, regenerate products, and update the Rmd.

Status legend: ☐ = need from Cody / to obtain · ✅ = already have · ⚙ = Grant can do without Cody

---

## A. R environment / code to make the report run

The **September 2025 Rmd** (`SAFE_snow_gmacs.Rmd` in this repo) is the *old* architecture: it
`source.all()`s gmr and gmacsr from Cody's local folders and calls old-style helpers
(`.get_catch_df`, `.get_cpue_df`, `.get_M_df`, `.get_sizeComps_df`, `.get_selectivity_df`,
`.get_molt_prob_df`, `.get_gi_df`, `compareFitsZCs`). The installed `gmr` v1.3.7
(gmacs-project/gmr) does **not** provide these, and `gmacsr`/`rema` are not installed at all.

- ☐ **`gmr` source folder** Cody sources from `C:/Users/cody.szuwalski/Work/gmr/R/` — i.e. the
  exact version/fork that defines `.get_catch_df`, `.get_cpue_df`, `.get_M_df`,
  `.get_sizeComps_df`, `.get_selectivity_df`, `.get_molt_prob_df`, `.get_gi_df`. (Zip the folder,
  or give repo + commit/branch.) The gmacs-project `gmr` on my machine is a rewrite with a
  different API and won't work with the Sept Rmd as written.
- ☐ **`gmacsr` source folder** from `C:/Users/cody.szuwalski/Work/gmacsr/R/`, including
  `compareFitsZCs`. Not installed here; not on GitHub under an obvious name — need his copy or the
  repo/commit.
- ☐ **wts* package versions**: which commits of `wtsGMACS`, `wtsUtilities` (and `wtsQMD`) he used,
  so `readModelResults()` / `extractRep1Results()` behave identically. (I have these installed but
  should match versions for a byte-faithful report.)
- ⚙ **`rema`** (needed by `07_calc_tier4.R`): I can install from `afsc-assessments/rema`. Confirm he
  used the standard release, not a fork.
- ⚙ **`tinytex`/pandoc**: TinyTeX is installed here; I'll drive rendering via Positron's pandoc.

> **Decision (see §D-1):** if we instead port the Sept SAFE onto the *May 2026 portable Rmd*
> architecture (`0-models.R` + `wtsGMACS` + `Models/rda_ModelsResLst.RData`, no `source.all`),
> the old `gmr`/`gmacsr` items above become unnecessary. Recommended.

---

## B. The final model + GMACS executable (to advance to 2026)

- ☐ **Confirm** `25_gmacs_update_newmat_plus_group` is THE accepted September 2026 model
  structure (= May's `Model 25.2c`, "update + compfix + plus group + new_mat"). Any CTL/PRJ tweaks
  agreed *after* the May CPT that should be carried in?
- ☐ **The exact GMACS executable / TPL** to use. The final model dir ships `gmacs.exe`
  (Apr 2, 8.87 MB) **and** `gmacsbase.TPL` (May 11); this repo's `25_gmacs/gmacs.exe` is a
  *different* build (8.67 MB). Pin one (version string / commit of gmacsbase.TPL) so 2026 results
  are reproducible.
- ☐ **`.prj` / projection & reference-point settings** for the September OFL/ABC (projection
  horizon, SR assumption, B35% basis, ABC buffer — currently `ABC_buffer = 0.8` in the Rmd).
  Confirm unchanged from 2025.
- ✅ **Last year's accepted (2025) model** = `snow_crab/Models/25_gmacs` ("Model 25.1 gmacs").
  Copied into `snow_sept/Models/25_gmacs` as the rolled-forward "status quo" comparison.
  (Open design question for §D: does the reference stay at End year 2024, or also advance to 2025?)

---

## C. 2026 raw data inputs (not yet gathered — the bulk of the work)

Scripts `01_prep_fishery_data.R` and `02_prep_survey_data.R` build the `data/derived/*`
files that get pasted into the GMACS `.DAT`. They currently target **crab year 2024** (date
windows `2024-07-01 … 2025-06-30`). For 2026 these shift to **`2025-07-01 … 2026-06-30`** and need
the new season's data. None of the following 2026 inputs are in the repo yet:

**Survey (crabpack / AKFIN API):**
- ☐ Confirm **crabpack API access** works for Grant (the scripts use `channel = 'API'` — needs
  AKFIN credentials / on-network). If not, Cody sends the **2026 specimen data pull** (`get_specimen_data(species="SNOW", region="EBS", years=1982:2026)`).
- ☐ **`data/SNOW_male_pmolt_array.csv`** — male terminal-molt probability array, updated through
  2026 (read by `02_...R`; currently missing).
- ☐ **`data/survey/EBSCrab_Abundance_Biomass_female.csv`** and **`_male.csv`** — Kodiak-lab EBSCrab
  pulls used by `04_plot_numbers_at_length.R` (the whole `data/survey/` folder is missing).

**Observer (AKFIN "Observer data" tab):**
- ☐ **`data/norpac_length_report/norpac_length_report.csv`** — NORPAC Length Report (Haul &
  Length), snow crab, **Jul 1 2025 – Jun 30 2026**.
- ☐ **`data/norpac_catch_report/norpac_catch_report.csv`** — NORPAC Catch Report, snow crab, BS,
  same window.

**Directed fishery / catch (ADF&G + AKFIN fish tickets, dockside):** add the **2025/26 season**
rows to each of these (currently end at 2024):
- ☐ `data/new_catch/retained_catch.csv`
- ☐ `data/new_catch/total_catch.csv`
- ☐ `data/new_catch/bssc_discards.csv`
- ☐ `data/new_catch/retained_catch_composition.csv`
- ☐ `data/new_catch/directed_total_composition.csv`
- ☐ `data/new_catch/crab_bycatch_composition.csv`

**Management table:** ☐ 2025/26 TAC, retained catch, OFL/ABC realized, state harvest specs for the
historical management / status-determination tables.

---

## D. Decisions to lock (with recommendations)

1. **Report architecture.** Build the Sept 2026 SAFE on the **May 2026 portable Rmd**
   (`snow_crab/SAFE_snow_gmacs.Rmd` + `0-models.R`, which already runs on Grant's machine and is
   2026-ready) and port in the September-only sections (retrospectives, projections, Tier-4/REMA,
   jitter, final OFL/ABC & status determination) — **recommended**; or resurrect the old Sept 2025
   Rmd with Cody's sourced `gmr`/`gmacsr`. Recommendation avoids the brittle `source.all` deps in §A.
2. **Single model vs. bracket.** Sept SAFE typically presents the one accepted model
   (25.2c/newmat_plus_group) rolled forward vs. last year, not the full May candidate bracket.
   Confirm.
3. **Output format.** 2025 Sept Rmd → PDF; May 2026 → Word + PDF. Which for the Sept SAFE? (SAFE
   standard is PDF.)

---

## What I (Grant/Claude) can start now without Cody
- ⚙ Install `rema`; confirm the full package stack renders.
- ⚙ De-hardcode all `C:/Users/cody.szuwalski/...` paths in the Rmd and scripts `05`, `06` to
  repo-relative.
- ⚙ Copy `25_gmacs_update_newmat_plus_group` into `snow_sept` as the working model dir.
- ⚙ Update the data-prep scripts' hardcoded date windows (2024→2025) and stage the empty
  `data/survey/`, `data/norpac_*` folders so inputs drop straight in.
- ⚙ Update Rmd metadata (title/date/author/GitHub URL) to September 2026.
