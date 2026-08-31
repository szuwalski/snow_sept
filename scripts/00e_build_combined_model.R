#!/usr/bin/env Rscript
## ============================================================================
## 00e_build_combined_model.R
##
## Builds Models/26_gmacs_combined/ -- the 26 model with ALL THREE diagnosed
## pathologies fixed at once. Not a core model folder; not in 0-models.R.
##
## WHY. The 2026-08-29 diagnosis of the 26 model's multimodality found three
## INDEPENDENT pathologies. Three models were built, each fixing a different
## subset, and each failed to move the headline recovery rate:
##
##                      M_pars_est[15]   sex-ratio    initial-N level   best-nll%
##   26 two-sex             flat         saturating   unpenalised        1.3
##   26_gmacs_stability     FIXED        FIXED        left               4.1
##   26_gmacs_initscaled    left         left         wrong fix          --
##   26_gmacs_eqmdevs       left         left         FIXED              1.2
##   26_gmacs_combined      FIXED        FIXED        FIXED              <- this
##
## No model has yet had all three fixed simultaneously, and each fix is
## independently verified to do what it claims:
##   1. M_pars_est[15] (the 2019 immature-female M deviation) is the ONLY one of
##      412 parameters that moves while the objective does not -- it varied by up
##      to 5.66 within groups of runs sharing an nll to 3 dp. Above dev ~4 the
##      annual survival is < 1e-10, so the likelihood is exactly flat and the
##      optimiser parks wherever the jitter dropped it.
##   2. Tightening the sex-ratio deviation penalty from sd 2.0 to 1.0 cut
##      saturated years (|logit| > 2) from 13/44 to 4/44, max |logit| 4.24 -> 3.00.
##   3. The equilibrium backbone (Rceattle initMode 2, GMACS mode 6 EQMDEVS)
##      halved the nll span across usable jitter runs, 301.6 -> 151.8, and its
##      deviations fit at rms 0.469 against a prior sd of 0.407.
##
## DELIBERATELY NOT INCLUDED: moving Initial_logN to phase 2. That was a fourth
## change in 26_gmacs_stability, not one of the three pathologies, and its
## motivation (phase 1 starting with ~1 crab per size class) is void under mode 6,
## where the deviations start at 0 and phase 1 therefore starts AT the equilibrium.
##
## HONEST EXPECTATION: three individual fixes each failed to move the recovery
## rate, so the combination may too. The argument for trying is that the
## pathologies are independent and each fix is verified in isolation.
##
## The TPL fork is taken from the ALREADY-PATCHED eqmdevs tree rather than
## re-deriving its 12 edits, so only the sex-ratio sd and the version stamp are
## new here. The shared tree is asserted unchanged.
##
## Run from the repo root:
##   Rscript 00e_build_combined_model.R [--no-compile]
##
## Builds INPUTS and an executable. Never runs the model (CLAUDE.md rule 10).
## ============================================================================

options(warn = 1)
args       <- commandArgs(trailingOnly = TRUE)
DO_COMPILE <- !("--no-compile" %in% args)

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

SRC_MODEL  <- file.path(REPO_ROOT, "Models", "26_gmacs_update_newmat_plus_group")
DST_MODEL  <- file.path(REPO_ROOT, "Models", "26_gmacs_combined")
SHARED     <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code")
EQM_TREE   <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code_eqmdevs")
FORK_TREE  <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code_combined")

SD_OLD <- "2.0"; SD_NEW <- "1.0"
VER_OLD <- "## GMACS Version 2.20.34-eqmdevs; ** AEP **; Compiled 2026-01-15"
VER_NEW <- "## GMACS Version 2.20.34-combined; ** AEP **; Compiled 2026-01-15"
LOGRINI_IVAL     <- "13.90"
INITDEV_EMPHASIS <- "1.0"

rule <- function(x) message("\n== ", x, " ", strrep("=", max(0, 66 - nchar(x))))

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
## 1. Fork the eqmdevs source and add the sex-ratio patch
## ---------------------------------------------------------------------------
rule("1. Fork the eqmdevs source")
stopifnot("eqmdevs fork not found -- run 00d first" = dir.exists(EQM_TREE))
shared_before <- unname(tools::md5sum(file.path(SHARED, "gmacsbase.TPL")))

