#-- Define Models (Labels and Folder Paths) ----
# Using a named vector directly ensures each folder has a unique label
# and prevents length mismatches.
#
# THE SEPTEMBER 2026 SET. Pruned 2026-08-28 from the 14-model May candidate
# bracket to the six models this cycle actually runs. The May bracket is not
# lost -- it lives in the May repo's own 0-models.R (../snow_crab/0-models.R)
# and in this file's git history.
#
# Pruning was gated on the audit the old port note called for ("audit every
# model_defs[N] use in the Rmd"). That audit was done before pruning and found
# NO positional indexing anywhere: every reference to model_defs/model_shorts is
# by name (report_model <- model_defs[accepted_model]), by loop, or whole-vector,
# and the results object is likewise keyed by case name
# (reslst$repsLst[[accepted_model]]), never by position. The one "model_defs[1]"
# in the Rmd is a comment recording a reference that had already been removed.
#
# MODEL NUMBERING (Grant, 2026-08-28). The shortnames below are what the report
# shows; the long labels are internal case keys only and still carry the earlier
# "26.1 gmacs (...)" wording -- that is cosmetic and deliberately NOT churned,
# because those strings are the join key across 0-models.R,
# 03_build_results_object.R and the Rmd's accepted_model selector.
# Set with the Plan Team, 2026-08-28. The scheme distinguishes DATA variants from
# STRUCTURAL ones: a run that only changes the data keeps its parent's number and
# takes a parenthetical, while a change to the model itself takes a new number.
#   Model 25                 the September 2025 assessment, rolled forward.
#   Model 25.2c              the MAY accepted fit (terminal 2024), the step-change
#                            baseline and the number the SSC endorsed.
#   Model 25.2e              binning (right = FALSE) + growth-typo methodology
#                            sensitivity, terminal 2024. "e" because 25.2d was
#                            already the immature-index model.
#   Model 25.2e (new data)   the RECOMMENDED model -- the 25.2e configuration
#                            advanced to end year 2025 (fishery through 2025,
#                            survey through 2026). Data change only, so it keeps
#                            the 25.2e number. Numbered from 25.2e rather than
#                            25.2c because it carries the right = FALSE binning
#                            and the growth-typo fix.
#   Model 25.2e (2019 data)  the same configuration truncated to 2019, a May 2026
#                            CPT request: tests whether the convergence problems
#                            originate in estimating recruitment after the 2018-19
#                            collapse and across the missing 2020 survey. Also a
#                            data change only.
#   Model 26.1               male-only sensitivity, requested by the May 2026 CPT.
#                            This one IS structural -- nsex = 1 removes the female
#                            population, parameters and data (412 -> 234 estimated
#                            parameters) -- so it takes a new number rather than a
#                            parenthetical. Not proposed for specification unless
#                            the CPT selects it.
# The May 2026 CPT minutes call the accepted configuration "Model 25.2c"; the
# SAFE review checklist requires model numbers to be cross-validated against the
# numbers the SSC endorsed, so state the mapping explicitly in the report text.
model_defs <- c(
  "25.1 gmacs"                                                       = "Models/25_gmacs/",
  "25.1 gmacs (update + compfix + plus group + new_mat)"             = "Models/25_gmacs_update_newmat_plus_group/",
  "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)"  = "Models/25_gmacs_rightFALSE_growthfix/",
  "26.1 gmacs (update + compfix + plus group + new_mat)"             = "Models/26_gmacs_update_newmat_plus_group/", # RECOMMENDED
  "26.1 gmacs (update + compfix + plus group + new_mat + male_only)" = "Models/26_gmacs_male_only/",
  "26.1 gmacs (update + compfix + plus group + new_mat + data2019)"  = "Models/26_gmacs_data2019/"
)


#-- Compact shortnames for tables and figures -----------------------------
# One-to-one map keyed by the long labels in `model_defs`. The long labels are
# INTERNAL case keys only -- they must match the names assigned in
# 03_build_results_object.R and the case selectors in SAFE_snow_gmacs.Rmd, but
# they never reach a table or figure. Everything the reader sees is the
# letter-based shortname, applied via to_short().
model_shorts <- c(
  "25.1 gmacs"                                                       = "Model 25",
  "25.1 gmacs (update + compfix + plus group + new_mat)"             = "Model 25.2c",
  "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)"  = "Model 25.2e",
  "26.1 gmacs (update + compfix + plus group + new_mat)"             = "Model 25.2e (new data)",
  "26.1 gmacs (update + compfix + plus group + new_mat + male_only)" = "Model 26.1",
  "26.1 gmacs (update + compfix + plus group + new_mat + data2019)"  = "Model 25.2e (2019 data)"
)


