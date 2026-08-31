#!/usr/bin/env Rscript
## ============================================================================
## 06_run_retrospective.R
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
##   Rscript 06_run_retrospective.R [stage] [model_dir]
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
##   <model_dir>/retro/retro_diagnostics.csv  per-run convergence + provenance
##   <model_dir>/retro/mohns_rho.csv          rho + Ralston's sigma per mode
##   plots/retro_mmb.png, retro_recruitment.png,
##   plots/retro_mmb_drop_survey.png
##
##   NO reference points per peel: GMACS does not compute them when nyrRetro > 0
##   (gmacsbase.TPL 2.20.34 :5478, :13625). MMB and recruitment only.
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

## Figure titles carry the model's REPORT designation ("Model 26.1b"), not the
## folder name. Titling them basename(MODEL_DIR) put the internal directory
## string ("26_gmacs_update_newmat_plus_group") on figures that go to the CPT.
## Resolved through 0-models.R so the shortname has one definition; falls back
## to the folder name if the directory is not one of the report's models, which
## is the case when a scratch copy is retrospected.
MODEL_LABEL <- local({
  fallback <- basename(MODEL_DIR)
  defs <- file.path(REPO_ROOT, "0-models.R")
  if (!file.exists(defs)) return(fallback)
  e <- new.env()
  ok <- tryCatch({ suppressWarnings(sys.source(defs, envir = e)); TRUE },
                 error = function(...) FALSE)
  if (!ok || is.null(e$model_defs) || is.null(e$model_shorts)) return(fallback)
  ## Compare resolved paths, so a trailing slash or a relative form cannot miss.
  want  <- normalizePath(file.path(REPO_ROOT, e$model_defs), winslash = "/",
                         mustWork = FALSE)
  hit   <- which(want == MODEL_DIR)
  if (length(hit) != 1L) return(fallback)
  unname(e$model_shorts[names(e$model_defs)[hit]])
})
cat(sprintf("Model label for figures: %s\n", MODEL_LABEL))

## Per-peel parameter-vector shapes, used to seed each peel from the accepted
## fit -- see prepare_peel(). One <mode>/<peel>.par per peel, each a .par GMACS
## itself wrote for that peel, so the pin lengths are never inferred. Cached
## across runs because a peel must be fit once before its shape is known.
SHAPE_DIR <- file.path(RETRO_DIR, "_shapes")

## A shape is only valid for the model that produced it. Next cycle's .DAT has
## different year ranges, so its peels have different block lengths -- and
## write_peel_pin()'s count check CANNOT catch that, because it validates the
## pin against the shape itself. A stale shape would silently truncate every
## pin to last year's lengths and misalign the parameter vector.
##
## So the cache carries the identity of the data file it was built from, and is
## ignored wholesale on any mismatch (the peels then cold-start and rebuild it).
SHAPE_STAMP <- file.path(SHAPE_DIR, "SHAPES_FOR.txt")

shape_identity <- function()
  sprintf("datafile=%s md5=%s end_year=%d", GC$datafile,
          unname(tools::md5sum(file.path(MODEL_DIR, GC$datafile))), END_YEAR)

shapes_valid <- function() {
  if (!file.exists(SHAPE_STAMP)) return(FALSE)
  identical(trimws(readLines(SHAPE_STAMP, n = 1L, warn = FALSE)), shape_identity())
}

N_PEELS   <- 10L                      # peels 1..N_PEELS, plus the unpeeled peel 0
MODES     <- c("standard", "drop_survey")
GRAD_WARN <- 1e-3                     # WARN threshold, not an abort: the accepted
                                      # May 2026 fit has max gradient 1.46e-3
N_WORKERS <- gmacs_max_workers()      # small fixed default, NOT detectCores():
                                      # wide fan-out hard-resets this laptop and
                                      # corrupts the peel being written. Raise via
                                      # $env:GMACS_MAX_WORKERS. See
                                      # gmacs_max_workers() in R/gmacs_io.R.

