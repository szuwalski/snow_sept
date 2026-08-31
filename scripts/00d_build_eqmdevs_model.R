#!/usr/bin/env Rscript
## ============================================================================
## 00d_build_eqmdevs_model.R
##
## Ports Rceattle's initMode 2 ("NonEquilibrium") into GMACS as a new
## initialisation mode, and builds Models/26_gmacs_eqmdevs/ to test it.
## No existing model directory is touched and this is not a core model folder.
##
## THE IDEA (Grant, 2026-08-29). Rceattle initMode 2 (ceattle.cpp:1805-1840)
## builds the initial age structure as an equilibrium decay from M,
##     N(age)  = R_init * exp(-sum_{a'<age} M(a') + init_dev(age-1))
##     N(Amax) = ... / (1 - exp(-M(Amax)))            <- the geometric series
## and penalises the deviations at the recruitment sd (ceattle.cpp:4394),
##     init_dev ~ N(-sigmaR^2/2, sigmaR)
## so the structure is anchored to a mechanistic equilibrium instead of being
## 88 free parameters.
##
## With M by SIZE the scalar geometric series becomes a matrix Neumann series:
## individuals do not advance one age per year, they move through a size-
## transition matrix G, so equilibrium is N = R + S.G.N, i.e.
##     N = (I - S.G)^-1 R = sum_k (S.G)^k R
## GMACS already computes exactly this in calc_brute_equilibrium(), which
## iterates NyrEquil (200) years at constant recruitment. What GMACS lacks is
## Rceattle's middle option -- that equilibrium as a BACKBONE with penalised
## deviations around it. Its modes are all-or-nothing:
##   0 UNFISHEDEQN    equilibrium, 0 free parameters      (too rigid)
##   1 FISHEDEQN      equilibrium, nfleet parameters      (too rigid)
##   2 FREEPARS       88 free parameters, level UNPENALISED  <- the problem
##   3 FREEPARSSCALED 87 parameters, unweighted L2 toward a FLAT distribution
##                    (tested 2026-08-29: data fit 138 nll worse, OFL +10.6%)
##
## WHAT THIS ADDS -- mode 6, EQMDEVS:
##   d4_N(ig)(syr)(1) = x_equilibrium(ig) * exp(logN0(ig))
## where x is the F=0 equilibrium scaled by exp(logRini) (Rceattle's R_init) and
## logN0 are the 88 log-deviations, penalised by
##   nlogPenalty(5) = sum_k dnorm(logN0(k) + 0.5*sigmaR^2, sigmaR)
## weighted by ctl emphasis 5 -- the "Initial_devs" slot, which is currently
## DEAD CODE in GMACS (no nlogPenalty(5) exists anywhere in 2.20.34). Wiring it
## up gives a ctl-controllable weight with no change to the ctl file format.
##
## Slot 6 is used for the mode because 4 is already #define REFPOINTS.
##
## Design points worth knowing:
##   * bSteadyState is set to FISHEDEQN so calc_brute_equilibrium uses
##     rtt = exp(logRini)*SexRatio (:10741), then log_fimpbar is forced to -100
##     so the equilibrium is UNFISHED -- matching Rceattle, where Finit = 0 for
##     initMode 2 (ceattle.cpp:948).
##   * The mode deliberately does NOT join the UNFISHEDEQN branch at :8418,
##     which drives recruitment for EVERY year: annual recruitment stays on
##     logRbar, as in FREEPARS. Only the syr equilibrium uses logRini.
##   * The first-difference smoothness penalty (nlogPenalty(10)) is gated OFF
##     for this mode. logN0 are deviations here, not absolute log-N, and
##     Rceattle puts no smoothness on init_dev. One line to re-enable.
##
## Run from the repo root:
##   Rscript 00d_build_eqmdevs_model.R              # fork, patch, compile, build
##   Rscript 00d_build_eqmdevs_model.R --no-compile
##
## Builds INPUTS and an executable. Never runs the model (CLAUDE.md rule 10).
## ============================================================================

