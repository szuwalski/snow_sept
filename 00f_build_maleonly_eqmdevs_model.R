#!/usr/bin/env Rscript
## ============================================================================
## 00f_build_maleonly_eqmdevs_model.R
##
## Builds Models/26_gmacs_male_only_eqmdevs/ -- Model 26.2 (male-only) with the
## equilibrium-backbone initialisation (GMACS mode 6, EQMDEVS) added. Not a core
## model folder; not registered in 0-models.R.
##
## WHY THIS COMBINATION. Male-only is the only configuration that reliably
## recovers its own best fit (21/83 = 25.3% against ~1-3% for every two-sex
## configuration tested, Fisher p < 0.0001). The movement decomposition says why:
## it deletes the sex allocation, which carries 41.1% of all parameter movement
## in the accepted model at six times the per-parameter rate of male parameters.
##
## What remains moving in male-only is dominated by shared recruitment
## deviations (51.7% of a much smaller total, 1.82 against the two-sex 64.04),
## concentrated in Rec_dev_est_2019 and Rec_dev_est_2020 -- the COVID survey-gap
## years. The equilibrium backbone is precisely what anchors the early population
## those deviations trade against, so this is the one untested combination with a
## mechanism behind it: apply the fix that worked on the male/structural side
## (male-parameter movement fell 83%, 10.11 -> 1.76, under mode 6) to the only
## configuration whose surface is healthy enough to benefit.
##
## WHAT CHANGES, relative to Models/26_gmacs_male_only:
##   Initial conditions   2 (FREEPARS) -> 6 (EQMDEVS)
##   logRini              phase -1 -> 1, ival 15.0 -> LOGRINI_IVAL
##   emphasis 5           15 -> 1.0   (the deviation penalty weight; dead code in
##                                     stock GMACS, wired up by the mode-6 patch)
##   gmacs.dat use pin    1 -> 0
## The 44 initial numbers-at-length become log-deviations around the equilibrium.
## Male-only has no rows pinned at -19 and no female parameters, so neither of
## the two-sex special cases applies.
##
## EXECUTABLE. The eqmdevs fork is used unchanged. Its OTHER patch -- the
## sex-ratio deviation penalty sd 2.0 -> 1.0 -- is a NO-OP here: gmacsbase.TPL
## sets rec_prop_phz = -1 when nsex == 1 (:1651), so logit_rec_prop_est is never
## active and nloglike(4,3) is never evaluated. Verified after fitting by
## checking that component is zero.
##
## Run from the repo root:
##   Rscript 00f_build_maleonly_eqmdevs_model.R
##
## Builds INPUTS only. Never runs the model (CLAUDE.md rule 10).
## ============================================================================

options(warn = 1)
REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

SRC_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_male_only")
DST_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_male_only_eqmdevs")
EQM_TREE  <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code_eqmdevs")

## exp(LOGRINI_IVAL) is the equilibrium RECRUITMENT the size-transition matrix is
## driven with. Male-only's fitted Log(Rbar) is 12.99895, so start there.
LOGRINI_IVAL     <- "13.00"
INITDEV_EMPHASIS <- "1.0"

rule <- function(x) message("\n== ", x, " ", strrep("=", max(0, 64 - nchar(x))))

.split_runs <- function(line) {
  m <- gregexpr("[[:space:]]+|[^[:space:]]+", line, useBytes = TRUE)
  regmatches(line, m)[[1]]
}
set_field <- function(line, k, value) {
  runs <- .split_runs(line)
  tok  <- which(!grepl("^[[:space:]]", runs, useBytes = TRUE))
  if (length(tok) < k) stop("too few fields: ", line)
  i <- tok[k]; old <- runs[i]; runs[i] <- as.character(value)
  d <- nchar(old, type = "bytes") - nchar(as.character(value), type = "bytes")
  if (d != 0L && i < length(runs) && grepl("^[[:space:]]", runs[i + 1L], useBytes = TRUE)) {
    sep <- runs[i + 1L]
    if (d > 0L) runs[i + 1L] <- paste0(sep, strrep(" ", d))
    else if (nchar(sep, type = "bytes") + d >= 1L)
      runs[i + 1L] <- substr(sep, 1L, nchar(sep, type = "bytes") + d)
  }
  paste0(runs, collapse = "")
}
get_field <- function(line, k) { t <- toks(line); if (length(t) < k) NA_character_ else t[k] }