## Compensate GMACS's retrospective shift of snow.prj's spr_grow_yr?
##
## STILL FALSE, but the 2026-08 reasoning for it was wrong on both counts and is
## corrected here (2026-08-27, measured against the real 2.20.34 source, now in
## GMACs/GMACS_tpl-cpp_code/ -- the earlier conclusion was inferred from a crash
## without the source in hand).
##
## 1. The out-of-bounds shift IS in 2.20.34. gmacsbase.TPL:4612 reads
##        spr_grow_yr = spr_grow_yr - nyrRetroNo;
##    and the bounds checks (:4609-4610) run BEFORE it, with nothing re-checking
##    after. snow.prj sets spr_grow_yr = 1982 = syr, so peel p asks for growth in
##    1982 - p. Decrementing an absolute year is wrong on its face: the "0 = last
##    year" case is already resolved at :4608.
##
## 2. The compensation does NOT crash. Peel 5 was re-run with spr_grow_yr = 1987
##    on 2026-08-27: exit 134 (the benign macOS teardown), nll identical to the
##    uncompensated run to every digit. The old "Memory allocation error" reading
##    of exit 1 does not reproduce -- and exit 1 is what :4609-4610 return on a
##    bounds failure, so it was likely never a memory error at all.
##
## It stays FALSE because it changes NOTHING observable: peels do not compute
## reference points (see the note in section 6), so the only quantities
## spr_grow_yr feeds are never produced. Leaving snow.prj untouched keeps the
## peel inputs byte-identical to the parent, which is worth more than
## compensating a value nothing reads.
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
EXE_NAME <- gmacs_exe_name()          # "gmacs.exe" on Windows, "gmacs" on macOS
EXE      <- file.path(MODEL_DIR, EXE_NAME)
if (!file.exists(EXE)) stop("No ", EXE_NAME, " in ", MODEL_DIR)

## Model end year comes from the .DAT itself.
.dat_lines <- read_raw_lines(file.path(MODEL_DIR, GC$datafile))$lines
END_YEAR <- as.integer(toks(.dat_lines[find_anchor(.dat_lines, "# End year")])[1])
SYR      <- as.integer(toks(.dat_lines[find_anchor(.dat_lines, "# Start year")])[1])
if (is.na(END_YEAR) || is.na(SYR)) stop("Could not read Start/End year from ", GC$datafile)

## Is this the male-only variant? The drop-survey peels replay
## 00_advance_model.R, whose arg 8 selects the male-only reduction. Read it from
## the model's own .DAT rather than taking it on trust: a two-sex rebuild of a
## male-only peel parses, runs to convergence and returns plausible numbers
## (2026-08-28: nll -20673 against the male-only -12664, with ~40 extra female
## T_pars_est blocks). write_peel_pin()'s block check catches it on a SEEDED
## run -- but a cold start has no shape to check against, so the first pass
## silently produced a two-sex retrospective for a male-only model.
NSEX <- local({
  i <- grep("#[[:space:]]*Number of sexes", .dat_lines)
  if (length(i) != 1L)
    stop("Could not uniquely read '# Number of sexes' from ", GC$datafile)
  as.integer(toks(sub("#.*$", "", .dat_lines[i]))[1])
})
if (!NSEX %in% c(1L, 2L)) stop("Unexpected nsex = ", NSEX, " in ", GC$datafile)
MALE_ONLY <- NSEX == 1L

## Files a run needs. Named from gmacs.dat, so this works for Models/25_gmacs
## ("snow.dat") as well as the 26 model ("26_snow_update_newmat_plus_group.dat").
RUN_FILES <- c(GC$datafile, GC$ctlfile, GC$prjfile, "gmacs.dat", EXE_NAME)

cat(sprintf("\n=== 06_run_retrospective.R ===\n"))
cat(sprintf("stage      : %s\n", STAGE))
cat(sprintf("model      : %s\n", MODEL_REL))
cat(sprintf("data file  : %s   (ctl %s, prj %s)\n", GC$datafile, GC$ctlfile, GC$prjfile))
cat(sprintf("model years: %d - %d\n", SYR, END_YEAR))
cat(sprintf("sexes      : %d%s\n", NSEX,
            if (MALE_ONLY) "  (male-only: drop-survey peels rebuilt with male_only=TRUE)" else ""))
cat(sprintf("peels      : 0 - %d   modes: %s\n", N_PEELS, paste(MODES, collapse = ", ")))
cat(sprintf("workers    : %d of %d cores\n", N_WORKERS, parallel::detectCores()))
cat(sprintf("prj fix    : %s\n\n", FIX_PRJ_GROWTH_YEAR))

