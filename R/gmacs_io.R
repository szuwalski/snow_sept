## ============================================================================
## R/gmacs_io.R
##
## Shared, side-effect-free readers/writers for GMACS (ADMB) model files.
## Sourced by 00_advance_model.R (writes the model .DAT/.CTL) and by
## 06_run_retrospective.R (drives retrospective peels).
##
## Nothing in this file runs on source(); it only defines functions.
##
## Two groups:
##   1-2. Raw text I/O + anchor helpers -- MOVED VERBATIM from the original
##        00_advance_model.R sections 1-3. The raw-bytes approach is required:
##        the snow .DAT/.CTL carry CRLF line endings and non-ASCII comment
##        glyphs that readLines()/writeLines() would silently rewrite.
##   3-6. GMACS control-file, projection-file, and output-file parsers used by
##        the retrospective driver.
## ============================================================================

## ---------------------------------------------------------------------------
## 1. Raw line-based file I/O (preserves line endings + non-ASCII bytes)
## ---------------------------------------------------------------------------
read_raw_lines <- function(path) {
  raw <- readBin(path, "raw", n = file.info(path)$size)
  txt <- rawToChar(raw)
  Encoding(txt) <- "bytes"                       # treat as opaque bytes
  crlf <- grepl("\r\n", txt, fixed = TRUE, useBytes = TRUE)
  eol  <- if (crlf) "\r\n" else "\n"
  trailing_eol <- grepl(paste0(eol, "$"), txt, useBytes = TRUE)
  lines <- strsplit(txt, eol, fixed = TRUE, useBytes = TRUE)[[1]]
  list(lines = lines, eol = eol, trailing_eol = trailing_eol)
}

write_raw_lines <- function(obj, path) {
  txt <- paste(obj$lines, collapse = obj$eol)
  if (isTRUE(obj$trailing_eol)) txt <- paste0(txt, obj$eol)
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(charToRaw(txt), con)
}

## ---------------------------------------------------------------------------
## 2. Whitespace / anchor helpers
## ---------------------------------------------------------------------------
## trimmed content of a line (whitespace-insensitive helpers)
ltrim    <- function(x) sub("^[[:space:]]+", "", x)
norm_ws  <- function(x) gsub("[[:space:]]+", " ", trimws(x))

## split a whitespace-delimited data line into tokens
toks <- function(x) strsplit(trimws(x), "[[:space:]]+")[[1]]

## Find the UNIQUE line index containing a fixed (whitespace-normalized) anchor.
find_anchor <- function(lines, anchor, expect_one = TRUE) {
  hits <- which(grepl(anchor, norm_ws(lines), fixed = TRUE))
  if (expect_one && length(hits) != 1)
    stop(sprintf("Anchor '%s' matched %d lines (expected 1).", anchor, length(hits)))
  hits
}

## First data line index at/after i for which is_data() is TRUE.
next_data <- function(lines, i, is_data) {
  while (i <= length(lines) && !is_data(lines[i])) i <- i + 1L
  i
}

