#!/usr/bin/env Rscript
## ============================================================================
## 00c_build_initscaled_model.R
##
## Builds Models/26_gmacs_initscaled/ -- the 26 model switched from GMACS
## initialisation mode 2 (FREEPARS) to mode 3 (FREEPARSSCALED). Nothing in any
## existing model directory is touched; this is not a core model folder and is
## not registered in 0-models.R.
##
## WHY. In mode 2 the 88 initial numbers-at-length ARE log(N) at syr, assigned
## straight into the population (gmacsbase.TPL:5642, :7659). The only term that
## touches them is a FIRST-DIFFERENCE smoothness penalty (:10409),
##     nlogPenalty(10) += dnorm(first_difference(logN0(k)), 1.0)
## weighted by ctl emphasis 10 = 5. First differences are invariant to adding a
## constant to a whole group, so the OVERALL 1982 ABUNDANCE OF EACH GROUP IS
## COMPLETELY UNPENALISED -- 4 free level dimensions. There is no prior either:
## prior_type 0 is dunif, which returns log(ub-lb), a constant with zero
## gradient, and :2099-2103 discards the ctl's p1/p2 for uniform priors. The
## ctl's "15 # Initial_devs" emphasis is dead code -- no nlogPenalty(5) exists.
##
## Mode 3 changes three things (:5649-5670, :7663-7669):
##   * the reference class (Refclass = 1, the FIRST row) is pinned to 0 and
##     stops being a parameter    -> 88 params become 87
##   * d4_N = exp(logRini + logN0)/sum(exp(logN0)), a simplex times exp(logRini)
##     -> the LEVEL is set by logRini instead of floating free
##   * TempSS += sum of squares of the active parameters, added UNWEIGHTED to
##     objfun (:10438) -> genuine shrinkage, effective sd 1/sqrt(2) = 0.707
##
## CAVEAT, measured before building (2026-08-29). That shrinkage is toward a
## FLAT size distribution. Evaluated at the 26 model's fitted structure the
## offsets span -28.4 to +4.3 and TempSS would be ~11,637 against an objective
## of ~-23,546. The optimiser will flatten the size structure and accept a worse
## data fit rather than pay that. Mode 3 therefore fixes the unconstrained level
## and buys a very strong, biologically implausible shape prior in exchange.
## Where it settles is the empirical question this model exists to answer.
##
## Run from the repo root:
##   Rscript 00c_build_initscaled_model.R
##
## Outputs
##   Models/26_gmacs_initscaled/            model inputs only -- NO fit
##   Models/26_gmacs_initscaled/PROVENANCE.md
##
## Builds INPUTS. Never runs gmacs (CLAUDE.md hard rule 10).
## ============================================================================

options(warn = 1)

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

SRC_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_update_newmat_plus_group")
DST_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_initscaled")
SRC_TREE  <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code")

## exp(LOGRINI_IVAL) is the total 1982 numbers. Set to the level the 26 model
## actually fits -- sum(exp(logN0)) = 9,341,497 -- so the run starts correctly
## SCALED with a flat shape, rather than at mode 2's ival of 0 (one crab per
## size class, 4-6 orders of magnitude from the solution).
LOGRINI_IVAL <- "16.04998"

rule <- function(x) message("\n== ", x, " ", strrep("=", max(0, 66 - nchar(x))))

## ---------------------------------------------------------------------------
## 1. Byte-preserving field edits (see 00b_build_stability_model.R)
## ---------------------------------------------------------------------------
.split_runs <- function(line) {
  m <- gregexpr("[[:space:]]+|[^[:space:]]+", line, useBytes = TRUE)
  regmatches(line, m)[[1]]
}