options(warn = 1)
args       <- commandArgs(trailingOnly = TRUE)
DO_COMPILE <- !("--no-compile" %in% args)

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

SRC_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_update_newmat_plus_group")
DST_MODEL <- file.path(REPO_ROOT, "Models", "26_gmacs_eqmdevs")
SRC_TREE  <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code")
FORK_TREE <- file.path(REPO_ROOT, "GMACs", "GMACS_tpl-cpp_code_eqmdevs")

VER_OLD <- "## GMACS Version 2.20.34; ** AEP **; Compiled 2026-01-15"
VER_NEW <- "## GMACS Version 2.20.34-eqmdevs; ** AEP **; Compiled 2026-01-15"

## exp(LOGRINI_IVAL) is the equilibrium RECRUITMENT (not total numbers) that the
## size-transition matrix is driven with. The accepted fit's Log(Rbar) is
## 13.900027, so start there.
LOGRINI_IVAL <- "13.90"
## Weight on the deviation penalty. 1.0 mirrors Rceattle, where the init_dev
## penalty is an unweighted dnorm at the recruitment sd.
INITDEV_EMPHASIS <- "1.0"

rule <- function(x) message("\n== ", x, " ", strrep("=", max(0, 66 - nchar(x))))

## ---------------------------------------------------------------------------
## 1. Fork the GMACS source
## ---------------------------------------------------------------------------
rule("1. Fork GMACS source")
stopifnot("shared GMACS source tree not found" = dir.exists(SRC_TREE))
tpl_before <- unname(tools::md5sum(file.path(SRC_TREE, "gmacsbase.TPL")))

if (dir.exists(FORK_TREE)) {
  Sys.chmod(list.dirs(FORK_TREE, full.names = TRUE), "755")
  unlink(FORK_TREE, recursive = TRUE)
}
dir.create(FORK_TREE, recursive = TRUE)
for (f in c("gmacsbase.TPL", "personal.TPL", "compile_gmacs_mac.sh"))
  stopifnot(file.copy(file.path(SRC_TREE, f), file.path(FORK_TREE, f), overwrite = TRUE))
for (d in c("src", "include"))
  stopifnot(file.copy(file.path(SRC_TREE, d), FORK_TREE, recursive = TRUE))
Sys.chmod(list.dirs(FORK_TREE, full.names = TRUE), "755")
Sys.chmod(list.files(FORK_TREE, recursive = TRUE, full.names = TRUE), "644")
Sys.chmod(file.path(FORK_TREE, "compile_gmacs_mac.sh"), "755")

## ---------------------------------------------------------------------------
## 2. Patch the TPL
## ---------------------------------------------------------------------------
rule("2. Patch gmacsbase.TPL")
tpl_path <- file.path(FORK_TREE, "gmacsbase.TPL")
tpl <- read_raw_lines(tpl_path)
L   <- tpl$lines
eol_note <- if (identical(tpl$eol, "\r\n")) "CRLF" else "LF"
message("line endings preserved: ", eol_note)

n_edits <- 0L
## Replace a unique anchor line with replacement line(s).
patch <- function(anchor, replacement, what) {
  i <- which(trimws(L) == trimws(anchor))
  if (length(i) != 1L)
    stop(sprintf("anchor for '%s' matched %d lines (expected 1):\n%s",
                 what, length(i), anchor))
  L <<- append(L[-i], replacement, after = i - 1L)
  n_edits <<- n_edits + 1L
  message(sprintf("  %-42s TPL:%d", what, i))
}
## Insert line(s) immediately AFTER a unique anchor line.
insert_after <- function(anchor, addition, what) {
  i <- which(trimws(L) == trimws(anchor))
  if (length(i) != 1L)
    stop(sprintf("anchor for '%s' matched %d lines (expected 1):\n%s",
                 what, length(i), anchor))
  L <<- append(L, addition, after = i)
  n_edits <<- n_edits + 1L
  message(sprintf("  %-42s TPL:%d", what, i))
}

