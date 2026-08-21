#!/usr/bin/env Rscript
## ============================================================================
## 06_run_jitter.R -- jitter (convergence / local-optimum) analysis for GMACS
##
## Re-fits the model many times from randomly perturbed starting values to test
## whether the reported fit is a global optimum. This sets federal harvest
## specifications: the 2025 SAFE reported the LOWEST-nll run out of 100 jitters,
## having found two clouds ~0.2 nll apart whose OFLs differed by 5,000 t.
##
## Run from the repo root:
##   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 06_run_jitter.R --dry-run
##   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 06_run_jitter.R --pilot
##   & "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe" 06_run_jitter.R
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
##
## Outputs
##   Models/<model>/jitter/<nnn>/            one directory per run
##   Models/<model>/jitter/jitter_results.csv
##   Models/rda_jitter.RData                 object `jitter`, read by the SAFE Rmd
##   plots/jittered_results_{ofl,rec,ssb}.png    (the names SAFE_snow_gmacs.Rmd expects)
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
MIN_DISK_GB <- 50          # ADMB writes ~700 MB of temp per concurrent run
## Worker count comes from gmacs_max_workers() (R/gmacs_io.R:7), resolved after
## the source() below. Deliberately NOT detectCores(): a wide fan-out of ADMB
## processes hard-resets this laptop mid-run (2026-08, per Grant).

## Max |gradient| above which a run is not treated as converged. WARN-ONLY for
## the base fit: the accepted May 2026 model sits at 1.46e-3, so a hard 1e-3
## abort would reject the accepted fit.
MAX_GRAD_TOL <- 1e-3

NLL_TOL     <- 0.001       # nll difference treated as "the same optimum"
MODE_GAP    <- 0.01        # cluster height separating jitter clouds
MIN_MODE_N  <- 3L          # runs needed before a cluster counts as a mode
TOP_PARAMS  <- 15L         # parameters reported in the attribution table

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
message("gmacs.exe  : ", exe$bytes, " bytes, ", exe$mtime, ", md5 ", exe$md5)
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