set_field <- function(line, k, value) {
  runs <- .split_runs(line)
  tok  <- which(!grepl("^[[:space:]]", runs, useBytes = TRUE))
  if (length(tok) < k)
    stop(sprintf("line has %d fields, field %d requested:\n%s", length(tok), k, line))
  i   <- tok[k]
  old <- runs[i]
  runs[i] <- as.character(value)
  d <- nchar(old, type = "bytes") - nchar(as.character(value), type = "bytes")
  if (d != 0L && i < length(runs) &&
      grepl("^[[:space:]]", runs[i + 1L], useBytes = TRUE)) {
    sep <- runs[i + 1L]
    if (d > 0L) {
      runs[i + 1L] <- paste0(sep, strrep(" ", d))
    } else if (nchar(sep, type = "bytes") + d >= 1L) {
      runs[i + 1L] <- substr(sep, 1L, nchar(sep, type = "bytes") + d)
    }
  }
  paste0(runs, collapse = "")
}

get_field <- function(line, k) {
  t <- toks(line)
  if (length(t) < k) NA_character_ else t[k]
}

## ---------------------------------------------------------------------------
## 2. Build the directory
## ---------------------------------------------------------------------------
rule("1. Build Models/26_gmacs_initscaled")

gc_src  <- read_gmacs_control(SRC_MODEL)
DATFILE <- gc_src$datafile
CTLFILE <- gc_src$ctlfile
PRJFILE <- gc_src$prjfile
message("source model : Models/", basename(SRC_MODEL))
message("  datafile   : ", DATFILE, "   control: ", CTLFILE, "   prj: ", PRJFILE)

if (dir.exists(DST_MODEL)) unlink(DST_MODEL, recursive = TRUE)
dir.create(DST_MODEL, recursive = TRUE)

## Inputs only. A new dir that inherits the template's gmacs.par / Gmacsall.out
## shows a complete, plausible fit belonging to the template (CLAUDE.md known
## traps; backlog 1e).
for (f in c(DATFILE, PRJFILE))
  stopifnot(file.copy(file.path(SRC_MODEL, f), file.path(DST_MODEL, f)))

## Stock 2.20.34, the binary that produced the accepted 26 fit -- NOT the
## recprop-sd1 variant built for 26_gmacs_stability. This model tests
## initialisation, so every other part of the likelihood must be identical.
stopifnot(file.copy(file.path(SRC_MODEL, gmacs_exe_name()),
                    file.path(DST_MODEL, gmacs_exe_name())))
Sys.chmod(file.path(DST_MODEL, gmacs_exe_name()), "755")
## The real 2.20.34 source, not the stale 2.20.32b copy the other model dirs
## carry (R/gmacs_jitter.R:39-43).
stopifnot(file.copy(file.path(SRC_TREE, "gmacsbase.TPL"),
                    file.path(DST_MODEL, "gmacsbase.TPL")))

## ---- 2a. snow.ctl -----------------------------------------------------------
ctl  <- read_raw_lines(file.path(SRC_MODEL, CTLFILE))
ctl0 <- ctl$lines
L    <- ctl0

## (i) initialisation mode 2 -> 3
i_mode <- grep("# Initial conditions", L, fixed = TRUE)
stopifnot("expected one 'Initial conditions' line" = length(i_mode) == 1L)
stopifnot("source model is not in mode 2" = get_field(L[i_mode], 1) == "2")
L[i_mode] <- set_field(L[i_mode], 1, "3")

## Refclass decides WHICH row stops being a parameter: gmacsbase.TPL:5659 pins
## the slot where Kpnt == Refclass-1, and Kpnt counts across all groups/classes.
i_ref <- grep("# Reference size-class for initial conditons", L, fixed = TRUE)
stopifnot("expected one Refclass line" = length(i_ref) == 1L)
REFCLASS <- as.integer(get_field(L[i_ref], 1))
stopifnot("this script assumes Refclass = 1 (the first theta row)" = REFCLASS == 1L)

## (ii) logRini becomes the level parameter. Mode 3 forbids estimating logR0
##      (:2124) but, unlike mode 2 (:2120), places NO restriction on logRini.
i_rini <- grep("# logRini", L, fixed = TRUE)
stopifnot("expected one logRini row" = length(i_rini) == 1L)
stopifnot("logRini is not fixed as expected" = get_field(L[i_rini], 7) == "-1")
L[i_rini] <- set_field(L[i_rini], 7, "1")
L[i_rini] <- set_field(L[i_rini], 1, LOGRINI_IVAL)