## ---------------------------------------------------------------------------
## 3. gmacs.dat -- the GMACS control file (which .dat/.ctl/.prj to read)
## ---------------------------------------------------------------------------
## Model file names are DISCOVERED here, never hardcoded: the September model
## set is inconsistent (Models/25_gmacs uses "snow.dat" while
## Models/26_gmacs_update_newmat_plus_group uses
## "26_snow_update_newmat_plus_group.dat"), and file.copy() of a non-existent
## file returns FALSE without erroring -- which is how a peel could silently
## run on the wrong data.
##
## Returns: list(dir, obj, datafile, ctlfile, prjfile, retro_idx)
##   obj       raw-lines object for gmacs.dat (see read_raw_lines)
##   retro_idx index of the VALUE line following the "# Retrospective" anchor
read_gmacs_control <- function(model_dir) {
  path <- file.path(model_dir, "gmacs.dat")
  if (!file.exists(path)) stop("No gmacs.dat in ", model_dir)
  obj <- read_raw_lines(path)
  L   <- obj$lines

  ## The value for each key is the first non-comment, non-blank line after it.
  val_after <- function(pattern, label) {
    i <- which(grepl(pattern, L))
    if (length(i) != 1)
      stop(sprintf("gmacs.dat: '%s' matched %d lines (expected 1) in %s",
                   label, length(i), model_dir))
    j <- i + 1L
    while (j <= length(L) && (nchar(trimws(L[j])) == 0L || grepl("^[[:space:]]*#", L[j]))) j <- j + 1L
    if (j > length(L)) stop(sprintf("gmacs.dat: no value line after '%s' in %s", label, model_dir))
    list(idx = j, value = trimws(L[j]))
  }

  d <- val_after("^[[:space:]]*#[[:space:]]*datafile",       "#datafile")
  c <- val_after("^[[:space:]]*#[[:space:]]*controlfile",    "#controlfile")
  p <- val_after("^[[:space:]]*#[[:space:]]*projectionfile", "#projectionfile")
  r <- val_after("^[[:space:]]*#[[:space:]]*Retrospective",  "# Retrospective")
  j <- val_after("^[[:space:]]*#[[:space:]]*Jitter",         "# Jitter specs")

  ## The retro value must be a bare integer -- if the anchor ever drifts onto a
  ## different key we want a hard failure here, not a corrupted run.
  if (!grepl("^[0-9]+$", r$value))
    stop(sprintf("gmacs.dat: value after '# Retrospective' is '%s', expected an integer (%s)",
                 r$value, model_dir))

  ## Jitter line. THIS EXECUTABLE reads THREE values here, in FILE order
  ##     IsJittered   IsPin   sdJitter
  ##
  ## Do NOT infer the order from gmacs_files_in.dat: the echo prints IsPin
  ## BEFORE IsJittered, which is the opposite of the file order. Settled
  ## empirically against a real converged 2.20.34 jitter run in the sibling
  ## repo, snow_crab/Models/25_gmacs_update_hyb_surv_and_fsh_newmat/jitter/1/:
  ##     gmacs.dat  jitter line = "1 0 0.1"
  ##     gmacs_files_in.dat     = IsPin 0, IsJittered 1, sdJitter 0.1
  ##     jitter.txt             = 1776275167  (jittering genuinely happened)
  ## Field 1 = 1 produced IsJittered = 1, so field 1 is IsJittered, not IsPin.
  ##
  ## Note the gmacsbase.TPL shipped in the model folders (2.20.32b) declares
  ## only IsJittered + sdJitter and has no IsPin at all; it is NOT the source of
  ## gmacs.exe (2.20.34). We record the token count and never change it.
  jt <- toks(j$value)
  if (!length(jt) %in% c(2L, 3L))
    stop(sprintf("gmacs.dat: jitter line is '%s'; expected 2 or 3 numeric fields (%s)",
                 j$value, model_dir))
  if (any(is.na(suppressWarnings(as.numeric(jt)))))
    stop(sprintf("gmacs.dat: non-numeric jitter field in '%s' (%s)", j$value, model_dir))

  for (nm in c(d$value, c$value, p$value))
    if (!file.exists(file.path(model_dir, nm)))
      stop(sprintf("gmacs.dat names '%s' but that file is not in %s", nm, model_dir))

  list(dir = model_dir, obj = obj,
       datafile = d$value, ctlfile = c$value, prjfile = p$value,
       retro_idx = r$idx,
       jitter_idx = j$idx, jitter_fields = jt)
}

