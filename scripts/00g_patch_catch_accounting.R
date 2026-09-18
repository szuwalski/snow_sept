#!/usr/bin/env Rscript
## ============================================================================
## 00g_patch_catch_accounting.R
##
## Applies the 2026-09-17 catch-accounting correction to an EXISTING model
## .dat in place, touching only the male discard and bycatch catch frames.
##
## WHY NOT 00_advance_model.R: 00 regenerates every block from data/derived
## (indices, comps, growth, molt probability). For the May-era models (25.3,
## 26.1, 26.1a) that would replace the survey data and binning they exist to
## contrast, and for 25.3 and 26.1 the catch series is the 2025 ADF&G vintage,
## which the current derived files no longer reproduce. This script therefore
## applies the correction as a DELTA to whatever catch series the model has:
##
##   discard_male[y] <- discard_male[y] + inc_retained_wt[y] / 1000
##       (the directed discard was total minus TOTAL retention; the directed
##        total never contained the incidentally retained crab, so the discard
##        was low by exactly inc_retained_wt)
##   bycatch[y]      <- bycatch[y] - 0.3 * inc_retained_wt[y] / 1000
##       (the other-crab-fishery pool was 0.3 x total catch, which counted the
##        retained crab a second time at 30 percent; they belong in the retained
##        series only)
##   retained, female discard: unchanged
##
## inc_retained_wt comes from data/new_catch/retained_catch.csv (NA -> 0, which
## is 1989-2004). For a model whose catch frames equal the pre-correction derived
## series (the September models), the result is identical to rebuilding the
## frames through 00 from the corrected derived files; the check at the end
## reports whether that holds for the model given.
##
## Usage:
##   Rscript scripts/00g_patch_catch_accounting.R <model_dir> [--dry-run]
##
## Idempotent: a marker comment is written above the discard frame and the
## script refuses to run twice. The original .dat is kept as <name>.pre_catchfix.
## ============================================================================
options(warn = 1)
source("R/gmacs_io.R")

args    <- commandArgs(trailingOnly = TRUE)
DRY     <- "--dry-run" %in% args
args    <- setdiff(args, "--dry-run")
if (length(args) != 1) stop("Usage: Rscript scripts/00g_patch_catch_accounting.R <model_dir> [--dry-run]")
MODEL_DIR <- args[1]
stopifnot(dir.exists(MODEL_DIR))

MARKER <- "## catch accounting patched 2026-09-17 by 00g_patch_catch_accounting.R (discard + inc_retained; bycatch - 0.3*inc_retained)"

## ---- incidental retention by crab year (t) ---------------------------------
ret_cat <- read.csv("data/new_catch/retained_catch.csv")
inc_t   <- setNames(ifelse(is.na(ret_cat$inc_retained_wt), 0, ret_cat$inc_retained_wt),
                    ret_cat$crab_year)
inc_t   <- inc_t[inc_t > 0]
cat(sprintf("incidental retention in %d crab years: %s\n", length(inc_t),
            paste(names(inc_t), collapse = " ")))

## ---- locate the .dat through gmacs.dat --------------------------------------
gc  <- read_gmacs_control(MODEL_DIR)
DAT <- file.path(MODEL_DIR, gc$datafile)
stopifnot(file.exists(DAT))
obj <- read_raw_lines(DAT)
L   <- obj$lines
if (any(grepl(MARKER, L, fixed = TRUE))) stop(DAT, " already carries the patch marker; nothing done.")

## ---- catch-frame rows: "year seas fleet sex obs cv type units mult effort dm"
is_row <- function(l) {
  t <- strsplit(trimws(l), "[[:space:]]+")[[1]]
  length(t) == 11 && grepl("^[0-9]{4}$", t[1])
}
tok <- function(l) strsplit(trimws(l), "[[:space:]]+")[[1]]

i_disc <- find_anchor(L, "## Male discard pot fishery")
i_byc  <- find_anchor(L, "## Bycatch from all")