## ---------------------------------------------------------------------------
## 1. Build
## ---------------------------------------------------------------------------
rule("1. Build Models/26_gmacs_male_only_eqmdevs")
stopifnot("eqmdevs fork not found -- run 00d first" = dir.exists(EQM_TREE))
exe_path <- file.path(EQM_TREE, gmacs_exe_name())
stopifnot("eqmdevs binary not built" = file.exists(exe_path))

gc_src  <- read_gmacs_control(SRC_MODEL)
DATFILE <- gc_src$datafile; CTLFILE <- gc_src$ctlfile; PRJFILE <- gc_src$prjfile
message("source model : Models/", basename(SRC_MODEL))
message("  datafile   : ", DATFILE, "   control: ", CTLFILE)

if (dir.exists(DST_MODEL)) unlink(DST_MODEL, recursive = TRUE)
dir.create(DST_MODEL, recursive = TRUE)
for (f in c(DATFILE, PRJFILE))
  stopifnot(file.copy(file.path(SRC_MODEL, f), file.path(DST_MODEL, f)))

ctl <- read_raw_lines(file.path(SRC_MODEL, CTLFILE)); C0 <- ctl$lines; C <- C0

i_mode <- grep("# Initial conditions", C, fixed = TRUE)
stopifnot("source is not mode 2" = length(i_mode) == 1L && get_field(C[i_mode], 1) == "2")
C[i_mode] <- set_field(C[i_mode], 1, "6")

i_rini <- grep("# logRini", C, fixed = TRUE)
stopifnot("logRini not fixed as expected" = get_field(C[i_rini], 7) == "-1")
C[i_rini] <- set_field(set_field(C[i_rini], 7, "1"), 1, LOGRINI_IVAL)

i_r0 <- grep("# logR0", C, fixed = TRUE)
stopifnot("logR0 must stay off in mode 6" = as.integer(get_field(C[i_r0], 7)) <= 0L)

## nsex = 1 -> 22 classes x 1 sex x 2 maturity x 1 shell = 44 rows, none pinned.
i_dev <- grep("# Deviation for size-class", C, fixed = TRUE)
stopifnot("expected 44 initial rows for a male-only model" = length(i_dev) == 44L)
ph <- vapply(C[i_dev], get_field, character(1), k = 7L, USE.NAMES = FALSE)
stopifnot("expected every male-only initial row in phase 1" = all(ph == "1"))
stopifnot("male-only ctl unexpectedly has rows pinned at -19" =
            !any(vapply(C[i_dev], get_field, character(1), k = 1L, USE.NAMES = FALSE) == "-19"))

i_e5 <- grep("# Initial_devs", C, fixed = TRUE)
i_e5 <- i_e5[grepl("^[[:space:]]*[0-9]", C[i_e5])]
stopifnot("expected one Initial_devs emphasis row" = length(i_e5) == 1L,
          "Initial_devs emphasis is not 15" = get_field(C[i_e5], 1) == "15")
C[i_e5] <- set_field(C[i_e5], 1, INITDEV_EMPHASIS)

ctl$lines <- C; write_raw_lines(ctl, file.path(DST_MODEL, CTLFILE))

## The source model's gmacs.pin is its promoted 234-parameter vector; this model
## has a different parameterisation, so it is neither copied nor read.
dat <- read_raw_lines(file.path(SRC_MODEL, "gmacs.dat"))
i_pin <- grep("use pin file", dat$lines, fixed = TRUE)
stopifnot("expected one 'use pin file' line" = length(i_pin) == 1L)
dat$lines[i_pin] <- set_field(dat$lines[i_pin], 1, "0")
write_raw_lines(dat, file.path(DST_MODEL, "gmacs.dat"))

stopifnot(file.copy(exe_path, file.path(DST_MODEL, gmacs_exe_name())))
Sys.chmod(file.path(DST_MODEL, gmacs_exe_name()), "755")
stopifnot(file.copy(file.path(EQM_TREE, "gmacsbase.TPL"),
                    file.path(DST_MODEL, "gmacsbase.TPL")))