## Write gmacs.dat into out_dir.
##   n_peel  retrospective peel count (# Retrospective). NULL leaves it alone.
##   jitter  NULL leaves the jitter line alone; otherwise list(on=, sd=) --
##           only the IsJittered and sdJitter fields are rewritten, and the
##           field count is preserved exactly (so IsPin keeps its value on the
##           3-field layout "IsJittered IsPin sdJitter" this executable expects;
##           see read_gmacs_control). Writing a 2-token string into a 3-token
##           slot shifts every subsequent field in the file -- which is exactly
##           what the pre-2026 05_run_jitter.R did with its `"1 0.1"`.
## Every other byte of the file is preserved.
write_gmacs_control <- function(gc, out_dir, n_peel = NULL, jitter = NULL) {
  obj <- gc$obj

  if (!is.null(n_peel)) {
    stopifnot(is.numeric(n_peel), length(n_peel) == 1L, n_peel >= 0, n_peel == round(n_peel))
    obj$lines[gc$retro_idx] <- as.character(as.integer(n_peel))
  }

  if (!is.null(jitter)) {
    stopifnot(is.list(jitter), !is.null(jitter$on), !is.null(jitter$sd))
    f <- gc$jitter_fields
    if (length(f) == 3L) {
      f[1] <- as.character(as.integer(jitter$on))   # IsJittered
      ##   f[2] = IsPin -- left exactly as found
      f[3] <- as.character(jitter$sd)
    } else {
      f[1] <- as.character(as.integer(jitter$on))
      f[2] <- as.character(jitter$sd)
    }
    obj$lines[gc$jitter_idx] <- paste(f, collapse = " ")
  }

  write_raw_lines(obj, file.path(out_dir, "gmacs.dat"))
  invisible(file.path(out_dir, "gmacs.dat"))
}

## ---------------------------------------------------------------------------
## 4. snow.prj -- compensate GMACS's retrospective shift of spr_grow_yr
## ---------------------------------------------------------------------------
## WHY THIS EXISTS.
##
## In the gmacsbase.TPL shipped in the model folders (GMACS 2.20.32b):
##
##   TPL:4605  if (spr_grow_yr < syr) { ... exit(1); }      <- guard runs FIRST
##   TPL:4608  spr_grow_yr = spr_grow_yr - nyrRetroNo;      <- shift runs AFTER
##
## so the guard can never fire on the shifted value. snow.prj sets
## spr_grow_yr = 1982 (= syr), so peel p yields 1982 - p, which is BELOW syr.
## That value is then passed to calc_brute_equilibrium() as YrRef and used as
##   TPL:10675   if ( fhit(YrRef,j,k) )
## where fhit is dimensioned (syr, nyrRetro, 1, nseason, 1, nfleet) (TPL:795)
## -- an out-of-bounds read for every peel >= 1, affecting the equilibrium F
## matrix and hence BMSY / Fmsy / Fofl / OFL for that peel. The fitted MMB and
## recruitment series come out of the fit and are not affected.
##
## Every other .prj averaging window shifts safely (spr_nyr 2023, spr_aveF_nyr
## 2024, spr_M_nyr 2017, spr_Prop_nyr 2024, spr_sel_nyr 2024 all stay >= syr
## after subtracting up to 10). spr_grow_yr is the only one that underflows.
##
## !! IMPORTANT CAVEAT !!  That folder TPL is 2.20.32b (** TJ **, 2026-01-14)
## and is NOT the source of gmacs.exe, which reports 2.20.34 (** AEP **,
## 2026-01-15) and contains an IsPin field the folder TPL does not have. So the
## above describes a version adjacent to the executable, not the executable.
## 06_run_retrospective.R therefore MEASURES the effect (runs one peel with and
## without this compensation and compares BMSY/OFL) instead of assuming it.
##
## COMPENSATION: write spr_grow_yr = base + n_peel so GMACS's own subtraction
## lands it back exactly on the base model's value. This preserves the accepted
## model's specification rather than changing it.
set_prj_growth_year <- function(prj_path, n_peel, syr = 1982L, nyr = NULL) {
  stopifnot(is.numeric(n_peel), length(n_peel) == 1L, n_peel >= 0)
  obj <- read_raw_lines(prj_path)
  L   <- obj$lines

  ## Distinct from ".. growth for projections (0=last year)" further down the
  ## file; find_anchor() asserts the match is unique.
  i <- find_anchor(L, "# Year for specifying growth (0 = last year)")
  base <- suppressWarnings(as.integer(toks(L[i])[1]))
  if (is.na(base))
    stop("snow.prj: could not read the spr_grow_yr value from: ", L[i])
  if (base == 0L)
    stop("snow.prj: spr_grow_yr is 0 (= last year). GMACS resolves 0 to nyr ",
         "before the retro shift, so no compensation is needed -- but this ",
         "function assumes an explicit year. Review before proceeding.")

  new <- base + as.integer(n_peel)
  if (new < syr) stop(sprintf("spr_grow_yr %d would be below syr %d", new, syr))
  if (!is.null(nyr) && new > nyr)
    stop(sprintf("spr_grow_yr %d would exceed nyr %d (peel %d)", new, nyr, n_peel))

  ## replace the leading integer only; keep the tab padding + comment verbatim
  L[i] <- sub("^([[:space:]]*)[0-9]+", paste0("\\1", new), L[i])
  obj$lines <- L
  write_raw_lines(obj, prj_path)

  ## read back and confirm
  chk <- suppressWarnings(as.integer(toks(read_raw_lines(prj_path)$lines[i])[1]))
  if (!identical(chk, new))
    stop(sprintf("snow.prj: wrote spr_grow_yr=%d but read back %s", new, chk))
  invisible(c(base = base, written = new))
}

