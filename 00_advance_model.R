#!/usr/bin/env Rscript
## ============================================================================
## 00_advance_model.R
##
## Writes the CLEAN derived data (produced by 01_prep_fishery_data.R and
## 02_prep_survey_data.R) into a GMACS (ADMB) snow-crab model's .dat and .ctl
## files, replacing an error-prone manual copy/paste.
##
## Strategy: ANCHORED BLOCK REPLACEMENT (not full-regenerate). The template
## .dat/.ctl are read as raw bytes (line endings + non-ASCII comment glyphs
## preserved). Each data block is located by its stable "#"/"##" comment
## header; the block body is replaced by rows built from the derived CSVs
## (values in MODEL UNITS, written verbatim as read -> no precision loss); the
## row-count declaration lines are recomputed from the emitted rows.
##
## Historical rows the derived files do NOT cover (e.g. pre-1990 catch and
## retained size comps for 1982-1989) are PRESERVED byte-for-byte from the
## template. Only the years the derived files provide are overlaid/appended.
##
## One knob: END_YEAR (model end year). Fishery data through crab-year
## END_YEAR; survey data through END_YEAR + 1.
##
## Usage:
##   Rscript 00_advance_model.R <template_dir> <out_dir> <end_year> <out_dat_name> \
##                              [growth_fix=TRUE] [repo_root] [survey_end]
##
## survey_end (arg 7, default END_YEAR + 1) cuts the SURVEY DATA short without
## touching the fishery data or the .CTL structure. Used by
## 06_run_retrospective.R to build the "drop terminal survey" retrospective:
## peel p wants fishery <= END_YEAR but survey <= END_YEAR - p. It affects the
## .DAT index and survey size-comp blocks ONLY. The .CTL time blocks and the
## molt-probability matrix stay pinned to END_YEAR + 1 (CTL_END), because a
## GMACS retrospective never rewrites the .CTL -- it clamps over-long blocks
## itself (gmacsbase.TPL:1499-1500) and auto-shifts the last rec_dev
## (gmacsbase.TPL:1632).
##
## Always regenerates out_dir fresh from template_dir (idempotent).
## ============================================================================

options(warn = 1)

## ---------------------------------------------------------------------------
## 0. Arguments
## ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4)
  stop("Usage: Rscript 00_advance_model.R <template_dir> <out_dir> <end_year> <out_dat_name> ",
       "[growth_fix=TRUE] [repo_root] [survey_end]")

TEMPLATE_DIR <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
OUT_DIR      <- args[2]
END_YEAR     <- as.integer(args[3])
OUT_DAT_NAME <- args[4]
## growth_fix (arg 5, default TRUE): TRUE -> fix the 26.3 mm '73'->'7.3' transcription
## typo in the template growth block; FALSE -> keep the template growth verbatim (73).
## A toggle so we can build 2025 sensitivities with vs without the growth-data fix.
GROWTH_FIX   <- if (length(args) >= 5) toupper(args[5]) %in% c("TRUE", "T", "YES", "1") else TRUE
REPO_ROOT    <- if (length(args) >= 6) normalizePath(args[6], winslash = "/", mustWork = TRUE) else
                normalizePath(getwd(), winslash = "/", mustWork = TRUE)

## CTL_END fixes the .CTL structure (time blocks, molt-probability matrix rows).
## SURVEY_END cuts the .DAT survey DATA and defaults to the same value; only the
## "drop terminal survey" retrospective passes something smaller.
## male_only (arg 8, default FALSE): build the MALE-ONLY sensitivity -- nsex = 1,
## with every female data frame/matrix/index dropped from the .DAT and every
## sex-paired block halved in the .CTL.
##
## Fixing female PHASES is not enough and does not give a male-only model. Two
## couplings survive it (gmacsbase.TPL 2.20.34, verified 2026-08-27):
##   * :8600-8602 -- a combined-sex (sex = 0) catch observation is predicted by
##     summing over BOTH sexes, so the female population still drives the
##     residual on the 44 sex-0 bycatch rows, hence F, hence male mortality.
##   * logRbar and rec_dev are NOT sex-indexed, so female likelihood
##     contributes gradient to the shared recruitment scale and deviations.
## Only nsex = 1 removes the female population, and GMACS then disables the
## sex-ratio parameter itself (:1653) and drops the recruitment split (:8424).
MALE_ONLY <- if (length(args) >= 8) toupper(args[8]) %in% c("TRUE", "T", "YES", "1") else FALSE

## Which frames/matrices/indices survive the male-only reduction. Positions are
## into the TEMPLATE's declared order; every count line is rewritten from these.
##   catch  1 retained male, 2 discard male, 3 discard FEMALE, 4 bycatch (sex 0)
##   comps  1 ret male, 2 tot male, 3 disc FEM, 4 trawl FEM, 5 trawl male,
##          6/7 FEM immature e1/e2, 8/9 male immature e1/e2,
##          10/11 FEM mature e1/e2, 12/13 male mature e1/e2
##   index  1/2 FEMALE era1/era2, 3/4 male era1/era2
MO_KEEP_CATCH <- c(1L, 2L, 4L)
MO_KEEP_COMP  <- c(1L, 2L, 5L, 8L, 9L, 12L, 13L)
MO_KEEP_INDEX <- c(3L, 4L)

CTL_END    <- END_YEAR + 1L   # crab-year convention: end-year N -> N+1 summer survey
SURVEY_END <- if (length(args) >= 7) as.integer(args[7]) else CTL_END
if (is.na(SURVEY_END)) stop("survey_end (arg 7) is not an integer: ", args[7])
if (SURVEY_END > CTL_END)
  stop(sprintf("survey_end (%d) cannot exceed end_year+1 (%d)", SURVEY_END, CTL_END))
if (SURVEY_END < 1989L)
  stop(sprintf("survey_end (%d) is before the era-2 survey start (1989)", SURVEY_END))

## Shared GMACS file I/O (raw-bytes readers, anchor helpers). Also sourced by
## 06_run_retrospective.R -- one parser, not two.
GMACS_IO <- file.path(REPO_ROOT, "R", "gmacs_io.R")
if (!file.exists(GMACS_IO))
  stop("Cannot find R/gmacs_io.R under repo_root '", REPO_ROOT,
       "'. Run from the snow_sept repo root or pass repo_root as arg 6.")
source(GMACS_IO)

DERIVED <- file.path(REPO_ROOT, "data", "derived")
GROWTHD <- file.path(REPO_ROOT, "data", "growth")

cat(sprintf("\n=== 00_advance_model.R ===\n"))
cat(sprintf("template_dir : %s\n", TEMPLATE_DIR))
cat(sprintf("out_dir      : %s\n", OUT_DIR))
cat(sprintf("end_year     : %d  (fishery<=%d, survey<=%d)\n", END_YEAR, END_YEAR, SURVEY_END))
if (SURVEY_END != CTL_END)
  cat(sprintf("               DROP-SURVEY build: survey cut %d yr short of end_year+1 (%d)\n",
              CTL_END - SURVEY_END, CTL_END))
cat(sprintf("out_dat_name : %s\n", OUT_DAT_NAME))
cat(sprintf("growth_fix   : %s\n", GROWTH_FIX))
cat(sprintf("derived dir  : %s\n\n", DERIVED))

TEMPLATE_DAT <- list.files(TEMPLATE_DIR, pattern = "\\.dat$", full.names = TRUE)
TEMPLATE_DAT <- TEMPLATE_DAT[grepl("snow", basename(TEMPLATE_DAT), ignore.case = TRUE)]
TEMPLATE_DAT <- TEMPLATE_DAT[!grepl("gmacs", basename(TEMPLATE_DAT), ignore.case = TRUE)]
if (length(TEMPLATE_DAT) != 1)
  stop("Could not uniquely identify the template model .dat in ", TEMPLATE_DIR,
       " (found: ", paste(basename(TEMPLATE_DAT), collapse = ", "), ")")
TEMPLATE_CTL   <- file.path(TEMPLATE_DIR, "snow.ctl")
TEMPLATE_GMACS <- file.path(TEMPLATE_DIR, "gmacs.dat")
stopifnot(file.exists(TEMPLATE_CTL), file.exists(TEMPLATE_GMACS))

## ---------------------------------------------------------------------------
## 1. Raw line I/O + anchor helpers
## ---------------------------------------------------------------------------
## read_raw_lines / write_raw_lines / ltrim / norm_ws / find_anchor / next_data
## / toks now live in R/gmacs_io.R (sourced in section 0) so that this script
## and 06_run_retrospective.R share one implementation.

## ---------------------------------------------------------------------------
## 2. is_data classifiers for each block type
## ---------------------------------------------------------------------------
is_catch    <- function(x) grepl("^[[:space:]]*[0-9]{4}[[:space:]]", x)
is_index    <- function(x) grepl("^[[:space:]]*[0-9]+[[:space:]]+[0-9]{4}[[:space:]]", x)
is_sizecomp <- function(x) grepl("^[[:space:]]*[0-9]{4}[[:space:]]", x)
is_growth   <- function(x) grepl("^[[:space:]]*[0-9]", x)   # premolt (e.g. 25.2) ; comments start with '#'

## ---------------------------------------------------------------------------
## 3. Generic region parser + rebuilder  (COUNT-driven, mirrors gmacs_model_r).
##    A region begins with a count-declaration line and holds K "matrices"
##    (frames/series). Matrix boundaries are defined by the DECLARED counts,
##    NOT by comments (e.g. survey era1/era2 matrices are contiguous with no
##    separator). Leading comment/blank lines before each matrix are preserved
##    verbatim; each matrix's data rows are replaced via a per-matrix builder;
##    the count line is recomputed from the emitted rows.
## ---------------------------------------------------------------------------
parse_by_counts <- function(lines, count_idx, old_counts, is_data) {
  ## Returns list(segs, end_idx, data_blocks). segs preserve order:
  ##   list(type="comment", lines=<chr>) | list(type="data", k=<int>, lines=<chr>)
  segs <- list(); data_blocks <- vector("list", length(old_counts))
  i <- count_idx + 1L; N <- length(lines)
  for (k in seq_along(old_counts)) {
    ## copy leading comment/blank lines
    while (i <= N && !is_data(lines[i])) {
      segs[[length(segs) + 1L]] <- list(type = "comment", lines = lines[i]); i <- i + 1L
    }
    ## read exactly old_counts[k] data rows (skip any interspersed comments defensively)
    rows <- character(0); need <- old_counts[k]
    while (length(rows) < need) {
      if (i > N) stop("Ran out of lines reading matrix ", k, " (need ", need, ")")
      if (is_data(lines[i])) { rows <- c(rows, lines[i]); i <- i + 1L }
      else { segs[[length(segs) + 1L]] <- list(type = "comment", lines = lines[i]); i <- i + 1L }
    }
    segs[[length(segs) + 1L]] <- list(type = "data", k = k, lines = rows)
    data_blocks[[k]] <- rows
  }
  list(segs = segs, end_idx = i - 1L, data_blocks = data_blocks)
}