## ---------------------------------------------------------------------------
## 2. Verify
## ---------------------------------------------------------------------------
rule("2. Verify")
md5 <- function(p) unname(tools::md5sum(p))
for (f in c(DATFILE, PRJFILE)) {
  stopifnot(setNames(identical(md5(file.path(SRC_MODEL, f)), md5(file.path(DST_MODEL, f))),
                     paste(f, "is not byte-identical to the male-only source")))
  message("byte-identical to 26.2      : ", f)
}
new <- read_raw_lines(file.path(DST_MODEL, CTLFILE))$lines
expect <- C0
expect[i_mode] <- set_field(expect[i_mode], 1, "6")
expect[i_rini] <- set_field(set_field(expect[i_rini], 7, "1"), 1, LOGRINI_IVAL)
expect[i_e5]   <- set_field(expect[i_e5], 1, INITDEV_EMPHASIS)
stopifnot("ctl differs from the intended edit" = identical(new, expect))
message("snow.ctl                    : exactly 3 lines changed, nothing else")
message("  initialisation mode       : 2 (FREEPARS) -> 6 (EQMDEVS)")
message("  logRini                   : phase -1 -> 1, ival 15.0 -> ", LOGRINI_IVAL)
message("  emphasis 5 (Initial_devs) : 15 -> ", INITDEV_EMPHASIS)
message("initial-N rows              : 44 (nsex=1), all become deviations")

stopifnot("gmacs.pin must not be present" = !file.exists(file.path(DST_MODEL, "gmacs.pin")))
stale <- intersect(c("gmacs.par","gmacs.std","Gmacsall.out","gmacs.rep"), list.files(DST_MODEL))
stopifnot("the new model dir contains a fit" = length(stale) == 0L)
message("no inherited fit or pin     : ok")

writeLines(c(
  "# Models/26_gmacs_male_only_eqmdevs -- provenance",
  "",
  sprintf("Built %s by `00f_build_maleonly_eqmdevs_model.R` from",
          format(Sys.Date())),
  "`Models/26_gmacs_male_only/`. **Inputs only -- not fit.** Not a core model",
  "folder; not registered in `0-models.R`.",
  "",
  "## What this is",
  "",
  "Model 26.2 (male-only) with the equilibrium-backbone initialisation added",
  "(GMACS mode 6, EQMDEVS -- Rceattle initMode 2 ported in). The 44 initial",
  "numbers-at-length become log-deviations around an unfished equilibrium scaled",
  "by `exp(logRini)`, penalised at the recruitment sd via ctl emphasis 5.",
  "",
  "## Why this combination",
  "",
  "Male-only is the ONLY configuration that reliably recovers its own best fit",
  "(25.3% against ~1-3% for every two-sex configuration; Fisher p < 0.0001).",
  "What still moves in it is dominated by shared recruitment deviations -- 51.7%",
  "of a much smaller total (1.82 against the two-sex 64.04) -- concentrated in",
  "`Rec_dev_est_2019` and `Rec_dev_est_2020`, the COVID survey-gap years. The",
  "equilibrium backbone anchors the early population those deviations trade",
  "against, and under mode 6 male-parameter movement fell 83% (10.11 -> 1.76) in",
  "the two-sex model. So this applies the fix that demonstrably worked on the",
  "structural side to the only configuration with a healthy surface to build on.",
  "",
  "## Executable",
  "",
  "`GMACs/GMACS_tpl-cpp_code_eqmdevs/gmacs`, used unchanged. Its other patch --",
  "the sex-ratio deviation penalty sd 2.0 -> 1.0 -- is a **no-op** here:",
  "`gmacsbase.TPL:1651` sets `rec_prop_phz = -1` when `nsex == 1`, so",
  "`logit_rec_prop_est` is never active. Confirm after fitting that the",
  "sex-ratio likelihood component is zero.",
  "",
  "`gmacs.exe` is deliberately absent -- the Windows binary is stock 2.20.34 and",
  "has no mode 6 at all.",
  "",
  "## Expectations",
  "",
  "npar should be 235: male-only's 234 plus `logRini`, with the 44 initial-N",
  "parameters re-interpreted rather than added or removed.",
  "",
  "nll is NOT comparable to male-only's -14010.6636 -- the parameterisation and",
  "the penalty set both changed. Compare reference points, and compare recovery",
  "against male-only's 25.3%, not against the two-sex models."),
  file.path(DST_MODEL, "PROVENANCE.md"))

rule("Done")
message("Models/26_gmacs_male_only_eqmdevs/ built. Inputs only -- not fit.")
message("Contents: ", paste(sort(list.files(DST_MODEL)), collapse = "  "))
