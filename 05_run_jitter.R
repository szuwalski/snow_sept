#!/usr/bin/env Rscript
## ============================================================================
## 05_run_jitter.R -- jitter (convergence / local-optimum) analysis for GMACS
##
## Re-fits the model many times from randomly perturbed starting values to test
## whether the reported fit is a global optimum. This sets federal harvest
## specifications: the 2025 SAFE reported the LOWEST-nll run out of 100 jitters,
## having found two clouds ~0.2 nll apart whose OFLs differed by 5,000 t.
##
## Run from the repo root:
##   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 05_run_jitter.R --dry-run
##   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 05_run_jitter.R --pilot
##   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 05_run_jitter.R
##
## Flags
##   --dry-run        preflight only; report and exit without running anything
##   --pilot          run PILOT_N jitters and stop after the verification gate
##   --n <int>        number of jitter runs (default JITTER_N)
##   --cores <int>    parallel workers (default: gmacs_max_workers(), see R/gmacs_io.R:7)
##   --model <dir>    model directory under Models/ (default MODEL_NAME)
##   --seed-base <n>  base for the deterministic per-run seeds
##   --no-promote     never promote a better-fitting jitter run (see PROMOTION)
##   --force          re-run every jitter directory instead of resuming
##   --tag <name>     short name used in output filenames (default: derived from
##                    --model; see "Output naming")
##
## Outputs -- ALWAYS, for every model
##   Models/<model>/jitter/<nnn>/                one directory per run
##   Models/<model>/jitter/jitter_results.csv
##   Models/rda_jitter_<tag>.RData               object `jitter`
##   plots/jittered_results_{ofl,rec,ssb}_<tag>.png
##   plots/jitter_convergence_<tag>.png
##   plots/jitter_param_attribution_<tag>.png
##
## Outputs -- ONLY when --model is REPORT_MODEL (copies of the above)
##   Models/rda_jitter.RData                     read by SAFE_snow_gmacs.Rmd:976
##   plots/jittered_results_{ofl,rec,ssb}.png    the names the Rmd expects
##   plots/jitter_convergence.png
##   plots/jitter_param_attribution.png
##
## ---------------------------------------------------------------------------
## PROMOTION
##
## If a jitter run fits better than the base by more than NLL_TOL, the base sat
## in an inferior local optimum. Following the 2025 precedent, the better fit is
## promoted into the model directory: the previous outputs are backed up, the
## winner's gmacs.par becomes gmacs.pin, the model is re-fit WITH the Hessian,
## the result is verified against the winner, and jitter/PROMOTION.md records
## what happened. A failed verification rolls back.
##
## This changes MMB/OFL for everything downstream, including the retrospective
## peels, which must then be re-run. Disable with --no-promote.
## ============================================================================

suppressPackageStartupMessages({
  library(doParallel)
  library(parallel)
  library(foreach)
  library(ggplot2)
})

## ---------------------------------------------------------------------------
## Configuration
## ---------------------------------------------------------------------------
MODEL_NAME  <- "26_gmacs_update_newmat_plus_group"  # the 2026 final model
JITTER_N    <- 100L        # 2025 convention
JITTER_SD   <- 0.1         # sdJitter; read from gmacs.dat and asserted, not written
SEED_BASE   <- 20260821L   # per-run seed = SEED_BASE + run index -> fully reproducible
PILOT_N     <- 3L

## Disk budget, computed rather than fixed (was a flat 50 GB, sized when every
## run kept its 620 MB cmpdiff.tmp forever -- 62 GB of scratch across 100 runs).
## run_gmacs() now purges ADMB scratch as each run finishes, so only the
## concurrent workers hold a copy at any moment. Measured on the 26 model,
## 2026-08-24: 0.62 GB scratch live per worker, ~17 MB of retained output per
## run. PROMOTION_GB covers the backup plus the re-fit a promotion performs.
SCRATCH_GB_PER_WORKER <- 0.62
OUTPUT_GB_PER_RUN     <- 0.017
PROMOTION_GB          <- 1.0
DISK_MARGIN_GB        <- 1.5    # headroom; a full volume corrupts a mid-write run
## Worker count comes from gmacs_max_workers() (R/gmacs_io.R:7), resolved after
## the source() below. Deliberately NOT detectCores(): a wide fan-out of ADMB
## processes hard-resets this laptop mid-run (2026-08, per Grant).

## Two gradient thresholds, deliberately separate.
##
## GRAD_CONVENTIONAL is the textbook convergence criterion. It is REPORTED, not
## used to filter: this assessment does not meet it. The 2026 base fit sits at
## 2.54e-3 and the SAFE already states that most candidate models exceed 1e-3.
## Screening on it would discard every run and leave the jitter with nothing to
## analyse -- which looks like a clean result and is actually an empty one.
##
## GRAD_USABLE is the screen for admitting a run to the cloud analysis: loose
## enough to include runs comparable to the base fit, tight enough to exclude
## runs that stopped nowhere near an optimum. Both counts are reported so the
## SAFE can state convergence honestly rather than against a flattering cutoff.
GRAD_CONVENTIONAL <- 1e-3
GRAD_USABLE       <- 1e-2

NLL_TOL     <- 0.001       # nll difference treated as "the same optimum"
MODE_GAP    <- 0.01        # cluster height separating jitter clouds
MIN_MODE_N  <- 3L          # runs needed before a cluster counts as a mode
TOP_PARAMS  <- 15L         # parameters reported in the attribution table