## (a) the mode constant. 4 is taken (#define REFPOINTS 4), so use 6.
insert_after("#define ZEROPOP 5",
             c("  #undef EQMDEVS", "  #define EQMDEVS 6"),
             "(a) #define EQMDEVS 6")

## (b) how many theta parameters the mode expects
insert_after("if (bInitializeUnfished == ZEROPOP)        nthetatest = 0;",
             "    if (bInitializeUnfished == EQMDEVS)        nthetatest = nclass*nsex*nmature*nshell;",
             "(b) theta count")

## (c) parameter naming -- share the FREEPARS loop, distinct names
patch("if ( bInitializeUnfished == FREEPARS ){",
      "    if ( bInitializeUnfished == FREEPARS || bInitializeUnfished == EQMDEVS ){",
      "(c) naming loop covers EQMDEVS")
patch(paste0('anystring = "Initial_logN_for_sex_"+sexes(h)+"_mature_"+maturestate(m)+"_"',
             '+shellstate(o)+"shell_class_"+str(l);'),
      c('              if ( bInitializeUnfished == EQMDEVS )',
        paste0('                anystring = "Init_logdev_for_sex_"+sexes(h)+"_mature_"+maturestate(m)+"_"',
               '+shellstate(o)+"shell_class_"+str(l);'),
        '              else',
        paste0('                anystring = "Initial_logN_for_sex_"+sexes(h)+"_mature_"+maturestate(m)+"_"',
               '+shellstate(o)+"shell_class_"+str(l);')),
      "(d) deviation parameter names")

## (e) validation: the level is logRini, so logR0 must stay off
patch("if ( bInitializeUnfished == ZEROPOP && T_phz(2) > 0 ){",
      c('  if ( bInitializeUnfished == EQMDEVS && T_phz(1) > 0 ){',
        '    cout << "Error: cannot estimate LogR0 with the equilibrium+devs initialisation (the level is LogRini)" << endl;',
        '    exit(1);',
        '  }',
        '  if ( bInitializeUnfished == ZEROPOP && T_phz(2) > 0 ){'),
      "(e) validation")

## (f) read the 88 parameters into logN0, exactly as FREEPARS does
patch("if ( bInitializeUnfished == FREEPARS )",
      "  if ( bInitializeUnfished == FREEPARS || bInitializeUnfished == EQMDEVS )",
      "(f) logN0 assignment")

## (g) the equilibrium recruitment level
patch("case FREEPARS:                                         //> Free parameters",
      c("    case EQMDEVS:                                          //> Equilibrium + penalised deviations",
        "      log_initial_recruits = logRini;",
        "      break;",
        "    case FREEPARS:                                         //> Free parameters"),
      "(g) log_initial_recruits")

## (h) the population at syr: equilibrium x exp(deviations)
patch("case ZEROPOP:                                 ///> zero population",
      c("    case EQMDEVS:                                 ///> Equilibrium x exp(deviations)",
        "     // bSteadyState = FISHEDEQN makes calc_brute_equilibrium use",
        "     // rtt = exp(logRini)*SexRatio (:10741); log_fimpbar = -100 then makes",
        "     // that equilibrium UNFISHED, matching Rceattle initMode 2 (Finit = 0).",
        "     bSteadyState = FISHEDEQN;",
        "     for (int kf=1;kf<=nfleet;kf++) log_fimpbar(kf) = -100;",
        "     x = calc_brute_equilibrium(syr,syr,syr,syr,syr,syr,syr,syr,syr,syr,NyrEquil);",
        "     for ( int ig2 = 1; ig2 <= n_grp; ig2++ )",
        "      d4_N(ig2)(syr)(1) = elem_prod(x(ig2), mfexp(logN0(ig2)));",
        "     break;",
        "    case ZEROPOP:                                 ///> zero population"),
      "(h) population initialisation")

