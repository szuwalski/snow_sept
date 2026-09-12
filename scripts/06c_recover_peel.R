#!/usr/bin/env Rscript
## ============================================================================
## scripts/06c_recover_peel.R
##
## Re-run ONE retrospective peel from a supplied starting vector, verify it with
## 06's own verify_run(), and record it in retro/retro_diagnostics.csv.
##
## Why: 06 seeds every peel from the accepted fit. For 26.1b drop_survey peel 1
## (2026-09-12) the seeded run stopped at nll -22509.58 and its Hessian did not
## invert, while the first (cold) sweep had reached -22517.92 for the same peel;
## that cold .par survives in retro/_shapes/. Re-running from it recovers the
## better optimum (2026-09-12, per Grant). Backlog item 1g.
##
## Usage (repo root):
##   Rscript scripts/06c_recover_peel.R <model_dir> <mode> <peel> <pin_source.par>
## Then re-run `06_run_retrospective.R collect <model_dir>`.
##
## run_gmacs() and verify_run() are taken verbatim from 06 by parsing it, so the
## recovered peel passes exactly the checks every other peel passed.
## The failed run's gmacs.par / gmacs.pin / run.log are kept in <peel>/_seeded_failed/.
## ============================================================================
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4L)
  stop("Usage: Rscript scripts/06c_recover_peel.R <model_dir> <mode> <peel> <pin_source.par>")
MODEL_DIR <- args[1]; MODE <- args[2]; PEEL <- as.integer(args[3]); PIN_SRC <- args[4]
stopifnot("mode must be standard or drop_survey" = MODE %in% c("standard", "drop_survey"),
          "peel must be 1-10" = !is.na(PEEL) && PEEL >= 1L && PEEL <= 10L,
          "pin source not found" = file.exists(PIN_SRC))

source("R/gmacs_io.R")
EXE_NAME  <- gmacs_exe_name()
GRAD_WARN <- 1e-3                                   # same threshold as 06
for (e in parse("scripts/06_run_retrospective.R"))
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
      as.character(e[[2]]) %in% c("run_gmacs", "verify_run")) eval(e)
stopifnot("could not load run_gmacs/verify_run from 06" =
            exists("run_gmacs") && exists("verify_run"))

END_YEAR <- read_gmacs_echo(MODEL_DIR)$end_year     # the parent fit's terminal year
dir <- file.path(MODEL_DIR, "retro", MODE, PEEL)
stopifnot("peel directory not found" = dir.exists(dir))

bk <- file.path(dir, "_seeded_failed")
dir.create(bk, showWarnings = FALSE)
for (f in c("gmacs.pin", "gmacs.par", "run.log"))
  if (file.exists(file.path(dir, f))) file.copy(file.path(dir, f), bk, overwrite = TRUE)
stopifnot(file.copy(PIN_SRC, file.path(dir, "gmacs.pin"), overwrite = TRUE))

t0 <- Sys.time()
r  <- run_gmacs(dir)
v  <- verify_run(dir, sprintf("%s/%d", MODE, PEEL), END_YEAR - PEEL, t0, r, peel = PEEL)
print(v[, c("label", "ok", "terminal_year", "npar", "nll", "max_grad", "problems")], row.names = FALSE)
if (!isTRUE(v$ok)) stop("recovered peel failed verification: ", v$problems)

dfile <- file.path(MODEL_DIR, "retro", "retro_diagnostics.csv")
d <- read.csv(dfile, stringsAsFactors = FALSE)
i <- which(d$mode == MODE & d$peel == PEEL)
stopifnot("expected exactly one diagnostics row for this peel" = length(i) == 1L)
d[i, ] <- cbind(mode = MODE, peel = PEEL, v, stringsAsFactors = FALSE)[, names(d)]
write.csv(d, dfile, row.names = FALSE)
cat(sprintf("recorded %s peel %d: nll %.4f, max|grad| %.3g (seeded run kept in %s)\n",
            MODE, PEEL, v$nll, v$max_grad, bk))