free_gb <- disk_free_gb(MODEL_DIR)
if (!is.na(free_gb)) {
  message("disk free  : ", round(free_gb, 1), " GB")
  if (free_gb < MIN_DISK_GB)
    stop(sprintf(paste0("Only %.1f GB free; %d GB required. ADMB writes ~700 MB of temp ",
                        "per run, so %d concurrent workers need headroom. Free space or ",
                        "lower --cores."), free_gb, MIN_DISK_GB, N_CORES))
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
if (!is.na(base$max_grad) && base$max_grad > MAX_GRAD_TOL)
  warning(sprintf("Base fit max|grad| = %.3g exceeds %.3g. Recorded, not fatal.",
                  base$max_grad, MAX_GRAD_TOL), call. = FALSE)
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
is_done <- function(d, seed) {
  file.exists(file.path(d, "Gmacsall.out")) &&
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
    ## copied unmodified. -nohess because per-run standard errors are not used;
    ## the promoted winner is re-fit with the Hessian.
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
res$converged <- res$complete & !is.na(res$maxGrad) & res$maxGrad < MAX_GRAD_TOL

## Batch-level assertions.
ok_runs <- res[res$complete, ]
if (!nrow(ok_runs)) stop("No jitter run produced complete results.")
if (anyDuplicated(res$seed))
  stop("Duplicate seeds requested -- the runs would not be independent.")
if (nrow(ok_runs) > 1L && length(unique(round(ok_runs$objFun, 8))) == 1L)
  stop("Every completed run returned an identical objective function. The jitter ",
       "is not taking effect -- do not report these results.")

message(sprintf("complete: %d/%d   converged (max|grad| < %.0e): %d",
                nrow(ok_runs), N_RUNS, MAX_GRAD_TOL, sum(res$converged)))
message(sprintf("nll range: %.4f to %.4f   (base %.4f)",
                min(ok_runs$objFun), max(ok_runs$objFun), BASE_NLL))
message(sprintf("OFL range: %.3f to %.3f kt", min(ok_runs$ofl_tot), max(ok_runs$ofl_tot)))

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
ord  <- order(ok_runs$objFun, abs(ok_runs$maxGrad))
best <- ok_runs[ord[1], ]
improvement <- BASE_NLL - best$objFun
message(sprintf("best run %s: nll %.4f (base %.4f, improvement %.4f), max|grad| %.3g",
                sprintf("%03d", best$idx), best$objFun, BASE_NLL, improvement, best$maxGrad))
message(sprintf("  OFL %.3f kt (base run's OFL is in the model dir), MMB %.3f kt",
                best$ofl_tot, best$mmb_terminal))

promoted <- FALSE
if (improvement > NLL_TOL) {
  message("\n*** A jitter run fits better than the base by ", round(improvement, 4),
          " nll units. The base fit was at an inferior local optimum. ***")
  if (!PROMOTE) {
    message("--no-promote: reporting only; the model directory is unchanged.")
  } else {
    backup <- file.path(JITTER_DIR, "base_prepromotion")
    dir.create(backup, recursive = TRUE, showWarnings = FALSE)
    keep <- c("gmacs.par", "gmacs.std", "gmacs.rep", "gmacs.rep1", "gmacs.cor",
              "Gmacsall.out", "Gmacsall.std", "gmacs_files_in.dat", "gmacs_in.dat")
    for (f in keep)
      if (file.exists(file.path(MODEL_DIR, f)))
        file.copy(file.path(MODEL_DIR, f), file.path(backup, f), overwrite = TRUE)
    message("  backed up the previous fit to jitter/base_prepromotion/")

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
      for (f in keep)
        if (file.exists(file.path(backup, f)))
          file.copy(file.path(backup, f), file.path(MODEL_DIR, f), overwrite = TRUE)
      stop("Promotion failed and was rolled back. The model directory is as it was.")
    }

    promoted <- TRUE
    message(sprintf("  promoted: model dir re-fit with Hessian, nll %.4f, max|grad| %.3g",
                    after$nll, after$max_grad))
    writeLines(c(
      "# Promoted jitter fit",
      "",
      sprintf("On %s, `06_run_jitter.R` found a jitter run that fit better than the base", Sys.Date()),
      "fit, and promoted it into this model directory.",
      "",
      sprintf("- source run      : jitter/%s", sprintf("%03d", best$idx)),
      sprintf("- seed            : %d", best$seed),
      sprintf("- nll before      : %.6f", BASE_NLL),
      sprintf("- nll after       : %.6f  (improvement %.6f)", after$nll, BASE_NLL - after$nll),
      sprintf("- max|grad| after : %.3g", after$max_grad),
      sprintf("- jitter sd       : %s over %d runs", jspec$sd, N_RUNS),
      sprintf("- gmacs.exe       : md5 %s, %s", exe$md5, gmacs_exe_version(MODEL_DIR)),
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
save_jitter_fig("jittered_results_ofl.png", "ofl_tot", "Total OFL (1,000 t)")
save_jitter_fig("jittered_results_ssb.png", "mmb_terminal", sprintf("MMB in %d (1,000 t)", term_yr))
save_jitter_fig("jittered_results_rec.png", "rec_terminal", sprintf("Male recruitment in %d", term_yr))

png(file.path(REPO_ROOT, "plots", "jitter_convergence.png"),
    height = 5, width = 7, res = 350, units = "in")
print(ggplot(plt, aes(x = objFun, y = abs(maxGrad), colour = mode)) +
        geom_point(size = 2, alpha = 0.85) +
        geom_hline(yintercept = MAX_GRAD_TOL, linetype = 2, colour = "grey30") +
        scale_y_log10() + theme_bw() +
        labs(x = "Negative log likelihood", y = "Maximum |gradient|", colour = "Mode",
             title = sprintf("Convergence of %d jitter runs", nrow(plt)),
             subtitle = sprintf("dashed line = convergence threshold %.0e", MAX_GRAD_TOL)))
dev.off()

if (!is.null(attribution)) {
  a <- attribution
  a$parameter <- factor(a$parameter, levels = rev(unique(a$parameter)))
  png(file.path(REPO_ROOT, "plots", "jitter_param_attribution.png"),
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
  jitter_sd        = jspec$sd,
  base_nll         = BASE_NLL,
  best_nll         = best$objFun,
  nll_improvement  = improvement,
  n_at_best_mode   = sum(res$mode == "A", na.rm = TRUE),
  pct_at_best_mode = round(100 * sum(res$mode == "A", na.rm = TRUE) / max(1L, sum(res$converged)), 1),
  ofl_min          = min(ok_runs$ofl_tot), ofl_max = max(ok_runs$ofl_tot),
  ofl_cv           = stats::sd(ok_runs$ofl_tot) / mean(ok_runs$ofl_tot),
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
    max_grad_tol = MAX_GRAD_TOL, nll_tol = NLL_TOL, mode_gap = MODE_GAP,
    base_nll = BASE_NLL, promoted = promoted,
    start_year = yr$start_year, end_year = yr$end_year,
    r_version = R.version.string, git_commit = git_sha,
    run_date = format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

save(jitter, file = file.path(REPO_ROOT, "Models", "rda_jitter.RData"))
message("  Models/rda_jitter.RData")

rule("Done")
message(sprintf("%d/%d runs converged; %.1f%% reached the best mode.",
                summ$n_converged, N_RUNS, summ$pct_at_best_mode))
if (promoted)
  message("MODEL DIRECTORY WAS CHANGED -- re-run 03_build_results_object.R, the ",
          "retrospective, 07_calc_tier4.R and the report. See jitter/PROMOTION.md.")