## ---------------------------------------------------------------------------
## 2. Run + verify helpers
## ---------------------------------------------------------------------------
## Run gmacs.exe with `dir` as the working directory. Returns status, elapsed
## seconds, and the captured console output (also written to run.log).
run_gmacs <- function(dir, extra_args = character(0)) {
  ## ADMB derives its output file names from argv[0], so the executable is
  ## invoked from INSIDE the run directory -- as "./gmacs" on macOS, a bare
  ## "gmacs.exe" on Windows -- never by absolute path. gmacs_exe_call() picks
  ## the form; R/gmacs_jitter.R:344 does the same. (2026-08, macOS port.)
  if (!file.exists(file.path(dir, EXE_NAME))) stop("No ", EXE_NAME, " in ", dir)
  old <- setwd(dir); on.exit(setwd(old), add = TRUE)
  t0  <- Sys.time()
  out <- suppressWarnings(system2(gmacs_exe_call(EXE_NAME), args = extra_args,
                                  stdout = TRUE, stderr = TRUE))
  st  <- attr(out, "status"); if (is.null(st)) st <- 0L
  el  <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  ## Reclaim ADMB scratch now the process has exited -- 620 MB per run for this
  ## model, ~14 GB across a 22-run peel sweep, none of it ever read again. Same
  ## helper 06 uses; it lives in R/gmacs_io.R section 9. (2026-08-27, per Grant)
  purge_gmacs_scratch(".")
  writeLines(c(sprintf("# %s %s", EXE_NAME, paste(extra_args, collapse = " ")),
               sprintf("# exit status %d, %.1f s", st, el),
               out), "run.log")
  list(status = st, elapsed = el, out = out)
}