## ---------------------------------------------------------------------------
## 5. Gmacsall.out parsers
## ---------------------------------------------------------------------------
## Shared block reader: returns the character lines between a unique block
## header and the next ">EOD<" terminator. No fixed line window -- the original
## 06_run_retrospective.R used tmp[(st+1):(st+50)], which silently truncates
## once the model gains years.
.gmacsall_block <- function(lines, header) {
  st <- which(trimws(lines) == header)
  if (length(st) != 1L)
    stop(sprintf("Gmacsall.out: '%s' matched %d lines (expected 1)", header, length(st)))
  eod <- which(grepl(">EOD<", lines, fixed = TRUE))
  eod <- eod[eod > st]
  if (!length(eod)) stop(sprintf("Gmacsall.out: no '>EOD<' after '%s'", header))
  lines[(st + 1L):(eod[1] - 1L)]
}

## Parse the "Summary: dataframe" block -> data.frame.
## Columns Year, SSB, Recruit_male, Recruit_female are unique; the header also
## contains repeated names (log(Recruits) appears twice), so names are passed
## through make.unique().
read_gmacsall_summary <- function(path) {
  if (!file.exists(path)) stop("No Gmacsall.out at ", path)
  L   <- readLines(path, warn = FALSE)
  blk <- .gmacsall_block(L, "Summary: dataframe")
  if (length(blk) < 2L) stop("Gmacsall.out: empty summary block in ", path)

  nms  <- toks(blk[1])
  nms  <- make.unique(nms)
  rows <- lapply(blk[-1], function(x) suppressWarnings(as.numeric(toks(x))))

  ncols <- vapply(rows, length, integer(1))
  if (any(ncols != length(nms)))
    stop(sprintf("Gmacsall.out: %d summary row(s) have != %d fields in %s",
                 sum(ncols != length(nms)), length(nms), path))

  df <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
  names(df) <- nms

  if (!all(c("Year", "SSB") %in% nms))
    stop("Gmacsall.out summary block is missing Year and/or SSB in ", path)
  if (anyNA(df$Year) || anyNA(df$SSB))
    stop("Gmacsall.out: NA in the Year or SSB column of ", path)
  df$Year <- as.integer(round(df$Year))
  if (nrow(df) > 1L && !all(diff(df$Year) == 1L))
    stop("Gmacsall.out: Year column is not a contiguous 1-year run in ", path)

  df
}

