#!/usr/bin/env Rscript
## ============================================================================
## 05b_jitter_movement_decomposition.R
##
## Where does a jitter's parameter movement live? Decomposes, by sex class, how
## far each parameter travels across the near-equivalent optima a jitter finds.
##
## The question this answers: the 26 model's jitter lands on many optima that are
## nearly indistinguishable in likelihood but differ materially in OFL. If the
## parameters doing the moving are concentrated in one part of the model, that
## part is where the identifiability problem lives.
##
## MOVEMENT METRIC. For each parameter, the RANGE (max - min) of its estimate
## across the retained optima. Ranges are summed within a class and expressed as
## a share of the total. Range, not variance, so one run at an extreme counts as
## much as the spread of the rest -- these are alternative optima, not samples.
##
## WHICH RUNS ARE RETAINED. Runs that both converged (max|grad| < GRAD_USABLE,
## 1e-2, the screen 05_run_jitter.R uses) AND sit within NLL_WINDOW (2.0) of the
## best nll found. The window matters: comparing a failed run to a good one
## measures optimiser failure, not the shape of the likelihood near the optimum.
##
## Run from the repo root:
##   Rscript 05b_jitter_movement_decomposition.R [<model_dir_name> ...]
##
## Outputs (one per model, dated, following data/diagnostics/ convention):
##   data/diagnostics/jitter_movement_by_class_<model>_<date>.csv
##   data/diagnostics/jitter_movement_by_param_<model>_<date>.csv
##
## The by_class file carries n_parameters, total_range and share_pct so every
## percentage is re-derivable from the file itself; the by_param file is the
## per-parameter detail the class file aggregates, so the aggregation is
## checkable too.
## ============================================================================

options(warn = 1)
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) args <- "26_gmacs_update_newmat_plus_group"

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
GRAD_USABLE <- 1e-2      # matches 05_run_jitter.R
NLL_WINDOW  <- 2.0
OUT_DIR     <- file.path(REPO_ROOT, "data", "diagnostics")
STAMP       <- format(Sys.Date())

## ---------------------------------------------------------------------------
## 1. Reader
## ---------------------------------------------------------------------------
## Read the ESTIMATED parameters, BY NAME, from a run's Gmacsall.out.
##
## Deliberately NOT from gmacs.par. The .par groups parameters into blocks whose
## sizes depend on model structure (nsex, nmature, ...), and its slot count does
## not even match the Gmacsall.out name list -- 467 vs 462 for the two-sex model.
## An earlier version of this script mapped .par slots onto Gmacsall names using
## hardcoded block offsets taken from the two-sex model, which silently
## misclassified the male-only model (nsex = 1 shifts every offset) and mapped
## selectivity slots onto F deviations. Reading names and values from the same
## table removes that entire class of error: there is no offset to get wrong.
##
## Fixed parameters are excluded, which is what we want -- they cannot move.
read_estimated <- function(path) {
  L  <- readLines(path, warn = FALSE)
  i0 <- grep("^--Estimated parameters", L)[1]
  i1 <- grep("^>EOD<", L); i1 <- i1[i1 > i0][1]
  b  <- L[(i0 + 2):(i1 - 1)]
  m  <- regmatches(b, regexec("^[[:space:]]*([0-9]+)[[:space:]]+(.*?):[[:space:]]*(.*)$", b))
  m  <- m[sapply(m, length) == 4]
  f  <- strsplit(trimws(sapply(m, `[`, 4)), "[[:space:]]+")
  est <- sapply(f, length) >= 9            # estimated rows carry the full record
  setNames(as.numeric(sapply(f[est], `[`, 1)), sapply(m, `[`, 3)[est])
}

## ---------------------------------------------------------------------------
## 2. Per model
## ---------------------------------------------------------------------------
if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

