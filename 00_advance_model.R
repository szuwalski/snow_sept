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
## 05_run_retrospective.R to build the "drop terminal survey" retrospective:
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
CTL_END    <- END_YEAR + 1L   # crab-year convention: end-year N -> N+1 summer survey
SURVEY_END <- if (length(args) >= 7) as.integer(args[7]) else CTL_END
if (is.na(SURVEY_END)) stop("survey_end (arg 7) is not an integer: ", args[7])
if (SURVEY_END > CTL_END)
  stop(sprintf("survey_end (%d) cannot exceed end_year+1 (%d)", SURVEY_END, CTL_END))
if (SURVEY_END < 1989L)
  stop(sprintf("survey_end (%d) is before the era-2 survey start (1989)", SURVEY_END))

## Shared GMACS file I/O (raw-bytes readers, anchor helpers). Also sourced by
## 05_run_retrospective.R -- one parser, not two.
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
## and 05_run_retrospective.R share one implementation.

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

## bins line unchanged (all 22)
binln <- find_anchor(V, "Number of bins in each matrix")
bins  <- as.integer(toks(V[next_data(V, binln + 1L, function(x) grepl("^[[:space:]]*[0-9]", x))]))
check(all(bins == 22L) && length(bins) == 13L, "all 13 size-comp matrices declare 22 bins")

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
  mk <- sp[[1]]; fl <- sp[[2]]; sx <- sp[[3]]; tp <- sp[[4]]
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
  tk <- Filter(function(s) s$type=="data" && s$k==k, tmpl_sc$segs)[[1]]$lines
  ok <- Filter(function(s) s$type=="data" && s$k==k, pr_sc$segs)[[1]]$lines
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
male_rows <- Vc[(next_data(Vc, ma+1L, function(x) grepl("^[[:space:]]*[0-9.]",x))):(fa2-1L)]
male_rows <- male_rows[grepl("^[[:space:]]*[0-9.]", male_rows)]
expect_molt <- CTL_END - 1982L + 1L
check(length(male_rows) == expect_molt,
      sprintf("MALES molt matrix has %d rows (expected %d = 1982..%d)", length(male_rows), expect_molt, CTL_END))
row1 <- suppressWarnings(as.numeric(toks(male_rows[1])))
og1  <- suppressWarnings(as.numeric(as.character(og_keep[1, 2:23])))
check(length(row1)==22L && max(abs(row1 - og1)) < 1e-9, "MALES molt row1 == ogive(1982), 22 cols")
## FEMALES: same row count, constant
fend <- next_data(Vc, fa2+1L, function(x) grepl("^[[:space:]]*[0-9.]",x))
fe <- fend; while (fe <= length(Vc) && grepl("^[[:space:]]*[0-9.]", Vc[fe])) fe <- fe + 1L
female_rows <- Vc[fend:(fe-1L)]
check(length(female_rows) == expect_molt && length(unique(female_rows)) == 1L,
      sprintf("FEMALES molt matrix has %d identical (constant) rows", length(female_rows)))

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
for (fi in 1:4) {
  tl <- Filter(function(s) s$type=="data" && s$k==fi, tmpl_catch$segs)[[1]]$lines
  ol <- Filter(function(s) s$type=="data" && s$k==fi, out_catch$segs)[[1]]$lines
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
sc_surv_max <- max(vapply(6:13, function(k) {
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
  spot(pr_c$segs, 1, 2025, 5, 4.12549,    "retained catch 2025")
  spot(pr_c$segs, 2, 2025, 5, 2.517741,   "male-discard 2025")
  spot(pr_c$segs, 3, 2025, 5, 0.03027465, "female-discard 2025")
  spot(pr_c$segs, 4, 2025, 5, 0.4218131,  "bycatch 2025")
  ## index: female-mature era2 is run within the single index block; parse by Index id
  ir <- Filter(function(s) s$type=="data", pr_i$segs)[[1]]$lines
  ir_tok <- lapply(ir, toks)
  si_exp  <- read.csv(file.path(DERIVED, "survey_indices.csv"))
  exp_fem <- si_exp$biomass[si_exp$sex=="female" & si_exp$maturity=="mature" & si_exp$year==2026]
  exp_mmb <- si_exp$biomass[si_exp$sex=="male"   & si_exp$maturity=="mature" & si_exp$year==2026]
  fmr <- Filter(function(t) t[1]=="2" && t[2]=="2026", ir_tok)   # Index 2 = female mature era2
  check(length(fmr)==1 && abs(as.numeric(fmr[[1]][7]) - exp_fem) < 1e-2,
        sprintf("mature-female index 2026 = %.3f (matches survey_indices.csv)", exp_fem))
  mmb <- Filter(function(t) t[1]=="4" && t[2]=="2026", ir_tok)   # Index 4 = male mature era2 (MMB)
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