## Every check that must hold before a run's output is allowed into the
## analysis. Returns a one-row data.frame; `ok` FALSE means do not use it.
## `peel` gates the reference-point check: GMACS does not compute reference
## points for a peeled run at all (see the block on that check below), so a
## non-zero peel must not be failed for their absence.
verify_run <- function(dir, label, expect_end_year, started_at, run, peel = 0L) {
  fail <- character(0); warn <- character(0)

  ## The macOS build aborts at teardown (status 134) AFTER writing every output
  ## file. is_benign_gmacs_exit() is strict about what qualifies, and always
  ## returns FALSE on Windows, so this changes nothing there.
  benign <- is_benign_gmacs_exit(run$status, run$out)

  if (run$status != 0L && !benign)
    fail <- c(fail, sprintf("exit status %d", run$status))
  if (benign)
    warn <- c(warn, sprintf("exit status %d -- macOS FP teardown abort, outputs complete",
                            run$status))

  ## GMACS can exit 0 on some failure paths, so the log is inspected directly.
  bad <- grep("STOPPING|Index out of bounds|array bound|Error|error in",
              run$out, value = TRUE, ignore.case = FALSE)
  if (benign) bad <- bad[!trimws(bad) %in% GMACS_FP_TEARDOWN_MSGS]
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
  ##
  ## PEELED RUNS HAVE NO REFERENCE POINTS, BY DESIGN. gmacsbase.TPL 2.20.34
  ## guards both call sites -- lines 5478 and 13625 --
  ##     if (CalcRefPoints!=0 && nyrRetroNo==0) calc_spr_reference_points2(1);
  ## so a peel never computes them and all 18 derived quantities come back as
  ## exactly 0 in VALUE, not merely zero-variance. (The only unguarded call,
  ## :11779, is inside write_eval, the -mceval path.) Verified 2026-08-27
  ## against the 2.20.34 source in GMACs/GMACS_tpl-cpp_code/.
  ##
  ## So `retro_refpoints.csv` cannot be produced from peels with this GMACS.
  ## Failing peels for it would make the sweep impossible to complete; the
  ## retrospective's real products -- the MMB and recruitment trajectories and
  ## Mohn's rho -- need none of it.
  ##
  ## For an UNPEELED run the zeros are still fatal, and there the old reading
  ## holds: either the sd phase was skipped (-nohess, no gmacs.std) or it ran
  ## and the quantities came back degenerate. A zero BMSY/OFL from a terminal
  ## fit must never reach a SAFE figure.
  bmsy <- ofl <- NA_real_
  if (!is.null(rp) && !inherits(rp, "try-error")) {
    bmsy <- refpoint(rp, "BMSY"); ofl <- refpoint(rp, "OFL(tot)")
    if (!is.na(bmsy) && !is.na(ofl) && bmsy == 0 && ofl == 0) {
      if (peel > 0L) {
        warn <- c(warn, "no reference points (GMACS does not compute them for a peel)")
        bmsy <- ofl <- NA_real_          # NA, not 0 -- absent, not an estimate of zero
      } else {
        sd_ran <- file.exists(file.path(dir, "gmacs.std"))
        fail <- c(fail, if (!sd_ran)
          "BMSY and OFL(tot) are exactly 0 and there is no gmacs.std -- the sd phase did not run (was -nohess used?)"
        else
          "BMSY and OFL(tot) are exactly 0 despite a completed sd phase on an UNPEELED run -- the reference-point calculation produced degenerate values")
      }
    }
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
                                   as.character(END_YEAR - peel),
                                   if (MALE_ONLY) "TRUE" else "FALSE")),
                  stdout = file.path(dir, "advance.log"), stderr = file.path(dir, "advance.log"))
    if (st != 0L)
      stop(sprintf("00_advance_model.R failed for %s peel %d (see %s)",
                   mode, peel, file.path(dir, "advance.log")))
    ## keep only what a run needs; drop the template's stale ADMB artefacts
    for (f in c(GC$datafile, GC$ctlfile, GC$prjfile))
      file.copy(file.path(stage_dir, f), file.path(dir, f), overwrite = TRUE)
    unlink(stage_dir, recursive = TRUE, force = TRUE)
    file.copy(file.path(MODEL_DIR, EXE_NAME), file.path(dir, EXE_NAME), overwrite = TRUE)
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

  ## Seed the peel from the accepted fit.
  ##
  ## Cold-started peels land wherever this multi-modal likelihood takes them:
  ## measured 2026-08-27, standard peel 0 cold-started to nll -23542.77 -- the
  ## inferior optimum this model was promoted AWAY from -- rather than the
  ## accepted -23546.35, and pinning peel 5 improved it by 12.19 nll units.
  ## Unseeded, Mohn's rho measures which optimum each peel fell into rather than
  ## retrospective bias.
  ##
  ## A peel estimates fewer parameters than the parent, and not by a fixed count
  ## (the directed fishery was closed in 2022 and 2023, so those years carry no
  ## F deviation). write_peel_pin() therefore shapes the pin from a .par GMACS
  ## itself wrote for this peel; SHAPE_DIR caches those. Without a shape the
  ## peel cold-starts and its own .par becomes the shape for next time.
  shape <- file.path(SHAPE_DIR, mode, sprintf("%d.par", peel))
  if (file.exists(shape) && shapes_valid()) {
    write_peel_pin(file.path(MODEL_DIR, "gmacs.par"), shape,
                   file.path(dir, "gmacs.pin"))
  } else {
    message(sprintf("  note: no valid shape for %s peel %d -- cold start; its ",
                    mode, peel), ".par will be cached as the shape.")
  }

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
    ## peel = 1: these ARE peel-1 runs, so they must be verified as peeled.
    ## Verified as unpeeled they fail on the missing reference points, which no
    ## peel can produce -- and `diagnose` is part of the default `all` stage, so
    ## that turned every full run into a spurious failure.
    v  <- verify_run(d, if (fx) "prjfix_on" else "prjfix_off", END_YEAR - 1L, t0, r,
                     peel = 1L)
    ## No BMSY/OFL columns. This stage was written to compare reference points
    ## between the compensated and uncompensated peel, but GMACS computes none
    ## for a peel at all (see the note in section 6), so those columns were
    ## always exactly 0 in both rows -- the comparison could never answer its
    ## own question, and the 2026-08 file on disk records that pair of zeros as
    ## if it were a result. nll and max|grad| ARE real and are what the
    ## comparison now rests on. (2026-08-27)
    diag_rows[[length(diag_rows) + 1L]] <- data.frame(
      spr_grow_yr_compensated = fx,
      ok       = v$ok,
      nll      = v$nll,
      max_grad = v$max_grad,
      problems = v$problems, stringsAsFactors = FALSE)
  }
  dg <- do.call(rbind, diag_rows)
  print(dg, row.names = FALSE)
  write.csv(dg, file.path(RETRO_DIR, "prj_growth_year_diagnostic.csv"), row.names = FALSE)

  if (all(dg$ok)) {
    ## Compare nll and max|grad|, which is what the rows actually carry. This
    ## read dg$BMSY and dg$OFL_tot, columns the block above deliberately stopped
    ## writing on 2026-08-27 -- so it errored on `if (is.na(NULL))` and aborted
    ## the default `all` stage AFTER two full GMACS fits (fixed 2026-08-29).
    cat(sprintf("  nll differs by %.6f; max|grad| %.3g compensated vs %.3g not\n",
                dg$nll[2] - dg$nll[1], dg$max_grad[2], dg$max_grad[1]))
    cat("  -> if the nll difference is ~0 the compensation is a no-op.\n")
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

  ## Drop a shape cache built from a different data file before staging anything
  ## -- a stale shape cannot be detected later, because write_peel_pin() checks
  ## the pin against the shape itself.
  if (dir.exists(SHAPE_DIR) && !shapes_valid()) {
    unlink(SHAPE_DIR, recursive = TRUE, force = TRUE)
    cat("  shape cache was built from a different data file -- cleared;",
        "peels will cold-start and rebuild it\n")
  }
  dir.create(SHAPE_DIR, recursive = TRUE, showWarnings = FALSE)
  writeLines(shape_identity(), SHAPE_STAMP)
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
                       jobs$expect_end_year[i], t0, r, peel = jobs$peel[i])

      ## Cache this peel's parameter-vector shape so the next run can seed it.
      ## Only from a run that passed -- a shape from a broken fit would give
      ## every later pin the wrong lengths.
      par_f <- file.path(jobs$dir[i], "gmacs.par")
      if (isTRUE(v$ok) && file.exists(par_f)) {
        sd_ <- file.path(SHAPE_DIR, jobs$mode[i])
        dir.create(sd_, recursive = TRUE, showWarnings = FALSE)
        file.copy(par_f, file.path(sd_, sprintf("%d.par", jobs$peel[i])), overwrite = TRUE)
      }
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