## ---------------------------------------------------------------------------
## Output naming -- WHY THIS EXISTS (2026-08-30)
## ---------------------------------------------------------------------------
## Until today this script wrote Models/rda_jitter.RData and five FIXED plot
## paths regardless of --model. Those six paths are what SAFE_snow_gmacs.Rmd
## reads for the ACCEPTED model (:976 and the figure chunks), so a jitter of any
## other model silently replaced the accepted model's diagnostics with a
## different model's, under the accepted model's labels. Nothing in the rendered
## document would look wrong. It happened on 2026-08-30 -- the report path held
## 26_gmacs_combined's results and was caught by a hand md5 check, not by
## anything in the pipeline, and the accepted model's jitter object existed in no
## backed-up location at all.
##
## Now: EVERY run writes per-model files. The shared paths are additionally
## written ONLY when the model is REPORT_MODEL, so no diagnostic jitter can
## reach the SAFE by accident.
##
## OUTPUT_TAG reproduces the names already referenced by 0-models.R:215-217 and
## SAFE_snow_gmacs.Rmd:543,4208-4212 -- stripping the "<yy>_gmacs_" prefix gives
## male_only, stability, eqmdevs, combined, data2019. The accepted model is the
## one exception, kept as "26" because that is the name already in use. Use
## --tag to override for anything these rules do not cover (e.g. 25.2c).
REPORT_MODEL <- "26_gmacs_update_newmat_plus_group"  # the model the SAFE reports
REPORT_TAG   <- "26"

## ---------------------------------------------------------------------------
## Command line
## ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
has_flag <- function(f) f %in% args
opt_val  <- function(f, default) {
  i <- match(f, args)
  if (is.na(i) || i == length(args)) return(default)
  args[i + 1L]
}
DRY_RUN     <- has_flag("--dry-run")
PILOT       <- has_flag("--pilot")
FORCE       <- has_flag("--force")
PROMOTE     <- !has_flag("--no-promote")
MODEL_NAME  <- opt_val("--model", MODEL_NAME)
SEED_BASE   <- as.integer(opt_val("--seed-base", SEED_BASE))
N_RUNS      <- as.integer(opt_val("--n", if (PILOT) PILOT_N else JITTER_N))
CORES_ARG   <- opt_val("--cores", NA_character_)
if (is.na(N_RUNS) || N_RUNS < 1L)  stop("--n must be a positive integer")

## Short name used in every output filename (see "Output naming" above).
OUTPUT_TAG <- opt_val("--tag",
                      if (identical(MODEL_NAME, REPORT_MODEL)) REPORT_TAG
                      else sub("^[0-9]+_gmacs_", "", MODEL_NAME))
IS_REPORT_MODEL <- identical(MODEL_NAME, REPORT_MODEL)

## "jitter_convergence.png" -> "jitter_convergence_<tag>.png"
tagged <- function(file)
  sub("\\.([^.]+)$", paste0("_", OUTPUT_TAG, ".\\1"), file, perl = TRUE)

REPO_ROOT <- normalizePath(getwd(), winslash = "/")
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))
source(file.path(REPO_ROOT, "R", "gmacs_jitter.R"))

## Resolved after source() because gmacs_max_workers() lives in R/gmacs_io.R.
N_CORES <- if (is.na(CORES_ARG)) gmacs_max_workers() else as.integer(CORES_ARG)
if (is.na(N_CORES) || N_CORES < 1L) stop("--cores must be a positive integer")

MODEL_DIR  <- normalizePath(file.path(REPO_ROOT, "Models", MODEL_NAME),
                            winslash = "/", mustWork = TRUE)
JITTER_DIR <- file.path(MODEL_DIR, "jitter")

rule <- function(x) message("\n== ", x, " ", strrep("=", max(0, 68 - nchar(x))))

## ===========================================================================
## Phase A -- preflight
## ===========================================================================
rule("A. Preflight")
message("model      : Models/", MODEL_NAME)
message("output tag : ", OUTPUT_TAG, "   -> Models/rda_jitter_", OUTPUT_TAG,
        ".RData, plots/*_", OUTPUT_TAG, ".png")
message("SAFE paths : ", if (IS_REPORT_MODEL)
        "WILL BE WRITTEN (this is the report model)" else
        paste0("not written (report model is ", REPORT_MODEL, ")"))
message("runs       : ", N_RUNS, "   workers: ", N_CORES, "   seeds: ",
        SEED_BASE + 1L, "..", SEED_BASE + N_RUNS)

## File names are DISCOVERED from gmacs.dat, never hardcoded. The 2026 model's
## data file is 26_snow_update_newmat_plus_group.dat; there is no snow.dat, and
## file.copy() of a missing file returns FALSE without erroring.
gc_ctl <- read_gmacs_control(MODEL_DIR)
message("datafile   : ", gc_ctl$datafile)
message("controlfile: ", gc_ctl$ctlfile)
message("projection : ", gc_ctl$prjfile)

exe <- gmacs_exe_info(MODEL_DIR)
message("executable : ", gmacs_exe_name(), ", ", exe$bytes, " bytes, ", exe$mtime,
        ", md5 ", exe$md5)
message("exe version: ", gmacs_exe_version(MODEL_DIR))

## The jitter line is read to confirm sdJitter and to fail loudly if the file
## format shifts again -- it is never written (see R/gmacs_jitter.R header).
jspec <- read_jitter_spec(gc_ctl)
message("jitter line: '", jspec$raw, "'  -> sdJitter = ", jspec$sd,
        "  (field order ", paste(verified_jitter_field_order, collapse = " "), ")")