rebuild_region <- function(lines, count_idx, is_data, run_builders, count_line_builder) {
  old_counts <- as.integer(toks(lines[count_idx]))
  K <- length(run_builders)
  if (length(old_counts) != K)
    stop(sprintf("count line declares %d values but %d builders supplied", length(old_counts), K))
  pr <- parse_by_counts(lines, count_idx, old_counts, is_data)
  new_runs <- vector("list", K)
  for (s in pr$segs) if (s$type == "data")
    new_runs[[s$k]] <- run_builders[[s$k]](s$lines)
  counts <- vapply(new_runs, length, integer(1))
  region <- count_line_builder(counts)
  for (s in pr$segs) {
    if (s$type == "comment") region <- c(region, s$lines)
    else                     region <- c(region, new_runs[[s$k]])
  }
  new_lines <- c(if (count_idx > 1) lines[1:(count_idx - 1L)] else character(0),
                 region,
                 if (pr$end_idx < length(lines)) lines[(pr$end_idx + 1L):length(lines)] else character(0))
  list(lines = new_lines, counts = counts)
}

## (toks() -- split a whitespace-delimited data line -- is defined in R/gmacs_io.R)

## ---------------------------------------------------------------------------
## 4. Load derived data (character = verbatim; convert to numeric only for keys)
## ---------------------------------------------------------------------------
rd <- function(f) read.csv(f, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
dc  <- rd(file.path(DERIVED, "directed_catch.csv"))     # year,retained_male,discard_male,discard_female
bc  <- rd(file.path(DERIVED, "bycatch_catch.csv"))      # year,trawl_bycatch,othercrab_bycatch,total_bycatch
fsc <- rd(file.path(DERIVED, "fishery_size_comps.csv")) # year,fleet,sex,type,m27.5..m132.5
ssc <- rd(file.path(DERIVED, "survey_size_comps.csv"))  # year,sex,maturity,m27.5..m132.5
si  <- rd(file.path(DERIVED, "survey_indices.csv"))     # year,sex,maturity,biomass,cv
og  <- rd(file.path(DERIVED, "male_maturity_ogive.csv"))# year,m27.5..m132.5
## growth: per Grant (2026-08) the model keeps the TEMPLATE .DAT's growth block
## (with one typo fixed), NOT growth_increments.csv -- see section 6d.

yr <- function(df) as.integer(df$year)

## year -> value(char) map for a single derived column, scoped to <= ymax
catch_map <- function(df, col, ymax) {
  y <- yr(df); keep <- y <= ymax
  setNames(df[[col]][keep], as.character(y[keep]))
}
## year -> 22 bin char-vector, for fishery comps filtered by fleet/sex/type
fcomp_map <- function(fleet, sex, type, ymax) {
  m <- fsc$fleet == fleet & fsc$sex == sex & fsc$type == type & as.integer(fsc$year) <= ymax
  sub <- fsc[m, , drop = FALSE]
  setNames(lapply(seq_len(nrow(sub)), function(r) as.character(sub[r, 5:26])),
           as.character(sub$year))
}
## year -> 22 bin char-vector, for survey comps filtered by sex/maturity/era
scomp_map <- function(sex, maturity, era, ymax) {
  m <- ssc$sex == sex & ssc$maturity == maturity & as.integer(ssc$year) <= ymax
  if (era == 1) m <- m & as.integer(ssc$year) <= 1988
  if (era == 2) m <- m & as.integer(ssc$year) >= 1989
  sub <- ssc[m, , drop = FALSE]
  setNames(lapply(seq_len(nrow(sub)), function(r) as.character(sub[r, 4:25])),
           as.character(sub$year))
}

## ---------------------------------------------------------------------------
## 5. Row builders
## ---------------------------------------------------------------------------
## Generic overlay of a single-value block (catch). template_lines are the
## original data rows of this run; dmap is year->obs(char). Historical template
## years NOT covered by the derived file (at all) are preserved verbatim.
## Per-year metadata picker: metadata columns (everything but year and the
## derived value) come from the template row of the SAME year when present, so
## per-year fields such as Nsamp are preserved (Nsamp is 10, not 100, in the
## closure-era 2021/2024/2025 discard-female rows). For a NEW year with no
## template precedent, use the first template row (year before the template
## range) or the last template row (otherwise) -- matching the 26 hand-edit's
## terminal-row metadata choice.
make_meta_picker <- function(template_lines) {
  tt  <- lapply(template_lines, toks)
  tyr <- vapply(tt, function(t) as.integer(t[1]), integer(1))
  tmeta <- setNames(tt, as.character(tyr))
  tline <- setNames(template_lines, as.character(tyr))
  first_meta <- tt[[which.min(tyr)]]; last_meta <- tt[[which.max(tyr)]]
  list(
    tyr = tyr, tline = tline,
    meta = function(y) {
      yk <- as.character(y)
      if (yk %in% names(tmeta)) tmeta[[yk]]
      else if (y < min(tyr)) first_meta else last_meta
    }
  )
}

## Overlay a single-value block (catch). dmap = year->obs(char). src_years =
## full year coverage of the derived source. Template years the derived source
## does NOT cover are kept verbatim (e.g. pre-1990 rows).
build_value_block <- function(template_lines, dmap, src_years, scope_max) {
  mp <- make_meta_picker(template_lines)
  hist_years <- mp$tyr[!(mp$tyr %in% src_years) & mp$tyr <= scope_max]
  keep_years <- sort(unique(c(hist_years, as.integer(names(dmap)))))
  out <- character(0)
  for (y in keep_years) {
    yk <- as.character(y)
    if (yk %in% names(dmap)) {
      m <- mp$meta(y)                              # y seas fleet sex obs cv type units mult effort dmr
      out <- c(out, paste(c(yk, m[2], m[3], m[4], dmap[[yk]], m[6], m[7], m[8], m[9], m[10], m[11]), collapse = "\t"))
    } else {
      out <- c(out, mp$tline[[yk]])                # verbatim historical row
    }
  }
  out
}
build_catch_directed <- function(template_lines, col, scope_max)
  build_value_block(template_lines, catch_map(dc, col, scope_max), as.integer(dc$year), scope_max)
build_catch_bycatch <- function(template_lines, scope_max)
  build_value_block(template_lines, catch_map(bc, "total_bycatch", scope_max), as.integer(bc$year), scope_max)

## size-comp block builder. dmap = year->22bins(char); metadata cols 2:8
## (seas fleet sex type shell maturity nsamp) preserved per-year via the picker.
build_comp_block <- function(template_lines, dmap, src_years, scope_max) {
  mp <- make_meta_picker(template_lines)
  hist_years <- mp$tyr[!(mp$tyr %in% src_years) & mp$tyr <= scope_max]
  keep_years <- sort(unique(c(hist_years, as.integer(names(dmap)))))
  out <- character(0)
  for (y in keep_years) {
    yk <- as.character(y)
    if (yk %in% names(dmap)) {
      stopifnot(length(dmap[[yk]]) == 22L)
      m <- mp$meta(y)                              # y seas fleet sex type shell maturity nsamp
      out <- c(out, paste(c(yk, m[2], m[3], m[4], m[5], m[6], m[7], m[8], dmap[[yk]]), collapse = "\t"))
    } else {
      out <- c(out, mp$tline[[yk]])
    }
  }
  out
}

## ---------------------------------------------------------------------------
## 6. Build the .dat
## ---------------------------------------------------------------------------
datobj <- read_raw_lines(TEMPLATE_DAT)
L <- datobj$lines

## --- 6.0 Model "End year" (top-of-file scalar) -> END_YEAR ------------------
## (Start year stays 1982; survey/molt blocks run to END_YEAR+1 by convention.)
ey <- which(grepl("#[[:space:]]*End[[:space:]]*year", L))
if (length(ey) != 1) stop("Could not uniquely find the '# End year' line in the .dat")
L[ey] <- sub("^[[:space:]]*[0-9]+", as.character(END_YEAR), L[ey])
sy <- which(grepl("#[[:space:]]*Start[[:space:]]*year", L))
if (length(sy) == 1 && as.integer(toks(L[sy])[1]) != 1982L)
  stop("Unexpected Start year in template .dat")

## --- 6a. Index block (full rebuild from survey_indices; both eras) ----------
## Learn per-series metadata from the template index rows.
idx_ci <- find_anchor(L, "Number of rows of index data")
idx_count_idx <- next_data(L, idx_ci + 1L, function(x) grepl("^[[:space:]]*[0-9]+[[:space:]]*($|#)", x))
## first index data row
idx_first <- next_data(L, idx_count_idx + 1L, is_index)
## collect template index rows to derive series metadata
jj <- idx_first; tmp_idx_rows <- character(0)
while (jj <= length(L) && is_index(L[jj])) { tmp_idx_rows <- c(tmp_idx_rows, L[jj]); jj <- jj + 1L }
idx_tok <- lapply(tmp_idx_rows, toks)   # Index Year Season Fleet Sex Mature Obs CV Units Timing RAI
idx_meta <- do.call(rbind, lapply(idx_tok, function(t)
  data.frame(Index = t[1], Season = t[3], Fleet = t[4], Sex = t[5], Mature = t[6],
             Units = t[9], Timing = t[10], RAI = t[11], stringsAsFactors = FALSE)))
idx_meta_u <- idx_meta[!duplicated(idx_meta$Index), ]
## map (sex-name, era) -> series metadata row of the template
lookup_series <- function(sexname, era) {
  target_sex   <- if (sexname == "female") "2" else "1"
  target_fleet <- if (era == 1) "3" else "4"
  m <- idx_meta_u[idx_meta_u$Sex == target_sex & idx_meta_u$Fleet == target_fleet, ]
  if (nrow(m) != 1) stop("Could not map index series for ", sexname, " era", era)
  m
}
build_index_rows <- function() {
  out <- character(0)
  ## order in the .dat: (female era1, female era2, male era1, male era2)
  for (spec in list(c("female", 1), c("female", 2), c("male", 1), c("male", 2))) {
    sexname <- spec[1]; era <- as.integer(spec[2])
    sub <- si[si$sex == sexname & si$maturity == "mature", , drop = FALSE]
    y   <- as.integer(sub$year)
    keep <- if (era == 1) y <= 1988 else (y >= 1989 & y <= SURVEY_END)
    sub <- sub[keep, , drop = FALSE]
    sub <- sub[order(as.integer(sub$year)), , drop = FALSE]
    m   <- lookup_series(sexname, era)
    for (r in seq_len(nrow(sub)))
      out <- c(out, paste(c(m$Index, sub$year[r], m$Season, m$Fleet, m$Sex, m$Mature,
                            sub$biomass[r], sub$cv[r], m$Units, m$Timing, m$RAI), collapse = "\t"))
  }
  out
}
rb <- rebuild_region(L, idx_count_idx, is_data = is_index,
                     run_builders = list(function(orig) build_index_rows()),
                     count_line_builder = function(counts) as.character(counts[1]))
L <- rb$lines
INDEX_COUNT <- rb$counts[1]

## --- 6b. Catch block (4 frames) --------------------------------------------
catch_ci <- find_anchor(L, "Number of rows in each data frame")
catch_count_idx <- next_data(L, catch_ci + 1L, function(x) grepl("^[[:space:]]*[0-9]", x))
catch_builders <- list(
  function(o) build_catch_directed(o, "retained_male",  END_YEAR),  # frame 1 retained male
  function(o) build_catch_directed(o, "discard_male",   END_YEAR),  # frame 2 discard male
  function(o) build_catch_directed(o, "discard_female", END_YEAR),  # frame 3 discard female
  function(o) build_catch_bycatch(o, END_YEAR)                      # frame 4 bycatch (all)
)
rb <- rebuild_region(L, catch_count_idx, is_data = is_catch,
                     run_builders = catch_builders,
                     count_line_builder = function(counts) paste(counts, collapse = "\t"))
L <- rb$lines
CATCH_COUNTS <- rb$counts

## --- 6c. Size-composition block (13 matrices) ------------------------------
sc_ci <- find_anchor(L, "Number of rows in each matrix")
sc_count_idx <- next_data(L, sc_ci + 1L, function(x) grepl("^[[:space:]]*[0-9]", x))
## derived source-year coverage per matrix (for historical-preservation test)
fsc_years <- function(fleet, sex, type)
  as.integer(fsc$year[fsc$fleet == fleet & fsc$sex == sex & fsc$type == type])
ssc_years <- function(sex, maturity, era) {
  y <- as.integer(ssc$year[ssc$sex == sex & ssc$maturity == maturity])
  if (era == 1) y[y <= 1988] else y[y >= 1989]
}
comp_builders <- list(
  function(o) build_comp_block(o, fcomp_map(1, 1, 1, END_YEAR),   fsc_years(1,1,1), END_YEAR),  # 1 retained males
  function(o) build_comp_block(o, fcomp_map(1, 1, 0, END_YEAR),   fsc_years(1,1,0), END_YEAR),  # 2 total males
  function(o) build_comp_block(o, fcomp_map(1, 2, 2, END_YEAR),   fsc_years(1,2,2), END_YEAR),  # 3 discard females
  function(o) build_comp_block(o, fcomp_map(2, 2, 2, END_YEAR),   fsc_years(2,2,2), END_YEAR),  # 4 trawl bycatch female
  function(o) build_comp_block(o, fcomp_map(2, 1, 2, END_YEAR),   fsc_years(2,1,2), END_YEAR),  # 5 trawl bycatch male
  function(o) build_comp_block(o, scomp_map("female","immature",1,SURVEY_END), ssc_years("female","immature",1), SURVEY_END), #6
  function(o) build_comp_block(o, scomp_map("female","immature",2,SURVEY_END), ssc_years("female","immature",2), SURVEY_END), #7
  function(o) build_comp_block(o, scomp_map("male","immature",1,SURVEY_END),   ssc_years("male","immature",1),   SURVEY_END), #8
  function(o) build_comp_block(o, scomp_map("male","immature",2,SURVEY_END),   ssc_years("male","immature",2),   SURVEY_END), #9
  function(o) build_comp_block(o, scomp_map("female","mature",1,SURVEY_END),   ssc_years("female","mature",1),   SURVEY_END), #10
  function(o) build_comp_block(o, scomp_map("female","mature",2,SURVEY_END),   ssc_years("female","mature",2),   SURVEY_END), #11
  function(o) build_comp_block(o, scomp_map("male","mature",1,SURVEY_END),     ssc_years("male","mature",1),     SURVEY_END), #12
  function(o) build_comp_block(o, scomp_map("male","mature",2,SURVEY_END),     ssc_years("male","mature",2),     SURVEY_END)  #13
)
rb <- rebuild_region(L, sc_count_idx, is_data = is_sizecomp,
                     run_builders = comp_builders,
                     count_line_builder = function(counts) paste(counts, collapse = "\t"))
L <- rb$lines
COMP_COUNTS <- rb$counts

## --- 6d. Growth block ------------------------------------------------------
gr_ci <- find_anchor(L, "nobs_growth")
gr_count_idx <- next_data(L, gr_ci + 1L, function(x) grepl("^[[:space:]]*[0-9]", x))
## Per Grant (2026-08): use the PREVIOUS .DAT's growth block (the template's 294
## rows) verbatim, NOT the 365-row master set -- but fix the single transcription
## typo: a 26.3 mm crab whose increment reads 73 (impossible) should read 7.3 (the
## specimen master has postmolt 33.6 -> increment 7.3). Minimal byte edit; every
## other growth row is preserved exactly.
fix_growth_typo <- function(orig) {
  if (!GROWTH_FIX) return(orig)   # keep the template growth verbatim (incl. the 73 typo)
  hit <- grepl("^[[:space:]]*26\\.3[[:space:]]+1[[:space:]]+73([[:space:]]|$)", orig)
  if (sum(hit) != 1L)
    stop(sprintf("growth typo-fix: expected exactly 1 row '26.3 1 73', found %d", sum(hit)))
  orig[hit] <- sub("([[:space:]])73([[:space:]]|$)", "\\17.3\\2", orig[hit])
  orig
}
rb <- rebuild_region(L, gr_count_idx, is_data = is_growth,
                     run_builders = list(function(orig) fix_growth_typo(orig)),
                     count_line_builder = function(counts) as.character(counts[1]))
L <- rb$lines
GROWTH_COUNT <- rb$counts[1]

datobj$lines <- L

## ---------------------------------------------------------------------------
## 6e. MALE-ONLY reduction of the .DAT  (no-op unless MALE_ONLY)
## ---------------------------------------------------------------------------
## Applied AFTER the normal build so the derived data is written exactly as in
## the two-sex model; this pass only removes what nsex = 1 cannot carry.

## Replace the leading integer(s) of the first data line at/after `anchor`.
set_count_line <- function(lines, anchor, values) {
  ci <- next_data(lines, find_anchor(lines, anchor) + 1L,
                  function(x) grepl("^[[:space:]]*[0-9]", x))
  lines[ci] <- paste(values, collapse = "\t")
  lines
}

## Drop whole matrices from a count-driven region, taking each matrix's leading
## comment lines with it -- the "#Retained males" / "#Year Season ..." header
## immediately preceding a matrix belongs to that matrix, and leaving it behind
## would orphan a header above the wrong data.
drop_matrices <- function(lines, count_idx, keep, is_data) {
  old_counts <- as.integer(toks(lines[count_idx]))
  pr <- parse_by_counts(lines, count_idx, old_counts, is_data)
  out <- character(0); pending <- character(0)
  for (s in pr$segs) {
    if (s$type == "comment") { pending <- c(pending, s$lines); next }
    if (s$k %in% keep) out <- c(out, pending, s$lines)   # keep header + data
    pending <- character(0)                              # else drop both
  }
  out <- c(paste(old_counts[keep], collapse = "\t"), out, pending)
  list(lines = c(if (count_idx > 1) lines[1:(count_idx - 1L)] else character(0),
                 out,
                 if (pr$end_idx < length(lines)) lines[(pr$end_idx + 1L):length(lines)] else character(0)),
       counts = old_counts[keep])
}

if (MALE_ONLY) {
  cat("--- male-only reduction (.DAT) ---\n")

  ## nsex
  ns <- which(grepl("#[[:space:]]*Number of sexes", L))
  if (length(ns) != 1) stop("Could not uniquely find '# Number of sexes' in the .dat")
  if (as.integer(toks(L[ns])[1]) != 2L) stop("Template .dat is not a 2-sex model")
  L[ns] <- sub("^[[:space:]]*2", "1", L[ns])

  ## nSizeSex (gmacsbase.TPL:444) -- "maximum size-class (males then females)"
  ## is init_ivector(1,nsex), so nsex = 1 reads ONE value. Leaving both makes
  ## ADMB read the spare token as the first size_break and every later scalar
  ## shifts by one; the visible symptom is the unrelated
  ## "m_prop_type can only be 1 or 2; STOPPING" further down the file.
  msi <- next_data(L, find_anchor(L, "maximum size-class") + 1L,
                   function(x) grepl("^[[:space:]]*[0-9]", x))
  L[msi] <- toks(L[msi])[1]

  ## growth: the observation rows carry a Sex column (## Premolt Sex Molt Inc CV)
  gh <- grep("Premolt", L); if (length(gh) != 1) stop("male-only: no unique growth header")
  gci <- next_data(L, find_anchor(L, "nobs_growth") + 1L,
                   function(x) grepl("^[[:space:]]*[0-9]", x))
  ngr <- as.integer(toks(L[gci])[1])
  grows <- L[(gh + 1L):(gh + ngr)]
  gkeep <- vapply(strsplit(trimws(grows), "[[:space:]]+"), function(z) z[2] == "1", logical(1))
  L <- c(L[1:gh], grows[gkeep],
         if (gh + ngr < length(L)) L[(gh + ngr + 1L):length(L)] else character(0))
  L[gci] <- as.character(sum(gkeep))
  GROWTH_COUNT <- sum(gkeep)          # the final SUMMARY reports the reduced file
  cat(sprintf("  growth rows   : %d -> %d  (male only)\n", ngr, sum(gkeep)))

  ## catch: drop the discard-female frame
  cci <- next_data(L, find_anchor(L, "Number of rows in each data frame") + 1L,
                   function(x) grepl("^[[:space:]]*[0-9]", x))
  rb <- drop_matrices(L, cci, MO_KEEP_CATCH, is_catch)
  L  <- rb$lines
  L  <- set_count_line(L, "Number of catch data frames", length(MO_KEEP_CATCH))
  CATCH_COUNTS <- rb$counts
  cat(sprintf("  catch frames  : 4 -> %d  (rows %s)\n",
              length(rb$counts), paste(rb$counts, collapse = " ")))

  ## size comps: drop the six female matrices, and the matching bin-count line
  sci <- next_data(L, find_anchor(L, "Number of rows in each matrix") + 1L,
                   function(x) grepl("^[[:space:]]*[0-9]", x))
  rb <- drop_matrices(L, sci, MO_KEEP_COMP, is_sizecomp)
  L  <- rb$lines
  L  <- set_count_line(L, "Number of length frequency matrices", length(MO_KEEP_COMP))
  L  <- set_count_line(L, "Number of bins in each matrix", rep(22L, length(MO_KEEP_COMP)))
  MO_COMP_COUNTS <- rb$counts
  COMP_COUNTS    <- rb$counts
  cat(sprintf("  comp matrices : 13 -> %d  (rows %s)\n",
              length(rb$counts), paste(rb$counts, collapse = " ")))

  ## indices: drop the female series, then RENUMBER the surviving index column
  ## so it is contiguous 1..n -- GMACS indexes q and selectivity by this value.
  idx_hdr <- grep("^#Index[[:space:]]+Year", L)
  if (length(idx_hdr) != 1) stop("Could not uniquely find the index data header")
  nrow_idx <- as.integer(toks(L[next_data(L, find_anchor(L, "Number of rows of index data") + 1L,
                                          function(x) grepl("^[[:space:]]*[0-9]", x))])[1])
  body <- L[(idx_hdr + 1L):(idx_hdr + nrow_idx)]
  tk   <- strsplit(trimws(body), "[[:space:]]+")
  keep <- vapply(tk, function(z) as.integer(z[1]) %in% MO_KEEP_INDEX, logical(1))
  remap <- setNames(seq_along(MO_KEEP_INDEX), as.character(MO_KEEP_INDEX))
  ## The index id appears TWICE on every row: column 1 (which q to use) and the
  ## LAST column (dSurveyData(jj,10), the relative-abundance-index id). Both
  ## must be renumbered. calc_relative_abundance reads the last column and
  ## looks it up in SurveyType(1,nSurveys) (gmacsbase.TPL:933, :9219), so an
  ## un-renumbered 3 survives every file check and then aborts phase 1 with
  ## "Invalid index 3 used for array range [1, 2]" (fixed 2026-08-28).
  body <- vapply(which(keep), function(i) {
    z <- tk[[i]]
    if (length(z) != 11L)
      stop(sprintf("male-only: index row %d has %d fields, expected 11", i, length(z)))
    if (z[11] != z[1])
      stop(sprintf(paste("male-only: index row %d has q id %s but index id %s;",
                         "the template no longer keys both columns off one id"),
                   i, z[1], z[11]))
    new <- remap[[z[1]]]
    x <- sub("^([[:space:]]*)[0-9]+", paste0("\\1", new), body[i])
    sub("([[:space:]])[0-9]+([[:space:]]*)$", paste0("\\1", new, "\\2"), x)
  }, "")
  L <- c(L[1:idx_hdr], body,
         if (idx_hdr + nrow_idx < length(L)) L[(idx_hdr + nrow_idx + 1L):length(L)] else character(0))
  L <- set_count_line(L, "Number of relative abundance indicies", length(MO_KEEP_INDEX))
  L <- set_count_line(L, "Number of rows of index data", length(body))
  L <- set_count_line(L, "Index Type", rep(1L, length(MO_KEEP_INDEX)))
  INDEX_COUNT <- length(body)
  cat(sprintf("  indices       : 4 -> %d  (rows 88 -> %d)\n",
              length(MO_KEEP_INDEX), length(body)))

  ## Re-sync. datobj$lines was set from L at the end of section 6d, BEFORE this
  ## block runs, and section 8 writes datobj -- not L. Without this the whole
  ## reduction is computed and then silently discarded.
  datobj$lines <- L

  ## No female row may survive, in any block that carries a sex column.
  .sexcol <- function(rows, f) vapply(strsplit(trimws(rows), "[[:space:]]+"),
                                      function(z) if (length(z) >= f) z[f] else NA_character_, "")
  chk <- function(rows, f, what) {
    s <- .sexcol(rows, f); s <- s[!is.na(s)]
    if (any(s == "2")) stop(sprintf("male-only: %d female row(s) survived in %s",
                                    sum(s == "2"), what))
  }
  chk(Filter(is_catch,    L), 4L, "catch")
  chk(Filter(is_sizecomp, L), 4L, "size comps")
  cat("  female-row check: none remain in catch or size comps\n")
}

## ---------------------------------------------------------------------------
## 7. Build the .ctl
## ---------------------------------------------------------------------------
ctlobj <- read_raw_lines(TEMPLATE_CTL)
C <- ctlobj$lines

## --- 7a. blocks-per-group + block-2 year pairs -----------------------------
bpg_c <- find_anchor(C, "Number of blocks per group")
bpg_idx <- next_data(C, bpg_c + 1L, function(x) grepl("^[[:space:]]*[0-9]", x))
bpg_tok <- toks(C[bpg_idx])                          # e.g. "3 43"
block1_n <- bpg_tok[1]
## CTL_END, not SURVEY_END: the .CTL structure is pinned to END_YEAR+1 even for
## a drop-survey build, matching how a GMACS retrospective leaves the .CTL alone.
block2_pairs <- 1983:CTL_END                         # block 2 spans 1983 .. END_YEAR+1
C[bpg_idx] <- paste(block1_n, length(block2_pairs))

## Replace block-2 definition lines (after "# Block 2" up to the next blank line)
b2_c <- which(norm_ws(C) == "# Block 2")
if (length(b2_c) != 1) stop("'# Block 2' definition header not unique (", length(b2_c), " matches)")
b2_start <- b2_c + 1L
b2_end <- b2_start
while (b2_end <= length(C) && nchar(trimws(C[b2_end])) > 0 && !grepl("^[[:space:]]*#", C[b2_end]))
  b2_end <- b2_end + 1L
b2_end <- b2_end - 1L
## emit pairs 10 per line
pair_str <- paste(block2_pairs, block2_pairs)
chunks <- split(pair_str, ceiling(seq_along(pair_str) / 10))
new_b2 <- vapply(chunks, function(z) paste(z, collapse = " "), character(1))
C <- c(C[1:(b2_start - 1L)], new_b2, if (b2_end < length(C)) C[(b2_end + 1L):length(C)] else character(0))

## --- 7a2. clamp block-group 1 (the M event periods) to END_YEAR -------------
## Block group 1 holds the additional-mortality event periods -- 2018, 2019 and
## 2020 in the template. Unlike block 2 these are assessment decisions and are
## NOT advanced with END_YEAR, but a model built at an EARLIER end year cannot
## carry a period past its own terminal year: GMACS dies in timevarparM() with
## "matrix bound exceeded -- row index too high ... value was 2020" during
## preliminary_calculations, before the first function evaluation (hit
## 2026-08-28 building the data-through-2019 run).
##
## Each period has one parameter row per sex/maturity group, commented
## "# Block <k>"; they are dropped with the period. In the template every 2020
## row is phz -4 with ival 0 -- structurally required, never estimated -- so for
## a 2019 model this removes nothing the model was fitting. If a dropped period
## IS estimated the build stops: that would be an assessment change, not a
## mechanical clamp, and it is Grant's call.
b1_c <- which(norm_ws(C) == "# Block 1")
if (length(b1_c) != 1L) stop("'# Block 1' definition header not unique")
b1_i <- b1_c + 1L
b1_v <- as.integer(toks(sub("#.*$", "", C[b1_i])))
if (length(b1_v) == 0L || length(b1_v) %% 2L != 0L)
  stop("Block 1 definition is not a whole number of year pairs")
b1_beg  <- b1_v[c(TRUE, FALSE)]
drop_k  <- which(b1_beg > END_YEAR)
if (length(drop_k)) {
  is_par <- function(i) grepl("^[[:space:]]*[-0-9]", C[i])
  drop_i <- integer(0)
  for (k in drop_k) {
    kk <- grep(sprintf("#[[:space:]]*Block[[:space:]]+%d[[:space:]]*$", k), C)
    kk <- kk[vapply(kk, is_par, logical(1))]
    if (!length(kk))
      stop(sprintf("No parameter rows found for out-of-range block period %d", k))
    for (i in kk) {
      z <- toks(sub("#.*$", "", C[i]))
      if (length(z) >= 7L && suppressWarnings(as.numeric(z[7])) > 0)
        stop(sprintf(paste("Block period %d starts in %d, past end year %d, but its",
                           "parameter row is ESTIMATED (phz %s). Dropping it would",
                           "change the model, not just its year range -- decide",
                           "explicitly before building at this end year."),
                     k, b1_beg[k], END_YEAR, z[7]))
    }
    drop_i <- c(drop_i, kk)
  }
  keep_v <- b1_v[rep(seq_along(b1_beg) %in% setdiff(seq_along(b1_beg), drop_k), each = 2L)]
  C[b1_i] <- paste(keep_v, collapse = " ")
  C <- C[-drop_i]
  ## the per-group count is "blocks after the first", i.e. the number of pairs
  bi <- next_data(C, find_anchor(C, "Number of blocks per group") + 1L,
                  function(x) grepl("^[[:space:]]*[0-9]", x))
  C[bi] <- paste(length(keep_v) %/% 2L, length(block2_pairs))
  cat(sprintf("  .ctl: dropped %d M event period(s) past end year %d (%d parameter row(s))\n",
              length(drop_k), END_YEAR, length(drop_i)))
}

## --- 7b. last rec_dev -> END_YEAR ------------------------------------------
rd_c <- find_anchor(C, "last rec_dev")
C[rd_c] <- sub("^[[:space:]]*[0-9]+", sprintf("%d      ", END_YEAR), C[rd_c])

## --- 7c. MALES molt-probability matrix <- male_maturity_ogive --------------
og_year <- as.integer(og$year)
og_keep <- og[og_year <= CTL_END, , drop = FALSE]   # CTL structure -> END_YEAR+1
og_keep <- og_keep[order(as.integer(og_keep$year)), , drop = FALSE]
if (as.integer(og_keep$year[1]) != 1982L) stop("Male maturity ogive row 1 is not 1982.")
n_molt <- nrow(og_keep)
male_molt_rows <- vapply(seq_len(n_molt),
  function(r) paste(as.character(og_keep[r, 2:23]), collapse = "\t"), character(1))

replace_ctl_matrix <- function(C, anchor, new_rows, is_data = function(x) grepl("^[[:space:]]*[0-9.]", x)) {
  a <- find_anchor(C, anchor)
  ## anchor must be an EXACT (whitespace-normalized) line, not a substring of a bigger line
  a_exact <- which(norm_ws(C) == norm_ws(anchor))
  if (length(a_exact) == 1) a <- a_exact
  s <- a + 1L
  s <- next_data(C, s, is_data)
  e <- s
  while (e <= length(C) && is_data(C[e])) e <- e + 1L
  e <- e - 1L
  c(C[1:(s - 1L)], new_rows, if (e < length(C)) C[(e + 1L):length(C)] else character(0))
}

## FEMALES constant molt row (extract before replacing) -> replicate to n_molt
fa <- which(norm_ws(C) == "## FEMALES")
if (length(fa) != 1) stop("## FEMALES molt anchor not unique")
fs <- next_data(C, fa + 1L, function(x) grepl("^[[:space:]]*[0-9.]", x))
female_const <- C[fs]
female_molt_rows <- rep(female_const, n_molt)

C <- replace_ctl_matrix(C, "## MALES",   male_molt_rows)
C <- replace_ctl_matrix(C, "## FEMALES", female_molt_rows)

## ---------------------------------------------------------------------------
## 7d. MALE-ONLY reduction of the .CTL  (no-op unless MALE_ONLY)
## ---------------------------------------------------------------------------
## Every dimension below is nsex-driven in gmacsbase.TPL 2.20.34, and GMACS
## echoed its own group order for this model, so which half is male is read,
## not assumed:
##     # 1 : male   New shell(1) Mature(1)      # 3 : female New shell(1) Mature(1)
##     # 2 : male   New shell(1) Immature(2)    # 4 : female New shell(1) Immature(2)
## Loop order is sex -> maturity -> shell (:486-488), so males are always the
## FIRST half of any n_grp- or nsex-dimensioned block.
if (MALE_ONLY) {
  cat("--- male-only reduction (.CTL) ---\n")

  ## Drop lines whose trailing comment names the female half of a sex pair.
  drop_female_labelled <- function(lines, idx, pat) {
    kill <- idx[grepl(pat, lines[idx], ignore.case = TRUE)]
    if (!length(kill)) stop("male-only: no female rows matched ", pat)
    lines[-kill]
  }
  ## Index of the line CARRYING an anchor's value. In this .ctl the value is
  ## sometimes on the comment line itself ("3 3 # Maximum size-class ...") and
  ## sometimes on the following line ("# Proportion mature by sex" then rows),
  ## so both forms must be handled -- taking the next line unconditionally
  ## edits the wrong row and silently destroys real data.
  dat_at <- function(lines, anchor) {
    a <- find_anchor(lines, anchor)
    if (grepl("^[[:space:]]*[-0-9]", lines[a])) a
    else next_data(lines, a + 1L, function(x) grepl("^[[:space:]]*[-0-9]", x))
  }
  ## Values on a line, with any trailing comment stripped first -- toks() alone
  ## would count the comment's words as data.
  vals_of <- function(line) toks(sub("#.*$", "", line))
  ## Replace a line's values, keeping its trailing comment verbatim.
  put_vals <- function(line, v)
    paste0(paste(v, collapse = "   "), "\t", sub("^[^#]*", "", line))

  ## (1) theta. Two blocks are sex-paired: the SECOND recruitment
  ## expected-value/scale pair, and deviation groups 3-4 (female mature and
  ## female immature). GMACS reports the count it wants -- 52 here, 98 before --
  ## so this is checked against its own arithmetic below, not against ours.
  dv <- grep("Deviation for size-class", C)
  if (length(dv) != 88L) stop("male-only: expected 88 theta deviations, found ", length(dv))
  C <- C[-dv[45:88]]                                   # groups 3 and 4 = female
  rs <- grep("recruitment (expected|scale)", C)
  if (length(rs) != 4L) stop("male-only: expected 4 recruitment-distribution rows, found ", length(rs))
  C <- C[-rs[3:4]]                                     # second pair = female
  cat("  theta rows    : 98 -> 52 (44 female deviations + the female recruitment pair)\n")

  ## (2) nSizeClassRec(1,nsex) -- "Maximum size-class for recruitment(males then females)"
  i <- dat_at(C, "Maximum size-class for recruitment")
  C[i] <- put_vals(C[i], vals_of(C[i])[1])

  ## (3) weight-at-length: lw_dim = nsex*nmature (TPL:2164) -> keep the male half
  wl <- grep("^##[[:space:]]*Females", C)
  if (length(wl) != 1L) stop("male-only: could not locate the '## Females' weight-at-length header")
  nrow_sex <- (grep("# Proportion mature by sex", C) - wl - 1L)
  C <- C[-(wl:(wl + nrow_sex))]
  cat(sprintf("  weight-at-len : dropped the female half (%d row(s))\n", nrow_sex))

  ## (4) maturity(1,nsex,1,nclass) and legal(1,nsex,1,nclass) -- 2 rows each
  for (a in c("Proportion mature by sex", "Proportion legal by sex")) {
    i <- dat_at(C, a); C <- C[-(i + 1L)]               # row 2 = female
  }

  ## (5-6) growth/molt/mature TYPE rows and the growth-increment parameters
  C <- drop_female_labelled(C, grep("Growth-transition", C), "Female")
  C <- drop_female_labelled(C, grep("Molt probability",  C), "Female")
  C <- drop_female_labelled(C, grep("Mature probability",C), "Female")
  C <- drop_female_labelled(C, grep("# *Females (alpha|beta|scale)", C), "Females")

  ## (7) pre-specified molt-probability matrix: drop the whole ## FEMALES block
  fm <- grep("^##[[:space:]]*FEMALES", C)
  if (length(fm) != 1L) stop("male-only: could not locate the '## FEMALES' molt matrix")
  nxt <- grep("^##[[:space:]]*males and combined", C)
  if (length(nxt) != 1L || nxt <= fm) stop("male-only: could not bound the FEMALES molt matrix")
  cat(sprintf("  molt matrix   : dropped FEMALES (%d rows)\n", nxt - fm - 1L))
  C <- C[-(fm:(nxt - 1L))]

  ## (8) natural mortality: 4 "Relative?" rows -> 2, then 16 parameter rows -> 8
  C <- drop_female_labelled(C, grep("#[[:space:]]*Females;", C), "Females;")
  mrow <- grep("#[[:space:]]*(Males|Male|Females|Female) \\((Mature|Immature)\\)|# Block [123]", C)
  fem  <- grep("#[[:space:]]*Females? \\((Mature|Immature)\\)", C)
  if (length(fem) != 2L) stop("male-only: expected 2 female M base rows, found ", length(fem))
  C <- C[-(fem[1]:(fem[2] + 3L))]                      # both female groups + their 3 blocks each
  cat("  natural mort. : 4 -> 2 relative rows, 16 -> 8 parameter rows\n")

  ## (9) selectivity / retention: the model is now sex-independent
  for (a in c("sex specific selectivity", "sex specific retention")) {
    i <- dat_at(C, a)
    C[i] <- put_vals(C[i], rep("0", length(vals_of(C[i]))))
  }
  C <- C[-grep("#[[:space:]]*(female selectivity type|female retention type|female +retention flag)", C, ignore.case = TRUE)]
  C <- C[-grep("\\(females\\)|selectivity is 1 females", C, ignore.case = TRUE)]
  ## The "forced to equal 1" pair carries the SAME comment on both rows, so it
  ## can only be told apart by position: male first, female second.
  fe1 <- grep("determines if maximum selectivity", C)
  if (length(fe1) != 2L)
    stop("male-only: expected 2 'maximum selectivity forced' rows, found ", length(fe1))
  C <- C[-fe1[2]]

  ## (10) per-gear female selectivity parameter blocks
  gf <- grep("^#Gear-[0-9]+-females", C)
  if (length(gf)) {
    ends <- c(gf[-1], grep("^#Gear-[0-9]+-males", C)[grep("^#Gear-[0-9]+-males", C) > gf[1]][1])
    C <- C[-(gf[1]:(ends[length(ends)] - 1L))]
    cat(sprintf("  selectivity   : dropped %d female gear block(s)\n", length(gf)))
  }

  ## (10b) index-dimensioned blocks: one row per relative-abundance index, so
  ## they must shrink 4 -> 2 exactly as the .DAT's index list did. Missing these
  ## does not fail here -- it silently over-reads two rows and the stream is
  ## still offset when the size-comp block is parsed, which surfaces as the
  ## unrelated "Size comp type must be 0, 1, 2, 5 or 6".
  ##
  ## Each section holds TWO such runs, and BOTH are dimensioned nSurveys in the
  ## TPL -- specifications then parameters (q: gmacsbase.TPL:3688/:3774;
  ## additional CV: :3834/:3936). Reducing only the first left the reader two
  ## rows out of step: it kept the FEMALE q priors, then read the two leftover
  ## MALE q parameter rows AS the additional-CV specifications, saw mirror = 1
  ## on both, computed n_addcv_par = 0, and died on the zero-row matrix with
  ## "matrix bound exceeded -- row index too high" (fixed 2026-08-28).
  ## `end_anchor` bounds the search to this section. Without it a missing
  ## parameters block would send the second pass into the NEXT section, whose
  ## first run is also 4 rows wide -- the row-count check below would not catch
  ## it and the wrong block would be silently halved.
  keep_index_rows <- function(lines, anchor, end_anchor, label) {
    a <- find_anchor(lines, anchor)
    is_row <- function(x) grepl("^[[:space:]]*[-0-9]", x)
    for (blk in c("specifications", "parameters")) {
      stop_at <- find_anchor(lines, end_anchor)   # recompute: lines shrink below
      i <- next_data(lines, a + 1L, is_row)
      if (i >= stop_at)
        stop(sprintf("male-only: no %s %s rows before '%s'", label, blk, end_anchor))
      j <- i; while (j <= length(lines) && is_row(lines[j])) j <- j + 1L
      rows <- lines[i:(j - 1L)]
      if (length(rows) != 4L)
        stop(sprintf("male-only: expected 4 %s %s rows, found %d", label, blk, length(rows)))
      lines <- c(lines[1:(i - 1L)], rows[MO_KEEP_INDEX],
                 if (j <= length(lines)) lines[j:length(lines)] else character(0))
      a <- i + length(MO_KEEP_INDEX) - 1L        # resume after the block just written
    }
    cat(sprintf("  %-13s : 4 -> %d rows, specifications and parameters\n",
                label, length(MO_KEEP_INDEX)))
    lines
  }
  C <- keep_index_rows(C, "PRIORS FOR CATCHABILITY", "ADDITIONAL CV FOR SURVEYS",
                       "catchability")
  C <- keep_index_rows(C, "ADDITIONAL CV FOR SURVEYS",
                       "PENALTIES FOR AVERAGE FISHING MORTALITY RATE", "additional CV")

  ## (11) size-comp option vectors: one column per DAT matrix, so they must lose
  ## exactly the columns the .DAT lost. The splicer is positional and is
  ## renumbered 1..n rather than merely shortened.
  sc_lab <- c("Type of likelihood", "Auto tail compression", "Composition splicer",
              "survey-like predictions", "LAMBDA", "Emphasis AEP", "Q to adjust comps")
  for (lab in sc_lab) {
    ii <- grep(lab, C, fixed = TRUE)
    ii <- ii[grepl("^[[:space:]]*[-0-9]", C[ii])]      # data rows only, not legend text
    for (i in ii) {
      v <- toks(sub("#.*$", "", C[i]))
      if (length(v) != 13L) next
      v <- v[MO_KEEP_COMP]
      if (grepl("Composition splicer", C[i], fixed = TRUE)) v <- as.character(seq_along(v))
      C[i] <- paste0(paste(v, collapse = "   "), "\t", sub("^[^#]*", "", C[i]))
    }
  }
  cat(sprintf("  comp vectors  : 13 -> %d columns, splicer renumbered\n", length(MO_KEEP_COMP)))

  ## (11b) effective-sample-size parameters: one ROW per size-comp matrix
  ## (log_vn_pars(1,nSizeComps,1,7), gmacsbase.TPL:4084), so 13 -> 7 like the
  ## vectors above. The block carries no per-row comment to key on; it is the
  ## 13-row run of 7-field rows between the size-comp options and the TAGGING
  ## header. Left at 13 it does not fail here -- GMACS reads the first 7 and the
  ## remaining 42 numbers are silently consumed by every later read.
  ii <- find_anchor(C, "OPTIONS FOR SIZE COMPOSTION DATA")
  jj <- find_anchor(C, "TAGGING controls")
  hd <- ii + grep("Initial.*Lower_bound.*Upper_bound", C[(ii + 1L):(jj - 1L)])
  if (length(hd) != 1L)
    stop("male-only: could not locate the effective-sample-size parameter header")
  vs <- next_data(C, hd + 1L, function(x) grepl("^[[:space:]]*[-0-9]", x))
  ve <- vs; while (ve <= length(C) && grepl("^[[:space:]]*[-0-9]", C[ve])) ve <- ve + 1L
  vn <- vs:(ve - 1L)
  if (length(vn) != 13L)
    stop("male-only: expected 13 effective-sample-size rows, found ", length(vn))
  C <- C[-vn[-MO_KEEP_COMP]]
  cat(sprintf("  eff. samp. N  : 13 -> %d rows\n", length(MO_KEEP_COMP)))

  ## (11c) catch emphasis: one value per catch data frame
  ## (catch_emphasis(1,nCatchDF), gmacsbase.TPL:4439), so it must lose the
  ## discard-FEMALE column exactly as the .DAT's catch frames did.
  ## Bounded for the same reason as keep_index_rows: the next section's first
  ## row is the 4-field "1 1 0 0 # Pot_Fishery" fdev penalty, so a missing
  ## catch-emphasis line would otherwise be "found" there and silently rewritten.
  ce <- find_anchor(C, "EMPHASIS FACTORS (CATCH)")
  ce_end <- find_anchor(C, "EMPHASIS FACTORS (Priors) by fleet")
  i  <- next_data(C, ce + 1L, function(x) grepl("^[[:space:]]*[-0-9]", x))
  if (i >= ce_end)
    stop("male-only: no catch-emphasis row before the by-fleet penalty block")
  v  <- toks(sub("#.*$", "", C[i]))
  if (length(v) != 4L)
    stop("male-only: expected 4 catch-emphasis values, found ", length(v))
  C[i] <- paste0("   ", paste(v[MO_KEEP_CATCH], collapse = "         "),
                 "      # male-only: dropped the discard-female weight")
  cat(sprintf("  catch emphasis: 4 -> %d values\n", length(MO_KEEP_CATCH)))

  ## (11d) female F offset: log_foff(1,nfleet) is estimated whenever f_controls
  ## column 6 (Phz_mean_F_fem) is positive (gmacsbase.TPL:4030, :4993). With
  ## nsex = 1 there is no female fishery to inform it. Left on, it sat at its
  ## initial value with a standard error of 2.9e+04 and drove the Hessian
  ## condition number to 1e14 (2026-08-28). Phase off for every fleet;
  ## foffdevs_phz follows it (:4031).
  fm <- find_anchor(C, "PENALTIES FOR AVERAGE FISHING MORTALITY RATE")
  i  <- next_data(C, fm + 1L, function(x) grepl("^[[:space:]]*[-0-9]", x))
  nf <- 0L
  while (i <= length(C) && grepl("^[[:space:]]*[-0-9]", C[i])) {
    v <- toks(sub("#.*$", "", C[i]))
    if (length(v) != 12L)
      stop(sprintf("male-only: F-control row has %d fields, expected 12", length(v)))
    if (as.numeric(v[6]) > 0) { v[6] <- "-1"; nf <- nf + 1L }
    C[i] <- paste0("   ", paste(v, collapse = "\t"), "\t", sub("^[^#]*", "", C[i]))
    i <- i + 1L
  }
  cat(sprintf("  female F offs.: phase disabled on %d fleet(s)\n", nf))

  ctlobj$lines <- C
}

ctlobj$lines <- C

## ---------------------------------------------------------------------------
## 8. Regenerate out_dir fresh from template_dir; write files; patch gmacs.dat
## ---------------------------------------------------------------------------
if (dir.exists(OUT_DIR)) unlink(OUT_DIR, recursive = TRUE, force = TRUE)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
## copy every template file (idempotent regenerate)
tf <- list.files(TEMPLATE_DIR, full.names = TRUE, all.files = TRUE, no.. = TRUE)
file.copy(tf, OUT_DIR, overwrite = TRUE, recursive = TRUE, copy.date = TRUE)
## remove the copied template model .dat (we write it under the new name)
old_dat_copy <- file.path(OUT_DIR, basename(TEMPLATE_DAT))
if (file.exists(old_dat_copy) && basename(TEMPLATE_DAT) != OUT_DAT_NAME) unlink(old_dat_copy)

OUT_DAT <- file.path(OUT_DIR, OUT_DAT_NAME)
OUT_CTL <- file.path(OUT_DIR, "snow.ctl")
OUT_GMACS <- file.path(OUT_DIR, "gmacs.dat")
write_raw_lines(datobj, OUT_DAT)
write_raw_lines(ctlobj, OUT_CTL)

## Clamp the .PRJ averaging windows to END_YEAR. The projection file carries its
## own year ranges and is otherwise copied from the template verbatim, so a model
## built at an EARLIER end year inherits windows that run past its own data.
## GMACS refuses to start: "Last year for computing Rbar must be nyr or earlier:
## STOPPING. spr_nyr = 2023 nyr = 2019" (hit 2026-08-28 building the
## data-through-2019 run). Only the "first and last year" range lines are
## touched; the projection HORIZON (":22", last year of projection) is legitimately
## beyond END_YEAR and is left alone, as is the growth year (see the snow.prj note
## in CLAUDE.md). A 0 means "last year" and is a sentinel, so it is never clamped.
## No-op whenever END_YEAR is at or beyond every window, which is the case for the
## 2025 build -- verified byte-identical.
## Read the .prj name from the TEMPLATE's control file: OUT_DIR's gmacs.dat still
## names the template datafile at this point (it is patched just below), so
## read_gmacs_control(OUT_DIR) would fail its own existence check.
OUT_PRJ <- file.path(OUT_DIR, read_gmacs_control(TEMPLATE_DIR)$prjfile)
pj <- read_raw_lines(OUT_PRJ)
prj_rows <- grep("[Ff]irst and last year", pj$lines)
n_clamped <- 0L
for (i in prj_rows) {
  body <- sub("#.*$", "", pj$lines[i])
  z    <- toks(body)
  if (length(z) < 2L) next                     # single-value rows (e.g. growth year)
  yy <- suppressWarnings(as.integer(z[1:2]))
  if (anyNA(yy)) next
  new <- ifelse(yy > 0L & yy > END_YEAR, END_YEAR, yy)   # 0 = "last year" sentinel
  if (identical(new, yy)) next
  pj$lines[i] <- sub(body, paste0(paste(new, collapse = " "), "\t"), pj$lines[i], fixed = TRUE)
  n_clamped <- n_clamped + 1L
}
if (n_clamped > 0L) {
  write_raw_lines(pj, OUT_PRJ)
  cat(sprintf("  .prj: clamped %d averaging window(s) to end year %d\n", n_clamped, END_YEAR))
}

## patch gmacs.dat: the line after '#datafile' -> OUT_DAT_NAME
gm <- read_raw_lines(OUT_GMACS)
gi <- which(grepl("^[[:space:]]*#\\s*datafile", gm$lines))[1]
if (is.na(gi)) stop("Could not find '#datafile' in gmacs.dat")
gm$lines[gi + 1L] <- OUT_DAT_NAME
write_raw_lines(gm, OUT_GMACS)

## ---------------------------------------------------------------------------
## 9. ASSERTIONS / TESTS
## ---------------------------------------------------------------------------
pass <- 0L; fail <- 0L
check <- function(cond, msg) {
  if (isTRUE(cond)) { pass <<- pass + 1L; cat(sprintf("  [PASS] %s\n", msg)) }
  else              { fail <<- fail + 1L; cat(sprintf("  [FAIL] %s\n", msg)) }
}
cat("\n--- ASSERTIONS ---\n")

## Re-read the written files and parse them independently.
V <- read_raw_lines(OUT_DAT)$lines
ey_v <- which(grepl("#[[:space:]]*End[[:space:]]*year", V))
check(length(ey_v) == 1 && as.integer(toks(V[ey_v])[1]) == END_YEAR,
      sprintf(".dat End year = %s (expected %d)", if(length(ey_v)==1) toks(V[ey_v])[1] else "?", END_YEAR))

## (a) declared counts == emitted rows, for every region
get_run_counts <- function(lines, count_anchor, is_data, count_first_data) {
  ci <- find_anchor(lines, count_anchor)
  cidx <- next_data(lines, ci + 1L, count_first_data)
  declared <- as.integer(toks(lines[cidx]))
  pr <- parse_by_counts(lines, cidx, declared, is_data)
  emitted <- vapply(pr$data_blocks, length, integer(1))
  list(declared = declared, emitted = emitted)
}
cc <- get_run_counts(V, "Number of rows in each data frame", is_catch,
                     function(x) grepl("^[[:space:]]*[0-9]", x))
check(identical(cc$declared, cc$emitted),
      sprintf("catch: declared {%s} == emitted {%s}",
              paste(cc$declared, collapse=","), paste(cc$emitted, collapse=",")))

ic <- get_run_counts(V, "Number of rows of index data", is_index,
                     function(x) grepl("^[[:space:]]*[0-9]+[[:space:]]*($|#)", x))
check(identical(ic$declared, ic$emitted),
      sprintf("index: declared %d == emitted %d", ic$declared[1], ic$emitted[1]))

mc <- get_run_counts(V, "Number of rows in each matrix", is_sizecomp,
                     function(x) grepl("^[[:space:]]*[0-9]", x))
check(identical(mc$declared, mc$emitted),
      sprintf("size comps: declared {%s} == emitted {%s}",
              paste(mc$declared, collapse=","), paste(mc$emitted, collapse=",")))

gc <- get_run_counts(V, "nobs_growth", is_growth,
                     function(x) grepl("^[[:space:]]*[0-9]", x))
check(identical(gc$declared, gc$emitted),
      sprintf("growth: declared %d == emitted %d", gc$declared[1], gc$emitted[1]))

## helper: parse a written region by its declared counts
parse_anchor <- function(lines, anchor, is_data, count_first_data) {
  ci   <- find_anchor(lines, anchor)
  cidx <- next_data(lines, ci + 1L, count_first_data)
  parse_by_counts(lines, cidx, as.integer(toks(lines[cidx])), is_data)
}

## Template matrix index -> its position in the WRITTEN file, or NA if the
## male-only reduction dropped it. Identity for a two-sex build. Every
## matrix-indexed assertion below goes through this so the same checks cover
## both structures instead of being skipped for male-only.
mo_mi  <- function(k) if (!MALE_ONLY) k else match(k, MO_KEEP_COMP)
N_COMP <- if (MALE_ONLY) length(MO_KEEP_COMP) else 13L

## bins line unchanged (all 22)
binln <- find_anchor(V, "Number of bins in each matrix")
bins  <- as.integer(toks(V[next_data(V, binln + 1L, function(x) grepl("^[[:space:]]*[0-9]", x))]))
check(all(bins == 22L) && length(bins) == N_COMP,
      sprintf("all %d size-comp matrices declare 22 bins", N_COMP))

## (b) every size-comp row: exactly 22 bins summing to ~1.0 (tol 1e-3)
pr_sc <- parse_anchor(V, "Number of rows in each matrix", is_sizecomp,
                      function(x) grepl("^[[:space:]]*[0-9]", x))
## comps are rounded at source (trawl-bycatch to 3 decimals -> deviates up to
## ~3e-3 from 1.0, exactly as the template does; GMACS renormalizes internally).
COMP_SUM_TOL <- 5e-3
bad_bins <- 0L; bad_sum <- 0L; nrows_comp <- 0L; over_1e3 <- 0L; max_dev <- 0
for (s in pr_sc$segs) if (s$type == "data") for (ln in s$lines) {
  t <- toks(ln); nrows_comp <- nrows_comp + 1L
  binv <- suppressWarnings(as.numeric(t[9:length(t)]))
  if (length(binv) != 22L) { bad_bins <- bad_bins + 1L; next }
  dev <- abs(sum(binv) - 1)
  max_dev <- max(max_dev, dev)
  if (dev > 1e-3) over_1e3 <- over_1e3 + 1L
  if (dev > COMP_SUM_TOL) bad_sum <- bad_sum + 1L
}
check(bad_bins == 0L, sprintf("all %d size-comp rows have exactly 22 bin values", nrows_comp))
check(bad_sum == 0L, sprintf("all size-comp rows sum to 1.0 (tol %.0e); max|sum-1|=%.4f; %d rows in (1e-3, %.0e]",
                             COMP_SUM_TOL, max_dev, over_1e3, COMP_SUM_TOL))

## fidelity: written comp bins == derived source bins (exact numeric round-trip)
fid_bad <- 0L; fid_n <- 0L
cmp_written <- function(matrix_k, y) {
  ln <- Filter(function(s) s$type=="data" && s$k==matrix_k, pr_sc$segs)[[1]]$lines
  hit <- ln[which(vapply(ln, function(x) as.integer(toks(x)[1]), integer(1)) == y)]
  if (length(hit) != 1) return(NULL)
  suppressWarnings(as.numeric(toks(hit)[9:30]))
}
fid_spec <- list(list(2, 1,1,0), list(3, 1,2,2), list(4, 2,2,2), list(5, 2,1,2))  # matrix_k, fleet,sex,type
for (sp in fid_spec) {
  mk <- mo_mi(sp[[1]]); fl <- sp[[2]]; sx <- sp[[3]]; tp <- sp[[4]]
  if (is.na(mk)) next                      # female matrix, dropped by male-only
  sub <- fsc[fsc$fleet==fl & fsc$sex==sx & fsc$type==tp & as.integer(fsc$year)<=END_YEAR, , drop=FALSE]
  for (r in seq_len(nrow(sub))) {
    fid_n <- fid_n + 1L
    src <- suppressWarnings(as.numeric(as.character(sub[r, 5:26])))
    got <- cmp_written(mk, as.integer(sub$year[r]))
    if (is.null(got) || max(abs(src - got)) > 1e-9) fid_bad <- fid_bad + 1L
  }
}
check(fid_bad == 0L, sprintf("all %d fishery-comp rows written value-identical to derived source", fid_n))

## metadata preservation: for years present in BOTH template and output, the
## per-matrix metadata cols (year..Nsamp, 1:8) must be byte-equal (guards the
## per-year Nsamp of closure-era discard-female rows: 10, not 100).
Tl_all <- read_raw_lines(TEMPLATE_DAT)$lines
tmpl_sc <- parse_anchor(Tl_all, "Number of rows in each matrix", is_sizecomp,
                        function(x) grepl("^[[:space:]]*[0-9]", x))
meta_bad <- 0L; meta_n <- 0L; nsamp10 <- 0L
for (k in 1:13) {
  ko <- mo_mi(k); if (is.na(ko)) next      # female matrix, dropped by male-only
  tk <- Filter(function(s) s$type=="data" && s$k==k,  tmpl_sc$segs)[[1]]$lines
  ok <- Filter(function(s) s$type=="data" && s$k==ko, pr_sc$segs)[[1]]$lines
  tmeta <- setNames(lapply(tk, function(x) toks(x)[1:8]), vapply(tk, function(x) toks(x)[1], character(1)))
  for (ln in ok) {
    m <- toks(ln)[1:8]; yk <- m[1]
    if (m[8] == "10") nsamp10 <- nsamp10 + 1L
    if (yk %in% names(tmeta)) { meta_n <- meta_n + 1L; if (!identical(m, tmeta[[yk]])) meta_bad <- meta_bad + 1L }
  }
}
check(meta_bad == 0L, sprintf("all %d shared-year comp rows keep template metadata (incl per-year Nsamp); %d rows carry Nsamp=10",
                              meta_n, nsamp10))

## (c) every catch row has 11 fields; every index row has 11 fields
pr_c <- parse_anchor(V, "Number of rows in each data frame", is_catch,
                     function(x) grepl("^[[:space:]]*[0-9]", x))
nbad <- 0L; ncat <- 0L
for (s in pr_c$segs) if (s$type=="data") for (ln in s$lines){ncat<-ncat+1L; if(length(toks(ln))!=11L) nbad<-nbad+1L}
check(nbad == 0L, sprintf("all %d catch rows have 11 fields", ncat))

pr_i <- parse_anchor(V, "Number of rows of index data", is_index,
                     function(x) grepl("^[[:space:]]*[0-9]+[[:space:]]*($|#)", x))
nbadi <- 0L; nidx <- 0L
for (s in pr_i$segs) if (s$type=="data") for (ln in s$lines){nidx<-nidx+1L; if(length(toks(ln))!=11L) nbadi<-nbadi+1L}
check(nbadi == 0L, sprintf("all %d index rows have 11 fields", nidx))

## (d) molt matrices: n_molt rows, 22 cols, MALES row1 == 1982 ogive
Vc <- read_raw_lines(OUT_CTL)$lines
ma <- which(norm_ws(Vc) == "## MALES"); fa2 <- which(norm_ws(Vc) == "## FEMALES")
## A male-only build has no ## FEMALES matrix; the MALES block then runs to the
## "## males and combined" comment that follows it.
if (MALE_ONLY) fa2 <- which(grepl("^##[[:space:]]*males and combined", Vc))[1]
male_rows <- Vc[(next_data(Vc, ma+1L, function(x) grepl("^[[:space:]]*[0-9.]",x))):(fa2-1L)]
male_rows <- male_rows[grepl("^[[:space:]]*[0-9.]", male_rows)]
expect_molt <- CTL_END - 1982L + 1L
check(length(male_rows) == expect_molt,
      sprintf("MALES molt matrix has %d rows (expected %d = 1982..%d)", length(male_rows), expect_molt, CTL_END))
row1 <- suppressWarnings(as.numeric(toks(male_rows[1])))
og1  <- suppressWarnings(as.numeric(as.character(og_keep[1, 2:23])))
check(length(row1)==22L && max(abs(row1 - og1)) < 1e-9, "MALES molt row1 == ogive(1982), 22 cols")
## FEMALES: same row count, constant. Absent by construction in a male-only
## build -- assert it is GONE rather than skipping the check entirely.
if (MALE_ONLY) {
  check(length(which(norm_ws(Vc) == "## FEMALES")) == 0L,
        "male-only: FEMALES molt matrix removed from the .ctl")
} else {
  fend <- next_data(Vc, fa2+1L, function(x) grepl("^[[:space:]]*[0-9.]",x))
  fe <- fend; while (fe <= length(Vc) && grepl("^[[:space:]]*[0-9.]", Vc[fe])) fe <- fe + 1L
  female_rows <- Vc[fend:(fe-1L)]
  check(length(female_rows) == expect_molt && length(unique(female_rows)) == 1L,
        sprintf("FEMALES molt matrix has %d identical (constant) rows", length(female_rows)))
}

## ctl block/rec_dev
bpg2 <- toks(Vc[next_data(Vc, find_anchor(Vc,"Number of blocks per group")+1L, function(x) grepl("^[[:space:]]*[0-9]",x))])
check(as.integer(bpg2[2]) == (CTL_END - 1983L + 1L),
      sprintf("blocks-per-group block-2 count = %s (expected %d)", bpg2[2], CTL_END - 1983L + 1L))
rdv <- toks(Vc[find_anchor(Vc,"last rec_dev")])[1]
check(as.integer(rdv) == END_YEAR, sprintf("last rec_dev = %s (expected %d)", rdv, END_YEAR))

## (e) historical preservation: template pre-1990 catch rows byte-identical
Tl <- read_raw_lines(TEMPLATE_DAT)$lines
tmpl_catch <- parse_anchor(Tl, "Number of rows in each data frame", is_catch,
                           function(x) grepl("^[[:space:]]*[0-9]", x))
out_catch  <- pr_c
hist_ok <- TRUE; hist_checked <- 0L
## Template catch frame -> its position in the written file (NA if male-only
## dropped it), mirroring mo_mi() for the comp matrices.
mo_ci <- function(k) if (!MALE_ONLY) k else match(k, MO_KEEP_CATCH)
for (fi in 1:4) {
  fo <- mo_ci(fi); if (is.na(fo)) next     # discard-female frame, dropped
  tl <- Filter(function(s) s$type=="data" && s$k==fi, tmpl_catch$segs)[[1]]$lines
  ol <- Filter(function(s) s$type=="data" && s$k==fo, out_catch$segs)[[1]]$lines
  ty <- vapply(tl, function(x) as.integer(toks(x)[1]), integer(1))
  oy <- vapply(ol, function(x) as.integer(toks(x)[1]), integer(1))
  for (h in ty[ty <= 1989]) {
    hist_checked <- hist_checked + 1L
    ti <- tl[which(ty == h)]; oi <- ol[which(oy == h)]
    if (length(oi) != 1 || !identical(ti, oi)) hist_ok <- FALSE
  }
}
check(hist_ok, sprintf("all %d pre-1990 catch rows byte-identical to template", hist_checked))

## (e2) survey data actually stops at SURVEY_END (the drop-survey knob works,
##      and for a normal build it re-confirms the crab-year convention).
##      Compared against the last survey year the DERIVED DATA actually has at
##      or below SURVEY_END, not against SURVEY_END itself: there was no 2020
##      survey (COVID cancellation), so a cut at 2020 correctly yields 2019.
si_yrs      <- as.integer(si$year[si$sex == "male" & si$maturity == "mature"])
expect_surv <- max(si_yrs[si_yrs <= SURVEY_END])

ir_all <- Filter(function(s) s$type == "data", pr_i$segs)[[1]]$lines
ir_yrs <- vapply(ir_all, function(x) as.integer(toks(x)[2]), integer(1))
check(max(ir_yrs) == expect_surv,
      sprintf("last survey index year = %d (expected %d, the last survey at or before survey_end %d)",
              max(ir_yrs), expect_surv, SURVEY_END))
sc_surv_k <- Filter(Negate(is.na), vapply(6:13, mo_mi, integer(1)))
sc_surv_max <- max(vapply(sc_surv_k, function(k) {
  ln <- Filter(function(s) s$type == "data" && s$k == k, pr_sc$segs)[[1]]$lines
  max(vapply(ln, function(x) as.integer(toks(x)[1]), integer(1)))
}, integer(1)))
check(sc_surv_max == expect_surv,
      sprintf("last survey size-comp year = %d (expected %d)", sc_surv_max, expect_surv))

## (f) spot-check known values in the END_YEAR=2025 (26) output.
##     Skipped for drop-survey builds -- the 2026 survey is deliberately absent.
if (END_YEAR == 2025L && SURVEY_END == 2026L) {
  getrow <- function(segs, run, y) {
    ln <- Filter(function(s) s$type=="data" && s$k==run, segs)[[1]]$lines
    ln[which(vapply(ln, function(x) as.integer(toks(x)[1]), integer(1)) == y)]
  }
  spot <- function(seg, run, y, col, target, name) {
    r <- getrow(seg, run, y)
    v <- suppressWarnings(as.numeric(toks(r)[col]))
    check(length(v)==1 && abs(v - target) < 1e-3, sprintf("spot %s = %.6g (target %.6g)", name, v, target))
  }
  ## Frame numbers are TEMPLATE positions; mo_ci() maps them to the written
  ## file and returns NA for the discard-female frame a male-only build drops.
  spot(pr_c$segs, mo_ci(1), 2025, 5, 4.12549,  "retained catch 2025")
  spot(pr_c$segs, mo_ci(2), 2025, 5, 2.517741, "male-discard 2025")
  if (!MALE_ONLY)
    spot(pr_c$segs, mo_ci(3), 2025, 5, 0.03027465, "female-discard 2025")
  spot(pr_c$segs, mo_ci(4), 2025, 5, 0.4218131, "bycatch 2025")
  ## index: female-mature era2 is run within the single index block; parse by Index id
  ir <- Filter(function(s) s$type=="data", pr_i$segs)[[1]]$lines
  ir_tok <- lapply(ir, toks)
  si_exp  <- read.csv(file.path(DERIVED, "survey_indices.csv"))
  exp_fem <- si_exp$biomass[si_exp$sex=="female" & si_exp$maturity=="mature" & si_exp$year==2026]
  exp_mmb <- si_exp$biomass[si_exp$sex=="male"   & si_exp$maturity=="mature" & si_exp$year==2026]
  ## Male-only renumbers the surviving indices 3,4 -> 1,2 and drops the female
  ## series entirely, so the female check does not apply and MMB moves to 2.
  if (!MALE_ONLY) {
    fmr <- Filter(function(t) t[1]=="2" && t[2]=="2026", ir_tok) # Index 2 = female mature era2
    check(length(fmr)==1 && abs(as.numeric(fmr[[1]][7]) - exp_fem) < 1e-2,
          sprintf("mature-female index 2026 = %.3f (matches survey_indices.csv)", exp_fem))
  }
  mmb_id <- if (MALE_ONLY) "2" else "4"                          # male mature era2 (MMB)
  mmb <- Filter(function(t) t[1]==mmb_id && t[2]=="2026", ir_tok)
  check(length(mmb)==1 && abs(as.numeric(mmb[[1]][7]) - exp_mmb) < 1e-2,
        sprintf("MMB 2026 = %.3f (matches survey_indices.csv)", exp_mmb))
}

cat(sprintf("\n--- SUMMARY (%s, END_YEAR=%d) ---\n", basename(OUT_DIR), END_YEAR))
cat(sprintf("  catch counts     : %s\n", paste(CATCH_COUNTS, collapse=" ")))
cat(sprintf("  index count      : %d\n", INDEX_COUNT))
cat(sprintf("  size-comp counts : %s\n", paste(COMP_COUNTS, collapse=" ")))
cat(sprintf("  growth nobs      : %d\n", GROWTH_COUNT))
cat(sprintf("  molt-matrix rows : %d (1982..%d)\n", n_molt, CTL_END))
cat(sprintf("  survey data thru : %d\n", SURVEY_END))
cat(sprintf("  PASS=%d  FAIL=%d\n", pass, fail))
if (fail > 0) quit(status = 1L)
cat(sprintf("  Wrote: %s\n         %s\n         %s (datafile -> %s)\n",
            OUT_DAT, OUT_CTL, OUT_GMACS, OUT_DAT_NAME))
