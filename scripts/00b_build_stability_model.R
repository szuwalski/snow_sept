#!/usr/bin/env Rscript
## ============================================================================
## 00b_build_stability_model.R
##
## Builds Models/26_gmacs_stability/ -- the 26 model with the three changes
## that address the jitter instability diagnosed 2026-08-29 (per Grant). The
## 26 model's own directory is never touched.
##
## The instability, in one line: 40 usable jitter runs land on 23 distinct
## optima spanning 1.71 nll but OFL 85.4-90.0 kt. Three causes, one change each:
##
##   1. A structurally non-identified parameter. The 2019 immature-female M
##      deviation is the ONLY one of 412 parameters that moves while the
##      objective does not (it varies by up to 5.66 within a group of runs
##      sharing an nll to 3 dp). The block function is exponential
##      (gmacsbase.TPL:6315, `tpar(i) *= exp(pars(jpnt))`) and the base rate is
##      relative to mature females (:6278), so M2019 = 0.427 * exp(dev). Above
##      dev ~4 annual survival is < 1e-10 -- numerically zero, zero derivative,
##      and the optimiser parks wherever the jitter dropped it.
##      -> FIXED at 0.0 (phase -4): no 2019 immature-female mortality event.
##
##   2. 259 parameters resolved in phase 1, 83 of them the free 1982
##      numbers-at-length, whose ival is 0 while the MLE is 9-14 on the log
##      scale. Where phase 1 lands sets the basin; later phases cannot leave it.
##      -> Initial_logN moved to phase 2.
##
##   3. The recruitment sex ratio is 44 free logits whose only real restraint is
##      an annual N(0, sd) penalty with sd HARDCODED at 2.0 -- loose enough that
##      six years saturate (p_male > 0.94 or < 0.03, se >= 1). The ctl's
##      emphasis 7 penalises the MEAN sex ratio only, and contributes 0.205 nll.
##      -> sd 2.0 -> 1.0 (a forked TPL, see below) and emphasis 7 -> 0.
##
## WHY A FORKED GMACS SOURCE. Change 3 is not reachable from the .ctl:
## logit_rec_prop_est is an init_bounded_dev_vector built in the TPL
## (gmacsbase.TPL:5005) with its bounds and penalty written into the source; it
## has no .ctl row, no prior type, no p1/p2. Editing the shared tree in
## GMACs/GMACS_tpl-cpp_code/ would mean any later rebuild silently carries this
## change into the ACCEPTED model's binary -- the exact failure mode CLAUDE.md's
## known-traps section exists to prevent. So we fork ~1 MB of build inputs to
## GMACs/GMACS_tpl-cpp_code_recprop_sd1/ and build there. The shared tree is
## left byte-identical, asserted at the end.
##
## Note ADMB's dnorm(dvar_vector, double) is
##   0.5*n*log(2*pi*sd^2) + norm2(x)/(2*sd^2)
## so sd = 1.0 is exactly `0.5 * norm2(x)` plus a constant with zero gradient.
## The constant shifts the reported nll; it cannot move an estimate.
##
## Run from the repo root:
##   Rscript 00b_build_stability_model.R              # fork, patch, compile, build
##   Rscript 00b_build_stability_model.R --no-compile # skip the compile step
##
## Outputs
##   GMACs/GMACS_tpl-cpp_code_recprop_sd1/    forked source + patched TPL + gmacs
##   Models/26_gmacs_stability/               model inputs only -- NO fit
##   Models/26_gmacs_stability/PROVENANCE.md  what changed, and against what
##
## This script builds INPUTS. It never runs gmacs on the new model (CLAUDE.md
## hard rule 10): that is a separate, confirmed step.
## ============================================================================

options(warn = 1)

args       <- commandArgs(trailingOnly = TRUE)
DO_COMPILE <- !("--no-compile" %in% args)

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

SRC_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_update_newmat_plus_group")
DST_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_stability")
SRC_TREE  <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code")
FORK_TREE <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code_recprop_sd1")

## The sex-ratio deviation penalty sd, before and after.
SD_OLD <- "2.0"
SD_NEW <- "1.0"
## Stamped into TheHeader so every output file the variant writes identifies
## itself. gmacs_exe_version() only RECORDS this string, never asserts it.
VER_OLD <- "## GMACS Version 2.20.34; ** AEP **; Compiled 2026-01-15"
VER_NEW <- "## GMACS Version 2.20.34-recprop-sd1; ** AEP **; Compiled 2026-01-15"