if (!isTRUE(all.equal(jspec$sd, JITTER_SD)))
  stop(sprintf(paste0("gmacs.dat declares sdJitter = %s but this script is configured for %s. ",
                      "The jitter magnitude is a decision about the diagnostic -- reconcile ",
                      "them deliberately rather than letting them drift apart."),
               jspec$sd, JITTER_SD))

## A retrospective peel left switched on would silently shorten every run.
retro_val <- suppressWarnings(as.integer(trimws(gc_ctl$obj$lines[gc_ctl$retro_idx])))
if (!identical(retro_val, 0L))
  stop("gmacs.dat has Retrospective = ", retro_val,
       "; jitter runs must use the full time series. Reset it to 0.")

assert_no_stray_pin(MODEL_DIR)

yr <- read_dat_year_range(file.path(MODEL_DIR, gc_ctl$datafile))
message("year range : ", yr$start_year, "-", yr$end_year, " (from ", gc_ctl$datafile, ")")

MIN_DISK_GB <- N_CORES * SCRATCH_GB_PER_WORKER + N_RUNS * OUTPUT_GB_PER_RUN +
               (if (PROMOTE) PROMOTION_GB else 0) + DISK_MARGIN_GB

free_gb <- disk_free_gb(MODEL_DIR)
if (!is.na(free_gb)) {
  message("disk free  : ", round(free_gb, 1), " GB   (need ", round(MIN_DISK_GB, 1),
          " GB: ", N_CORES, " workers x ", SCRATCH_GB_PER_WORKER, " GB scratch + ",
          N_RUNS, " x ", OUTPUT_GB_PER_RUN, " GB output",
          if (PROMOTE) paste0(" + ", PROMOTION_GB, " GB promotion") else "",
          " + ", DISK_MARGIN_GB, " GB margin)")
  if (free_gb < MIN_DISK_GB)
    stop(sprintf(paste0("Only %.1f GB free; %.1f GB required for %d runs on %d workers. ",
                        "Lower --cores (each worker holds %.2f GB of ADMB scratch), lower ",
                        "--n, or free space. Do NOT run a volume to zero: a full disk ",
                        "corrupts whichever run directory is mid-write."),
                 free_gb, MIN_DISK_GB, N_RUNS, N_CORES, SCRATCH_GB_PER_WORKER))
}

base <- base_run_status(gc_ctl, expect_end_year = yr$end_year)
if (base$stale) {
  message("\nbase fit   : STALE -- ", length(base$reasons), " problem(s):")
  for (r in base$reasons) message("             - ", r)
} else {
  message("base fit   : current (nll ", round(base$nll, 4),
          ", max|grad| ", signif(base$max_grad, 3), ")")
}

if (DRY_RUN) {
  message("\n--dry-run: preflight only, nothing was run.")
  quit(save = "no", status = 0L)
}

## ===========================================================================
## Phase B -- base fit
## ===========================================================================
rule("B. Base fit")
if (base$stale) {
  message("Fitting the base model (with Hessian) -- required before jittering.")
  bi <- run_gmacs(MODEL_DIR, args = c("-nox", "-verbose", "0"), log = "gmacs_base_run.log")
  message("  exit ", bi$status, " in ", round(bi$elapsed, 1), "s")
  if (length(bi$errors)) for (e in bi$errors) message("  log: ", e)
  if (!bi$ok) stop("The base fit failed. See ", file.path(MODEL_DIR, "gmacs_base_run.log"))

  base <- base_run_status(gc_ctl, expect_end_year = yr$end_year)
  if (base$stale)
    stop("The base fit ran but still looks stale:\n  - ", paste(base$reasons, collapse = "\n  - "))
  if (!file.exists(file.path(MODEL_DIR, "gmacs.std")))
    stop("The base fit produced no gmacs.std -- the Hessian did not invert. ",
         "The SAFE needs standard errors from this fit.")
  message("  base nll ", round(base$nll, 4), ", max|grad| ", signif(base$max_grad, 3))
} else {
  message("Base fit is current; skipping (End year ", base$end_year, ").")
}
if (!is.na(base$max_grad) && base$max_grad > GRAD_CONVENTIONAL)
  message(sprintf("  note: base max|grad| %.3g exceeds the conventional %.0e. ",
                  base$max_grad, GRAD_CONVENTIONAL),
          "Expected for this assessment; recorded and reported, not fatal.")
BASE_NLL <- base$nll

## ===========================================================================
## Phase C/D -- build run directories and execute
## ===========================================================================
rule(sprintf("C/D. %d jitter runs on %d workers", N_RUNS, N_CORES))
dir.create(JITTER_DIR, recursive = TRUE, showWarnings = FALSE)

run_ids   <- sprintf("%03d", seq_len(N_RUNS))
run_dirs  <- file.path(JITTER_DIR, run_ids)
run_seeds <- SEED_BASE + seq_len(N_RUNS)

