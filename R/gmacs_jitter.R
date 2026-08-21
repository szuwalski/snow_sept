## ============================================================================
## R/gmacs_jitter.R
##
## Helpers for the GMACS jitter analysis. Sourced by 06_run_jitter.R.
## Nothing in this file runs on source(); it only defines functions.
##
## Depends on R/gmacs_io.R (owned by the retrospective work) for:
##   read_raw_lines, write_raw_lines, toks, find_anchor, read_gmacs_control,
##   read_gmacsall_summary, read_gmacsall_refpoints, refpoint,
##   read_par_header, read_gmacs_echo
## Source that file FIRST. This file deliberately adds nothing to it.
##
## ---------------------------------------------------------------------------
## WHY THE JITTER IS DRIVEN FROM THE COMMAND LINE
##
## GMACS can be jittered two ways: the "# Jitter specs" line in gmacs.dat, or
## the "-jitter <rseed>" command-line flag. We use the flag, and copy gmacs.dat
## byte-for-byte unmodified. Two reasons, both correctness:
##
## 1. SEEDS. gmacsbase.TPL:5257 is `if (rseed==0) rseed = start;` where `start`
##    is a time_t -- WHOLE SECONDS. Without an explicit seed every run seeds off
##    the wall clock, so runs launched in the same second by a parallel backend
##    get the SAME seed and therefore the SAME jitter. The old script did this,
##    and recorded nothing, so no run was reproducible. Passing an explicit
##    seed makes the whole analysis re-runnable bit-for-bit.
##
## 2. FILE FORMAT. The gmacs.dat jitter line changed between GMACS versions
##    (2 fields in 2.20.22, 3 in 2.20.34) and the field ORDER is not what the
##    echo file suggests -- see verified_jitter_field_order() below. Not
##    touching the line avoids the question entirely.
##
## "-jitter" sets jitflag=1, which forces IsJittered=1 regardless of the file
## (gmacsbase.TPL:249-253 and :323), and the seed GMACS actually used is written
## to jitter.txt in the run directory (TPL:5264-5267). sdJitter still comes from
## gmacs.dat, where it is already 0.1.
##
## CAUTION: the gmacsbase.TPL sitting in each model folder is NOT the source of
## gmacs.exe (folder TPL = 2.20.32b ** TJ **; exe = 2.20.34 ** AEP **). Read it
## for orientation, never as ground truth. The files the exe writes itself --
## gmacs_files_in.dat, gmacs_in.dat, jitter.txt -- are the only authority. That
## is why every run is verified against them rather than trusted.
## ============================================================================


## ---------------------------------------------------------------------------
## 1. Reading what the executable says it did
## ---------------------------------------------------------------------------

## Value following a "# <key>" line in one of GMACS's own echo files.
## Returns NA_character_ when the file or the key is absent.
gmacs_echo_value <- function(model_dir, key, file = "gmacs_files_in.dat") {
  path <- file.path(model_dir, file)
  if (!file.exists(path)) return(NA_character_)
  L <- readLines(path, warn = FALSE)
  i <- which(trimws(L) == paste0("# ", key))
  if (length(i) != 1L) return(NA_character_)
  j <- i + 1L
  if (j > length(L)) return(NA_character_)
  trimws(L[j])
}

## The version string the EXECUTABLE stamps into its own echo, e.g.
## "## GMACS Version 2.20.34; ** AEP **; Compiled 2026-01-15".
## This is the version to record in the manifest -- not the folder's TPL.
gmacs_exe_version <- function(model_dir) {
  path <- file.path(model_dir, "gmacs_files_in.dat")
  if (!file.exists(path)) return(NA_character_)
  L <- readLines(path, n = 5L, warn = FALSE)
  v <- grep("GMACS Version", L, value = TRUE)
  if (!length(v)) NA_character_ else trimws(v[1])
}