rule <- function(x) message("\n== ", x, " ", strrep("=", max(0, 66 - nchar(x))))

## ---------------------------------------------------------------------------
## 1. Byte-preserving field edits
## ---------------------------------------------------------------------------
## snow.ctl is tab-aligned and carries non-ASCII em-dash rules; gmacsbase.TPL is
## CRLF. Both are read and written through read_raw_lines()/write_raw_lines()
## (CLAUDE.md hard rule 2). These helpers rewrite ONE whitespace-delimited field
## and leave every other byte on the line untouched.

.split_runs <- function(line) {
  m <- gregexpr("[[:space:]]+|[^[:space:]]+", line, useBytes = TRUE)
  regmatches(line, m)[[1]]
}

## Replace field `k` of `line` with `value`, absorbing any width change in the
## FOLLOWING whitespace run so the column alignment a reader relies on survives.
set_field <- function(line, k, value) {
  runs <- .split_runs(line)
  tok  <- which(!grepl("^[[:space:]]", runs, useBytes = TRUE))
  if (length(tok) < k)
    stop(sprintf("line has %d fields, field %d requested:\n%s", length(tok), k, line))
  i   <- tok[k]
  old <- runs[i]
  new <- as.character(value)
  runs[i] <- new
  d <- nchar(old, type = "bytes") - nchar(new, type = "bytes")
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

## Field `k` of `line`, as text.
get_field <- function(line, k) {
  t <- toks(line)
  if (length(t) < k) NA_character_ else t[k]
}

## ---------------------------------------------------------------------------
## 2. Fork the GMACS source and patch the sex-ratio penalty
## ---------------------------------------------------------------------------
rule("1. Fork GMACS source")

stopifnot("shared GMACS source tree not found" = dir.exists(SRC_TREE))
tpl_before <- unname(tools::md5sum(file.path(SRC_TREE, "gmacsbase.TPL")))

if (dir.exists(FORK_TREE)) unlink(FORK_TREE, recursive = TRUE)
dir.create(FORK_TREE, recursive = TRUE)

## Only what compile_gmacs_mac.sh actually consumes (~1 MB). build/, tpl_files/,
## testing/ and quarto/ are 83 MB of material the build never reads.
for (f in c("gmacsbase.TPL", "personal.TPL", "compile_gmacs_mac.sh"))
  stopifnot(file.copy(file.path(SRC_TREE, f), file.path(FORK_TREE, f), overwrite = TRUE))
for (d in c("src", "include"))
  stopifnot(file.copy(file.path(SRC_TREE, d), FORK_TREE, recursive = TRUE))
## The distributed src/ and include/ are mode 555 and file.copy() preserves that.
## The build itself only READS them (it stages into src_mac/), but a mode-555
## directory cannot have entries removed, which would break the unlink() above
## on any re-run. Make the fork writable.
Sys.chmod(list.dirs(FORK_TREE, full.names = TRUE), "755")
Sys.chmod(list.files(FORK_TREE, recursive = TRUE, full.names = TRUE), "644")
Sys.chmod(file.path(FORK_TREE, "compile_gmacs_mac.sh"), "755")
message("forked : ", length(list.files(FORK_TREE, recursive = TRUE)), " files -> ",
        sub(REPO_ROOT, ".", FORK_TREE, fixed = TRUE))

tpl_path <- file.path(FORK_TREE, "gmacsbase.TPL")
tpl <- read_raw_lines(tpl_path)

## (a) the annual sex-ratio deviation penalty
i_pen <- grep("nloglike(4,3) = dnorm(logit_rec_prop_est,", tpl$lines, fixed = TRUE)
stopifnot("expected exactly one sex-ratio penalty line" = length(i_pen) == 1L)
old_pen <- tpl$lines[i_pen]
stopifnot("sex-ratio penalty is not at the expected sd" =
            grepl(paste0("logit_rec_prop_est, ", SD_OLD), old_pen, fixed = TRUE))
tpl$lines[i_pen] <- sub(paste0("logit_rec_prop_est, ", SD_OLD),
                        paste0("logit_rec_prop_est, ", SD_NEW),
                        old_pen, fixed = TRUE)

## (b) the version stamp, so the variant is self-identifying in every output
i_ver <- grep(VER_OLD, tpl$lines, fixed = TRUE)
stopifnot("expected exactly one version-header line" = length(i_ver) == 1L)
tpl$lines[i_ver] <- sub(VER_OLD, VER_NEW, tpl$lines[i_ver], fixed = TRUE)

write_raw_lines(tpl, tpl_path)

chk  <- read_raw_lines(tpl_path)$lines
orig <- read_raw_lines(file.path(SRC_TREE, "gmacsbase.TPL"))$lines
stopifnot("patch (a) did not land" =
            grepl(paste0("logit_rec_prop_est, ", SD_NEW), chk[i_pen], fixed = TRUE),
          "patch (b) did not land" = grepl(VER_NEW, chk[i_ver], fixed = TRUE),
          "forked TPL line count changed" = length(chk) == length(orig),
          "patch changed lines other than the two intended" =
            identical(which(chk != orig), sort(c(i_pen, i_ver))))
message("patched: TPL:", i_pen, "  sd ", SD_OLD, " -> ", SD_NEW)
message("         TPL:", i_ver, "  version stamp -> 2.20.34-recprop-sd1")
message("         (exactly 2 lines differ from the shared source)")

## ---------------------------------------------------------------------------
## 3. Compile the variant binary
## ---------------------------------------------------------------------------
rule("2. Compile")

exe_path <- file.path(FORK_TREE, gmacs_exe_name())
if (DO_COMPILE) {
  message("building (this takes a few minutes) ...")
  ## system2() has no working-directory argument and the build script resolves
  ## src/, include/ and personal.TPL relative to its own directory, so drive it
  ## through a subshell that cd's first. No setwd() (CLAUDE.md hard rule 4).
  st <- system2("zsh", c("-c", shQuote(sprintf("cd %s && zsh ./compile_gmacs_mac.sh",
                                               shQuote(FORK_TREE)))),
                stdout = file.path(FORK_TREE, "compile.log"),
                stderr = file.path(FORK_TREE, "compile.log.err"))
  if (st != 0L || !file.exists(exe_path))
    stop("compile failed (exit ", st, "); see ",
         file.path(FORK_TREE, "compile.log.err"))
  message("built  : ", exe_path)
} else {
  message("skipped (--no-compile)")
}

## ---------------------------------------------------------------------------
## 4. Build the model directory
## ---------------------------------------------------------------------------
rule("3. Build Models/26_gmacs_stability")

gc_src <- read_gmacs_control(SRC_MODEL)
DATFILE <- gc_src$datafile
CTLFILE <- gc_src$ctlfile
PRJFILE <- gc_src$prjfile
message("source model: Models/", basename(SRC_MODEL))
message("  datafile  : ", DATFILE)
message("  controlfile: ", CTLFILE)
message("  projection : ", PRJFILE)

if (dir.exists(DST_MODEL)) unlink(DST_MODEL, recursive = TRUE)
dir.create(DST_MODEL, recursive = TRUE)

## INPUTS ONLY. A new model dir that inherits the template's gmacs.par /
## gmacs.std / Gmacsall.out shows a complete, plausible fit that belongs to the
## template, and nothing marks it stale (CLAUDE.md known traps; backlog 1e).
## Nothing here is copied that a run could be mistaken for.
for (f in c(DATFILE, PRJFILE))
  stopifnot(file.copy(file.path(SRC_MODEL, f), file.path(DST_MODEL, f)))

## ---- 4a. snow.ctl: the three structural edits ------------------------------
ctl <- read_raw_lines(file.path(SRC_MODEL, CTLFILE))
ctl0 <- ctl$lines
L <- ctl$lines

## (i) 2019 immature-female M deviation -> fixed at its ival of 0.0.
##     The M rows are `ival lb ub prior p1 p2 phz`; phase is field 7. The four
##     "# Block 2" rows are mature males / immature males / mature females /
##     immature females in that order, so the LAST is the one to fix.
i_blk2 <- grep("# Block 2", L, fixed = TRUE)
i_blk2 <- i_blk2[grepl("^[[:space:]]*[0-9.]", L[i_blk2])]   # data rows, not headers
stopifnot("expected 4 M '# Block 2' rows" = length(i_blk2) == 4L)
i_m <- i_blk2[4]
stopifnot("M target row is not the expected phase 4" = get_field(L[i_m], 7) == "4",
          "M target row ival is not 0.000"           = get_field(L[i_m], 1) == "0.000")
L[i_m] <- set_field(L[i_m], 7, "-4")

## (ii) free 1982 numbers-at-length -> phase 2. 88 rows; the 5 already at -1
##      (female immature classes 18-22, ival -19) stay fixed.
i_dev <- grep("# Deviation for size-class", L, fixed = TRUE)
stopifnot("expected 88 Initial_logN rows" = length(i_dev) == 88L)
ph    <- vapply(L[i_dev], get_field, character(1), k = 7L, USE.NAMES = FALSE)
i_ph1 <- i_dev[ph == "1"]
stopifnot("expected 83 Initial_logN rows in phase 1" = length(i_ph1) == 83L,
          "expected 5 Initial_logN rows already fixed" = sum(ph == "-1") == 5L)
for (i in i_ph1) L[i] <- set_field(L[i], 7, "2")

## (iii) mean sex-ratio emphasis -> 0. The annual deviation penalty (now
##       sd 1.0, in the forked TPL) replaces it.
i_emp <- grep("# Mean_sex-Ratio", L, fixed = TRUE)
i_emp <- i_emp[grepl("^[[:space:]]*[0-9]", L[i_emp])]
stopifnot("expected exactly one Mean_sex-Ratio emphasis row" = length(i_emp) == 1L)
stopifnot("Mean_sex-Ratio emphasis is not the expected 3" =
            get_field(L[i_emp], 1) == "3")
L[i_emp] <- set_field(L[i_emp], 1, "0")

ctl$lines <- L
write_raw_lines(ctl, file.path(DST_MODEL, CTLFILE))

## ---- 4b. gmacs.dat: do not read the accepted model's pin -------------------
## The pin is the 26 model's 412-parameter winner. This model has 411 (M fixed)
## and a different phase structure, so the pin is both wrong-length and exactly
## the starting point we are trying not to inherit.
dat <- read_raw_lines(file.path(SRC_MODEL, "gmacs.dat"))
i_pin <- grep("use pin file", dat$lines, fixed = TRUE)
stopifnot("expected exactly one 'use pin file' line" = length(i_pin) == 1L)
stopifnot("source model is not set to use a pin" = get_field(dat$lines[i_pin], 1) == "1")
dat$lines[i_pin] <- set_field(dat$lines[i_pin], 1, "0")
write_raw_lines(dat, file.path(DST_MODEL, "gmacs.dat"))

## ---- 4c. the variant binary and the source that built it -------------------
## gmacs.exe is deliberately NOT copied: the Windows binary is unpatched stock
## 2.20.34 and would silently fit a DIFFERENT model (sd 2.0) in this directory.
if (file.exists(exe_path)) {
  stopifnot(file.copy(exe_path, file.path(DST_MODEL, gmacs_exe_name())))
  Sys.chmod(file.path(DST_MODEL, gmacs_exe_name()), "755")
}
stopifnot(file.copy(tpl_path, file.path(DST_MODEL, "gmacsbase.TPL")))

## ---------------------------------------------------------------------------
## 5. Verification
## ---------------------------------------------------------------------------
rule("4. Verify")

md5 <- function(p) unname(tools::md5sum(p))

## Data and projection files must be byte-identical: this model differs from the
## 26 model in structure only, never in data.
for (f in c(DATFILE, PRJFILE)) {
  same <- identical(md5(file.path(SRC_MODEL, f)), md5(file.path(DST_MODEL, f)))
  stopifnot(setNames(same, paste(f, "is not byte-identical to the source model")))
  message("byte-identical to 26 model : ", f)
}

## snow.ctl must differ in exactly the 85 lines we meant to change.
new <- read_raw_lines(file.path(DST_MODEL, CTLFILE))$lines
stopifnot("ctl line count changed" = length(new) == length(ctl0))
diff_idx <- which(new != ctl0)
expect   <- sort(c(i_m, i_ph1, i_emp))
stopifnot("ctl changed in lines we did not intend" = identical(sort(diff_idx), expect))
message("snow.ctl lines changed     : ", length(diff_idx),
        "  (1 M + 83 Initial_logN + 1 emphasis)")

## Re-parse the written file rather than trusting the in-memory edit.
stopifnot("M dev not fixed"  = get_field(new[i_m], 7) == "-4",
          "M ival moved"     = get_field(new[i_m], 1) == "0.000",
          "emphasis 7 not 0" = get_field(new[i_emp], 1) == "0")
ph2 <- vapply(new[i_dev], get_field, character(1), k = 7L, USE.NAMES = FALSE)
stopifnot("Initial_logN phases wrong" =
            sum(ph2 == "2") == 83L && sum(ph2 == "-1") == 5L && sum(ph2 == "1") == 0L)
message("M 2019 immature-female     : ival 0.000, phase -4  (fixed, npar 412 -> 411)")
message("Initial_logN               : 83 rows phase 1 -> 2, 5 stay fixed")
message("emphasis 7 (mean sex ratio): 3 -> 0")

## The shared source tree must be untouched.
stopifnot("the SHARED GMACS source was modified" =
            identical(md5(file.path(SRC_TREE, "gmacsbase.TPL")), tpl_before))
message("shared GMACS source        : unchanged (md5 ", substr(tpl_before, 1, 8), ")")

## No fit may be present.
stale <- intersect(c("gmacs.par", "gmacs.std", "Gmacsall.out", "gmacs.rep",
                     "Gmacsall.std", "gmacs.pin", "gmacs.cor"),
                   list.files(DST_MODEL))
stopifnot("the new model dir contains a fit" = length(stale) == 0L)
message("no inherited fit in the dir: ok")

## ---------------------------------------------------------------------------
## 6. Provenance note
## ---------------------------------------------------------------------------
writeLines(c(
  "# Models/26_gmacs_stability -- provenance",
  "",
  sprintf("Built %s by `00b_build_stability_model.R` from", format(Sys.Date())),
  "`Models/26_gmacs_update_newmat_plus_group/`, to address the jitter",
  "instability diagnosed 2026-08-29. **This directory holds INPUTS ONLY -- it has",
  "not been fit.**",
  "",
  "## Data",
  "",
  sprintf("`%s` and `%s` are **byte-identical** to the 26 model", DATFILE, PRJFILE),
  "(md5-checked at build time). This model differs in structure only.",
  "",
  "## The three changes",
  "",
  "| # | Where | From | To | Why |",
  "|---|---|---|---|---|",
  sprintf("| 1 | `%s:%d` M 2019 immature-female | phase 4, est. 1.826 | phase -4, fixed **0.0** | The only one of 412 parameters that moved while the objective did not. |",
          CTLFILE, i_m),
  sprintf("| 2 | `%s:%d-%d` Initial_logN | phase 1 (83 rows) | phase 2 | Took 83 of the 259 parameters out of the phase-1 solve. |",
          CTLFILE, min(i_ph1), max(i_ph1)),
  sprintf("| 3 | `%s:%d` emphasis 7 | 3 | 0 | Mean sex-ratio penalty off; annual deviations now carry it. |",
          CTLFILE, i_emp),
  "| 3 | forked `gmacsbase.TPL` sex-ratio penalty | `dnorm(x, 2.0)` | `dnorm(x, 1.0)` | sd is hardcoded, not a ctl input. |",
  "",
  "Change 1 removes the 2019 mortality event for immature females entirely",
  "(M 2.65 -> 0.427 /yr, annual survival 0.071 -> 0.652) while immature males",
  "(dev 2.03) and mature females (dev 1.33) keep theirs. That is a deliberate",
  "structural assumption, not a neutral fix, and it will move MMB and OFL.",
  "",
  "## Executable",
  "",
  "Built from `GMACs/GMACS_tpl-cpp_code_recprop_sd1/`, a fork of the shared tree",
  "carrying exactly two changed lines: the sex-ratio penalty sd and the version",
  "stamp. The shared tree is verified unchanged at build time, so no later",
  "rebuild can carry this patch into the accepted model's binary.",
  "",
  sprintf("Version string: `%s`", VER_NEW),
  "",
  "`gmacs.exe` is deliberately **absent**. The Windows binary is unpatched stock",
  "2.20.34 and would silently fit a different model (sd 2.0) in this directory.",
  "",
  "## Not yet done",
  "",
  "- No fit. Run `./gmacs` here to convergence, then `03_build_results_object.R`.",
  "- Not registered in `0-models.R`; it does not reach the SAFE until it is.",
  "- Jitter (`05`) is the actual test of whether this worked."),
  file.path(DST_MODEL, "PROVENANCE.md"))

rule("Done")
message("Models/26_gmacs_stability/ built. Inputs only -- not fit.")
message("Contents: ", paste(sort(list.files(DST_MODEL)), collapse = "  "))