## Resume: a directory counts as done only if it holds output AND its recorded
## seed is the one we would ask for now.
## Deliberately does NOT require gmacs.std: jitter runs are made with -nohess,
## so a complete run legitimately has no .std file.
##
## It DOES require that Gmacsall.out ends with GMACS's ">EOD<" terminator.
## File existence is not enough: a hard reset mid-write leaves a truncated
## Gmacsall.out that still parses for hundreds of lines and looks like a result.
## This machine reset during a 100-run sweep on 2026-08-21 and left 18 of 44
## directories in that state. Without this check they would be treated as done
## and silently omitted from the analysis forever.
.ends_cleanly <- function(f) {
  if (!file.exists(f)) return(FALSE)
  L <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(0))
  L <- trimws(L[nzchar(trimws(L))])
  length(L) > 0L && utils::tail(L, 1L) == ">EOD<"
}
is_done <- function(d, seed) {
  .ends_cleanly(file.path(d, "Gmacsall.out")) &&
    file.exists(file.path(d, "gmacs.par")) &&
    isTRUE(identical(suppressWarnings(as.integer(trimws(readLines(
      file.path(d, "jitter.txt"), warn = FALSE)[1]))), as.integer(seed)))
}
todo <- if (FORCE) seq_len(N_RUNS) else
  which(!vapply(seq_len(N_RUNS), function(i)
    dir.exists(run_dirs[i]) && is_done(run_dirs[i], run_seeds[i]), logical(1)))
message(length(todo), " run(s) to do, ", N_RUNS - length(todo), " already complete.")

if (length(todo)) {
  cl <- parallel::makeCluster(min(N_CORES, length(todo)))
  registerDoParallel(cl)
  on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)

  t0 <- Sys.time()
  ## Each worker sources the helpers itself, so nothing depends on what the
  ## parent happens to have in scope.
  infos <- foreach(i = todo, .packages = character(0),
                   .export = c("REPO_ROOT", "run_dirs", "run_seeds", "gc_ctl")) %dopar% {
    source(file.path(REPO_ROOT, "R", "gmacs_io.R"))
    source(file.path(REPO_ROOT, "R", "gmacs_jitter.R"))
    prepare_run_dir(gc_ctl, run_dirs[i])
    ## -jitter <seed> forces IsJittered=1 and fixes the seed; gmacs.dat is
    ## copied unmodified.
    ##
    ## -nohess: the jitter asks "where does the optimiser land", which needs the
    ## likelihood and the point estimates, not their standard errors. Skipping
    ## the sd phase roughly halves run time (~2 min vs ~4). The single run that
    ## is finally adopted IS re-fit with the Hessian, in Phase F.
    ##
    ## The cost is that the ADMB sdreport quantities -- OFL(tot), BMSY,
    ## Bcurr/BMSY -- come back as exactly 0.0 rather than missing. collect_run()
    ## records those as NA (never 0) and the figures use Ofl (1), the DIRECTED
    ## OFL, which -nohess preserves and which is what the SAFE's jitter figure
    ## has always plotted. See the note above collect_run() in R/gmacs_jitter.R.
    run_gmacs(run_dirs[i],
              args = c("-jitter", run_seeds[i], "-nohess", "-nox", "-verbose", "0"))
  }
  names(infos) <- run_ids[todo]
  parallel::stopCluster(cl)
  message("  wall clock: ", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1),
          " min for ", length(todo), " run(s)")
} else {
  infos <- list()
}

## ===========================================================================
## Phase E -- verify, then collect
## ===========================================================================
rule("E. Verification")

## The failure mode that matters is a directory full of plausible output from
## runs that were never actually jittered. jitter.txt is the proof: GMACS writes
## it only when IsJittered != 0, and writes the seed it really used.
ver <- lapply(seq_len(N_RUNS), function(i)
  verify_jitter_run(run_dirs[i], run_seeds[i], jspec$sd, yr$end_year))
bad <- which(!vapply(ver, `[[`, logical(1), "ok"))
ran <- which(dir.exists(run_dirs) & file.exists(file.path(run_dirs, "gmacs.par")))

if (length(bad)) {
  message(length(bad), " of ", N_RUNS, " run(s) failed verification:")
  for (i in utils::head(bad, 10L))
    message("  ", run_ids[i], ": ", paste(ver[[i]]$problems, collapse = "; "))
  if (length(bad) > 10L) message("  ... and ", length(bad) - 10L, " more")
}
## A run that never produced output is a failed run; a run that produced output
## while NOT jittered invalidates the whole diagnostic.
mis_jittered <- intersect(bad, ran)
if (length(mis_jittered))
  stop(length(mis_jittered), " run(s) produced output but were not correctly jittered ",
       "(see above). These results would be meaningless -- fix before continuing.")

res <- do.call(rbind, lapply(seq_len(N_RUNS), function(i) {
  r <- collect_run(run_dirs[i], i, run_seeds[i], infos[[run_ids[i]]])
  r$seed_used <- ver[[i]]$seed_used
  r
}))
res$converged           <- res$complete & !is.na(res$maxGrad) & res$maxGrad < GRAD_USABLE
res$meets_conventional  <- res$complete & !is.na(res$maxGrad) & res$maxGrad < GRAD_CONVENTIONAL

## Batch-level assertions.
ok_runs <- res[res$complete, ]
if (!nrow(ok_runs)) stop("No jitter run produced complete results.")
if (anyDuplicated(res$seed))
  stop("Duplicate seeds requested -- the runs would not be independent.")

## An all-zero OFL cloud is what a -nohess run produces: BMSY / Bcurr/BMSY /
## OFL are sdreport quantities and come back exactly 0 when the sd phase is
## skipped, while Fmsy and Fofl still look plausible. Catch it here rather than
## letting a figure of zeros reach the SAFE.
if (all(ok_runs$ofl_directed == 0, na.rm = TRUE))
  stop("Every run returned a directed OFL of 0. Ofl (1) normally survives ",
       "-nohess, so this means the reference-point calculation did not run at ",
       "all -- check that gmacs.dat still has 'Calculate reference points' = 1.")