for (MODEL in args) {
  MD <- file.path(REPO_ROOT, "Models", MODEL)
  JD <- file.path(MD, "jitter")
  rf <- file.path(JD, "jitter_results.csv")
  if (!file.exists(rf)) { message("skip ", MODEL, ": no jitter_results.csv"); next }

  j <- read.csv(rf, stringsAsFactors = FALSE)
  best <- min(j$objFun, na.rm = TRUE)
  keep <- which(j$maxGrad < GRAD_USABLE & j$objFun < best + NLL_WINDOW)
  dirs <- sprintf("%s/%03d", JD, j$idx[keep])
  ok   <- file.exists(file.path(dirs, "gmacs.par"))
  dirs <- dirs[ok]
  if (length(dirs) < 3) { message("skip ", MODEL, ": fewer than 3 retained optima"); next }

  ## One row per retained optimum, columns named by GMACS parameter name.
  pl <- lapply(file.path(dirs, "Gmacsall.out"), read_estimated)
  nm <- names(pl[[1]])
  stopifnot("runs disagree on the estimated-parameter set" =
              all(vapply(pl, function(x) identical(names(x), nm), logical(1))))
  P <- do.call(rbind, pl)
  rownames(P) <- basename(dirs)
  cn <- colnames(P)

  ## Classify on the GMACS parameter name itself. No offsets, no block
  ## arithmetic -- the name and the value come from the same table row.
  ##   - "sex allocation" (Logit_rec_prop) is its own class: it is neither male
  ##     nor female, it is the split between them.
  ##   - Log_fdov / Log_foff are the FEMALE offsets on fishing mortality.
  ## Order matters: later rules overwrite earlier ones.
  cls <- rep("shared (other)", ncol(P))
  cls[grepl("female", cn, ignore.case = TRUE)] <- "female"
  cls[grepl("male", cn, ignore.case = TRUE) &
        !grepl("female", cn, ignore.case = TRUE)] <- "male"
  cls[grepl("^Log_fdev|^Log_fbar", cn, ignore.case = TRUE)] <- "shared (fishing mortality)"
  cls[grepl("^Log_fdov|^Log_foff", cn, ignore.case = TRUE)] <- "female (F offsets)"
  cls[grepl("^Rec_dev_est", cn, ignore.case = TRUE)]        <- "shared (recruitment devs)"
  cls[grepl("^Logit_rec_prop", cn, ignore.case = TRUE)]     <- "sex allocation"

  ## A male-only model must contain no female parameters. If it does, the
  ## classification is wrong and every share below is untrustworthy.
  if (grepl("male_only", MODEL))
    stopifnot("male-only model classified female parameters -- classification is wrong" =
                !any(cls %in% c("female", "female (F offsets)")))

  rng <- apply(P, 2, function(x) diff(range(x)))
  tot <- sum(rng)

  by_param <- data.frame(
    model = MODEL, parameter = cn, class = cls, n_optima = nrow(P),
    min = apply(P, 2, min), max = apply(P, 2, max), range = rng,
    share_pct = 100 * rng / tot, stringsAsFactors = FALSE)
  by_param <- by_param[order(-by_param$range), ]

  agg <- aggregate(cbind(range) ~ class, data = by_param, FUN = sum)
  cnt <- aggregate(cbind(parameter) ~ class, data = by_param,
                   FUN = length)
  by_class <- merge(agg, cnt, by = "class")
  names(by_class)[names(by_class) == "parameter"] <- "n_parameters"
  names(by_class)[names(by_class) == "range"] <- "total_range"
  by_class$mean_range <- by_class$total_range / by_class$n_parameters
  by_class$share_pct  <- 100 * by_class$total_range / tot
  by_class <- by_class[order(-by_class$total_range), ]
  by_class <- data.frame(model = MODEL, n_optima = nrow(P),
                         grad_screen = GRAD_USABLE, nll_window = NLL_WINDOW,
                         by_class, total_range_all_classes = tot,
                         row.names = NULL, stringsAsFactors = FALSE)

  stopifnot("class shares do not sum to 100" =
              isTRUE(all.equal(sum(by_class$share_pct), 100)))

  f1 <- file.path(OUT_DIR, sprintf("jitter_movement_by_class_%s_%s.csv", MODEL, STAMP))
  f2 <- file.path(OUT_DIR, sprintf("jitter_movement_by_param_%s_%s.csv", MODEL, STAMP))
  write.csv(by_class, f1, row.names = FALSE)
  write.csv(by_param, f2, row.names = FALSE)

  message("\n== ", MODEL, " ==")
  message("retained optima: ", nrow(P), " (max|grad| < ", GRAD_USABLE,
          " and within ", NLL_WINDOW, " nll of the best)")
  print(by_class[, c("class", "n_parameters", "total_range", "mean_range", "share_pct")],
        row.names = FALSE, digits = 4)
  fem <- sum(by_class$share_pct[by_class$class %in%
                                  c("female", "female (F offsets)", "sex allocation")])
  message(sprintf("female + sex-allocation share: %.1f%%", fem))
  message("wrote ", sub(REPO_ROOT, ".", f1, fixed = TRUE))
  message("wrote ", sub(REPO_ROOT, ".", f2, fixed = TRUE))
}