## Parse the "--Derived quatities: dataframe" block (GMACS spells it that way)
## -> data.frame(parameter, estimate, std_error). Rows look like:
##    BMSY : 177.60767282 7.08498159 411
read_gmacsall_refpoints <- function(path) {
  if (!file.exists(path)) stop("No Gmacsall.out at ", path)
  L   <- readLines(path, warn = FALSE)
  blk <- .gmacsall_block(L, "--Derived quatities: dataframe")
  blk <- blk[grepl(":", blk, fixed = TRUE)]
  if (!length(blk)) stop("Gmacsall.out: no derived-quantity rows in ", path)

  nm  <- trimws(sub(":.*$", "", blk))
  rest <- lapply(blk, function(x) suppressWarnings(as.numeric(toks(sub("^.*?:", "", x)))))

  out <- data.frame(
    parameter = nm,
    estimate  = vapply(rest, function(z) if (length(z) >= 1L) z[1] else NA_real_, numeric(1)),
    std_error = vapply(rest, function(z) if (length(z) >= 2L) z[2] else NA_real_, numeric(1)),
    stringsAsFactors = FALSE
  )
  if (anyNA(out$estimate))
    stop("Gmacsall.out: unparseable derived-quantity row(s) in ", path)
  out
}

## Convenience: named vector lookup over read_gmacsall_refpoints().
refpoint <- function(rp, parameter) {
  i <- which(rp$parameter == parameter)
  if (length(i) != 1L) return(NA_real_)
  rp$estimate[i]
}

## ---------------------------------------------------------------------------
## 6. Run diagnostics
## ---------------------------------------------------------------------------
## gmacs.par line 1, e.g.
##   # Number of parameters = 407 Objective function value = -19222.489
##     Maximum gradient component = 0.00146008294554266
read_par_header <- function(model_dir) {
  path <- file.path(model_dir, "gmacs.par")
  if (!file.exists(path)) return(list(npar = NA_integer_, nll = NA_real_, max_grad = NA_real_))
  h <- readLines(path, n = 1L, warn = FALSE)
  num <- function(pat) {
    m <- regmatches(h, regexpr(pat, h))
    if (!length(m)) return(NA_real_)
    suppressWarnings(as.numeric(sub(pat, "\\1", m)))
  }
  list(
    npar     = as.integer(num("Number of parameters = ([0-9]+)")),
    nll      = num("Objective function value = (-?[0-9.eE+-]+)"),
    max_grad = num("Maximum gradient component = (-?[0-9.eE+-]+)")
  )
}

## GMACS echoes the data it ACTUALLY used to gmacs_in.dat. Reading the peel
## structure back from that file verifies the run independently of what we
## think we asked for.
##   "2024 # End year (retro)"          -> terminal model year
##   "# 86 4 2025 1 4 1 1 116.5 ..."    -> survey index rows kept (field 3 = year)
read_gmacs_echo <- function(model_dir) {
  path <- file.path(model_dir, "gmacs_in.dat")
  if (!file.exists(path)) return(list(end_year = NA_integer_, last_survey_year = NA_integer_))
  L <- readLines(path, warn = FALSE)

  ey <- L[grepl("# End year \\(retro\\)", L)]
  end_year <- if (length(ey) >= 1L) suppressWarnings(as.integer(toks(ey[1])[1])) else NA_integer_

  sv <- L[grepl("^#[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]{4}[[:space:]]", L)]
  yrs <- suppressWarnings(as.integer(vapply(sv, function(x) toks(sub("^#", "", x))[3], character(1))))
  yrs <- yrs[!is.na(yrs)]

  list(end_year         = end_year,
       last_survey_year = if (length(yrs)) max(yrs) else NA_integer_)
}

## ---------------------------------------------------------------------------
## 7. Parallel worker budget
## ---------------------------------------------------------------------------
## Each parallel worker is a full ADMB process: one CPU core pinned at 100% for
## the whole fit, plus a ~700 MB cmpdiff.tmp. On a mobile workstation (the
## Precision 5690 / Core Ultra 9 185H this is run on, 16 physical / 22 logical
## cores) a wide fan-out draws more sustained package power than the chassis can
## shed, and the machine HARD-RESETS mid-run -- which corrupts whatever peel or
## jitter directory was being written (2026-08, per Grant).
##
## So the budget is a small fixed default, NOT detectCores(). Raise it only on a
## machine known to sustain it, via the env var or the scripts' --cores flag:
##   $env:GMACS_MAX_WORKERS = 8      # PowerShell, this session only
gmacs_max_workers <- function(default = 4L) {
  v <- suppressWarnings(as.integer(Sys.getenv("GMACS_MAX_WORKERS", "")))
  n <- if (is.na(v) || v < 1L) as.integer(default) else v
  ## Never exceed the machine: detectCores() is the ceiling, not the target.
  max(1L, min(n, parallel::detectCores()))
}