if (any(ok_runs$ofl_directed == 0, na.rm = TRUE))
  warning(sum(ok_runs$ofl_directed == 0, na.rm = TRUE),
          " run(s) returned a directed OFL of 0 and are excluded from the OFL figures.",
          call. = FALSE)
if (nrow(ok_runs) > 1L && length(unique(round(ok_runs$objFun, 8))) == 1L)
  stop("Every completed run returned an identical objective function. The jitter ",
       "is not taking effect -- do not report these results.")

message(sprintf("complete: %d/%d   usable (max|grad| < %.0e): %d   meets %.0e: %d",
                nrow(ok_runs), N_RUNS, GRAD_USABLE, sum(res$converged),
                GRAD_CONVENTIONAL, sum(res$meets_conventional)))
message(sprintf("max|grad| range: %.3g to %.3g   (base %.3g)",
                min(ok_runs$maxGrad, na.rm = TRUE), max(ok_runs$maxGrad, na.rm = TRUE),
                base$max_grad))
message(sprintf("nll range: %.4f to %.4f   (base %.4f)",
                min(ok_runs$objFun), max(ok_runs$objFun), BASE_NLL))
message(sprintf("directed OFL range: %.3f to %.3f kt", min(ok_runs$ofl_directed), max(ok_runs$ofl_directed)))

if (PILOT) {
  message("\n--pilot: verification gate PASSED for ", N_RUNS, " run(s).")
  message("Seeds honoured, IsJittered echoed as 1, objective functions distinct.")
  message("Mean run time: ", round(mean(res$elapsed_s, na.rm = TRUE), 1), "s -- ",
          "estimate for ", JITTER_N, " runs on ", N_CORES, " workers: ",
          round(mean(res$elapsed_s, na.rm = TRUE) * JITTER_N / N_CORES / 60, 1), " min.")
  quit(save = "no", status = 0L)
}

## ===========================================================================
## Phase F -- best run and promotion
## ===========================================================================
rule("F. Best run")
## Runs within NLL_TOL of the best nll ARE the same optimum, so the gradient
## picks among them. Ordering on objFun directly never reaches the maxGrad
## tiebreaker -- objFun is a continuous double and exact ties do not occur. On
## 2026-08-28 the male-only jitter had five runs agreeing to 2e-09 in nll and
## 1.6e-05 kt in OFL; ordering on objFun promoted the one with max|grad|
## 0.00166 (failing the 1e-3 criterion) over a numerically identical run at
## 0.000712, because its nll was lower by 1.6e-09. The reported convergence of
## a fit that sets the OFL was decided by floating-point noise.
## na.rm and the non-finite guard are load-bearing: ok_runs is filtered on
## `complete` only, so a run can in principle carry an unparsed objFun. Without
## them a single NA makes min() NA, every bucket NA, and order() falls through
## to maxGrad alone -- which would promote the lowest-gradient run regardless of
## its likelihood (on this data set that is a fit 5.6 nll units worse).
if (!any(is.finite(ok_runs$objFun)))
  stop("No complete jitter run has a finite objective function value.")
best_nll   <- min(ok_runs$objFun, na.rm = TRUE)
nll_bucket <- floor((ok_runs$objFun - best_nll) / NLL_TOL)
nll_bucket[!is.finite(nll_bucket)] <- Inf   # unparsed nll can never win
ord  <- order(nll_bucket, abs(ok_runs$maxGrad))
best <- ok_runs[ord[1], ]
improvement <- BASE_NLL - best$objFun
message(sprintf("best run %s: nll %.4f (base %.4f, improvement %.4f), max|grad| %.3g",
                sprintf("%03d", best$idx), best$objFun, BASE_NLL, improvement, best$maxGrad))
message(sprintf("  OFL %.3f kt (base run's OFL is in the model dir), MMB %.3f kt",
                best$ofl_directed, best$mmb_terminal))

