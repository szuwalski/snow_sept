---
description: Render SAFE_snow_gmacs.Rmd to PDF
---

Render the SAFE report.

## Before rendering

Check what the document will actually load. The Rmd defends against missing model results by
substituting `NA`/`0`, so a stale or absent `Models/rda_ModelsResLst.RData` produces a
plausible-looking table rather than an error.

1. Does `Models/rda_ModelsResLst.RData` exist, and is it newer than the model dirs it summarizes?
2. Do the case names in `03_build_results_object.R` still match `accepted_model` /
   `reference_model` in the Rmd setup chunk and the labels in `0-models.R`?

If either is off, say so and stop. Rendering a SAFE off stale results is the failure mode rule 1
exists to prevent.

## Invocation

```powershell
$RS = "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe"
& $RS 08_render_report.R
```

pandoc is not on the terminal PATH. `08_render_report.R` points `RSTUDIO_PANDOC` at the Positron
bundle (`%LOCALAPPDATA%/Programs/Positron/resources/app/quarto/bin/tools`). Rendering from inside
Positron/RStudio works without that. If the `stopifnot` at `08_render_report.R:17` fires, pandoc
wasn't found — report it rather than guessing another path.

## After rendering

- Report every knit warning. Silent `NA` substitution shows up here first.
- Note that the knit drops `tot_likes_t_<date>.csv` in the repo root
  (`SAFE_snow_gmacs.Rmd:979`) and it is not gitignored — see `docs/CLEANUP_BACKLOG.md` item 10.
- **Cross-check the numbers**: OFL and ABC must be identical in the Executive Summary management
  table, the OFL basis, the ABC basis, Section G, and Appendix B. They all read the same shared
  scalars, so any disagreement means something recomputed a value locally.