## logR0 must stay off (:2124 exits with an error otherwise).
i_r0 <- grep("# logR0", L, fixed = TRUE)
stopifnot("expected one logR0 row" = length(i_r0) == 1L)
stopifnot("logR0 must not be estimated in mode 3" =
            as.integer(get_field(L[i_r0], 7)) <= 0L)

## (iii) drop the reference row: mode 3 expects nclass*nsex*nmature*nshell - 1
##       initial-N parameters (:1756), i.e. 87 instead of 88.
i_dev <- grep("# Deviation for size-class", L, fixed = TRUE)
stopifnot("expected 88 initial-N rows" = length(i_dev) == 88L)
i_drop <- i_dev[REFCLASS]
stopifnot("the row being dropped is not size-class 1" =
            grepl("Deviation for size-class 1\\b", L[i_drop]))
L <- L[-i_drop]

ctl$lines <- L
write_raw_lines(ctl, file.path(DST_MODEL, CTLFILE))

## ---- 2b. gmacs.dat ----------------------------------------------------------
## The 26 model's pin is a 412-parameter mode-2 vector; this model has a
## different parameterisation and one fewer theta.
dat <- read_raw_lines(file.path(SRC_MODEL, "gmacs.dat"))
i_pin <- grep("use pin file", dat$lines, fixed = TRUE)
stopifnot("expected one 'use pin file' line" = length(i_pin) == 1L)
dat$lines[i_pin] <- set_field(dat$lines[i_pin], 1, "0")
write_raw_lines(dat, file.path(DST_MODEL, "gmacs.dat"))

## ---------------------------------------------------------------------------
## 3. Verification
## ---------------------------------------------------------------------------
rule("2. Verify")
md5 <- function(p) unname(tools::md5sum(p))

for (f in c(DATFILE, PRJFILE)) {
  same <- identical(md5(file.path(SRC_MODEL, f)), md5(file.path(DST_MODEL, f)))
  stopifnot(setNames(same, paste(f, "is not byte-identical to the source")))
  message("byte-identical to 26 model : ", f)
}

new <- read_raw_lines(file.path(DST_MODEL, CTLFILE))$lines
stopifnot("ctl should be exactly one line shorter" =
            length(new) == length(ctl0) - 1L)

## Rebuild what we intended and require the written file to equal it exactly.
expect <- ctl0
expect[i_mode] <- set_field(expect[i_mode], 1, "3")
expect[i_rini] <- set_field(set_field(expect[i_rini], 7, "1"), 1, LOGRINI_IVAL)
expect <- expect[-i_drop]
stopifnot("ctl differs from the intended edit" = identical(new, expect))
message("snow.ctl                   : 2 lines edited, 1 removed, nothing else")

n_dev <- length(grep("# Deviation for size-class", new, fixed = TRUE))
stopifnot("initial-N rows should now be 87" = n_dev == 87L)
j_mode <- grep("# Initial conditions", new, fixed = TRUE)
j_rini <- grep("# logRini", new, fixed = TRUE)
stopifnot("mode not 3"          = get_field(new[j_mode], 1) == "3",
          "logRini not phase 1" = get_field(new[j_rini], 7) == "1",
          "logRini ival wrong"  = get_field(new[j_rini], 1) == LOGRINI_IVAL)
message("initialisation mode        : 2 (FREEPARS) -> 3 (FREEPARSSCALED)")
message("initial-N rows             : 88 -> 87 (reference class ",
        REFCLASS, " pinned to 0)")
message("logRini                    : phase -1 -> 1, ival 15.0 -> ", LOGRINI_IVAL,
        "  (exp = ", format(round(exp(as.numeric(LOGRINI_IVAL))), big.mark = ","), ")")
message("theta rows                 : 98 -> 97 (GMACS expects 10 + 87)")