promoted <- FALSE
if (improvement > NLL_TOL) {
  message("\n*** A jitter run fits better than the base by ", round(improvement, 4),
          " nll units. The base fit was at an inferior local optimum. ***")
  if (!PROMOTE) {
    message("--no-promote: reporting only; the model directory is unchanged.")
  } else {
    backup <- file.path(JITTER_DIR, "base_prepromotion")
    dir.create(backup, recursive = TRUE, showWarnings = FALSE)

    ## Snapshot EVERY file the fit wrote, not a hand-listed subset. The former
    ## nine-name list could not restore a directory even in principle: it
    ## omitted admodel.hes / admodel.cov (the Hessian, which ADMB reuses for
    ## MCMC), gmacs.eva (eigenvalues), gradient.dat, checkfile.rep and
    ## personal.rep. After the 2026-08-24 rollback those six still described the
    ## REJECTED promotion run while gmacs.par/.std described the base -- one
    ## directory holding two different fits, which no downstream reader checks.
    ##
    ## Inputs and the executable are excluded: a fit does not rewrite them, and
    ## the exe is 3.5 MB (macOS) / 8.9 MB (Windows) per copy.
    exclude <- c(gc_ctl$datafile, gc_ctl$ctlfile, gc_ctl$prjfile, "gmacs.dat",
                 "gmacs", "gmacs.exe")
    ## ADMB scratch is excluded too: it is regenerated by every run, never read,
    ## and cmpdiff.tmp alone is 620 MB -- backing it up would put most of a
    ## gigabyte of garbage in base_prepromotion/ (observed 2026-08-27).
    snap <- function() {
      f <- setdiff(list.files(MODEL_DIR, all.files = FALSE, no.. = TRUE), exclude)
      f <- f[!grepl(GMACS_SCRATCH_PATTERN, f)]
      f[!dir.exists(file.path(MODEL_DIR, f))]
    }
    ## Record what actually made it into the backup. An unchecked file.copy()
    ## here is what let the 2026-08-24 rollback lie: a file that was never
    ## backed up is skipped by the restore loop, so it lands in neither
    ## `restored` nor `failed` and the "as it was" message covers for it.
    keep <- snap()
    backed_up <- unbacked <- character(0)
    for (f in keep) {
      s <- file.path(MODEL_DIR, f); d <- file.path(backup, f)
      file.copy(s, d, overwrite = TRUE)
      if (file.exists(d) && identical(unname(tools::md5sum(s)), unname(tools::md5sum(d))))
        backed_up <- c(backed_up, f)
      else
        unbacked <- c(unbacked, f)
    }
    if (length(unbacked))
      stop("Could not back up ", length(unbacked), " file(s) before promoting, so a\n",
           "rollback could not restore them. Refusing to promote:\n  - ",
           paste(unbacked, collapse = "\n  - "))
    message("  backed up the previous fit to jitter/base_prepromotion/ (",
            length(backed_up), " files, md5-verified)")

    copy_checked(file.path(best$folder, "gmacs.par"), file.path(MODEL_DIR, "gmacs.pin"),
                 "winner's gmacs.par -> gmacs.pin")
    pi_ <- run_gmacs(MODEL_DIR, args = c("-nox", "-verbose", "0"), log = "gmacs_promote_run.log")
    after <- read_par_header(MODEL_DIR)
    good <- pi_$ok && !is.na(after$nll) &&
      abs(after$nll - best$objFun) <= NLL_TOL &&
      file.exists(file.path(MODEL_DIR, "gmacs.std"))

    if (!good) {
      message("  promotion FAILED (exit ", pi_$status, ", nll ", after$nll,
              "); rolling back.")
      unlink(file.path(MODEL_DIR, "gmacs.pin"))

      ## Verify the rollback by checksum instead of trusting file.copy()'s
      ## return value. On 2026-08-24 this loop reported success while leaving
      ## seven of nine files holding the REJECTED promotion run, and the old
      ## message below then asserted "the model directory is as it was" -- a
      ## model dir containing output from a fit the script had just judged
      ## invalid, announced as clean. That is the worst failure mode this repo
      ## has (CLAUDE.md rule 1), so the claim is now earned, not assumed.
      ## Iterate `backed_up`, not `keep`: every entry is known to exist in the
      ## backup, so nothing can be silently skipped. (They are equal here --
      ## the backup step above aborts otherwise -- but the restore must not
      ## depend on that being true.)
      restored <- failed <- character(0)
      for (f in backed_up) {
        s <- file.path(backup, f); d <- file.path(MODEL_DIR, f)
        file.copy(s, d, overwrite = TRUE)
        if (identical(unname(tools::md5sum(s)), unname(tools::md5sum(d))))
          restored <- c(restored, f)
        else
          failed <- c(failed, f)
      }

      ## Anything the rejected run CREATED that the base fit had not written is
      ## not restorable -- it has to be deleted, or the directory keeps a file
      ## belonging to a fit that is no longer here.
      ##
      ## EXCEPT the promotion's own logs. They are created after the snapshot,
      ## so they look like output of the rejected run, but they are the only
      ## record of WHY it was rejected -- deleting them here destroyed the
      ## evidence immediately before the abort that asks you to explain it.
      ## Diagnosing the 2026-08-24 sd-phase failure depended entirely on
      ## gmacs_promote_run.log.err.
      evidence <- c("gmacs_promote_run.log", "gmacs_promote_run.log.err")
      extra <- setdiff(setdiff(snap(), keep), evidence)
      if (length(extra)) {
        unlink(file.path(MODEL_DIR, extra))
        message("  removed ", length(extra), " file(s) created by the rejected run",
                " (kept the promotion logs)")
      }

      if (length(failed))
        stop("Promotion failed AND the rollback did not complete.\n",
             "These files still hold the REJECTED promotion run and must be restored\n",
             "by hand from jitter/base_prepromotion/ before this model dir is used:\n  - ",
             paste(failed, collapse = "\n  - "))

      stop("Promotion failed and was rolled back (", length(restored),
           " files restored, md5-verified). The model directory is as it was.")
    }

    promoted <- TRUE
    message(sprintf("  promoted: model dir re-fit with Hessian, nll %.4f, max|grad| %.3g",
                    after$nll, after$max_grad))
    writeLines(c(
      "# Promoted jitter fit",
      "",
      sprintf("On %s, `05_run_jitter.R` found a jitter run that fit better than the base", Sys.Date()),
      "fit, and promoted it into this model directory.",
      "",
      sprintf("- source run      : jitter/%s", sprintf("%03d", best$idx)),
      sprintf("- seed            : %d", best$seed),
      sprintf("- nll before      : %.6f", BASE_NLL),
      sprintf("- nll after       : %.6f  (improvement %.6f)", after$nll, BASE_NLL - after$nll),
      sprintf("- max|grad| after : %.3g", after$max_grad),
      sprintf("- jitter sd       : %s over %d runs", jspec$sd, N_RUNS),
      sprintf("- executable      : %s, md5 %s, %s",
              gmacs_exe_name(), exe$md5, gmacs_exe_version(MODEL_DIR)),
      "",
      "The previous fit is in `jitter/base_prepromotion/`.",
      "",
      "`gmacs.pin` is retained deliberately: it is the winner's parameter vector and",
      "is what makes this fit reproducible. ADMB reads it automatically on any further",
      "run in this directory.",
      "",
      "**Downstream work must be re-run against this fit** -- `03_build_results_object.R`,",
      "the retrospective peels, Tier 4, and the report."),
      file.path(JITTER_DIR, "PROMOTION.md"))
    message("  wrote jitter/PROMOTION.md")
  }
} else {
  message("No jitter run improved on the base by more than ", NLL_TOL,
          " nll units; the base fit stands.")
}