## rows of a frame: consecutive data rows after the header, comment lines skipped
frame_rows <- function(start) {
  i <- start + 1L; out <- integer(0)
  while (i <= length(L)) {
    l <- L[i]
    if (grepl("^[[:space:]]*##", l)) break
    if (is_row(l)) out <- c(out, i)
    i <- i + 1L
  }
  out
}
r_disc <- frame_rows(i_disc)
r_byc  <- frame_rows(i_byc)
stopifnot(length(r_disc) > 0, length(r_byc) > 0)
## frame identity checks: discard frame is fleet 1 / male / type 2; bycatch is fleet 2
stopifnot(all(vapply(L[r_disc], function(l) all(tok(l)[c(3, 4, 7)] == c("1", "1", "2")), TRUE)),
          all(vapply(L[r_byc],  function(l) tok(l)[3] == "2", TRUE)))

## ---- apply the delta, replacing the 5th token only ---------------------------
fmt <- function(x) sub("\\.?0+$", "", formatC(x, digits = 10, format = "f"))
patch_rows <- function(rows, delta_kt, label) {
  log <- data.frame()
  for (i in rows) {
    t <- tok(L[i]); y <- t[1]
    if (!(y %in% names(delta_kt))) next
    old <- as.numeric(t[5]); new <- old + delta_kt[[y]]
    stopifnot(new >= 0)
    ## replace the obs token in place, keeping the line's own spacing.
    ## ONE backslash in the escape: with fixed = TRUE the replacement is taken
    ## literally, so "\\\\." would put 2 backslashes into the pattern and it
    ## would look for a literal backslash and never match (2026-09-17).
    L[i] <<- sub(paste0("^(\\s*", y, "\\s+\\S+\\s+\\S+\\s+\\S+\\s+)", gsub(".", "\\.", t[5], fixed = TRUE), "(\\s)"),
                 paste0("\\1", fmt(new), "\\2"), L[i], perl = TRUE)
    stopifnot(tok(L[i])[5] == fmt(new))
    log <- rbind(log, data.frame(frame = label, year = as.integer(y), old = old, new = new))
  }
  log
}
log_d <- patch_rows(r_disc, inc_t / 1000, "discard_male")
log_b <- patch_rows(r_byc, -0.3 * inc_t / 1000, "bycatch")
log   <- rbind(log_d, log_b)
print(log, row.names = FALSE, digits = 7)

## every year with incidental retention that has a row in a frame must have moved
## (the discard frame has no rows for the 2022/23 and 2023/24 closures, while the
## bycatch frame does; 2022 carries 5 kg of incidental retention)
frame_years <- function(rows) as.integer(vapply(L[rows], function(l) tok(l)[1], ""))
stopifnot("a year with incidental retention was not patched in the discard frame" =
            setequal(log_d$year, intersect(as.integer(names(inc_t)), frame_years(r_disc))),
          "a year with incidental retention was not patched in the bycatch frame" =
            setequal(log_b$year, intersect(as.integer(names(inc_t)), frame_years(r_byc))))

## ---- cross-check against the corrected derived series (informational) -------
if (file.exists("data/derived/directed_catch.csv") && file.exists("data/derived/bycatch_catch.csv")) {
  dc <- read.csv("data/derived/directed_catch.csv"); bc <- read.csv("data/derived/bycatch_catch.csv")
  md <- merge(log_d, dc, by = "year"); mb <- merge(log_b, bc, by = "year")
  ok_d <- all(abs(md$new - md$discard_male)  < 1e-6)
  ok_b <- all(abs(mb$new - mb$total_bycatch) < 1e-6)
  cat(sprintf("\npatched discard frame %s the corrected data/derived series; bycatch frame %s.\n",
              if (ok_d) "REPRODUCES" else "differs from (expected for a 2025-vintage catch series)",
              if (ok_b) "REPRODUCES" else "differs from (expected for a 2025-vintage catch series)"))
}

if (DRY) { cat("\n--dry-run: nothing written.\n"); quit(status = 0) }

## ---- write: backup, marker, file -------------------------------------------
bak <- paste0(DAT, ".pre_catchfix")
stopifnot(file.copy(DAT, bak, overwrite = FALSE))
L <- append(L, MARKER, after = i_disc - 1L)
obj$lines <- L
write_raw_lines(obj, DAT)
cat(sprintf("\nwrote %s (original kept as %s)\n", DAT, basename(bak)))