## Identity of the executable itself, for the reproducibility manifest.
gmacs_exe_info <- function(model_dir, exe = "gmacs.exe") {
  path <- file.path(model_dir, exe)
  if (!file.exists(path)) stop("No ", exe, " in ", model_dir)
  fi <- file.info(path)
  list(path  = normalizePath(path, winslash = "/"),
       bytes = as.numeric(fi$size),
       mtime = format(fi$mtime, "%Y-%m-%d %H:%M:%S"),
       md5   = unname(tools::md5sum(path)))
}


## ---------------------------------------------------------------------------
## 2. The gmacs.dat jitter line
## ---------------------------------------------------------------------------
## We do not WRITE this line (see the header), but we read it to confirm
## sdJitter and to fail loudly if the format shifts under us again.
##
## FIELD ORDER IS `IsJittered IsPin sdJitter`.
##
## This is established empirically, not inferred. A real converged run under
## this exact executable --
##   snow_crab/Models/25_gmacs_update_hyb_surv_and_fsh_newmat/jitter/1/
##   (gmacs.exe 8,872,135 bytes, "GMACS Version 2.20.34; ** AEP **")
## has gmacs.dat line 14 = "1 0 0.1", its own gmacs_files_in.dat reporting
##   # IsPin / 0 , # IsJittered / 1 , # sdJitter / 0.1
## and a populated jitter.txt (so jittering demonstrably ran).
##
## Note the ECHO prints IsPin first while the FILE puts IsJittered first. Do not
## infer the file order from the echo order -- that inference yields "0 1 0.1",
## which would leave IsJittered = 0 and silently produce un-jittered runs. Our
## own model dirs cannot settle it either: their line is "0 0 0.1", which is
## symmetric under both orderings.
verified_jitter_field_order <- c("IsJittered", "IsPin", "sdJitter")

## Locate and parse the jitter spec line of a gmacs.dat.
## `gc` is the object returned by read_gmacs_control().
read_jitter_spec <- function(gc) {
  L <- gc$obj$lines
  i <- which(grepl("^[[:space:]]*#.*Jitter", L))
  if (length(i) != 1L)
    stop(sprintf("gmacs.dat: '# Jitter' anchor matched %d lines (expected 1) in %s",
                 length(i), gc$dir))

  ## value = first non-comment, non-blank line after the anchor
  j <- i + 1L
  while (j <= length(L) && (nchar(trimws(L[j])) == 0L || grepl("^[[:space:]]*#", L[j]))) j <- j + 1L
  if (j > length(L)) stop("gmacs.dat: no value line after the Jitter anchor in ", gc$dir)

  f <- toks(L[j])
  if (length(f) != 3L)
    stop(sprintf(paste0("gmacs.dat: the jitter line is '%s' (%d fields); this code was written ",
                        "for the 3-field GMACS 2.20.34 format '<IsJittered> <IsPin> <sdJitter>'. ",
                        "The format has changed -- re-verify against gmacs_files_in.dat before ",
                        "running anything. File: %s"),
                 trimws(L[j]), length(f), file.path(gc$dir, "gmacs.dat")))

  v <- suppressWarnings(as.numeric(f))
  if (anyNA(v))
    stop("gmacs.dat: non-numeric jitter field(s) '", trimws(L[j]), "' in ", gc$dir)

  list(idx = j, raw = trimws(L[j]), fields = v,
       is_jittered = v[1], is_pin = v[2], sd = v[3])
}