#-- Which models were jittered --------------------------------------------
# Lives here, keyed by the same labels, rather than as a positional vector in
# the Rmd's model-overview chunk. A positional list silently misaligns every row
# below an insertion point, and R only errors when the lengths do not divide
# evenly -- so 14 against 28 would have recycled without complaint.
model_jittered <- c(
  "25.1 gmacs"                                                       = "n",
  "25.1 gmacs (update + compfix + plus group + new_mat)"             = "Y",
  "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)"  = "n",
  "26.1 gmacs (update + compfix + plus group + new_mat)"             = "Y",
  "26.1 gmacs (update + compfix + plus group + new_mat + male_only)" = "Y",
  "26.1 gmacs (update + compfix + plus group + new_mat + data2019)"  = "Y"
)

#-- Model type and purpose -------------------------------------------------
# The SAFE checklist requires the type and purpose of every model discussed to
# be stated: diagnostic, research, or for consideration for harvest specs.
# Keyed by the same long labels, for the same reason as model_jittered.
#
# None is "harvest specs" this cycle: the June 2026 SSC directed that only the
# Tier 4 model be brought forward in October, and Tier 4 is computed from the
# REMA-smoothed survey series rather than from any of these fits.
model_type <- c(
  "25.1 gmacs"                                                       = "Reference",
  "25.1 gmacs (update + compfix + plus group + new_mat)"             = "Research",
  "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)"  = "Research",
  "26.1 gmacs (update + compfix + plus group + new_mat)"             = "Research",
  "26.1 gmacs (update + compfix + plus group + new_mat + male_only)" = "Research",
  "26.1 gmacs (update + compfix + plus group + new_mat + data2019)"  = "Diagnostic"
)
model_purpose <- c(
  "25.1 gmacs"                                                       = "The 2025 accepted model (GMACS 2.20.22), carried as the bridge from the previous assessment.",
  "25.1 gmacs (update + compfix + plus group + new_mat)"             = "Carries the composition correction, expanded plus group and new maturity workflow endorsed in May and June 2026.",
  "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)"  = "As above with the data corrections applied; documents the effect of those corrections.",
  "26.1 gmacs (update + compfix + plus group + new_mat)"             = "The same configuration advanced to the 2025 fishery and 2026 survey; author-recommended Tier 3 model.",
  "26.1 gmacs (update + compfix + plus group + new_mat + male_only)" = "Simplification sensitivity: removes the female population, addressing the SSC's request to reduce the parameter set.",
  "26.1 gmacs (update + compfix + plus group + new_mat + data2019)"  = "Convergence diagnostic: data truncated to 2019 to test whether the recent data drive the multimodality."
)
stopifnot("model_type does not cover model_defs" =
            setequal(names(model_type), names(model_defs)))
stopifnot("model_purpose does not cover model_defs" =
            setequal(names(model_purpose), names(model_defs)))


# Sanity checks: the three maps must describe exactly the same models.
stopifnot(all(names(model_defs) %in% names(model_shorts)))
stopifnot(!anyDuplicated(model_shorts))
stopifnot("model_jittered does not cover model_defs" =
            setequal(names(model_jittered), names(model_defs)))

# A missing folder is not fatal -- a model may not be built yet -- but it must
# be visible, because the Rmd otherwise renders it as a row of NAs or zeros.
local({
  gone <- names(model_defs)[!dir.exists(model_defs)]
  if (length(gone))
    warning("0-models.R: model folder(s) not found, so these will be dropped from ",
            "the report's model set: ", paste(model_shorts[gone], collapse = ", "),
            call. = FALSE, immediate. = TRUE)
})


#-- Helper: convert long label(s) to shortname(s) -------------------------
# Vectorised, preserves order, leaves anything not in the lookup unchanged
# (so it's safe to apply to a `case` column that may include intermediate
# labels). Returns a factor whose level order follows `model_defs` so
# ggplot legends and kable column orders stay consistent across chunks.
to_short <- function(x, factor = TRUE) {
  out <- ifelse(x %in% names(model_shorts), model_shorts[x], x)
  if (factor) {
    lvls <- unname(model_shorts[names(model_defs)])
    out  <- factor(out, levels = unique(c(lvls, out)))
  }
  unname(out)
}