## NO REFERENCE POINTS PER PEEL -- the retrospective reports MMB and
## recruitment only (2026-08-27, per Grant).
##
## GMACS does not compute reference points for a peeled run. Both call sites in
## gmacsbase.TPL 2.20.34 (:5478, :13625) read
##     if (CalcRefPoints!=0 && nyrRetroNo==0) calc_spr_reference_points2(1);
## so every peel returns all 18 derived quantities as exactly 0 -- zero in
## VALUE, not merely zero-variance. Confirmed against the 2.20.34 source in
## GMACs/GMACS_tpl-cpp_code/, and against the runs: the unpeeled base fit
## reports non-positive sdreport variance for exactly 6 variables (Fmsy(3,4),
## Fofl(3,4), Ofl(3,4) -- fleets that do not exist, legitimately zero) while
## every peel reports 19 and zeroes all of them.
##
## This is not fixable from the R side and was never a -nohess problem: the
## peels here run WITH the Hessian. A retro_refpoints.csv would be a table of
## zeros, which is exactly the plausible-looking wrong number CLAUDE.md rule 1
## exists to prevent. MMB and recruitment need none of it, and Mohn's rho is
## computed on those.
##
## The terminal fit's reference points are not lost -- they are in the model
## directory and in retro/base_run.csv.

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
## NOTE ON THE PREVIOUS SCRIPT: the version of 06_run_retrospective.R inherited
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
                sprintf("Retrospective analysis, %s", MODEL_LABEL),
                sprintf("Peels 0-%d.  %s", N_PEELS, rho_lab("standard", "mature_male_biomass"))))
dev.off()

png(file.path(PLOT_DIR, "retro_recruitment.png"), height = 6, width = 8, res = 400, units = "in")
print(peel_plot("standard", "recruit_male", "Male recruitment (millions)",
                sprintf("Recruitment retrospective, %s", MODEL_LABEL),
                sprintf("Peels 0-%d.  %s", N_PEELS, rho_lab("standard", "recruitment_male"))))
dev.off()

if ("drop_survey" %in% series$mode) {
  png(file.path(PLOT_DIR, "retro_mmb_drop_survey.png"), height = 6, width = 8, res = 400, units = "in")
  print(peel_plot("drop_survey", "ssb", "Mature male biomass (1,000 t)",
                  sprintf("Retrospective with the terminal survey year withheld, %s", MODEL_LABEL),
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
         title = sprintf("Terminal-year MMB from each peel vs the base fit (black), %s", MODEL_LABEL)) +
    theme_bw(base_size = 11)
)
dev.off()

## No retro_refpoints.png: see the note where refs used to be built. A peel has
## no reference points to plot.

cat(sprintf("  wrote %s\n", file.path("plots", c("retro_mmb.png", "retro_recruitment.png",
      "retro_mmb_drop_survey.png", "retro_terminal_mmb.png"))))
cat(sprintf("  wrote %s\n", file.path(MODEL_REL, "retro",
      c("retro_ssb.csv","retro_recruitment.csv",
        "retro_peel_relative.csv","mohns_rho.csv","retro_diagnostics.csv"))))
cat("\nDone.\n")
