#!/usr/bin/env Rscript
## ============================================================================
## 05_run_retrospective.R
##
## Retrospective analysis for the September 2026 EBS snow crab SAFE.
##
## This assessment sets federal fishery regulations. Every GMACS run launched
## here is checked before its output is used, and every derived statistic is
## written to CSV next to the runs so the numbers in the SAFE can be traced
## back to a specific fit.
##
## TWO RETROSPECTIVE MODES
##   standard     Peel p removes the last p years of data. Set via nyrRetro in
##                gmacs.dat; GMACS does the peeling internally and correctly
##                honours the crab-year convention (end year N keeps the N+1
##                summer survey).
##   drop_survey  As above AND the terminal survey year is withheld, answering
##                "what would the assessment have said without this year's
##                survey?". Built by regenerating the peel's .DAT through
##                00_advance_model.R with survey_end = END_YEAR - p. That is
##                the same writer that produced the accepted model, verified to
##                reproduce it byte-for-byte -- not a bespoke row editor.
##
## Peel 0 is a real GMACS run in both modes, not a copy of the parent fit. In
## standard mode it is an independent re-fit of the base model and is asserted
## to reproduce the parent's MMB series.
##
## USAGE (from the snow_sept repo root)
##   Rscript 05_run_retrospective.R [stage] [model_dir]
##
##   stage = all       base + diagnose + peels + collect   (default)
##           base      fit the base model in model_dir only
##           diagnose  measure the snow.prj spr_grow_yr effect (see section 4)
##           peels     run the peel sweep (requires a fitted base)
##           collect   parse existing runs, write CSVs + figures (no GMACS)
##
## OUTPUTS
##   <model_dir>/retro/retro_ssb.csv          MMB by year x mode x peel
##   <model_dir>/retro/retro_recruitment.csv  recruitment by year x mode x peel
##   <model_dir>/retro/retro_refpoints.csv    BMSY/OFL/Fmsy/... per peel
##   <model_dir>/retro/retro_diagnostics.csv  per-run convergence + provenance
##   <model_dir>/retro/mohns_rho.csv          rho + Ralston's sigma per mode
##   plots/retro_mmb.png, retro_recruitment.png,
##   plots/retro_refpoints.png, retro_mmb_drop_survey.png
## ============================================================================

options(warn = 1)
suppressPackageStartupMessages({
  library(ggplot2)
  library(doParallel)
  library(foreach)
})

## ---------------------------------------------------------------------------
## 0. Configuration
## ---------------------------------------------------------------------------
args      <- commandArgs(trailingOnly = TRUE)
STAGE     <- if (length(args) >= 1) tolower(args[1]) else "all"
MODEL_REL <- if (length(args) >= 2) args[2] else "Models/26_gmacs_update_newmat_plus_group"

if (!STAGE %in% c("all", "base", "diagnose", "peels", "collect"))
  stop("stage must be one of: all, base, diagnose, peels, collect (got '", STAGE, "')")

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(REPO_ROOT, "R", "gmacs_io.R")))
  stop("Run this from the snow_sept repo root (no R/gmacs_io.R under ", REPO_ROOT, ").")
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

MODEL_DIR <- normalizePath(file.path(REPO_ROOT, MODEL_REL), winslash = "/", mustWork = TRUE)
RETRO_DIR <- file.path(MODEL_DIR, "retro")
PLOT_DIR  <- file.path(REPO_ROOT, "plots")

N_PEELS   <- 10L                      # peels 1..N_PEELS, plus the unpeeled peel 0
MODES     <- c("standard", "drop_survey")
GRAD_WARN <- 1e-3                     # WARN threshold, not an abort: the accepted
                                      # May 2026 fit has max gradient 1.46e-3
N_WORKERS <- gmacs_max_workers()      # small fixed default, NOT detectCores():
                                      # wide fan-out hard-resets this laptop and
                                      # corrupts the peel being written. Raise via
                                      # $env:GMACS_MAX_WORKERS. See R/gmacs_io.R:7.

## Compensate GMACS's retrospective shift of snow.prj's spr_grow_yr?
##
## SETTLED FALSE, EMPIRICALLY (2026-08). The stage-4 diagnostic ran peel 1
## twice with every input file md5-identical except one byte of snow.prj
## (spr_grow_yr 1982 vs 1983) and recorded, in retro/prj_growth_year_diagnostic.csv:
##     FALSE  ok=TRUE   nll = -22833.68
##     TRUE   ok=FALSE  "exit status 1; no Gmacsall.out"
## The compensated run dies with "Memory allocation error" while reading the
## control file, before optimising. So the out-of-bounds read that the
## model-folder gmacsbase.TPL (2.20.32b) implies does NOT exist in the actual
## executable (2.20.34) -- and the compensation itself is what breaks the run.
## Leave snow.prj alone. See the note on set_prj_growth_year() in R/gmacs_io.R.
FIX_PRJ_GROWTH_YEAR <- FALSE