## Terminal year declared by the model's own data file, e.g.
##   1982	# Start	year
##   2025	# End	year
## Read rather than hardcoded, so the staleness check follows the model forward
## each assessment cycle instead of silently going stale itself.
read_dat_year_range <- function(dat_path) {
  if (!file.exists(dat_path)) stop("No data file at ", dat_path)
  L <- read_raw_lines(dat_path)$lines
  grab <- function(pat, label) {
    i <- which(grepl(pat, L) & !grepl("^[[:space:]]*#", L))
    if (!length(i)) stop(sprintf("Could not find the '%s' line in %s", label, dat_path))
    v <- suppressWarnings(as.integer(toks(L[i[1]])[1]))
    if (is.na(v)) stop(sprintf("Unparseable '%s' line in %s: %s", label, dat_path, L[i[1]]))
    v
  }
  syr <- grab("#[[:space:]]*Start[[:space:]]+year", "Start year")
  nyr <- grab("#[[:space:]]*End[[:space:]]+year",   "End year")
  if (nyr < syr) stop(sprintf("Data file declares End year %d before Start year %d", nyr, syr))
  list(start_year = syr, end_year = nyr)
}


## ---------------------------------------------------------------------------
## 3. Preflight checks
## ---------------------------------------------------------------------------

## Free space, in GB, on the volume holding `path`. Returns NA (with a warning)
## rather than failing if it cannot be determined -- a missing disk reading
## should not block a run.
disk_free_gb <- function(path) {
  drive <- sub(":.*$", "", normalizePath(path, winslash = "/", mustWork = FALSE))
  out <- tryCatch(
    suppressWarnings(system2("powershell",
                             c("-NoProfile", "-Command",
                               sprintf("(Get-PSDrive %s).Free", drive)),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character(0))
  v <- suppressWarnings(as.numeric(out[nzchar(trimws(out))][1]))
  if (is.na(v)) {
    warning("Could not determine free disk space on drive ", drive, ".")
    return(NA_real_)
  }
  v / 1024^3
}

## ADMB reads <program>.pin automatically whenever it exists in the run
## directory. A stray gmacs.pin would override the jittered starting values and
## turn every "jitter" run back into the same fit -- exactly the silent failure
## this rewrite exists to prevent.
##
## The one legitimate pin is the one written by a promotion (Phase F), which is
## always accompanied by jitter/PROMOTION.md. Anything else is a hard stop.
assert_no_stray_pin <- function(model_dir) {
  pin <- file.path(model_dir, "gmacs.pin")
  if (!file.exists(pin)) return(invisible(TRUE))
  promoted <- file.exists(file.path(model_dir, "jitter", "PROMOTION.md"))
  if (!promoted)
    stop("A gmacs.pin exists in ", model_dir, " but there is no jitter/PROMOTION.md ",
         "explaining it. ADMB reads gmacs.pin automatically, which would override the ",
         "jittered starting values and make every run identical. Remove or explain it ",
         "before jittering.")
  message("  NOTE: gmacs.pin present and documented by jitter/PROMOTION.md (a promoted fit).")
  invisible(TRUE)
}

## Is the model directory's output actually from the inputs gmacs.dat now names?
##
## GMACS echoes the file names and terminal year it really used into
## gmacs_files_in.dat / gmacs_in.dat. Comparing those against the live gmacs.dat
## is the only reliable staleness test -- timestamps lie when a directory has
## been copied.
base_run_status <- function(gc, expect_end_year = NULL) {
  reasons <- character(0)

  par <- read_par_header(gc$dir)
  if (is.na(par$nll)) reasons <- c(reasons, "no gmacs.par (model has never been run here)")

  echo_dat <- gmacs_echo_value(gc$dir, "datafile")
  echo_ctl <- gmacs_echo_value(gc$dir, "controlfile")
  if (is.na(echo_dat)) {
    reasons <- c(reasons, "no gmacs_files_in.dat")
  } else {
    if (!identical(echo_dat, gc$datafile))
      reasons <- c(reasons, sprintf("last run used datafile '%s' but gmacs.dat now names '%s'",
                                    echo_dat, gc$datafile))
    if (!is.na(echo_ctl) && !identical(echo_ctl, gc$ctlfile))
      reasons <- c(reasons, sprintf("last run used controlfile '%s' but gmacs.dat now names '%s'",
                                    echo_ctl, gc$ctlfile))
  }

  ech <- read_gmacs_echo(gc$dir)
  if (!is.null(expect_end_year) && !is.na(ech$end_year) &&
      !identical(as.integer(ech$end_year), as.integer(expect_end_year)))
    reasons <- c(reasons, sprintf("last run had End year %d, expected %d",
                                  ech$end_year, expect_end_year))

  ## The .dat/.ctl being newer than gmacs.par is corroborating, not decisive.
  par_mt <- file.info(file.path(gc$dir, "gmacs.par"))$mtime
  dat_mt <- file.info(file.path(gc$dir, gc$datafile))$mtime
  if (!is.na(par_mt) && !is.na(dat_mt) && dat_mt > par_mt)
    reasons <- c(reasons, "the data file is newer than gmacs.par")

  list(stale = length(reasons) > 0L, reasons = reasons,
       echo_datafile = echo_dat, echo_ctlfile = echo_ctl,
       end_year = ech$end_year, last_survey_year = ech$last_survey_year,
       npar = par$npar, nll = par$nll, max_grad = par$max_grad)
}


## ---------------------------------------------------------------------------
## 4. Building a run directory
## ---------------------------------------------------------------------------

## file.copy() returns FALSE for a missing source WITHOUT erroring. That is how
## both the old jitter script and the old retrospective script "half-worked":
## they copied a hardcoded "snow.dat" that does not exist in these model dirs,
## and GMACS then ran on whatever happened to be lying around. Every copy here
## is checked.
copy_checked <- function(from, to, what = basename(from)) {
  if (!file.exists(from)) stop("Cannot copy ", what, ": no such file: ", from)
  ok <- file.copy(from, to, overwrite = TRUE, copy.date = TRUE)
  if (!isTRUE(ok)) stop("Failed to copy ", what, " -> ", to)
  invisible(TRUE)
}

## The executable is ~8.9 MB; 100 copies is ~890 MB of pure duplication. On NTFS
## a hard link is instantaneous and costs nothing. Falls back to a real copy on
## any filesystem that refuses.
##
## The exe is placed IN the run directory rather than called by absolute path
## because ADMB derives its output file names from argv[0].
link_or_copy_exe <- function(from, to) {
  if (file.exists(to)) return(invisible("existing"))
  ok <- suppressWarnings(file.link(from, to))
  if (isTRUE(ok)) return(invisible("link"))
  copy_checked(from, to, "gmacs.exe")
  invisible("copy")
}

## Populate one jitter run directory. gmacs.dat is copied byte-for-byte: the
## jitter is switched on by the -jitter flag at run time, not by editing it.
prepare_run_dir <- function(gc, dest) {
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(dest)) stop("Could not create run directory: ", dest)

  for (nm in c(gc$datafile, gc$ctlfile, gc$prjfile, "gmacs.dat"))
    copy_checked(file.path(gc$dir, nm), file.path(dest, nm), nm)

  link_or_copy_exe(file.path(gc$dir, "gmacs.exe"), file.path(dest, "gmacs.exe"))

  ## Never inherit a pin, and never inherit a previous run's seed record.
  for (junk in c("gmacs.pin", "jitter.txt"))
    if (file.exists(file.path(dest, junk))) unlink(file.path(dest, junk))

  invisible(dest)
}


## ---------------------------------------------------------------------------
## 5. Running the executable
## ---------------------------------------------------------------------------
## GMACS exits 0 on some failure paths, so the exit status alone is not a
## success test -- the captured log is scanned for error markers too.
GMACS_ERROR_MARKERS <- c("STOPPING", "Error", "error occurred", "cannot be opened",
                         "Fatal", "abnormal", "ad_exit")

run_gmacs <- function(run_dir, args = character(0), exe = "gmacs.exe",
                      log = "gmacs_run.log") {
  old <- setwd(run_dir)
  on.exit(setwd(old), add = TRUE)

  t0 <- Sys.time()
  status <- tryCatch(
    suppressWarnings(system2(exe, args = as.character(args),
                             stdout = log, stderr = paste0(log, ".err"))),
    error = function(e) { attr(e, "gmacs_failed") <- TRUE; 127L })
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  txt <- character(0)
  for (f in c(log, paste0(log, ".err")))
    if (file.exists(f)) txt <- c(txt, readLines(f, warn = FALSE))
  hits <- unique(unlist(lapply(GMACS_ERROR_MARKERS, function(m) grep(m, txt, value = TRUE, fixed = TRUE))))

  list(status  = as.integer(status),
       elapsed = elapsed,
       ok      = identical(as.integer(status), 0L) && length(hits) == 0L,
       errors  = if (length(hits)) utils::head(hits, 5L) else character(0))
}


## ---------------------------------------------------------------------------
## 6. Verifying that a run really was jittered
## ---------------------------------------------------------------------------
## The failure this guards against is the dangerous one: a directory full of
## plausible-looking output from 100 runs that were never actually jittered.
##
## jitter.txt is the proof. GMACS writes it ONLY inside `if (IsJittered!=0)`
## (gmacsbase.TPL:5259-5268), and writes the seed it actually used. If the file
## is absent, no jittering happened. If its contents differ from the seed we
## asked for, -jitter was ignored and the run is clock-seeded, hence not
## reproducible.
verify_jitter_run <- function(run_dir, expected_seed, expected_sd = NULL,
                              expected_end_year = NULL) {
  problems <- character(0)

  seed_path <- file.path(run_dir, "jitter.txt")
  seed_used <- NA_integer_
  if (!file.exists(seed_path)) {
    problems <- c(problems,
                  "no jitter.txt -- GMACS only writes it when IsJittered != 0, so this run was NOT jittered")
  } else {
    seed_used <- suppressWarnings(as.integer(trimws(readLines(seed_path, warn = FALSE))[1]))
    if (is.na(seed_used)) {
      problems <- c(problems, "jitter.txt is unreadable")
    } else if (!identical(seed_used, as.integer(expected_seed))) {
      problems <- c(problems, sprintf("jitter.txt reports seed %d but %d was requested -- '-jitter' was ignored",
                                      seed_used, as.integer(expected_seed)))
    }
  }

  echo_jit <- suppressWarnings(as.numeric(gmacs_echo_value(run_dir, "IsJittered")))
  if (is.na(echo_jit)) {
    problems <- c(problems, "no gmacs_files_in.dat -- cannot confirm IsJittered")
  } else if (!identical(echo_jit, 1)) {
    problems <- c(problems, sprintf("the executable echoed IsJittered = %s (expected 1)", echo_jit))
  }

  echo_sd <- suppressWarnings(as.numeric(gmacs_echo_value(run_dir, "sdJitter")))
  if (!is.null(expected_sd) && !is.na(echo_sd) && !isTRUE(all.equal(echo_sd, expected_sd)))
    problems <- c(problems, sprintf("the executable echoed sdJitter = %s (expected %s)", echo_sd, expected_sd))

  ech <- read_gmacs_echo(run_dir)
  if (!is.null(expected_end_year) && !is.na(ech$end_year) &&
      !identical(as.integer(ech$end_year), as.integer(expected_end_year)))
    problems <- c(problems, sprintf("End year %d, expected %d (an unintended retrospective peel?)",
                                    ech$end_year, expected_end_year))

  list(ok = length(problems) == 0L, problems = problems,
       seed_used = seed_used, sd_used = echo_sd, end_year = ech$end_year)
}


## ---------------------------------------------------------------------------
## 7. Collecting one run's results
## ---------------------------------------------------------------------------
## Never returns a silent NA: every failure is recorded in `note` so a run that
## produced no numbers can be told apart from one that produced bad numbers.
##
## Reference points are looked up BY NAME. The old script used fixed row indices
## (take_row <- c(1,2,3,4,8,12,13)) into the derived-quantities block, with the
## estimate at token 3 for one-word names and token 4 for two-word names -- one
## inserted row and it silently returns the wrong quantity under the right
## column heading.
collect_run <- function(run_dir, idx, seed, run_info = NULL) {
  out <- data.frame(
    idx = as.integer(idx), objFun = NA_real_, maxGrad = NA_real_,
    seed = as.integer(seed), folder = normalizePath(run_dir, winslash = "/", mustWork = FALSE),
    npar = NA_integer_, bmsy = NA_real_, status = NA_real_,
    ofl_tot = NA_real_, ofl_ret = NA_real_, ofl_disc = NA_real_,
    fmsy = NA_real_, fofl = NA_real_,
    mmb_terminal = NA_real_, rec_terminal = NA_real_, terminal_year = NA_integer_,
    seed_used = NA_integer_, exit_code = NA_integer_, elapsed_s = NA_real_,
    complete = FALSE, note = "", stringsAsFactors = FALSE)

  if (!is.null(run_info)) {
    out$exit_code <- run_info$status
    out$elapsed_s <- round(run_info$elapsed, 1)
    if (length(run_info$errors))
      out$note <- paste("run log:", paste(run_info$errors, collapse = " / "))
  }

  ph <- read_par_header(run_dir)
  out$npar <- ph$npar; out$objFun <- ph$nll; out$maxGrad <- ph$max_grad

  allout <- file.path(run_dir, "Gmacsall.out")
  if (!file.exists(allout)) {
    out$note <- trimws(paste(out$note, "no Gmacsall.out"))
    return(out)
  }

  rp <- tryCatch(read_gmacsall_refpoints(allout), error = function(e) e)
  if (inherits(rp, "error")) {
    out$note <- trimws(paste(out$note, "refpoints unreadable:", conditionMessage(rp)))
  } else {
    out$bmsy     <- refpoint(rp, "BMSY")
    out$status   <- refpoint(rp, "Bcurr/BMSY")
    out$ofl_tot  <- refpoint(rp, "OFL(tot)")
    out$ofl_ret  <- refpoint(rp, "Ofl (1)")
    out$ofl_disc <- refpoint(rp, "Ofl (2)")
    out$fmsy     <- refpoint(rp, "Fmsy (1)")
    out$fofl     <- refpoint(rp, "Fofl (1)")
  }

  sm <- tryCatch(read_gmacsall_summary(allout), error = function(e) e)
  if (inherits(sm, "error")) {
    out$note <- trimws(paste(out$note, "summary unreadable:", conditionMessage(sm)))
  } else {
    ty <- max(sm$Year)
    out$terminal_year <- as.integer(ty)
    out$mmb_terminal  <- sm$SSB[sm$Year == ty]
    if ("Recruit_male" %in% names(sm)) out$rec_terminal <- sm$Recruit_male[sm$Year == ty]
  }

  ## Cross-check the two independent reports of the objective function.
  ## gmacs.par line 1 and the "Total:" row of the Likelihoods_by_type block are
  ## written by different parts of GMACS; disagreement means a torn/partial run.
  tot <- tryCatch({
    L <- readLines(allout, warn = FALSE)
    i <- grep("^Total:", L)
    if (length(i)) suppressWarnings(as.numeric(toks(L[i[1]])[2])) else NA_real_
  }, error = function(e) NA_real_)
  if (!is.na(tot) && !is.na(out$objFun) && abs(tot - out$objFun) > 1e-4)
    out$note <- trimws(paste(out$note,
                             sprintf("objective mismatch: gmacs.par %.6f vs Gmacsall.out Total %.6f",
                                     out$objFun, tot)))

  out$complete <- !is.na(out$objFun) && !is.na(out$ofl_tot) && !is.na(out$mmb_terminal)
  out
}


## ---------------------------------------------------------------------------
## 8. Jitter clouds ("modes")
## ---------------------------------------------------------------------------
## A jitter that lands in more than one optimum is the headline result -- the
## 2025 assessment found two clouds ~0.2 nll apart whose OFLs differed by
## 5,000 t. Runs are grouped by objective function with complete-linkage
## clustering cut at `gap`; groups smaller than `min_n` are labelled "minor" so
## a single stray run cannot masquerade as a mode.
##
## Returns a factor, ordered best (lowest nll) first: "A", "B", ... / "minor".
classify_modes <- function(nll, gap = 0.01, min_n = 3L) {
  out <- rep(NA_character_, length(nll))
  ok  <- which(is.finite(nll))
  if (!length(ok)) return(factor(out))
  if (length(ok) == 1L) { out[ok] <- "A"; return(factor(out, levels = "A")) }

  cl <- stats::cutree(stats::hclust(stats::dist(nll[ok]), method = "complete"), h = gap)

  ord <- order(vapply(split(nll[ok], cl), min, numeric(1)))
  sizes <- table(cl)
  lab <- character(0); k <- 0L
  for (g in names(sizes)[ord]) {
    if (sizes[[g]] >= min_n) { k <- k + 1L; lab[g] <- LETTERS[k] } else lab[g] <- "minor"
  }
  out[ok] <- lab[as.character(cl)]
  factor(out, levels = c(intersect(LETTERS, unique(out)), "minor"[any(out == "minor", na.rm = TRUE)]))
}

## Which parameters separate the clouds?
##
## Asked for by the SSC (docs/SEPT2026_SNOW_CRAB_BUILD_PLAN.md row 417) and
## scaffolded in docs/PHASE1_SECTION_SKETCHES.md section 5.
##
## For the best mode against each other substantial mode, the standardized mean
## difference (mean_A - mean_B) / sd_pooled is computed per parameter and ranked
## by magnitude. sd is pooled ACROSS ALL runs so the scale is the jitter cloud's
## own spread; parameters that never move are dropped.
mode_attribution <- function(par_paths, modes, top_n = 15L) {
  stopifnot(length(par_paths) == length(modes))
  keep <- !is.na(modes) & modes != "minor" & file.exists(par_paths)
  if (sum(keep) < 2L) return(NULL)

  pars <- wtsGMACS::readParFile(stats::setNames(par_paths[keep], names(par_paths)[keep]))
  pars <- pars[!is.na(pars$index), c("case", "param", "value")]   # drop the 3 header rows
  if (!nrow(pars)) return(NULL)

  wide <- stats::reshape(as.data.frame(pars), idvar = "case", timevar = "param",
                         direction = "wide")
  rn <- wide$case; wide$case <- NULL
  names(wide) <- sub("^value\\.", "", names(wide))
  M <- as.matrix(wide); rownames(M) <- rn

  mode_of <- stats::setNames(as.character(modes[keep]), names(par_paths)[keep])[rownames(M)]
  sd_all  <- apply(M, 2, stats::sd, na.rm = TRUE)
  vary    <- which(is.finite(sd_all) & sd_all > 0)
  if (!length(vary)) return(NULL)
  M <- M[, vary, drop = FALSE]; sd_all <- sd_all[vary]

  lv <- sort(unique(mode_of))
  best <- lv[1]                                   # modes are already ordered best-first
  others <- setdiff(lv, best)
  if (!length(others)) return(NULL)

  res <- do.call(rbind, lapply(others, function(b) {
    ma <- colMeans(M[mode_of == best, , drop = FALSE], na.rm = TRUE)
    mb <- colMeans(M[mode_of == b,    , drop = FALSE], na.rm = TRUE)
    d  <- (ma - mb) / sd_all
    data.frame(parameter = names(ma), mode_a = best, mode_b = b,
               mean_a = unname(ma), mean_b = unname(mb),
               difference = unname(ma - mb), std_difference = unname(d),
               stringsAsFactors = FALSE)
  }))
  res <- res[order(-abs(res$std_difference)), ]
  rownames(res) <- NULL
  utils::head(res, top_n)
}
