#--read model files and create the results object consumed by SAFE_snow_gmacs.Rmd
#--(September 2026 SAFE). Run from the snow_sept repo root:
#--   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 03_read_model_results.R
require(wtsGMACS)

#==repo root. De-hardcoded from rstudioapi::getActiveProject() so this runs headless / from a
#==terminal (not just inside an RStudio/Positron session). Assumes wd = snow_sept repo root.
dirPrj = getwd()

#devtools::install_github("wStockhausen/wtsQMD")

##--September model set: the 2025 rolled-forward REFERENCE and the ACCEPTED final model.
fldrs = c("Models/25_gmacs/",
          "Models/25_gmacs_update_newmat_plus_group/")

#--create full (absolute) paths FIRST (file.path() drops names), THEN assign the case labels.
#--These names MUST match the case selectors in SAFE_snow_gmacs.Rmd (reference_model /
#--accepted_model) and the labels in 0-models.R.
fldrs = file.path(dirPrj, fldrs)
names(fldrs) = c("25.1 gmacs",
                 "25.1 gmacs (update + compfix + plus group + new_mat)")

#--read model results (returns a `gmacs_reslst` object) and save next to the models,
#--where the Rmd expects it: wtsUtilities::getObj("Models/rda_ModelsResLst.RData")
resLst = wtsGMACS::readModelResults(fldrs)
wtsUtilities::saveObj(resLst, file.path(dirPrj, "Models", "rda_ModelsResLst.RData"))