RSCRIPT <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

## The template that produced this model, needed to rebuild drop-survey .DATs.
## Verified 2026-08 to regenerate Models/26_gmacs_update_newmat_plus_group
## byte-for-byte (.dat, .ctl, gmacs.dat, snow.prj all md5-identical).
ADVANCE_TEMPLATE <- "Models/25_gmacs_update_newmat_plus_group"

dir.create(RETRO_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(PLOT_DIR,  recursive = TRUE, showWarnings = FALSE)

## ---------------------------------------------------------------------------
## 1. Model identity -- read, never hardcode
## ---------------------------------------------------------------------------
GC       <- read_gmacs_control(MODEL_DIR)
EXE      <- file.path(MODEL_DIR, "gmacs.exe")
if (!file.exists(EXE)) stop("No gmacs.exe in ", MODEL_DIR)

## Model end year comes from the .DAT itself.
.dat_lines <- read_raw_lines(file.path(MODEL_DIR, GC$datafile))$lines
END_YEAR <- as.integer(toks(.dat_lines[find_anchor(.dat_lines, "# End year")])[1])
SYR      <- as.integer(toks(.dat_lines[find_anchor(.dat_lines, "# Start year")])[1])
if (is.na(END_YEAR) || is.na(SYR)) stop("Could not read Start/End year from ", GC$datafile)

## Files a run needs. Named from gmacs.dat, so this works for Models/25_gmacs
## ("snow.dat") as well as the 26 model ("26_snow_update_newmat_plus_group.dat").
RUN_FILES <- c(GC$datafile, GC$ctlfile, GC$prjfile, "gmacs.dat", "gmacs.exe")

cat(sprintf("\n=== 05_run_retrospective.R ===\n"))
cat(sprintf("stage      : %s\n", STAGE))
cat(sprintf("model      : %s\n", MODEL_REL))
cat(sprintf("data file  : %s   (ctl %s, prj %s)\n", GC$datafile, GC$ctlfile, GC$prjfile))
cat(sprintf("model years: %d - %d\n", SYR, END_YEAR))
cat(sprintf("peels      : 0 - %d   modes: %s\n", N_PEELS, paste(MODES, collapse = ", ")))
cat(sprintf("workers    : %d of %d cores\n", N_WORKERS, parallel::detectCores()))
cat(sprintf("prj fix    : %s\n\n", FIX_PRJ_GROWTH_YEAR))

## ---------------------------------------------------------------------------
## 2. Run + verify helpers
## ---------------------------------------------------------------------------
## Run gmacs.exe with `dir` as the working directory. Returns status, elapsed
## seconds, and the captured console output (also written to run.log).
run_gmacs <- function(dir, extra_args = character(0)) {
  exe <- normalizePath(file.path(dir, "gmacs.exe"), winslash = "\\", mustWork = TRUE)
  old <- setwd(dir); on.exit(setwd(old), add = TRUE)
  t0  <- Sys.time()
  out <- suppressWarnings(system2(exe, args = extra_args, stdout = TRUE, stderr = TRUE))
  st  <- attr(out, "status"); if (is.null(st)) st <- 0L
  el  <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  writeLines(c(sprintf("# gmacs.exe %s", paste(extra_args, collapse = " ")),
               sprintf("# exit status %d, %.1f s", st, el),
               out), "run.log")
  list(status = st, elapsed = el, out = out)
}

## Every check that must hold before a run's output is allowed into the
## analysis. Returns a one-row data.frame; `ok` FALSE means do not use it.
verify_run <- function(dir, label, expect_end_year, started_at, run) {
  fail <- character(0); warn <- character(0)

  if (run$status != 0L) fail <- c(fail, sprintf("exit status %d", run$status))

  ## GMACS can exit 0 on some failure paths, so the log is inspected directly.
  bad <- grep("STOPPING|Index out of bounds|array bound|Error|error in",
              run$out, value = TRUE, ignore.case = FALSE)
  if (length(bad)) fail <- c(fail, sprintf("log: %s", bad[1]))

  ga <- file.path(dir, "Gmacsall.out")
  if (!file.exists(ga)) {
    fail <- c(fail, "no Gmacsall.out")
  } else if (file.info(ga)$mtime < started_at) {
    fail <- c(fail, "Gmacsall.out not rewritten by this run (stale output)")
  }

  ## gmacs.std is written ONLY when ADMB's sd phase ran, so it is the precise
  ## marker separating a full run from a -nohess one. Without this check a
  ## leftover -nohess directory looks complete: Gmacsall.out and gmacs.par are
  ## both present and the summary block is fully populated. (Guard contributed
  ## by the parallel jitter session, 2026-08, which hit exactly that.)
  std <- file.path(dir, "gmacs.std")
  if (!file.exists(std)) {
    fail <- c(fail, "no gmacs.std -- sd phase did not run (was -nohess used?)")
  } else if (file.info(std)$mtime < started_at) {
    fail <- c(fail, "gmacs.std predates this run (stale -nohess output?)")
  }

  s <- NULL; rp <- NULL; par <- list(npar = NA_integer_, nll = NA_real_, max_grad = NA_real_)
  echo <- list(end_year = NA_integer_, last_survey_year = NA_integer_)
  if (!length(fail)) {
    s    <- try(read_gmacsall_summary(ga), silent = TRUE)
    rp   <- try(read_gmacsall_refpoints(ga), silent = TRUE)
    par  <- read_par_header(dir)
    echo <- read_gmacs_echo(dir)
    if (inherits(s, "try-error")) fail <- c(fail, "unparseable summary block")
    if (inherits(rp, "try-error")) warn <- c(warn, "no reference points parsed")
  }

  term <- if (!is.null(s) && !inherits(s, "try-error")) max(s$Year) else NA_integer_
  if (!is.na(term) && term != expect_end_year)
    fail <- c(fail, sprintf("terminal year %d, expected %d", term, expect_end_year))
  if (!is.na(echo$end_year) && echo$end_year != expect_end_year)
    fail <- c(fail, sprintf("gmacs echo end year %d, expected %d", echo$end_year, expect_end_year))

  if (!is.na(par$max_grad) && par$max_grad > GRAD_WARN)
    warn <- c(warn, sprintf("max gradient %.3g > %.0e", par$max_grad, GRAD_WARN))

  ## Reference points must be genuinely populated. A -nohess run does NOT give
  ## a clean all-zero block: Fmsy and Fofl are computed directly and stay
  ## plausible, while the sdreport quantities (BMSY, Bcurr/BMSY, OFL) are
  ## exactly 0. So a sanity check on Fmsy would pass on worthless output --
  ## test the sdreport quantities specifically.
  bmsy <- ofl <- NA_real_
  if (!is.null(rp) && !inherits(rp, "try-error")) {
    bmsy <- refpoint(rp, "BMSY"); ofl <- refpoint(rp, "OFL(tot)")
    if (!is.na(bmsy) && !is.na(ofl) && bmsy == 0 && ofl == 0)
      fail <- c(fail, "BMSY and OFL(tot) are exactly 0 -- sdreport quantities absent")
  }

  data.frame(
    label            = label,
    ok               = length(fail) == 0L,
    terminal_year    = term,
    echo_end_year    = echo$end_year,
    last_survey_year = echo$last_survey_year,
    npar             = par$npar,
    nll              = par$nll,
    max_grad         = par$max_grad,
    converged        = !is.na(par$max_grad) && par$max_grad <= GRAD_WARN,
    BMSY             = bmsy,
    OFL_tot          = ofl,
    elapsed_sec      = round(run$elapsed, 1),
    problems         = paste(fail, collapse = "; "),
    warnings         = paste(warn, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

## Build one peel's run directory.
##   mode  "standard" keeps the full .DAT; "drop_survey" regenerates it with
##         survey_end = END_YEAR - peel.
prepare_peel <- function(mode, peel, dir, fix_prj = FIX_PRJ_GROWTH_YEAR) {
  if (dir.exists(dir)) unlink(dir, recursive = TRUE, force = TRUE)  # never reuse a stale peel
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)

  if (mode == "drop_survey") {
    stage_dir <- file.path(dir, "_stage")
    st <- system2(RSCRIPT,
                  args = shQuote(c(file.path(REPO_ROOT, "00_advance_model.R"),
                                   file.path(REPO_ROOT, ADVANCE_TEMPLATE),
                                   stage_dir, as.character(END_YEAR), GC$datafile,
                                   "TRUE", REPO_ROOT,
                                   as.character(END_YEAR - peel))),
                  stdout = file.path(dir, "advance.log"), stderr = file.path(dir, "advance.log"))
    if (st != 0L)
      stop(sprintf("00_advance_model.R failed for %s peel %d (see %s)",
                   mode, peel, file.path(dir, "advance.log")))
    ## keep only what a run needs; drop the template's stale ADMB artefacts
    for (f in c(GC$datafile, GC$ctlfile, GC$prjfile))
      file.copy(file.path(stage_dir, f), file.path(dir, f), overwrite = TRUE)
    unlink(stage_dir, recursive = TRUE, force = TRUE)
    file.copy(file.path(MODEL_DIR, "gmacs.exe"), file.path(dir, "gmacs.exe"), overwrite = TRUE)
  } else {
    for (f in RUN_FILES) {
      ok <- file.copy(file.path(MODEL_DIR, f), file.path(dir, f), overwrite = TRUE)
      if (!ok) stop(sprintf("failed to copy %s into %s", f, dir))
    }
  }

  ## gmacs.dat carries the peel count. Written from the parsed parent so every
  ## other byte (including the 3-field jitter line) is preserved.
  write_gmacs_control(GC, dir, n_peel = peel)

  ## Compensate GMACS's spr_grow_yr shift so it lands back on the base value.
  if (fix_prj && peel > 0L)
    set_prj_growth_year(file.path(dir, GC$prjfile), peel, syr = SYR, nyr = END_YEAR)

  for (f in RUN_FILES)
    if (!file.exists(file.path(dir, f)))
      stop(sprintf("%s missing from prepared peel dir %s", f, dir))
  invisible(dir)
}

peel_dir <- function(mode, peel) file.path(RETRO_DIR, mode, as.character(peel))

## ---------------------------------------------------------------------------
## 3. Stage: base -- fit the model itself
## ---------------------------------------------------------------------------
if (STAGE %in% c("all", "base")) {
  cat("--- STAGE base: fitting the model in place ---\n")

  ## The committed outputs in this folder may be stale copies of an earlier
  ## model's run (they were, as of 2026-08). Back them up once, then refit.
  bk <- file.path(MODEL_DIR, "_pre_run_backup")
  if (!dir.exists(bk)) {
    dir.create(bk, showWarnings = FALSE)
    for (f in c("Gmacsall.out", "gmacs.par", "gmacs.rep", "gmacs.std",
                "gmacs_files_in.dat", "gmacs_in.dat", "Gmacsall.std"))
      if (file.exists(file.path(MODEL_DIR, f)))
        file.copy(file.path(MODEL_DIR, f), file.path(bk, f), overwrite = FALSE)
    cat(sprintf("  pre-run outputs backed up to %s\n", basename(bk)))
  }

  pre_md5 <- tools::md5sum(file.path(MODEL_DIR, "Gmacsall.out"))
  t0 <- Sys.time()
  r  <- run_gmacs(MODEL_DIR)                       # WITH the Hessian
  v  <- verify_run(MODEL_DIR, "base", END_YEAR, t0, r)

  cat(sprintf("  exit %d, %.1f s, terminal year %s, npar %s, nll %s, max grad %s\n",
              r$status, r$elapsed, v$terminal_year, v$npar,
              format(v$nll), format(v$max_grad)))
  cat(sprintf("  survey data reaches %s (expect %d under the crab-year convention)\n",
              v$last_survey_year, END_YEAR + 1L))
  if (nzchar(v$warnings)) cat(sprintf("  WARNING: %s\n", v$warnings))
  if (!v$ok) stop("Base model run failed: ", v$problems)
  if (identical(unname(pre_md5), unname(tools::md5sum(file.path(MODEL_DIR, "Gmacsall.out")))))
    stop("Gmacsall.out is unchanged after the run -- the fit did not actually execute.")

  write.csv(v, file.path(RETRO_DIR, "base_run.csv"), row.names = FALSE)
  cat("  base fit OK\n\n")
}

## ---------------------------------------------------------------------------
## 4. Stage: diagnose -- measure the snow.prj spr_grow_yr effect
## ---------------------------------------------------------------------------
## The model-folder gmacsbase.TPL (2.20.32b) shows spr_grow_yr being shifted
## below the model start year for every peel, which would corrupt the peel's
## reference points. But that TPL is NOT the source of gmacs.exe (2.20.34), so
## the defect is measured here rather than assumed: peel 1 is run twice,
## identical except for the compensation, and BMSY/OFL are compared.
##
## ALREADY RUN, 2026-08 -- see FIX_PRJ_GROWTH_YEAR in section 0 for the verdict
## and retro/prj_growth_year_diagnostic.csv for the recorded numbers. This stage
## is kept so the measurement can be repeated against a new executable.
## Runs WITHOUT -nohess: reference points are ADMB sdreport quantities, so a
## -nohess run reports BMSY/OFL as exactly zero and the comparison is vacuous.
if (STAGE %in% c("all", "diagnose")) {
  cat("--- STAGE diagnose: snow.prj spr_grow_yr sensitivity (peel 1) ---\n")
  diag_rows <- list()
  for (fx in c(FALSE, TRUE)) {
    d <- file.path(RETRO_DIR, "_diagnostic", if (fx) "prjfix_on" else "prjfix_off")
    prepare_peel("standard", 1L, d, fix_prj = fx)
    t0 <- Sys.time(); r <- run_gmacs(d)
    v  <- verify_run(d, if (fx) "prjfix_on" else "prjfix_off", END_YEAR - 1L, t0, r)
    rp <- if (v$ok) read_gmacsall_refpoints(file.path(d, "Gmacsall.out")) else NULL
    diag_rows[[length(diag_rows) + 1L]] <- data.frame(
      spr_grow_yr_compensated = fx,
      ok       = v$ok,
      nll      = v$nll,
      max_grad = v$max_grad,
      BMSY     = if (is.null(rp)) NA_real_ else refpoint(rp, "BMSY"),
      OFL_tot  = if (is.null(rp)) NA_real_ else refpoint(rp, "OFL(tot)"),
      B_BMSY   = if (is.null(rp)) NA_real_ else refpoint(rp, "Bcurr/BMSY"),
      problems = v$problems, stringsAsFactors = FALSE)
  }
  dg <- do.call(rbind, diag_rows)
  print(dg, row.names = FALSE)
  write.csv(dg, file.path(RETRO_DIR, "prj_growth_year_diagnostic.csv"), row.names = FALSE)

  if (all(dg$ok)) {
    rel <- function(a, b) if (is.na(a) || is.na(b) || b == 0) NA_real_ else (a - b) / b
    cat(sprintf("  BMSY differs by %.4f%%, OFL by %.4f%% (compensated vs not)\n",
                100 * rel(dg$BMSY[2], dg$BMSY[1]), 100 * rel(dg$OFL_tot[2], dg$OFL_tot[1])))
    cat("  -> if ~0, the executable is not affected and the compensation is a no-op;\n")
    cat("     if non-zero, uncompensated peel reference points are unreliable.\n")
  } else {
    cat("  NOTE: a diagnostic run failed; see prj_growth_year_diagnostic.csv\n")
  }
  cat("\n")
}

## ---------------------------------------------------------------------------
## 5. Stage: peels -- run the sweep
## ---------------------------------------------------------------------------
if (STAGE %in% c("all", "peels")) {
  cat("--- STAGE peels: preparing run directories ---\n")
  jobs <- do.call(rbind, lapply(MODES, function(m)
    data.frame(mode = m, peel = 0:N_PEELS, stringsAsFactors = FALSE)))
  jobs$dir <- mapply(peel_dir, jobs$mode, jobs$peel)
  jobs$expect_end_year <- END_YEAR - jobs$peel

  for (i in seq_len(nrow(jobs))) {
    prepare_peel(jobs$mode[i], jobs$peel[i], jobs$dir[i])
    cat(sprintf("  %-12s peel %2d -> %s\n", jobs$mode[i], jobs$peel[i],
                file.path(basename(dirname(jobs$dir[i])), basename(jobs$dir[i]))))
  }

  ## Peels run WITH the Hessian (no -nohess). BMSY, Fmsy, Fofl and the OFL are
  ## ADMB sdreport quantities, and -nohess skips the sd phase -- a -nohess peel
  ## writes them as exactly 0.0, so retro_refpoints.csv would be all zeros. That
  ## was verified against the stage-4 diagnostic output. The cost is real: a
  ## peel takes ~13 min with the Hessian versus ~3 min without.
  cat(sprintf("\n--- STAGE peels: running %d GMACS fits (with Hessian) on %d workers ---\n",
              nrow(jobs), N_WORKERS))
  cat(sprintf("    expect roughly %.0f min wall clock\n",
              ceiling(nrow(jobs) / N_WORKERS) * 13))
  cl <- parallel::makeCluster(N_WORKERS)
  doParallel::registerDoParallel(cl)

  ## tryCatch(finally=), NOT on.exit(). on.exit() registers a handler on the
  ## FUNCTION frame it is called in; this code is at script top level (the
  ## `if` block is not a function), so the handler is never run. If a worker
  ## errored, the cluster leaked N Rsession processes, each potentially still
  ## holding an ADMB child at 100% CPU -- the same sustained-load condition
  ## rule 11 exists to prevent, reached by leak rather than by fan-out width,
  ## and indistinguishable from "the machine reset again at 4 workers".
  ## (Found by the parallel review session, 2026-08-21; verified here.)
  res <- tryCatch(
    foreach(i = seq_len(nrow(jobs)), .combine = rbind,
            .packages = character(0)) %dopar% {
      source(file.path(REPO_ROOT, "R", "gmacs_io.R"))
      t0 <- Sys.time()
      r  <- run_gmacs(jobs$dir[i])
      v  <- verify_run(jobs$dir[i], sprintf("%s/%d", jobs$mode[i], jobs$peel[i]),
                       jobs$expect_end_year[i], t0, r)
      cbind(mode = jobs$mode[i], peel = jobs$peel[i], v)
    },
    finally = {
      try(parallel::stopCluster(cl), silent = TRUE)
      try(doParallel::stopImplicitCluster(), silent = TRUE)
    }
  )

  res <- res[order(res$mode, res$peel), ]
  write.csv(res, file.path(RETRO_DIR, "retro_diagnostics.csv"), row.names = FALSE)
  print(res[, c("mode", "peel", "ok", "terminal_year", "last_survey_year",
                "nll", "max_grad", "converged", "elapsed_sec")], row.names = FALSE)

  if (any(!res$ok)) {
    bad <- res[!res$ok, ]
    stop(sprintf("%d peel run(s) failed:\n%s", nrow(bad),
                 paste(sprintf("  %s peel %s: %s", bad$mode, bad$peel, bad$problems),
                       collapse = "\n")))
  }
  nc <- res[!res$converged, ]
  if (nrow(nc))
    cat(sprintf("\n  WARNING: %d run(s) above the %.0e gradient threshold: %s\n",
                nrow(nc), GRAD_WARN,
                paste(sprintf("%s/%s (%.3g)", nc$mode, nc$peel, nc$max_grad), collapse = ", ")))
  cat("\n")
}

## ---------------------------------------------------------------------------
## 6. Stage: collect -- parse, compute rho, write CSVs and figures
## ---------------------------------------------------------------------------
if (!STAGE %in% c("all", "collect")) {
  cat("Done (stage '", STAGE, "').\n", sep = "")
  quit(save = "no", status = 0L)
}

cat("--- STAGE collect: parsing runs ---\n")

read_peel <- function(mode, peel) {
  ga <- file.path(peel_dir(mode, peel), "Gmacsall.out")
  if (!file.exists(ga)) return(NULL)
  s  <- read_gmacsall_summary(ga)
  data.frame(mode = mode, peel = peel, Year = s$Year,
             ssb = s$SSB, recruit_male = s$Recruit_male,
             stringsAsFactors = FALSE)
}

series <- do.call(rbind, Filter(Negate(is.null),
  unlist(lapply(MODES, function(m) lapply(0:N_PEELS, function(p) read_peel(m, p))),
         recursive = FALSE)))
if (is.null(series) || !nrow(series))
  stop("No peel output found under ", RETRO_DIR, " -- run the 'peels' stage first.")

## Peel-0 identity: the standard peel 0 is an independent re-fit of the base
## model and must reproduce the parent folder's MMB series.
base_parent <- read_gmacsall_summary(file.path(MODEL_DIR, "Gmacsall.out"))
p0 <- series[series$mode == "standard" & series$peel == 0L, ]
if (nrow(p0)) {
  m <- merge(p0[, c("Year", "ssb")], base_parent[, c("Year", "SSB")], by = "Year")
  reldiff <- max(abs(m$ssb - m$SSB) / pmax(abs(m$SSB), 1e-12))
  cat(sprintf("  peel-0 vs parent fit: max relative MMB difference %.3g over %d years\n",
              reldiff, nrow(m)))
  if (nrow(m) != nrow(base_parent))
    warning("peel 0 and the parent fit do not span the same years")
  if (reldiff > 1e-6)
    warning(sprintf("peel 0 does not reproduce the parent fit (max rel diff %.3g). ",
                    reldiff),
            "The parent Gmacsall.out may predate the current inputs -- re-run stage 'base'.")
}

## Reference points per peel
refs <- do.call(rbind, Filter(Negate(is.null), unlist(lapply(MODES, function(m)
  lapply(0:N_PEELS, function(p) {
    ga <- file.path(peel_dir(m, p), "Gmacsall.out")
    if (!file.exists(ga)) return(NULL)
    rp <- try(read_gmacsall_refpoints(ga), silent = TRUE)
    if (inherits(rp, "try-error")) return(NULL)
    data.frame(mode = m, peel = p, terminal_year = END_YEAR - p,
               BMSY      = refpoint(rp, "BMSY"),
               B_BMSY    = refpoint(rp, "Bcurr/BMSY"),
               OFL_tot   = refpoint(rp, "OFL(tot)"),
               Fmsy      = refpoint(rp, "Fmsy (1)"),
               Fofl      = refpoint(rp, "Fofl (1)"),
               OFL_ret   = refpoint(rp, "Ofl (1)"),
               stringsAsFactors = FALSE)
  })), recursive = FALSE)))

## ---------------------------------------------------------------------------
## 7. Mohn's rho
## ---------------------------------------------------------------------------
## Mohn's rho, as used for NPFMC crab assessments:
##
##     rho = (1/P) * sum_p  ( X[T_p, peel p] - X[T_p, base] ) / X[T_p, base]
##
## where T_p = END_YEAR - p is peel p's terminal year and `base` is the
## unpeeled fit (peel 0). A POSITIVE rho means the peels sit ABOVE the base
## fit, i.e. the assessment revises terminal biomass DOWNWARD as data are
## added -- retrospective over-estimation.
##
## NOTE ON THE PREVIOUS SCRIPT: the version of 05_run_retrospective.R inherited
## from the 2023/2025 working sessions computed (base - peel)/peel, which
## inverts both the sign and the denominator. Any rho reported from it would
## have had the wrong sign and the wrong magnitude.
##
## Also reported: Ralston's sigma, the log-scale RMSE of the same terminal-year
## pairs, which the old script computed at line 320 and which does not depend
## on the sign convention.
rho_table <- function(series, value_col) {
  out <- list()
  for (m in unique(series$mode)) {
    d0 <- series[series$mode == m & series$peel == 0L, ]
    ## drop_survey peels are compared against the FULL base fit (standard peel
    ## 0), matching the intent of the old "drop terminal survey" figure.
    ref <- if (m == "drop_survey")
      series[series$mode == "standard" & series$peel == 0L, ] else d0
    if (!nrow(ref)) next

    rel <- vapply(1:N_PEELS, function(p) {
      d <- series[series$mode == m & series$peel == p, ]
      if (!nrow(d)) return(NA_real_)
      Tp <- max(d$Year)
      xb <- ref[[value_col]][ref$Year == Tp]
      xp <- d[[value_col]][d$Year == Tp]
      if (!length(xb) || !length(xp) || xb == 0) return(NA_real_)
      (xp - xb) / xb
    }, numeric(1))

    lg <- vapply(1:N_PEELS, function(p) {
      d <- series[series$mode == m & series$peel == p, ]
      if (!nrow(d)) return(NA_real_)
      Tp <- max(d$Year)
      xb <- ref[[value_col]][ref$Year == Tp]; xp <- d[[value_col]][d$Year == Tp]
      if (!length(xb) || !length(xp) || xb <= 0 || xp <= 0) return(NA_real_)
      log(xp) - log(xb)
    }, numeric(1))

    n <- sum(!is.na(rel))
    out[[length(out) + 1L]] <- data.frame(
      quantity        = value_col,
      mode            = m,
      n_peels         = n,
      mohns_rho       = mean(rel, na.rm = TRUE),
      ralstons_sigma  = if (n > 1L) sqrt(sum(lg^2, na.rm = TRUE) / (n - 1L)) else NA_real_,
      min_rel_diff    = min(rel, na.rm = TRUE),
      max_rel_diff    = max(rel, na.rm = TRUE),
      stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

peel_rel <- do.call(rbind, lapply(unique(series$mode), function(m) {
  ref <- if (m == "drop_survey")
    series[series$mode == "standard" & series$peel == 0L, ] else
    series[series$mode == m & series$peel == 0L, ]
  do.call(rbind, lapply(1:N_PEELS, function(p) {
    d <- series[series$mode == m & series$peel == p, ]
    if (!nrow(d)) return(NULL)
    Tp <- max(d$Year)
    xb <- ref$ssb[ref$Year == Tp]; xp <- d$ssb[d$Year == Tp]
    rb <- ref$recruit_male[ref$Year == Tp]; rp2 <- d$recruit_male[d$Year == Tp]
    if (!length(xb) || !length(xp)) return(NULL)
    data.frame(mode = m, peel = p, terminal_year = Tp,
               base_mmb = xb, peel_mmb = xp, rel_diff_mmb = (xp - xb) / xb,
               rel_diff_recruit = if (length(rb) && length(rp2) && rb != 0) (rp2 - rb) / rb else NA_real_,
               stringsAsFactors = FALSE)
  }))
}))

rho <- rbind(rho_table(series, "ssb"), rho_table(series, "recruit_male"))
rho$quantity[rho$quantity == "ssb"]          <- "mature_male_biomass"
rho$quantity[rho$quantity == "recruit_male"] <- "recruitment_male"

cat("\n  Mohn's rho  [ (peel - base) / base, at each peel's terminal year ]\n")
print(rho, row.names = FALSE, digits = 4)
cat("\n  Rule of thumb (Hurtado-Ferro et al. 2015 ICES JMS 72:99-110):\n")
cat("  rho outside [-0.22, 0.30] for a short-lived stock, or [-0.15, 0.20] for a\n")
cat("  long-lived one, indicates a retrospective pattern worth reporting.\n\n")

## ---------------------------------------------------------------------------
## 8. Write outputs
## ---------------------------------------------------------------------------
write.csv(series[series$mode == "standard", c("mode","peel","Year","ssb","recruit_male")],
          file.path(RETRO_DIR, "retro_ssb.csv"), row.names = FALSE)
write.csv(series, file.path(RETRO_DIR, "retro_series_all.csv"), row.names = FALSE)
write.csv(series[, c("mode","peel","Year","recruit_male")],
          file.path(RETRO_DIR, "retro_recruitment.csv"), row.names = FALSE)
if (!is.null(refs)) write.csv(refs, file.path(RETRO_DIR, "retro_refpoints.csv"), row.names = FALSE)
write.csv(rho,      file.path(RETRO_DIR, "mohns_rho.csv"),        row.names = FALSE)
write.csv(peel_rel, file.path(RETRO_DIR, "retro_peel_relative.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## 9. Figures
## ---------------------------------------------------------------------------
series$peel_label <- factor(END_YEAR - series$peel,
                            levels = sort(unique(END_YEAR - series$peel), decreasing = TRUE))

rho_lab <- function(m, q) {
  r <- rho$mohns_rho[rho$mode == m & rho$quantity == q]
  if (!length(r)) "" else sprintf("Mohn's rho = %.3f", r)
}

peel_plot <- function(mode, ycol, ylab, title, subtitle) {
  d <- series[series$mode == mode, ]
  ggplot(d, aes(x = Year, y = .data[[ycol]], colour = peel_label, group = peel)) +
    geom_line(linewidth = 0.9) +
    geom_point(data = do.call(rbind, lapply(split(d, d$peel), function(z) z[which.max(z$Year), ])),
               size = 1.8) +
    scale_colour_viridis_d(name = "Terminal year", option = "D", direction = -1) +
    expand_limits(y = 0) +
    labs(x = "Year", y = ylab, title = title, subtitle = subtitle) +
    theme_bw(base_size = 11)
}

png(file.path(PLOT_DIR, "retro_mmb.png"), height = 6, width = 8, res = 400, units = "in")
print(peel_plot("standard", "ssb", "Mature male biomass (1,000 t)",
                sprintf("Retrospective analysis, %s", basename(MODEL_DIR)),
                sprintf("Peels 0-%d.  %s", N_PEELS, rho_lab("standard", "mature_male_biomass"))))
dev.off()

png(file.path(PLOT_DIR, "retro_recruitment.png"), height = 6, width = 8, res = 400, units = "in")
print(peel_plot("standard", "recruit_male", "Male recruitment (millions)",
                sprintf("Recruitment retrospective, %s", basename(MODEL_DIR)),
                sprintf("Peels 0-%d.  %s", N_PEELS, rho_lab("standard", "recruitment_male"))))
dev.off()

if ("drop_survey" %in% series$mode) {
  png(file.path(PLOT_DIR, "retro_mmb_drop_survey.png"), height = 6, width = 8, res = 400, units = "in")
  print(peel_plot("drop_survey", "ssb", "Mature male biomass (1,000 t)",
                  "Retrospective with the terminal survey year withheld",
                  sprintf("Peels 0-%d, compared with the full base fit.  %s",
                          N_PEELS, rho_lab("drop_survey", "mature_male_biomass"))))
  dev.off()
}

## Terminal-year MMB: base series with each peel's terminal estimate on top --
## the clearest read of whether the pattern is directional.
png(file.path(PLOT_DIR, "retro_terminal_mmb.png"), height = 5, width = 8, res = 400, units = "in")
base_std <- series[series$mode == "standard" & series$peel == 0L, ]
term_pts <- peel_rel
print(
  ggplot() +
    geom_line(data = base_std, aes(Year, ssb), linewidth = 1.1) +
    geom_line(data = term_pts, aes(terminal_year, peel_mmb, colour = mode), linewidth = 0.9) +
    geom_point(data = term_pts, aes(terminal_year, peel_mmb, colour = mode), size = 2) +
    scale_colour_brewer(name = "Retrospective", palette = "Set1") +
    expand_limits(y = 0) +
    labs(x = "Year", y = "Mature male biomass (1,000 t)",
         title = "Terminal-year MMB from each peel vs the base fit (black)") +
    theme_bw(base_size = 11)
)
dev.off()

if (!is.null(refs) && nrow(refs)) {
  rl <- reshape(refs[, c("mode","terminal_year","BMSY","OFL_tot","B_BMSY")],
                direction = "long", varying = c("BMSY","OFL_tot","B_BMSY"),
                v.names = "value", timevar = "quantity",
                times = c("BMSY (1,000 t)","OFL total (1,000 t)","B / BMSY"),
                idvar = c("mode","terminal_year"))
  png(file.path(PLOT_DIR, "retro_refpoints.png"), height = 7, width = 8, res = 400, units = "in")
  print(
    ggplot(rl, aes(terminal_year, value, colour = mode)) +
      geom_line(linewidth = 0.9) + geom_point(size = 2) +
      facet_wrap(~quantity, ncol = 1, scales = "free_y") +
      scale_colour_brewer(name = "Retrospective", palette = "Set1") +
      expand_limits(y = 0) +
      labs(x = "Terminal year of the peel", y = NULL,
           title = "Management quantities by retrospective peel") +
      theme_bw(base_size = 11)
  )
  dev.off()
}

cat(sprintf("  wrote %s\n", file.path("plots", c("retro_mmb.png", "retro_recruitment.png",
      "retro_mmb_drop_survey.png", "retro_terminal_mmb.png", "retro_refpoints.png"))))
cat(sprintf("  wrote %s\n", file.path(MODEL_REL, "retro",
      c("retro_ssb.csv","retro_recruitment.csv","retro_refpoints.csv",
        "retro_peel_relative.csv","mohns_rho.csv","retro_diagnostics.csv"))))
cat("\nDone.\n")