if (dir.exists(FORK_TREE)) {
  Sys.chmod(list.dirs(FORK_TREE, full.names = TRUE), "755"); unlink(FORK_TREE, recursive = TRUE)
}
dir.create(FORK_TREE, recursive = TRUE)
for (f in c("gmacsbase.TPL", "personal.TPL", "compile_gmacs_mac.sh"))
  stopifnot(file.copy(file.path(EQM_TREE, f), file.path(FORK_TREE, f), overwrite = TRUE))
for (d in c("src", "include"))
  stopifnot(file.copy(file.path(EQM_TREE, d), FORK_TREE, recursive = TRUE))
Sys.chmod(list.dirs(FORK_TREE, full.names = TRUE), "755")
Sys.chmod(list.files(FORK_TREE, recursive = TRUE, full.names = TRUE), "644")
Sys.chmod(file.path(FORK_TREE, "compile_gmacs_mac.sh"), "755")

tpl_path <- file.path(FORK_TREE, "gmacsbase.TPL")
tpl <- read_raw_lines(tpl_path); L <- tpl$lines
base_lines <- L

## The eqmdevs patches must already be present -- assert rather than assume.
stopifnot("EQMDEVS mode missing from the eqmdevs fork" =
            any(grepl("#define EQMDEVS 6", L, fixed = TRUE)),
          "EQMDEVS population case missing" = any(grepl("case EQMDEVS:", L, fixed = TRUE)),
          "EQMDEVS deviation penalty missing" =
            any(grepl("nlogPenalty(5) += dnorm(logN0(k)", L, fixed = TRUE)))
message("inherited from eqmdevs fork: mode 6, nlogPenalty(5), smoothness gate")

i_pen <- grep("nloglike(4,3) = dnorm(logit_rec_prop_est,", L, fixed = TRUE)
stopifnot("expected one sex-ratio penalty line" = length(i_pen) == 1L,
          "sex-ratio penalty not at the expected sd" =
            grepl(paste0("logit_rec_prop_est, ", SD_OLD), L[i_pen], fixed = TRUE))
L[i_pen] <- sub(paste0("logit_rec_prop_est, ", SD_OLD),
                paste0("logit_rec_prop_est, ", SD_NEW), L[i_pen], fixed = TRUE)

i_ver <- grep(VER_OLD, L, fixed = TRUE)
stopifnot("expected one version-header line" = length(i_ver) == 1L)
L[i_ver] <- sub(VER_OLD, VER_NEW, L[i_ver], fixed = TRUE)

tpl$lines <- L; write_raw_lines(tpl, tpl_path)
chk <- read_raw_lines(tpl_path)$lines
stopifnot("patch changed lines other than the two intended" =
            identical(which(chk != base_lines), sort(c(i_pen, i_ver))))
message("patched: TPL:", i_pen, "  sex-ratio sd ", SD_OLD, " -> ", SD_NEW)
message("         TPL:", i_ver, "  version stamp -> 2.20.34-combined")
stopifnot("the SHARED GMACS source was modified" =
            identical(unname(tools::md5sum(file.path(SHARED, "gmacsbase.TPL"))), shared_before))
message("shared GMACS source unchanged (md5 ", substr(shared_before, 1, 8), ")")

## ---------------------------------------------------------------------------
## 2. Compile
## ---------------------------------------------------------------------------
rule("2. Compile")
exe_path <- file.path(FORK_TREE, gmacs_exe_name())
if (DO_COMPILE) {
  message("building ...")
  st <- system2("zsh", c("-c", shQuote(sprintf("cd %s && zsh ./compile_gmacs_mac.sh",
                                               shQuote(FORK_TREE)))),
                stdout = file.path(FORK_TREE, "compile.log"),
                stderr = file.path(FORK_TREE, "compile.log.err"))
  if (st != 0L || !file.exists(exe_path))
    stop("compile failed (exit ", st, "); see ", file.path(FORK_TREE, "compile.log.err"))
  message("built: ", exe_path)
} else message("skipped (--no-compile)")

## ---------------------------------------------------------------------------
## 3. Build the model directory
## ---------------------------------------------------------------------------
rule("3. Build Models/26_gmacs_combined")
gc_src  <- read_gmacs_control(SRC_MODEL)
DATFILE <- gc_src$datafile; CTLFILE <- gc_src$ctlfile; PRJFILE <- gc_src$prjfile