stale <- intersect(c("gmacs.par", "gmacs.std", "Gmacsall.out", "gmacs.rep",
                     "Gmacsall.std", "gmacs.pin", "gmacs.cor"),
                   list.files(DST_MODEL))
stopifnot("the new model dir contains a fit" = length(stale) == 0L)
message("no inherited fit           : ok")

## The executable must be the stock one, byte-identical to the 26 model's.
stopifnot("executable is not the stock 26 model binary" =
            identical(md5(file.path(SRC_MODEL, gmacs_exe_name())),
                      md5(file.path(DST_MODEL, gmacs_exe_name()))))
message("executable                 : stock 2.20.34, md5 ",
        substr(md5(file.path(DST_MODEL, gmacs_exe_name())), 1, 8),
        " (same as the 26 model)")

## ---------------------------------------------------------------------------
## 4. Provenance
## ---------------------------------------------------------------------------
writeLines(c(
  "# Models/26_gmacs_initscaled -- provenance",
  "",
  sprintf("Built %s by `00c_build_initscaled_model.R` from", format(Sys.Date())),
  "`Models/26_gmacs_update_newmat_plus_group/`. **Inputs only -- not fit.**",
  "Not a core model folder and not registered in `0-models.R`.",
  "",
  "## What changed",
  "",
  sprintf("`%s` and `%s` are byte-identical to the 26 model; the executable is the",
          DATFILE, PRJFILE),
  "same stock 2.20.34 binary. Only the initial-condition parameterisation differs.",
  "",
  "| Where | From | To |",
  "|---|---|---|",
  "| `snow.ctl` Initial conditions | 2 (FREEPARS) | **3 (FREEPARSSCALED)** |",
  sprintf("| `snow.ctl` logRini | phase -1, ival 15.0 | **phase 1, ival %s** |", LOGRINI_IVAL),
  "| `snow.ctl` initial-N rows | 88 | **87** (reference class dropped) |",
  "| `gmacs.dat` use pin file | 1 | 0 |",
  "",
  "## Why",
  "",
  "In mode 2 the 88 initial numbers-at-length are log(N) assigned straight into",
  "the 1982 population, and the ONLY term touching them is a first-difference",
  "smoothness penalty (`gmacsbase.TPL:10409`). First differences are invariant to",
  "shifting a whole group, so the overall 1982 abundance of each of the 4 groups",
  "is entirely unpenalised. There is no prior either -- `prior_type 0` is `dunif`,",
  "a constant with zero gradient, and `:2099-2103` discards the ctl's p1/p2 for",
  "uniform priors. The ctl's `15 # Initial_devs` emphasis is dead code; no",
  "`nlogPenalty(5)` exists in the TPL.",
  "",
  "Mode 3 pins the reference class to 0, makes the vector a simplex scaled by",
  "`exp(logRini)` so the level is a single bounded parameter, and adds",
  "`TempSS` = sum of squares of the active parameters directly to `objfun`",
  "(`:10438`) as genuine shrinkage.",
  "",
  "## Caveat measured before building",
  "",
  "`TempSS` is **unweighted** -- no emphasis factor -- and shrinks the size",
  "distribution toward FLAT. At the 26 model's fitted structure the offsets span",
  "-28.4 to +4.3 (51 of 82 exceed |2|) and TempSS would be **~11,637** against an",
  "objective of ~-23,546. The optimiser will flatten the size structure and accept",
  "a worse data fit rather than pay that. Mode 3 fixes the unconstrained level and",
  "buys a very strong, biologically implausible shape prior in exchange. Whether",
  "that trade is worth making is what this model was built to measure.",
  "",
  "## Next",
  "",
  "- Fit, then jitter, then compare against the 26 model on reference points",
  "  (nll is NOT comparable -- TempSS and the parameterisation both changed)."),
  file.path(DST_MODEL, "PROVENANCE.md"))

rule("Done")
message("Models/26_gmacs_initscaled/ built. Inputs only -- not fit.")
message("Contents: ", paste(sort(list.files(DST_MODEL)), collapse = "  "))