## ---------------------------------------------------------------------------
## 8. Executable naming and exit conventions, per platform
## ---------------------------------------------------------------------------
## The model dirs carry BOTH binaries: gmacs.exe (Windows, the one that produced
## every fit currently in Models/) and gmacs (macOS arm64, built 2026-08 from
## GMACs/GMACS_tpl-cpp_code via compile_gmacs_mac.sh). Same GMACS version,
## 2.20.34 ** AEP **. They do NOT give the same answer -- see the divergence
## note below -- so the platform must never be guessed.
is_windows <- function() .Platform$OS.type == "windows"

gmacs_exe_name <- function() if (is_windows()) "gmacs.exe" else "gmacs"

## ADMB derives its output file names from argv[0], so the executable is always
## invoked from INSIDE the run directory. On Unix a bare "gmacs" would be looked
## up on PATH, not in the working directory, and system2() would silently run
## nothing at all -- hence the explicit "./".
gmacs_exe_call <- function(name = gmacs_exe_name())
  if (is_windows()) name else file.path(".", name)

## The macOS ADMB debug build (admb -g, matching make_win.bat) reports the
## floating-point exception flags it accumulated, then aborts with status 134 --
## AFTER the model has finished and written every output file. Measured
## 2026-08-24 on the 26 model: run completes in 8m32s, gmacs.std / gmacs.rep /
## gmacs.rep1 / personal.rep / checkfile.rep / Gmacsall.std all have line counts
## identical to the Windows run, and the sdreport quantities are populated.
##
## These three messages are therefore benign teardown noise, NOT a failed fit.
## Any OTHER "Error" line is a real failure and must still fail the run.
GMACS_FP_TEARDOWN_MSGS <- c("Error: Detected division by zero.",
                            "Error: Detected invalid argument.",
                            "Error: Detected underflow.")

## GMACS prints this only after the optimiser and the sd phase have both run.
GMACS_FINISH_MARKER <- "--Number of function evaluations:"

## TRUE when a non-zero exit is only the macOS teardown abort described above.
## Deliberately strict: the finish banner must be present AND every error line
## in the log must be one of the three known messages.
is_benign_gmacs_exit <- function(status, out) {
  if (is_windows() || identical(as.integer(status), 0L)) return(FALSE)
  if (!any(grepl(GMACS_FINISH_MARKER, out, fixed = TRUE))) return(FALSE)
  errs <- grep("Error", out, value = TRUE, fixed = TRUE)
  length(errs) > 0L && all(trimws(errs) %in% GMACS_FP_TEARDOWN_MSGS)
}

## ---------------------------------------------------------------------------
## 9. ADMB scratch files
## ---------------------------------------------------------------------------
## ADMB leaves cmpdiff.tmp behind, and for this model it is 620 MB -- a finished
## run directory is 637 MB, of which only ~17 MB is real output. Left in place
## that is ~62 GB across a 100-run jitter and ~14 GB across a 22-run peel sweep,
## none of it ever read again.
##
## Safe to delete once the process has exited: these files are regenerated by
## every run and are never inputs. prepare_run_dir() in R/gmacs_jitter.R already
## treats them as disposable when it stages a directory; both drivers now also
## purge them as each run finishes, so the space comes back immediately instead
## of accumulating across a sweep.
##
## Lives here rather than in R/gmacs_jitter.R so 05 and 06 share one definition
## (2026-08-27, per Grant).
GMACS_SCRATCH_PATTERN <- "[.]tmp$"

purge_gmacs_scratch <- function(run_dir) {
  f <- list.files(run_dir, pattern = GMACS_SCRATCH_PATTERN, full.names = TRUE)
  if (length(f)) unlink(f)
  invisible(length(f))
}