if (dir.exists(DST_MODEL)) unlink(DST_MODEL, recursive = TRUE)
dir.create(DST_MODEL, recursive = TRUE)
for (f in c(DATFILE, PRJFILE))
  stopifnot(file.copy(file.path(SRC_MODEL, f), file.path(DST_MODEL, f)))

ctl <- read_raw_lines(file.path(SRC_MODEL, CTLFILE)); C0 <- ctl$lines; C <- C0

## ---- FIX 3: the equilibrium backbone (mode 6) ------------------------------
i_mode <- grep("# Initial conditions", C, fixed = TRUE)
stopifnot("source is not mode 2" = length(i_mode) == 1L && get_field(C[i_mode], 1) == "2")
C[i_mode] <- set_field(C[i_mode], 1, "6")

i_rini <- grep("# logRini", C, fixed = TRUE)
stopifnot("logRini not fixed as expected" = get_field(C[i_rini], 7) == "-1")
C[i_rini] <- set_field(set_field(C[i_rini], 7, "1"), 1, LOGRINI_IVAL)

i_r0 <- grep("# logR0", C, fixed = TRUE)
stopifnot("logR0 must stay off in mode 6" = as.integer(get_field(C[i_r0], 7)) <= 0L)

## Under mode 6 these are DEVIATIONS, so the -19 rows (absolute log-N, "empty")
## become "sit on the equilibrium" at 0.
i_dev <- grep("# Deviation for size-class", C, fixed = TRUE)
stopifnot("expected 88 initial rows" = length(i_dev) == 88L)
n19 <- 0L
for (i in i_dev) if (get_field(C[i], 1) == "-19") { C[i] <- set_field(C[i], 1, "0.0"); n19 <- n19 + 1L }
stopifnot("expected 5 rows pinned at -19" = n19 == 5L)

i_e5 <- grep("# Initial_devs", C, fixed = TRUE)
i_e5 <- i_e5[grepl("^[[:space:]]*[0-9]", C[i_e5])]
stopifnot("expected one Initial_devs emphasis row" = length(i_e5) == 1L,
          "Initial_devs emphasis is not 15" = get_field(C[i_e5], 1) == "15")
C[i_e5] <- set_field(C[i_e5], 1, INITDEV_EMPHASIS)

## ---- FIX 1: the structurally non-identified 2019 immature-female M dev ------
## The M rows are `ival lb ub prior p1 p2 phz`. The four "# Block 2" data rows
## are mature males / immature males / mature females / immature females in that
## order, so the LAST is the one to fix. ival stays 0.000.
i_b2 <- grep("# Block 2", C, fixed = TRUE)
i_b2 <- i_b2[grepl("^[[:space:]]*[0-9.]", C[i_b2])]
stopifnot("expected 4 M '# Block 2' rows" = length(i_b2) == 4L)
i_m <- i_b2[4]
stopifnot("M target row is not phase 4" = get_field(C[i_m], 7) == "4",
          "M target row ival is not 0.000" = get_field(C[i_m], 1) == "0.000")
C[i_m] <- set_field(C[i_m], 7, "-4")

## ---- FIX 2: the sex ratio -- mean penalty off, annual now sd 1.0 in the TPL --
i_e7 <- grep("# Mean_sex-Ratio", C, fixed = TRUE)
i_e7 <- i_e7[grepl("^[[:space:]]*[0-9]", C[i_e7])]
stopifnot("expected one Mean_sex-Ratio emphasis row" = length(i_e7) == 1L,
          "Mean_sex-Ratio emphasis is not 3" = get_field(C[i_e7], 1) == "3")
C[i_e7] <- set_field(C[i_e7], 1, "0")

ctl$lines <- C; write_raw_lines(ctl, file.path(DST_MODEL, CTLFILE))

dat <- read_raw_lines(file.path(SRC_MODEL, "gmacs.dat"))
i_pin2 <- grep("use pin file", dat$lines, fixed = TRUE)
dat$lines[i_pin2] <- set_field(dat$lines[i_pin2], 1, "0")
write_raw_lines(dat, file.path(DST_MODEL, "gmacs.dat"))

if (file.exists(exe_path)) {
  stopifnot(file.copy(exe_path, file.path(DST_MODEL, gmacs_exe_name())))
  Sys.chmod(file.path(DST_MODEL, gmacs_exe_name()), "755")
}
stopifnot(file.copy(tpl_path, file.path(DST_MODEL, "gmacsbase.TPL")))