## (i) the deviation penalty, in the dead "Initial_devs" emphasis slot
patch("// 6) Smoothness penalty on recruitment devs.",
             c("  // 5) Initial-abundance deviations from the equilibrium (Rceattle initMode 2,",
               "  //    ceattle.cpp:4394). logN0 are log-deviations around the unfished",
               "  //    equilibrium, shrunk at the recruitment sd with the lognormal bias",
               "  //    correction so E[N_init] is the deterministic equilibrium. The weight is",
               "  //    ctl emphasis 5 (\"Initial_devs\"), which was dead code before this.",
               "  if ( bInitializeUnfished == EQMDEVS )",
               "   {",
               "    dvariable sigR_init = mfexp(logSigmaR);",
               "    for ( int k = 1; k <= n_grp; k++ )",
               "     nlogPenalty(5) += dnorm(logN0(k) + 0.5*sigR_init*sigR_init, sigR_init);",
               "   }",
               "  if (verbose >= 3) cout<<\"finished penalty on initial deviations\"<<endl;",
               "",
               "  // 6) Smoothness penalty on recruitment devs."),
             "(i) nlogPenalty(5) deviation penalty")

## (j) the smoothness penalty is about absolute log-N, not deviations. Gate it
##     inside the loop: the enclosing `for` line is not unique in this file.
patch("nlogPenalty(10) += dnorm(first_difference(logN0(k)), 1.0);",
      "   if ( bInitializeUnfished != EQMDEVS ) nlogPenalty(10) += dnorm(first_difference(logN0(k)), 1.0);",
      "(j) gate smoothness off for EQMDEVS")

## (k) report the new penalty
insert_after(paste0('OutFile1 << "6. Rec_dev: " << nlogPenalty(6) << " " << Penalty_emphasis(6)',
                    ' << " " << nlogPenalty(6)*Penalty_emphasis(6) << endl;'),
             paste0('    OutFile1 << "5. Init_devs: " << nlogPenalty(5) << " " << Penalty_emphasis(5)',
                    ' << " " << nlogPenalty(5)*Penalty_emphasis(5) << endl;'),
             "(k) output the Init_devs penalty")

## (l) version stamp
patch(paste0(' !! TheHeader = adstring("', VER_OLD, '");'),
      paste0(' !! TheHeader = adstring("', VER_NEW, '");'),
      "(l) version stamp")

tpl$lines <- L
write_raw_lines(tpl, tpl_path)
message("edits applied: ", n_edits)

## Sanity: the patched source must mention EQMDEVS in every place we intended.
chk <- read_raw_lines(tpl_path)$lines
stopifnot("EQMDEVS not defined"        = any(grepl("#define EQMDEVS 6", chk, fixed = TRUE)),
          "theta count missing"        = any(grepl("bInitializeUnfished == EQMDEVS)        nthetatest", chk, fixed = TRUE)),
          "population case missing"    = any(grepl("case EQMDEVS:", chk, fixed = TRUE)),
          "penalty missing"            = any(grepl("nlogPenalty(5) += dnorm(logN0(k)", chk, fixed = TRUE)),
          "smoothness gate missing"    = any(grepl("if ( bInitializeUnfished != EQMDEVS )", chk, fixed = TRUE)),
          "shared source was modified" =
            identical(unname(tools::md5sum(file.path(SRC_TREE, "gmacsbase.TPL"))), tpl_before))
message("shared GMACS source unchanged (md5 ", substr(tpl_before, 1, 8), ")")

## ---------------------------------------------------------------------------
## 3. Compile
## ---------------------------------------------------------------------------
rule("3. Compile")
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
## 4. Build the model directory
## ---------------------------------------------------------------------------
rule("4. Build Models/26_gmacs_eqmdevs")
gc_src  <- read_gmacs_control(SRC_MODEL)
DATFILE <- gc_src$datafile; CTLFILE <- gc_src$ctlfile; PRJFILE <- gc_src$prjfile