## ---------------------------------------------------------------------------
## 10. Seeding a retrospective peel from the accepted fit
## ---------------------------------------------------------------------------
## Split a GMACS .par/.pin into named blocks. Line 1 is the run header; the rest
## alternates "# name:" with that block's values, which may wrap over lines.
read_par_blocks <- function(path) {
  L <- readLines(path, warn = FALSE)
  h <- grep("^#", L)
  ## Drop the run header ONLY when it is actually there. A .par written by ADMB
  ## opens with "# Number of parameters = ..."; a .pin we write ourselves does
  ## not, and dropping its first line unconditionally would swallow the first
  ## parameter block and shift every later one by one position.
  h <- h[!grepl("^#[[:space:]]*Number of parameters", L[h])]
  out <- vector("list", length(h))
  nm  <- sub("^#[[:space:]]*", "", L[h])
  for (i in seq_along(h)) {
    from <- h[i] + 1L
    to   <- if (i < length(h)) h[i + 1L] - 1L else length(L)
    v <- if (to >= from) toks(paste(L[from:to], collapse = " ")) else character(0)
    out[[i]] <- v
  }
  names(out) <- nm
  out
}

## Build a peel's gmacs.pin from the accepted fit's gmacs.par.
##
## A peel estimates FEWER parameters than its parent (412, then 407, 402 ... 366),
## because year-indexed blocks lose their most recent entries. ADMB reads a .pin
## POSITIONALLY, so handing a peel the parent's full-length vector would misalign
## every block after the first short one -- and the optimiser would still
## converge somewhere, silently, which is the failure mode this repo fears most.
##
## Five blocks shrink: rec_dev_est, logit_rec_prop_est, log_fdev[1], log_fdev[2],
## log_fdov[1]. Two of them do NOT shrink by the peel depth: the directed fishery
## was closed in crab years 2022 and 2023 (they are absent from
## data/derived/directed_catch.csv), so those years never carried an F deviation
## and removing them removes no parameter. Peel 5 drops five years but only three
## log_fdev[1] entries (42 -> 39).
##
## So the lengths are never inferred here. Each block is truncated to the length
## GMACS ITSELF used for that peel, read from `shape_par` -- a .par written by an
## earlier unpinned run of the same peel and mode. Leading elements are kept:
## the blocks are chronological and peeling removes the most recent years.
##
## Verified 2026-08-27 against all 22 cold-start peels of the 26 model.
write_peel_pin <- function(base_par, shape_par, dest_pin) {
  b <- read_par_blocks(base_par)
  s <- read_par_blocks(shape_par)

  if (!identical(names(b), names(s)))
    stop("Parameter blocks differ between\n  ", base_par, "\nand\n  ", shape_par,
         "\nThese must be the same model. Blocks only in the fit: ",
         paste(setdiff(names(b), names(s)), collapse = ", "),
         "; only in the shape: ", paste(setdiff(names(s), names(b)), collapse = ", "))

  out <- sprintf("# gmacs.pin written by write_peel_pin() from %s, shaped by %s",
                 basename(base_par), basename(shape_par))
  for (nm in names(b)) {
    want <- length(s[[nm]])
    have <- length(b[[nm]])
    if (want > have)
      stop(sprintf("Block '%s' needs %d values but the accepted fit has only %d. ",
                   nm, want, have),
           "The shape file is not a peel of this fit.")
    out <- c(out, paste0("# ", nm), paste(utils::head(b[[nm]], want), collapse = " "))
  }
  writeLines(out, dest_pin)

  ## ADMB errors on a total-count mismatch, but check here so the failure names
  ## the block rather than surfacing as an opaque ADMB abort mid-sweep.
  n_out <- sum(vapply(read_par_blocks(dest_pin), length, integer(1)))
  n_exp <- sum(vapply(s, length, integer(1)))
  if (!identical(n_out, n_exp))
    stop(sprintf("Wrote %d values to %s but the peel expects %d.",
                 n_out, dest_pin, n_exp))
  invisible(n_out)
}
