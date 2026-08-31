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
# MODEL NUMBERING (Grant, 2026-08-29). The shortnames below are what the report
# shows; the long labels are internal case keys only and still carry the earlier
# "25.1/26.1 gmacs (...)" wording -- that is cosmetic and deliberately NOT
# churned, because those strings are the join key across 0-models.R,
# 03_build_results_object.R and the Rmd's accepted_model selector.
#
# RENUMBERED to 26.x on 2026-08-29, following the May 2026 CPT report:
# "The base model brought forward was model 25.3 (which was mistakenly labeled
# as model 25 in the proposed model document and presentation)" and "Numbers for
# new models that were brought forward at this meeting were mistakenly labeled
# as corresponding to 2025 rather than 2026, and this will be corrected for the
# September CPT meeting." The September 2025 CPT report says the same of the
# 2025 document ("mistakenly labeled as model 25.1"). The previous scheme here
# (Model 25 / 25.2c / 25.2e / 25.2e (new data) / 25.2e (2019 data) / 26.1) was
# the labelling the CPT identified as mistaken.
#
# The scheme follows the review checklist: "Model yy.j" for a major change,
# "Model yy.jx" for a minor one, where yy is the year. A run that only changes
# the data is minor and takes a letter; a change to the model itself takes a new
# integer.
#   Model 25.3   the September 2025 accepted assessment, rolled forward. Its
#                correct number per both CPT reports; GMACS 2.20.22.
#   Model 26.1   the configuration accepted by the CPT in May 2026 -- GMACS
#                2.20.34, total-male composition corrected, plus group expanded,
#                new maturity workflow. Terminal 2024. The step-change baseline.
#   Model 26.1a  as 26.1 with the binning convention (right = FALSE) and the
#                growth transcription error corrected. Terminal 2024. Data
#                corrections only, hence a letter.
#   Model 26.1b  the RECOMMENDED model -- 26.1a advanced to end year 2025
#                (fishery through 2025, survey through 2026). Data only.
#   Model 26.1c  26.1b truncated to 2019, the May 2026 CPT diagnostic request.
#                Data only.
#   Model 26.2   male-only sensitivity, requested by the May 2026 CPT. Structural
#                -- nsex = 1 removes the female population, parameters and data
#                (412 -> 234 estimated parameters) -- so a new integer rather
#                than a letter. Not proposed for specification unless the CPT
#                selects it.
#
# CROSS-VALIDATION AGAINST THE SSC. The checklist also requires model numbers to
# match those the SSC endorsed, and the June 2026 SSC report refers to the
# accepted configuration as "Model 25.2c". That is Model 26.1 here. The mapping
# from the May 2026 numbering is therefore stated explicitly in Section E of the
# report, and it is:
#   25.3 -> 25.3 | 25.2c -> 26.1 | 25.2e -> 26.1a
#   25.2e (new data) -> 26.1b | 25.2e (2019 data) -> 26.1c | 26.1 (male-only) -> 26.2
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
  "25.1 gmacs"                                                       = "Model 25.3",
  "25.1 gmacs (update + compfix + plus group + new_mat)"             = "Model 26.1",
  "25.1 gmacs (update + compfix + plus group + new_mat + data-fix)"  = "Model 26.1a",
  "26.1 gmacs (update + compfix + plus group + new_mat)"             = "Model 26.1b",
  "26.1 gmacs (update + compfix + plus group + new_mat + male_only)" = "Model 26.2",
  "26.1 gmacs (update + compfix + plus group + new_mat + data2019)"  = "Model 26.1c"
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
#-- Display order for tables, figure legends and column headers ------------
# model_defs is ordered by folder/lineage, which since the 2026-08-29
# renumbering no longer reads in model-number order (the male-only run, 26.2,
# sits before the 2019 diagnostic, 26.1c). The report must present them in
# numerical order -- the review checklist asks for tables and figures to be
# correctly labelled and ordered -- so state that order once, here, rather than
# reordering model_defs and disturbing the folder listing it mirrors.
model_order <- c("Model 25.3", "Model 26.1", "Model 26.1a",
                 "Model 26.1b", "Model 26.1c", "Model 26.2")
stopifnot("model_order does not match model_shorts" =
            setequal(model_order, unname(model_shorts)))

to_short <- function(x, factor = TRUE) {
  out <- ifelse(x %in% names(model_shorts), model_shorts[x], x)
  if (factor) out <- factor(out, levels = unique(c(model_order, out)))
  unname(out)
}