## ---------------------------------------------------------------------------
## 4. Verify
## ---------------------------------------------------------------------------
rule("4. Verify")
md5 <- function(p) unname(tools::md5sum(p))
for (f in c(DATFILE, PRJFILE)) {
  stopifnot(setNames(identical(md5(file.path(SRC_MODEL, f)), md5(file.path(DST_MODEL, f))),
                     paste(f, "is not byte-identical to the source")))
  message("byte-identical to 26 model : ", f)
}
new <- read_raw_lines(file.path(DST_MODEL, CTLFILE))$lines
stopifnot("ctl line count changed" = length(new) == length(C0))
expect <- sort(unique(c(i_mode, i_rini, i_dev[which(get_field(C0[i_dev], 1) == "-19")],
                        i_e5, i_m, i_e7)))
changed <- which(new != C0)
message("snow.ctl lines changed     : ", length(changed))
stopifnot("mode not 6"            = get_field(new[i_mode], 1) == "6",
          "logRini not estimated" = get_field(new[i_rini], 7) == "1",
          "M dev not fixed"       = get_field(new[i_m], 7) == "-4",
          "M ival moved"          = get_field(new[i_m], 1) == "0.000",
          "emphasis 5 wrong"      = get_field(new[i_e5], 1) == INITDEV_EMPHASIS,
          "emphasis 7 not 0"      = get_field(new[i_e7], 1) == "0")
message("FIX 1  M 2019 immature-female : phase 4 -> -4, ival 0.000 (npar -1)")
message("FIX 2  sex ratio              : annual sd 2.0 -> 1.0 (TPL), mean emphasis 3 -> 0")
message("FIX 3  initialisation         : mode 2 -> 6, logRini estimated, emphasis 5 = ",
        INITDEV_EMPHASIS)
stale <- intersect(c("gmacs.par","gmacs.std","Gmacsall.out","gmacs.rep","gmacs.pin"),
                   list.files(DST_MODEL))
stopifnot("the new model dir contains a fit" = length(stale) == 0L)
message("no inherited fit           : ok")

writeLines(c(
  "# Models/26_gmacs_combined -- provenance",
  "",
  sprintf("Built %s by `00e_build_combined_model.R`. **Inputs only -- not fit.**",
          format(Sys.Date())),
  "Not a core model folder; not registered in `0-models.R`.",
  "",
  "## All three diagnosed pathologies fixed at once",
  "",
  "| | M_pars_est[15] | sex ratio | initial-N level | best-nll recovery |",
  "|---|---|---|---|---|",
  "| 26 two-sex (accepted) | flat | saturating | unpenalised | 1.3% |",
  "| 26_gmacs_stability | FIXED | FIXED | left | 4.1% |",
  "| 26_gmacs_eqmdevs | left | left | FIXED | 1.2% |",
  "| **26_gmacs_combined** | **FIXED** | **FIXED** | **FIXED** | to be measured |",
  "",
  "Each fix is independently verified: the M parameter provably has zero influence",
  "on the objective; tightening the sex-ratio sd cut saturated years 13/44 -> 4/44;",
  "the equilibrium backbone halved the nll span across usable runs, 301.6 -> 151.8.",
  "",
  "`gmacs.exe` is deliberately absent -- the Windows binary is unpatched stock",
  "2.20.34 and would silently fit a different model here.",
  "",
  "## Not included, deliberately",
  "",
  "Moving `Initial_logN` to phase 2 (a fourth change in `26_gmacs_stability`) is",
  "NOT applied. It was not one of the three pathologies, and its motivation --",
  "phase 1 starting at ~1 crab per size class -- is void under mode 6, where the",
  "deviations start at 0 and phase 1 therefore starts AT the equilibrium.",
  "",
  "## Honest expectation",
  "",
  "Three individual fixes each failed to move the headline recovery rate. The",
  "combination may too. The argument for trying is that the pathologies are",
  "independent and each fix is verified in isolation. If this does not work, the",
  "conclusion is that the two-sex model's multimodality is not reducible to these",
  "three causes, and male-only's 28.9% reflects something structural about",
  "carrying a female population this weakly informed."),
  file.path(DST_MODEL, "PROVENANCE.md"))

rule("Done")
message("Models/26_gmacs_combined/ built. Inputs only -- not fit.")
message("Contents: ", paste(sort(list.files(DST_MODEL)), collapse = "  "))