if (dir.exists(DST_MODEL)) unlink(DST_MODEL, recursive = TRUE)
dir.create(DST_MODEL, recursive = TRUE)
for (f in c(DATFILE, PRJFILE))
  stopifnot(file.copy(file.path(SRC_MODEL, f), file.path(DST_MODEL, f)))

.split_runs <- function(line) {
  m <- gregexpr("[[:space:]]+|[^[:space:]]+", line, useBytes = TRUE)
  regmatches(line, m)[[1]]
}
set_field <- function(line, k, value) {
  runs <- .split_runs(line)
  tok  <- which(!grepl("^[[:space:]]", runs, useBytes = TRUE))
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

ctl <- read_raw_lines(file.path(SRC_MODEL, CTLFILE)); C <- ctl$lines

i_mode <- grep("# Initial conditions", C, fixed = TRUE)
stopifnot("source is not mode 2" = length(i_mode) == 1L && get_field(C[i_mode], 1) == "2")
C[i_mode] <- set_field(C[i_mode], 1, "6")

i_rini <- grep("# logRini", C, fixed = TRUE)
stopifnot("logRini not fixed as expected" = get_field(C[i_rini], 7) == "-1")
C[i_rini] <- set_field(set_field(C[i_rini], 7, "1"), 1, LOGRINI_IVAL)

i_r0 <- grep("# logR0", C, fixed = TRUE)
stopifnot("logR0 must stay off" = as.integer(get_field(C[i_r0], 7)) <= 0L)

## The 88 rows are now DEVIATIONS. The five previously pinned at -19 (an absolute
## log-N meaning "empty") would mean "e^-19 times equilibrium" here; 0 is the
## right fixed value, i.e. sit exactly on the equilibrium.
i_dev <- grep("# Deviation for size-class", C, fixed = TRUE)
stopifnot("expected 88 initial rows" = length(i_dev) == 88L)
n19 <- 0L
for (i in i_dev) if (get_field(C[i], 1) == "-19") { C[i] <- set_field(C[i], 1, "0.0"); n19 <- n19 + 1L }
stopifnot("expected 5 rows pinned at -19" = n19 == 5L)

i_emp <- grep("# Initial_devs", C, fixed = TRUE)
i_emp <- i_emp[grepl("^[[:space:]]*[0-9]", C[i_emp])]
stopifnot("expected one Initial_devs emphasis row" = length(i_emp) == 1L)
stopifnot("Initial_devs emphasis is not the expected 15" = get_field(C[i_emp], 1) == "15")
C[i_emp] <- set_field(C[i_emp], 1, INITDEV_EMPHASIS)

ctl$lines <- C
write_raw_lines(ctl, file.path(DST_MODEL, CTLFILE))

dat <- read_raw_lines(file.path(SRC_MODEL, "gmacs.dat"))
i_pin <- grep("use pin file", dat$lines, fixed = TRUE)
dat$lines[i_pin] <- set_field(dat$lines[i_pin], 1, "0")
write_raw_lines(dat, file.path(DST_MODEL, "gmacs.dat"))

if (file.exists(exe_path)) {
  stopifnot(file.copy(exe_path, file.path(DST_MODEL, gmacs_exe_name())))
  Sys.chmod(file.path(DST_MODEL, gmacs_exe_name()), "755")
}
stopifnot(file.copy(tpl_path, file.path(DST_MODEL, "gmacsbase.TPL")))

## ---------------------------------------------------------------------------
## 5. Verify
## ---------------------------------------------------------------------------
rule("5. Verify")
md5 <- function(p) unname(tools::md5sum(p))
for (f in c(DATFILE, PRJFILE)) {
  stopifnot(setNames(identical(md5(file.path(SRC_MODEL, f)), md5(file.path(DST_MODEL, f))),
                     paste(f, "is not byte-identical to the source")))
  message("byte-identical to 26 model : ", f)
}
new <- read_raw_lines(file.path(DST_MODEL, CTLFILE))$lines
stopifnot("ctl line count changed" = length(new) == length(ctl$lines))
message("snow.ctl lines changed     : ", sum(new != read_raw_lines(file.path(SRC_MODEL, CTLFILE))$lines),
        "  (1 mode + 1 logRini + 5 pinned devs + 1 emphasis)")
message("initialisation mode        : 2 (FREEPARS) -> 6 (EQMDEVS)")
message("logRini                    : phase -1 -> 1, ival ", LOGRINI_IVAL)
message("emphasis 5 (Initial_devs)  : 15 -> ", INITDEV_EMPHASIS, "  (was dead code)")
stale <- intersect(c("gmacs.par","gmacs.std","Gmacsall.out","gmacs.rep","gmacs.pin"),
                   list.files(DST_MODEL))
stopifnot("the new model dir contains a fit" = length(stale) == 0L)
message("no inherited fit           : ok")

writeLines(c(
  "# Models/26_gmacs_eqmdevs -- provenance",
  "",
  sprintf("Built %s by `00d_build_eqmdevs_model.R`. **Inputs only -- not fit.**",
          format(Sys.Date())),
  "Not a core model folder; not registered in `0-models.R`.",
  "",
  "## What this is",
  "",
  "Rceattle's `initMode = 2` ported into GMACS as a new initialisation mode 6",
  "(`EQMDEVS`). The 1982 population becomes",
  "",
  "```",
  "d4_N(ig)(syr)(1) = x_equilibrium(ig) * exp(logN0(ig))",
  "```",
  "",
  "with `x` the **unfished equilibrium** scaled by `exp(logRini)` (Rceattle's",
  "`R_init`), and `logN0` the 88 log-deviations penalised at the recruitment sd:",
  "",
  "```",
  "nlogPenalty(5) = sum_k dnorm(logN0(k) + 0.5*sigmaR^2, sigmaR)",
  "```",
  "",
  "weighted by ctl emphasis 5 (`Initial_devs`) -- a slot that was **dead code** in",
  "stock 2.20.34 (no `nlogPenalty(5)` existed). Weight set to 1.0 to mirror",
  "Rceattle, giving an effective sd of sigmaR = exp(-0.9) = 0.407.",
  "",
  "With M by size the scalar geometric series `1/(1-exp(-M))` becomes the matrix",
  "Neumann series `(I - S.G)^-1 = sum_k (S.G)^k`, which is what",
  "`calc_brute_equilibrium()` computes by iterating 200 years at constant",
  "recruitment.",
  "",
  "## Design points",
  "",
  "- Mode number 6, because 4 is already `#define REFPOINTS 4`.",
  "- `bSteadyState = FISHEDEQN` so the equilibrium uses `exp(logRini)`; then",
  "  `log_fimpbar = -100` makes it unfished, matching Rceattle (`Finit = 0` for",
  "  initMode 2).",
  "- The mode does NOT join the `UNFISHEDEQN` branch at `:8418`, which sets",
  "  recruitment for EVERY year. Annual recruitment stays on `logRbar`; only the",
  "  syr equilibrium uses `logRini`.",
  "- The first-difference smoothness penalty `nlogPenalty(10)` is gated OFF:",
  "  `logN0` are deviations here, and Rceattle puts no smoothness on `init_dev`.",
  "- The five rows previously pinned at -19 (absolute log-N, \"empty\") are pinned",
  "  at 0 instead -- as deviations that means \"sit on the equilibrium\".",
  "",
  "## Verification still owed",
  "",
  "Fixing all 88 deviations at 0 must reproduce a pure equilibrium start; that is",
  "the test that the backbone is wired up correctly. Then fit, jitter, and compare",
  "on reference points (nll is NOT comparable across initialisation modes)."),
  file.path(DST_MODEL, "PROVENANCE.md"))

rule("Done")
message("Models/26_gmacs_eqmdevs/ built. Inputs only -- not fit.")
message("Contents: ", paste(sort(list.files(DST_MODEL)), collapse = "  "))
