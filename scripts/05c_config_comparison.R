#!/usr/bin/env Rscript
## ============================================================================
## 05c_config_comparison.R
##
## One row per model configuration: which of the three diagnosed convergence
## fixes it carries, and the reference points that result. Written so the effect
## of each fix can be ISOLATED rather than asserted.
##
## WHY THIS EXISTS. The three fixes were tested in different combinations, and
## attributing an OFL change to the wrong one is easy to do from memory. It
## happened: this author told the September SAFE session that the combined
## model's OFL rise was "driven mainly by" fixing the 2019 immature-female M
## deviation. The table below shows it is not -- the equilibrium initialisation
## contributes more on its own than the M and sex-ratio fixes together.
##
## THE THREE FIXES (diagnosed 2026-08-29 from the 26 model's 100-run jitter):
##   M_dev_fixed   the 2019 immature-female M deviation is the ONLY one of 412
##                 parameters that moves while the objective does not. Above a
##                 deviation of ~4 the annual survival is < 1e-10, so the
##                 likelihood is exactly flat there.
##   sexratio_sd   the annual penalty on the 44 recruitment sex-ratio logits.
##                 Hardcoded at 2.0 in stock GMACS (gmacsbase.TPL:10228), which
##                 lets 13 of 44 years saturate. A patched build uses 1.0.
##   init_mode     GMACS initial-condition mode. 2 = FREEPARS, 83 free 1982
##                 numbers-at-length whose LEVEL is entirely unpenalised.
##                 6 = EQMDEVS, an added mode: equilibrium backbone times
##                 exp(penalised deviations), after Rceattle initMode 2.
##
## READ THE fit_source COLUMN BEFORE COMPARING ROWS. A fit promoted from a
## jitter winner is not comparable to a cold start; the cold start may simply
## not have found its own configuration's best optimum.
##
## nll is NOT comparable across rows. The penalty set and the parameterisation
## both differ between configurations. Compare reference points.
##
## Run from the repo root:
##   Rscript 05c_config_comparison.R
##
## Output: data/diagnostics/model_config_comparison_<date>.csv
## ============================================================================

options(warn = 1)
REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))
source(file.path(REPO_ROOT, "R", "gmacs_jitter.R"))

OUT_DIR <- file.path(REPO_ROOT, "data", "diagnostics")
STAMP   <- format(Sys.Date())
BASE    <- "26_gmacs_update_newmat_plus_group"

MODELS <- c(BASE, "26_gmacs_stability", "26_gmacs_initscaled",
            "26_gmacs_eqmdevs", "26_gmacs_combined",
            "26_gmacs_male_only", "26_gmacs_male_only_eqmdevs")

get_field <- function(line, k) { t <- toks(line); if (length(t) < k) NA_character_ else t[k] }

## Read the configuration back OUT of the model's own ctl and binary, rather
## than hardcoding what each model was supposed to have been built with.
read_config <- function(md) {
  gc <- read_gmacs_control(md)
  C  <- read_raw_lines(file.path(md, gc$ctlfile))$lines

  i <- grep("# Initial conditions", C, fixed = TRUE)
  init_mode <- if (length(i) == 1L) as.integer(get_field(C[i], 1)) else NA_integer_

  ## The 2019 immature-female M deviation is the LAST of the four M "# Block 2"
  ## data rows; fixed means a negative phase.
  b <- grep("# Block 2", C, fixed = TRUE)
  b <- b[grepl("^[[:space:]]*[0-9.]", C[b])]
  m_fixed <- if (length(b) == 4L) as.integer(get_field(C[b[4]], 7)) < 0L else NA

  ## The sex-ratio sd lives in the TPL, not the ctl. Read it from the copy the
  ## model directory carries, which is the source its binary was built from for
  ## every patched model here.
  tp <- file.path(md, "gmacsbase.TPL")
  sd <- NA_character_
  if (file.exists(tp)) {
    L <- read_raw_lines(tp)$lines
    k <- grep("nloglike(4,3) = dnorm(logit_rec_prop_est,", L, fixed = TRUE)
    if (length(k) == 1L)
      sd <- sub(".*logit_rec_prop_est,[[:space:]]*([0-9.]+).*", "\\1", L[k])
  }

  e7 <- grep("# Mean_sex-Ratio", C, fixed = TRUE)
  e7 <- e7[grepl("^[[:space:]]*[0-9]", C[e7])]
  list(init_mode = init_mode, m_dev_fixed = m_fixed, sexratio_sd = sd,
       mean_sexratio_emphasis = if (length(e7) == 1L) get_field(C[e7], 1) else NA_character_)
}

terminal_mmb <- function(g) {
  L <- readLines(g, warn = FALSE)
  i <- grep("^Year SSB log\\(SSB\\)", L)[1]
  if (is.na(i)) return(NA_real_)
  j <- i + 1L; v <- NA_real_
  while (j <= length(L) && grepl("^[0-9]{4}[[:space:]]", L[j])) {
    v <- as.numeric(strsplit(trimws(L[j]), "[[:space:]]+")[[1]][2]); j <- j + 1L
  }
  v
}

rows <- list()
for (m in MODELS) {
  md <- file.path(REPO_ROOT, "Models", m)
  g  <- file.path(md, "Gmacsall.out")
  if (!dir.exists(md) || !file.exists(g)) { message("skip ", m, ": not fitted"); next }
  cf <- read_config(md)
  h  <- read_par_header(md)
  rp <- read_gmacsall_refpoints(g)
  L  <- readLines(g, warn = FALSE)
  mg <- suppressWarnings(as.numeric(sub("Maximum gradient: ", "",
          grep("^Maximum gradient", L, value = TRUE)[1])))
  rows[[m]] <- data.frame(
    model = m,
    fit_source = if (file.exists(file.path(md, "jitter", "PROMOTION.md")))
                   "jitter promotion" else "cold start",
    gmacs_version = gmacs_exe_version(md),
    init_mode = cf$init_mode, m_dev_fixed = cf$m_dev_fixed,
    sexratio_sd = cf$sexratio_sd,
    mean_sexratio_emphasis = cf$mean_sexratio_emphasis,
    npar = h$npar, nll = h$nll, max_abs_grad = abs(mg),
    BMSY = tryCatch(refpoint(rp, "BMSY"), error = function(e) NA_real_),
    OFL_tot = tryCatch(refpoint(rp, "OFL(tot)"), error = function(e) NA_real_),
    Bcurr_BMSY = tryCatch(refpoint(rp, "Bcurr/BMSY"), error = function(e) NA_real_),
    terminal_MMB = terminal_mmb(g),
    stringsAsFactors = FALSE)
}
d <- do.call(rbind, rows)
stopifnot("base model not found -- cannot compute deltas" = BASE %in% d$model)
base_ofl <- d$OFL_tot[d$model == BASE]
d$OFL_delta_vs_base     <- d$OFL_tot - base_ofl
d$OFL_pct_change_vs_base <- 100 * (d$OFL_tot - base_ofl) / base_ofl
rownames(d) <- NULL

if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)
f <- file.path(OUT_DIR, sprintf("model_config_comparison_%s.csv", STAMP))
write.csv(d, f, row.names = FALSE)

print(d[, c("model", "init_mode", "m_dev_fixed", "sexratio_sd", "fit_source",
            "npar", "OFL_tot", "OFL_delta_vs_base")], row.names = FALSE, digits = 6)
message("\nwrote ", sub(REPO_ROOT, ".", f, fixed = TRUE))
message("nll is NOT comparable across rows; compare reference points.")
