#--read model files and create the results object consumed by 2026_snowcrab_safe_draft.Rmd
#--(September 2026 SAFE). Run from the snow_sept repo root:
#--   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 03_build_results_object.R
require(wtsGMACS)

#==repo root. De-hardcoded from rstudioapi::getActiveProject() so this runs headless / from a
#==terminal (not just inside an RStudio/Positron session). Assumes wd = snow_sept repo root.
dirPrj = getwd()

#devtools::install_github("wStockhausen/wtsQMD")

##--September 2026 model set. Shortnames (Model 25.3, 26.1, ...) live in 0-models.R;
##--the long strings below are INTERNAL case keys only and never reach the report,
##--which shows the letter-based designations via to_short(). Renumbered to 26.x on
##--2026-08-29 per the May 2026 CPT report; see the numbering block in 0-models.R.
##--   Model 25.3   Models/25_gmacs/                          2025 rolled-forward REFERENCE
##--   Model 26.1   Models/25_gmacs_update_newmat_plus_group/  MAY accepted (terminal 2024)
##--   Model 26.1a  Models/25_gmacs_rightFALSE_growthfix/      binning + growth-typo corrections
##--   Model 26.1b  Models/26_gmacs_update_newmat_plus_group/  RECOMMENDED (terminal 2025)
##--   Model 26.2   Models/26_gmacs_male_only/                 male-only sensitivity of 26.1b
##--   Model 26.1c  Models/26_gmacs_data2019/                  data through 2019 diagnostic
fldrs = c("Models/25_gmacs/",
          "Models/25_gmacs_update_newmat_plus_group/",
          "Models/25_gmacs_rightFALSE_growthfix/",
          "Models/26_gmacs_update_newmat_plus_group/",
          "Models/26_gmacs_male_only/",
          "Models/26_gmacs_data2019/")

#--create full (absolute) paths FIRST (file.path() drops names), THEN assign the case labels.
#--These names MUST match the case selectors in 2026_snowcrab_safe_draft.Rmd (reference_model /
#--accepted_model) and the labels in 0-models.R.
fldrs = file.path(dirPrj, fldrs)
names(fldrs) = c("25.1 gmacs",
                 "25.1 gmacs (update + compfix + plus group + new_mat)",
                 "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)",
                 "26.1 gmacs (update + compfix + plus group + new_mat)",
                 "26.1 gmacs (update + compfix + plus group + new_mat + male_only)",
                 "26.1 gmacs (update + compfix + plus group + new_mat + data2019)")

#--Enforce the three-way agreement CLAUDE.md requires (this file, 0-models.R, the Rmd)
#--instead of leaving it to a comment. A label that drifts here produces a results
#--object the Rmd silently fills with NA rather than an error.
local({
  e = new.env()
  sys.source(file.path(dirPrj, "scripts", "0-models.R"), envir = e)
  missing = setdiff(names(fldrs), names(e$model_defs))
  if (length(missing))
    stop("Case label(s) not in 0-models.R model_defs: ", paste(missing, collapse = "; "))
  want = file.path(dirPrj, unname(e$model_defs[names(fldrs)]))
  if (!all(normalizePath(want, mustWork = FALSE) == normalizePath(fldrs, mustWork = FALSE)))
    stop("Folder(s) here disagree with 0-models.R for the same label.")
  gone = fldrs[!dir.exists(fldrs)]
  if (length(gone)) stop("Model folder(s) do not exist: ", paste(gone, collapse = "; "))
})

#--read model results (returns a `gmacs_reslst` object) and save next to the models,
#--where the Rmd expects it: wtsUtilities::getObj("Models/rda_ModelsResLst.RData")
resLst = wtsGMACS::readModelResults(fldrs)
wtsUtilities::saveObj(resLst, file.path(dirPrj, "Models", "rda_ModelsResLst.RData"))