## ===========================================================================
## Phase G -- modes, attribution, figures
## ===========================================================================
rule("G. Modes and figures")
res$mode <- NA_character_
res$mode[res$converged] <- as.character(classify_modes(res$objFun[res$converged],
                                                       gap = MODE_GAP, min_n = MIN_MODE_N))
mode_tab <- table(res$mode[!is.na(res$mode)])
message("modes: ", if (length(mode_tab))
  paste(sprintf("%s=%d", names(mode_tab), as.integer(mode_tab)), collapse = ", ") else "none")

attribution <- NULL
if (sum(!is.na(res$mode) & res$mode != "minor") > 1L &&
    length(setdiff(unique(res$mode[!is.na(res$mode)]), "minor")) > 1L) {
  pp <- stats::setNames(file.path(res$folder, "gmacs.par"), sprintf("%03d", res$idx))
  attribution <- tryCatch(mode_attribution(pp, res$mode, TOP_PARAMS),
                          error = function(e) { message("  attribution failed: ",
                                                        conditionMessage(e)); NULL })
  if (!is.null(attribution))
    message("  top separating parameter: ", attribution$parameter[1],
            " (std. difference ", round(attribution$std_difference[1], 2), ")")
} else {
  message("  only one mode -- no cloud separation to attribute.")
}

dir.create(file.path(REPO_ROOT, "plots"), showWarnings = FALSE)
plt <- res[res$complete, ]
plt$mode <- ifelse(is.na(plt$mode), "not converged", plt$mode)
plt$dnll <- plt$objFun - min(plt$objFun, na.rm = TRUE)

## Two panels per quantity, as in the 2025/May figures: the full nll spread on
## top, and the runs within 10 nll units below, where the clouds are legible.
## Axis limits come from the data -- the old script hardcoded the 2025 window.
jitter_panel <- function(d, yvar, ylab) {
  ggplot(d, aes(x = objFun, y = .data[[yvar]], colour = mode)) +
    geom_point(size = 2, alpha = 0.85) +
    geom_vline(xintercept = BASE_NLL, linetype = 2, colour = "grey30") +
    theme_bw() + labs(x = "Negative log likelihood", y = ylab, colour = "Mode")
}
save_jitter_fig <- function(file, yvar, ylab) {
  d2 <- plt[is.finite(plt[[yvar]]), ]
  if (!nrow(d2)) { message("  skipped ", file, " (no data)"); return(invisible(FALSE)) }
  near <- d2[d2$dnll <= 10, ]
  p <- jitter_panel(d2, yvar, ylab) +
    ggtitle(sprintf("%d jitter runs, sd %.2g (dashed line = base fit)", nrow(d2), jspec$sd))
  png(file.path(REPO_ROOT, "plots", file), height = 8, width = 7, res = 350, units = "in")
  if (nrow(near) > 1 && nrow(near) < nrow(d2)) {
    print(gridExtra::grid.arrange(
      p, jitter_panel(near, yvar, ylab) + ggtitle("Runs within 10 nll units of the best"),
      ncol = 1))
  } else print(p)
  dev.off()
  invisible(TRUE)
}
if (!requireNamespace("gridExtra", quietly = TRUE)) {
  save_jitter_fig <- function(file, yvar, ylab) {
    d2 <- plt[is.finite(plt[[yvar]]), ]
    if (!nrow(d2)) return(invisible(FALSE))
    png(file.path(REPO_ROOT, "plots", file), height = 6, width = 7, res = 350, units = "in")
    print(jitter_panel(d2, yvar, ylab) +
            ggtitle(sprintf("%d jitter runs, sd %.2g (dashed line = base fit)",
                            nrow(d2), jspec$sd)))
    dev.off(); invisible(TRUE)
  }
}

term_yr <- if (all(is.na(res$terminal_year))) yr$end_year else max(res$terminal_year, na.rm = TRUE)
save_jitter_fig(tagged("jittered_results_ofl.png"), "ofl_directed", "Directed OFL (1,000 t)")
save_jitter_fig(tagged("jittered_results_ssb.png"), "mmb_terminal", sprintf("MMB in %d (1,000 t)", term_yr))
save_jitter_fig(tagged("jittered_results_rec.png"), "rec_terminal", sprintf("Male recruitment in %d", term_yr))

png(file.path(REPO_ROOT, "plots", tagged("jitter_convergence.png")),
    height = 5, width = 7, res = 350, units = "in")