#-- Convergence experiments (2026-08-30, per Grant) ------------------------
# DELIBERATELY NOT IN model_defs. These three were built to diagnose the 26
# model's multimodality, not to be assessment candidates, and they must not
# enter the model-comparison tables. The reason is that their objective
# functions are not the same function:
#
#   26.d1 stability   forked TPL (GMACS_tpl-cpp_code_recprop_sd1): the sex-ratio
#                     penalty sd is hardcoded, changed 2.0 -> 1.0
#   26.d2 initscaled  stock binary, but initial conditions mode 2 -> 3
#                     (FREEPARSSCALED) drops the reference class and rescales
#   26.d3 eqmdevs     forked TPL (GMACS_tpl-cpp_code_eqmdevs): adds
#                     nlogPenalty(5), a term that does not exist in 2.20.34
#
# So a likelihood comparison against the six above is meaningless: eqmdevs
# reports nll -23886.01 against the accepted model's -23546.35 while its DATA
# component (catch + index + size + stock-recruit + tagging + growth) is 36 units
# WORSE. Only within-model convergence statistics -- how
# often a model recovers its own best optimum -- are comparable across this set,
# and that is all the convergence appendix reports.
#
# The shared tree GMACs/GMACS_tpl-cpp_code is byte-unchanged (md5
# b5392eea9d2956816b36acbae7c2c317), asserted at every build.
diagnostic_models <- c(
  "26.d1 stability"  = "Models/26_gmacs_stability/",
  "26.d2 initscaled" = "Models/26_gmacs_initscaled/",
  "26.d3 eqmdevs"    = "Models/26_gmacs_eqmdevs/",
  "26.d4 combined"   = "Models/26_gmacs_combined/",
  "26.d5 male-only + eqmdevs" = "Models/26_gmacs_male_only_eqmdevs/"
)

# Which pathology each one addresses. The diagnostic found THREE independent
# problems; each experiment fixed a different subset and none fixed all three,
# which is why none of them resolved the multimodality.
diagnostic_purpose <- c(
  "26.d1 stability"  = "Fixes the non-identified 2019 immature-female M deviation and the recruitment sex-ratio penalty; leaves the unpenalised 1982 initial numbers.",
  "26.d2 initscaled" = "Rescales the initial-condition parameterisation (GMACS mode 3). Not jittered: the data fit was 138 nll units worse and it was set aside.",
  "26.d3 eqmdevs"    = "Replaces the 83 unpenalised 1982 initial numbers with an equilibrium backbone times penalised deviations; leaves the other two.",
  "26.d4 combined"   = "All three fixes at once on the two-sex model. Its printed '16.7% at the best mode' is NOT the recovery rate: mode A sits 5.89 nll below its own best fit, which only 2 of 72 converged runs reached.",
  "26.d5 male-only + eqmdevs" = "Model 26.2 with the 26.d3 equilibrium backbone. The only configuration tested that improved recovery of its own best fit (41.2% vs 26.2's 25.3%, Fisher p = 0.034), and the only one whose usable runs span 6.3 nll rather than 128-312."
)

# Jitter results live in per-model files. This USED to be a workaround: until
# 2026-08-30 05_run_jitter.R wrote Models/rda_jitter.RData and five fixed plot
# paths regardless of --model, so every run overwrote the last and a diagnostic
# jitter could silently replace the accepted model's diagnostics under the
# accepted model's labels. That is now fixed at source -- 05 writes
# Models/rda_jitter_<tag>.RData and plots/*_<tag>.png for every model, and only
# touches the shared paths when --model is the report model. The per-model files
# below are therefore what the pipeline produces, not hand-kept copies.
# NA means the model was not jittered.
diagnostic_jitter <- c(
  "26.d1 stability"  = "Models/rda_jitter_stability.RData",
  "26.d2 initscaled" = NA_character_,
  "26.d3 eqmdevs"    = "Models/rda_jitter_eqmdevs.RData",
  "26.d4 combined"   = "Models/rda_jitter_combined.RData",
  "26.d5 male-only + eqmdevs" = "Models/rda_jitter_male_only_eqmdevs.RData"
)

stopifnot("diagnostic_purpose does not cover diagnostic_models" =
            setequal(names(diagnostic_purpose), names(diagnostic_models)))
stopifnot("diagnostic_jitter does not cover diagnostic_models" =
            setequal(names(diagnostic_jitter), names(diagnostic_models)))
stopifnot("a diagnostic model must never be in model_defs" =
            !any(diagnostic_models %in% model_defs))

local({
  gone <- names(diagnostic_models)[!dir.exists(diagnostic_models)]
  if (length(gone))
    warning("0-models.R: diagnostic model folder(s) not found: ",
            paste(gone, collapse = ", "), call. = FALSE, immediate. = TRUE)
})