print(ggplot(plt, aes(x = objFun, y = abs(maxGrad), colour = mode)) +
        geom_point(size = 2, alpha = 0.85) +
        geom_hline(yintercept = GRAD_CONVENTIONAL, linetype = 2, colour = "grey30") +
        geom_hline(yintercept = base$max_grad, linetype = 3, colour = "firebrick") +
        scale_y_log10() + theme_bw() +
        labs(x = "Negative log likelihood", y = "Maximum |gradient|", colour = "Mode",
             title = sprintf("Convergence of %d jitter runs", nrow(plt)),
             subtitle = sprintf("dashed = conventional threshold %.0e; dotted = base fit (%.3g)",
                                GRAD_CONVENTIONAL, base$max_grad)))
dev.off()

if (!is.null(attribution)) {
  a <- attribution
  a$parameter <- factor(a$parameter, levels = rev(unique(a$parameter)))
  png(file.path(REPO_ROOT, "plots", tagged("jitter_param_attribution.png")),
      height = 6, width = 7.5, res = 350, units = "in")
  print(ggplot(a, aes(x = std_difference, y = parameter)) +
          geom_col(fill = "grey35") + geom_vline(xintercept = 0) +
          facet_wrap(~ paste0("mode ", mode_a, " vs ", mode_b), scales = "free_x") +
          theme_bw() +
          labs(x = "Standardized difference in parameter value between modes",
               y = NULL, title = "Parameters separating the jitter clouds"))
  dev.off()
}

## ===========================================================================
## Save results
## ===========================================================================
rule("Saving")
csv <- file.path(JITTER_DIR, "jitter_results.csv")
write.csv(res, csv, row.names = FALSE)
message("  ", csv)

summ <- data.frame(
  model            = MODEL_NAME,
  n_runs           = N_RUNS,
  n_complete       = nrow(ok_runs),
  n_converged      = sum(res$converged),
  n_meets_conventional = sum(res$meets_conventional),
  base_max_grad    = base$max_grad,
  jitter_sd        = jspec$sd,
  base_nll         = BASE_NLL,
  best_nll         = best$objFun,
  nll_improvement  = improvement,
  n_at_best_mode   = sum(res$mode == "A", na.rm = TRUE),
  pct_at_best_mode = round(100 * sum(res$mode == "A", na.rm = TRUE) / max(1L, sum(res$converged)), 1),
  ofl_min          = min(ok_runs$ofl_directed), ofl_max = max(ok_runs$ofl_directed),
  ofl_cv           = stats::sd(ok_runs$ofl_directed) / mean(ok_runs$ofl_directed),
  mmb_min          = min(ok_runs$mmb_terminal), mmb_max = max(ok_runs$mmb_terminal),
  terminal_year    = term_yr,
  promoted         = promoted,
  stringsAsFactors = FALSE)

git_sha <- tryCatch(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE)[1],
                    error = function(e) NA_character_, warning = function(w) NA_character_)

jitter <- list(
  results     = res,
  summary     = summ,
  modes       = mode_tab,
  attribution = attribution,
  manifest    = list(
    model_dir    = MODEL_DIR,
    datafile     = gc_ctl$datafile, ctlfile = gc_ctl$ctlfile, prjfile = gc_ctl$prjfile,
    exe          = exe,
    gmacs_version = gmacs_exe_version(MODEL_DIR),
    n_runs = N_RUNS, jitter_sd = jspec$sd, seed_base = SEED_BASE,
    grad_usable = GRAD_USABLE, grad_conventional = GRAD_CONVENTIONAL,
    nll_tol = NLL_TOL, mode_gap = MODE_GAP,
    base_nll = BASE_NLL, promoted = promoted,
    start_year = yr$start_year, end_year = yr$end_year,
    r_version = R.version.string, git_commit = git_sha,
    run_date = format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

rda_model <- file.path(REPO_ROOT, "Models", sprintf("rda_jitter_%s.RData", OUTPUT_TAG))
save(jitter, file = rda_model)
message("  Models/", basename(rda_model))

## ---------------------------------------------------------------------------
## The six paths the SAFE reads belong to REPORT_MODEL alone
## ---------------------------------------------------------------------------
## Copied from the per-model files just written, so the two are byte-identical
## by construction rather than by a second render. For any other model these are
## left untouched -- that is the whole point (see "Output naming" above).
SHARED_PLOTS <- c("jittered_results_ofl.png", "jittered_results_ssb.png",
                  "jittered_results_rec.png", "jitter_convergence.png",
                  "jitter_param_attribution.png")
if (IS_REPORT_MODEL) {
  stopifnot("report-model copy failed" =
              file.copy(rda_model, file.path(REPO_ROOT, "Models", "rda_jitter.RData"),
                        overwrite = TRUE))
  message("  Models/rda_jitter.RData        (report model)")
  for (f in SHARED_PLOTS) {
    src <- file.path(REPO_ROOT, "plots", tagged(f))
    if (file.exists(src)) {
      stopifnot(setNames(file.copy(src, file.path(REPO_ROOT, "plots", f), overwrite = TRUE),
                         paste("could not write shared plot", f)))
      message("  plots/", f, strrep(" ", max(1L, 30L - nchar(f))), "(report model)")
    }
  }
} else {
  message("\n  NOT the report model (", REPORT_MODEL, "), so the shared paths the")
  message("  SAFE reads were NOT written. Outputs are tagged '", OUTPUT_TAG, "' only.")
}

rule("Done")
message(sprintf("%d/%d runs converged; %.1f%% reached the best mode.",
                summ$n_converged, N_RUNS, summ$pct_at_best_mode))
if (promoted)
  message("MODEL DIRECTORY WAS CHANGED -- re-run 03_build_results_object.R, the ",
          "retrospective, 07_calc_tier4.R and the report. See jitter/PROMOTION.md.")
