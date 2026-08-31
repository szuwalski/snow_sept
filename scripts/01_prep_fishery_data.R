# =============================================================================
# 01_prep_fishery_data.R  --  EBS snow crab, September 2026 SAFE
#
# PURPOSE
#   Turn the ADFG fishery-removal files + NORPAC observer downloads into the
#   fishery-side model inputs: directed discard estimates, directed-fishery size
#   compositions (retained / total male / total female), trawl-bycatch size
#   compositions, non-directed bycatch weights, and growth increments.
#   Outputs land in data/derived/ and data/growth/, then get written into the model
#   .DAT/.CTL by 00_advance_model.R (no more hand-pasting).
#
# OUTPUTS  (all .csv; header row; explicit `year` column; values already in MODEL UNITS)
#   data/derived/directed_catch.csv       year, retained_male, discard_male, discard_female (kt)
#   data/derived/bycatch_catch.csv        year, trawl_bycatch, othercrab_bycatch, total_bycatch (kt)
#   data/derived/fishery_size_comps.csv   year, fleet, sex, type, m27.5..m132.5
#                                         (fleet1 retained/total/discard + fleet2 trawl bycatch; rows sum 1)
#   data/growth/growth_increments.csv     premolt, sex, increment, cv
#                                         (+ intermediate growth_increments_from_master.csv)
#   plots/male_discards.png, plots/bycatch.png
#
# INPUTS
#   data/new_catch/{retained_catch,total_catch,retained_catch_composition,
#                   directed_total_composition}.csv        (ADFG, via Tyler)
#   data/norpac_length_report/norpac_length_report.csv     (AKFIN Observer download)
#   data/norpac_catch_report/norpac_catch_report.csv       (AKFIN Observer download)
#   data/growth/{SnowCrabGrowthMaster.csv, growth_increments_base.csv}
#
# TERMINAL-YEAR KNOBS (advance each cycle):
#   * NORPAC date windows below: "2025-07-01" .. "2026-06-30" (crab year 2025).
#   * use_yrs <- seq(1991, 2026) in the all-years bycatch loop.
#
# NOTES / latent issues (flagged in-line; NOT changed):
#   * `disc` (bssc_discards.csv) is read but never used downstream.
#   * ALL carapace-width bins are cut with right = FALSE (2026-08, per Grant) -- the
#     "previous survey approach": a crab exactly on a 5-mm cutoff goes to the UPPER
#     bin. Big crab (>132.5) are captured by the plus group (top edge 999), NOT by
#     the right= setting. NB the accepted May model cut total-male with right = TRUE.
#   * `in_dat <- bycatch_dat_big[,-24]` drops a column by position (fragile).
# =============================================================================

# ---- Libraries --------------------------------------------------------------
library(dplyr); library(tidyr); library(reshape2)   # data wrangling
library(ggplot2)                                     # figures
library(png); library(grid)                          # raster/image helpers


# =============================================================================
# 1. LOAD ADFG FISHERY REMOVALS
# =============================================================================
ret_cat <- read.csv("data/new_catch/retained_catch.csv")
ret_cat$fish <- substring(ret_cat$fishery, 1, 2)       # 2-letter fishery code (QO = directed)
tot_cat <- read.csv("data/new_catch/total_catch.csv")
disc    <- read.csv("data/new_catch/bssc_discards.csv")  # NOTE: read but unused downstream

# females (kept for the directed female-catch column) and males-by-year/fishery
# (total catch weight in t; used for directed discards and other-fishery bycatch)
fems <- filter(tot_cat, group == 'female')
fems$fish <- substring(fems$fishery, 1, 2)

males <- filter(tot_cat, group != 'female') %>%
  group_by(crab_year, fishery) %>%
  dplyr::summarize(tot_cat = sum(total_catch_wt) / 1000)
males$fish <- substring(males$fishery, 1, 2)


# =============================================================================
# 2. DIRECTED-FISHERY CATCH  -> directed_catch.csv
# =============================================================================
# Diagnostic: total catch by fishery through time.
png("plots/male_discards.png")
ggplot(males) +
  geom_line(aes(x = crab_year, y = tot_cat, col = fish, group = fish)) +
  theme_bw() + ylab("Total catch")
dev.off()

# Directed (QO) discard = directed total catch - retained. Where that goes
# negative (data quirks), fall back to retained x the median positive discard rate.
directed_discard <- merge(ret_cat, filter(males, fish == "QO"))
directed_discard$tot_retained_wt <- directed_discard$tot_retained_wt / 1000
directed_discard$subtract_disc <- directed_discard$tot_cat - directed_discard$tot_retained_wt

chrp <- filter(directed_discard, subtract_disc > 0)
hist(chrp$subtract_disc / chrp$tot_cat)                # interactive diagnostic (not saved)
med_disc_rate <- median(chrp$subtract_disc / chrp$tot_cat)

directed_discard$use_disc <- directed_discard$subtract_disc
directed_discard$use_disc[which(directed_discard$subtract_disc < 0)] <-
  directed_discard$tot_retained_wt[which(directed_discard$subtract_disc < 0)] * med_disc_rate

# directed_catch.csv: one row per crab year, all weights already in MODEL UNITS (kt)
#   retained_male   = ADFG retained weight (tot_retained_wt, /1000 at L78)
#   discard_male    = directed (QO) male discard  (use_disc)
#   discard_female  = directed (QO) female total catch
# NOTE: the female column assumes filter(fems, fish=='QO') is row-aligned by crab_year
#       with directed_discard (same directed years, sorted) -- preserved from prior cycles.
directed_catch <- data.frame(
  year           = directed_discard$crab_year,
  retained_male  = directed_discard$tot_retained_wt,
  discard_male   = directed_discard$use_disc,
  discard_female = filter(fems, fish == 'QO')$total_catch_wt / 1000
)
write.csv(directed_catch, "data/derived/directed_catch.csv", row.names = FALSE)


# =============================================================================
# 3. DIRECTED-FISHERY SIZE COMPOSITIONS  -> fishery_size_comps.csv (fleet 1)
# =============================================================================
# Each block below follows the same pattern: sum crab by (crab_year, size), cut
# into 5-mm bins centred on 27.5..132.5, normalise within year (rows sum to 1),
# reshape wide, zero-fill unrepresented bins, and write.
# NB the bins are still zero-padded "super dumb" at the .DAT paste step (Cody's note).
ret_cat_sc <- read.csv("data/new_catch/retained_catch_composition.csv")
tot_cat_sc <- read.csv("data/new_catch/directed_total_composition.csv")

# ---- 3a. retained size comp (right = FALSE) ---------------------------------
data <- ret_cat_sc %>%
  group_by(crab_year, size) %>%
  dplyr::summarize(tot_crab = sum(total))

# 5-mm bin scaffolding (defined here, reused by the female/male blocks below)
midpoints <- seq(27.5, 132.5, by = 5)
bin_width <- 5
bin_edges <- c(midpoints - bin_width / 2, last(midpoints) + bin_width / 2)
bin_edges[length(bin_edges)] <- 999   # PLUS GROUP: fold all crab >=135 mm into the 132.5 top bin.
# Carried over 2026-07 from snow_crab/01_update_catch_data.R (line 63) -- this is the "plus group"
# in the accepted model "25.1 gmacs (... + plus group + ...)". It was MISSING in snow_sept, so the
# directed size comps previously DROPPED crab >=135 mm instead of folding them in. Applies to all
# three directed comps (retained, total female, total male) since they share bin_edges.

data <- data %>%
  dplyr::mutate(bin = cut(size, breaks = bin_edges, include.lowest = TRUE, right = FALSE, labels = midpoints))

binned_data <- data %>%
  group_by(crab_year, bin) %>%
  dplyr::summarize(tot_crab_sum = sum(tot_crab), .groups = 'drop')

normalized_data_ret <- binned_data %>%
  group_by(crab_year) %>%
  dplyr::mutate(total_crab_year = sum(tot_crab_sum),
         normalized_crab = tot_crab_sum / total_crab_year) %>%
  ungroup()

# ---- fixed 22-bin reshape helper (replaces the old dcast + by-hand zero-fill) ---
# Reindex a normalized long comp (crab_year, bin[factor labelled by midpoint],
# normalized_crab) onto ALL 22 model bins m27.5..m132.5, zero-filling gaps and
# DROPPING the stray NA bin (crab < 25 mm). Guarantees exactly 22 bin columns --
# this is what fixes the two hand-paste bugs (missing 122.5/127.5, stray NA col).
bin_cols <- paste0("m", midpoints)                    # "m27.5" .. "m132.5"
to_wide22 <- function(long_df) {
  w <- long_df %>%
    dplyr::filter(!is.na(bin)) %>%
    dplyr::mutate(bin = as.character(bin)) %>%
    tidyr::pivot_wider(id_cols = crab_year, names_from = bin,
                       values_from = normalized_crab, values_fill = 0)
  w <- as.data.frame(w)
  for (b in as.character(midpoints)) if (!b %in% names(w)) w[[b]] <- 0  # add absent bins
  out <- w[, as.character(midpoints), drop = FALSE]
  names(out) <- bin_cols
  cbind(year = w$crab_year, out)
}

ret_comp <- cbind(fleet = 1, sex = 1, type = 1, to_wide22(normalized_data_ret))

# ---- 3b. total FEMALE size comp (sex == 2; right = FALSE) -------------------
data <- filter(tot_cat_sc, sex == 2) %>%
  group_by(crab_year, size) %>%
  dplyr::summarize(tot_crab = sum(total))

data <- data %>%
  dplyr::mutate(bin = cut(size, breaks = bin_edges, include.lowest = TRUE, right = FALSE, labels = midpoints))

binned_data <- data %>%
  group_by(crab_year, bin) %>%
  dplyr::summarize(tot_crab_sum = sum(tot_crab), .groups = 'drop')

normalized_data_tot <- binned_data %>%
  group_by(crab_year) %>%
  dplyr::mutate(total_crab_year = sum(tot_crab_sum),
                normalized_crab = tot_crab_sum / total_crab_year) %>%
  ungroup()

totf_comp <- cbind(fleet = 1, sex = 2, type = 2, to_wide22(normalized_data_tot))

# ---- 3c. total MALE size comp (sex == 1) ------------------------------------
# right = FALSE, same as 3a/3b (consistent upper-bin convention, 2026-08 per Grant).
# NB the accepted May model cut THIS comp with right = TRUE, so total-male differs.
data <- filter(tot_cat_sc, sex == 1) %>%
  group_by(crab_year, size) %>%
  dplyr::summarize(tot_crab = sum(total))

data <- data %>%
  dplyr::mutate(bin = cut(size, breaks = bin_edges, include.lowest = TRUE, right = FALSE, labels = midpoints))

binned_data <- data %>%
  group_by(crab_year, bin) %>%
  dplyr::summarize(tot_crab_sum = sum(tot_crab), .groups = 'drop')

normalized_data_tot <- binned_data %>%
  group_by(crab_year) %>%
  dplyr::mutate(total_crab_year = sum(tot_crab_sum),
         normalized_crab = tot_crab_sum / total_crab_year) %>%
  ungroup()

totm_comp <- cbind(fleet = 1, sex = 1, type = 0, to_wide22(normalized_data_tot))


# =============================================================================
# 4. TRAWL-BYCATCH SIZE COMPOSITIONS  (NORPAC "Length Report")
# =============================================================================
# Source: AKFIN "Observer data" tab -> "NORPAC Length Report - Haul & Length",
# snow crab, for July 1 (prev yr) .. June 30 (this yr). Binned into the 22 model
# bins (27.5..132.5, right = FALSE) with a 132.5+ plus group; normalised by sex.
#
# AKFIN prepends a "Parameter Value(s)" preamble whose length depends on how many
# filters the export carried (Year / FMP Area / Species Name / ...), so the column
# header is NOT at a fixed offset -- a plain skip=6/7 breaks whenever that count
# changes. Locate the header instead: it is the first line starting with "Year",
# (the data columns), as opposed to the "Year: ..." parameter echo lines above it.
read_norpac <- function(path) {
  hdr <- grep('^"Year",', readLines(path, n = 40))[1]
  if (is.na(hdr)) stop("NORPAC column header (\"Year\",...) not found in ", path)
  read.csv(path, skip = hdr - 1)
}
LenDatBig <- read_norpac("data/norpac_length_report/norpac_length_report.csv")
LenDatBig$Haul.Offload.Date <- strptime(LenDatBig$Haul.Offload.Date, format = "%d-%b-%y")
range(LenDatBig$Haul.Offload.Date)                     # sanity print of the date range

# ---- all years (1991 .. terminal) -------------------------------------------
use_yrs <- seq(1991, 2026)   # advance terminal year each cycle
bycatch_fem_sc  <- NULL
bycatch_male_sc <- NULL

# Bin each crab year's observed lengths into the SAME 22 model bins as the directed
# comps: cut() with right = FALSE and the shared bin_edges (top edge 999 = the 132.5+
# plus group), so every specimen >132.5 mm (there are real ones -- ~4356 records,
# up to ~218 mm) folds into the top bin instead of being dropped. tapply keeps all
# 22 factor levels in midpoint order (27.5 .. 132.5).
tab22 <- function(len, freq) {
  b <- cut(len, breaks = bin_edges, include.lowest = TRUE, right = FALSE, labels = midpoints)
  v <- tapply(freq, b, sum)
  v[is.na(v)] <- 0
  as.numeric(v)
}
for (x in 1:(length(use_yrs) - 1)) {
  LenDat <- LenDatBig[LenDatBig$Haul.Offload.Date >= paste(use_yrs[x], "-07-01", sep = "") & LenDatBig$Haul.Offload.Date <= paste(use_yrs[x] + 1, "-06-30", sep = "") & LenDatBig$Species.Name == "OPILIO TANNER CRAB", ]
  fem  <- LenDat[LenDat$Sex == "F", ]
  male <- LenDat[LenDat$Sex == "M", ]
  BycatchFem  <- tab22(fem$Length..cm.,  fem$Frequency)
  BycatchMale <- tab22(male$Length..cm., male$Frequency)
  bycatch_fem_sc  <- rbind(bycatch_fem_sc,  round(BycatchFem / sum(BycatchFem), 3))
  bycatch_male_sc <- rbind(bycatch_male_sc, round(BycatchMale / sum(BycatchMale), 3))
}

# attach the crab year to each bycatch comp row (loop used use_yrs[x] as the start
# year, x = 1..length-1  ->  years 1991 .. terminal-1 = 2025). The 22 bycatch bins
# (left edges 25..130) align positionally with the model midpoints 27.5..132.5.
byc_years  <- use_yrs[1:(length(use_yrs) - 1)]
byc_f_comp <- data.frame(fleet = 2, sex = 2, type = 2, year = byc_years,
                         setNames(as.data.frame(bycatch_fem_sc),  bin_cols), check.names = FALSE)
byc_m_comp <- data.frame(fleet = 2, sex = 1, type = 2, year = byc_years,
                         setNames(as.data.frame(bycatch_male_sc), bin_cols), check.names = FALSE)

# ---- consolidated fishery size comps -> fishery_size_comps.csv ----------------
# One tidy file, one row per (series, year); rows sum to 1.
#   columns: year, fleet, sex, type, m27.5 .. m132.5
#   fleet 1 = directed pot, 2 = trawl bycatch ; sex 1 = male, 2 = female
#   type  1 = retained, 0 = total, 2 = discard/bycatch
col_order <- c("year", "fleet", "sex", "type", bin_cols)
fishery_size_comps <- rbind(
  ret_comp[,  col_order],   # retained males      (fleet 1, sex 1, type 1)
  totm_comp[, col_order],   # total males         (fleet 1, sex 1, type 0)
  totf_comp[, col_order],   # total/discard fem   (fleet 1, sex 2, type 2)
  byc_f_comp[, col_order],  # trawl bycatch fem   (fleet 2, sex 2, type 2)
  byc_m_comp[, col_order]   # trawl bycatch male  (fleet 2, sex 1, type 2)
)
write.csv(fishery_size_comps, "data/derived/fishery_size_comps.csv", row.names = FALSE)


# =============================================================================
# 5. NON-DIRECTED BYCATCH WEIGHTS  (NORPAC "Catch Report" + other crab fisheries)
# =============================================================================
# Source: AKFIN "Observer data" tab -> "NORPAC Catch Report", snow crab in the BS
# of BSAI, Jul 1 (prev yr) .. Jun 30 (this yr). read_norpac() (Section 4) locates
# the column header below AKFIN's variable-length parameter preamble.
bycatch_dat <- read_norpac("data/norpac_catch_report/norpac_catch_report.csv")
temp <- strptime(bycatch_dat$Haul.Date, format = "%d-%b-%y")
bycatch_dat$Haul.Date <- substr(temp, start = 1, stop = 10)

# latest crab year total (trawl only: exclude POT OR TRAP gear)
bycatchDat <- bycatch_dat[bycatch_dat$Haul.Date >= "2025-07-01" & bycatch_dat$Haul.Date <= "2026-06-30" &
                          bycatch_dat$Species.Name == "OPILIO TANNER CRAB" & bycatch_dat$Gear.Description != "POT OR TRAP", ]
bycatch_num_tot <- sum(bycatchDat$Extrapolated.Number, na.rm = T)
bycatch_wt_tot  <- sum(bycatchDat$Extrapolated.Weight..kg., na.rm = T)

# ---- all years: extrapolated bycatch number/weight per crab year ------------
bycatch_dat_big <- bycatch_dat
#temp<-strptime(bycatch_dat_big$Haul.Date,format="%y-%b-%d")
#bycatch_dat_big$Haul.Date<-substr(temp,start=1,stop=10)
bycatch_dat_big$crab.year <- bycatch_dat_big$Year

bycatch_year    <- sort(unique(bycatch_dat_big$Year))
bycatch_num_tot <- rep(0, length(bycatch_year))
bycatch_wt_tot  <- rep(0, length(bycatch_year))

for (y in 1:(length(bycatch_year) - 1)) {
  bycatchDat <- bycatch_dat_big[bycatch_dat_big$Haul.Date >= paste(bycatch_year[y], "-07-01", sep = "") & bycatch_dat_big$Haul.Date <= paste(bycatch_year[y] + 1, "-06-30", sep = "") &
                                bycatch_dat_big$Species.Name == "OPILIO TANNER CRAB", ]
  bycatch_num_tot[y] <- sum(bycatchDat$Extrapolated.Number, na.rm = T)
  bycatch_wt_tot[y]  <- sum(bycatchDat$Extrapolated.Weight..kg., na.rm = T)
}

# ---- combine trawl bycatch (0.8 mortality) + other crab fisheries (0.3) ------
# other-crab-fishery bycatch = non-QO fisheries in total_catch, x 0.3 pot mortality
all_crab_bycatch <- filter(males, fish != "QO") %>%
  group_by(crab_year) %>%
  dplyr::summarize(all_crab_bycatch = sum(tot_cat, na.rm = T) * 0.3)

# trawl (non-directed) bycatch weight: kg -> kt, x 0.8 trawl mortality
nondir <- cbind(bycatch_year, bycatch_wt_tot)
nondir[, 2] <- (nondir[, 2] / 1000000) * 0.8
colnames(nondir)[1] <- 'crab_year'

all_nondir_bycatch <- merge(all_crab_bycatch, nondir)
all_nondir_bycatch$tot_nondir <- all_nondir_bycatch$all_crab_bycatch + all_nondir_bycatch$bycatch_wt_tot
# bycatch_catch.csv (kt): trawl-only bycatch, other-crab-fishery bycatch, and their
# sum. NB the old file called the trawl-only piece "bycatch_wt_tot" (a misnomer --
# the actual total is total_bycatch, = the .dat non-directed bycatch obs).
bycatch_catch <- data.frame(
  year              = all_nondir_bycatch$crab_year,
  trawl_bycatch     = all_nondir_bycatch$bycatch_wt_tot,
  othercrab_bycatch = all_nondir_bycatch$all_crab_bycatch,
  total_bycatch     = all_nondir_bycatch$tot_nondir
)
write.csv(bycatch_catch, "data/derived/bycatch_catch.csv", row.names = FALSE)

# ---- diagnostic figure: bycatch numbers by gear type ------------------------
for (y in 1:(length(bycatch_year) - 1))
  bycatch_dat_big$crab.year[bycatch_dat_big$Haul.Date >= paste(bycatch_year[y], "-07-01", sep = "") & bycatch_dat_big$Haul.Date <= paste(bycatch_year[y] + 1, "-06-30", sep = "")] <- bycatch_year[y]

in_dat <- bycatch_dat_big[, -24]     # NOTE: drops column 24 by position (fragile)
temp <- in_dat %>%
  group_by(crab.year, Gear.Description) %>%
  dplyr::summarise(Bycatch = sum(Extrapolated.Number))

temp$Year <- as.numeric(temp$crab.year)

temp$Gear.Description[temp$Gear.Description == "NON PELAGIC"] <- "NON-PELAGIC TRAWL"
temp$Gear.Description[temp$Gear.Description == "PELAGIC"] <- "PELAGIC TRAWL"
png("plots/bycatch.png", height = 8, width = 8, res = 400, units = 'in')
ggplot(temp) +
  geom_line(aes(x = crab.year, y = Bycatch, col = Gear.Description)) +
  geom_point(aes(x = crab.year, y = Bycatch, col = Gear.Description)) +
  theme_bw() + theme(legend.position = c(.8, .8))
dev.off()


# =============================================================================
# 6. GROWTH INCREMENTS  -> growth_increments_from_master / _final
# =============================================================================
# From the specimen master: keep crab with no missing premolt legs, compute the
# molt increment, attach a fixed CV of 0.03. Then merge with the base (assumed)
# increment set, keeping only new rows not already present.
grow <- read.csv("data/growth/SnowCrabGrowthMaster.csv")
use_grow <- filter(grow, Legs_missing_premolt == 0)
use_grow$molt_inc <- use_grow$Postmolt_CW - use_grow$Premolt_CW
new_grow <- cbind(use_grow[, c(6, 3, 17)], rep(0.03, nrow(use_grow)))   # premolt CW, sex, molt_inc, cv
colnames(new_grow) <- c("premolt", "sex", "increment", "cv")           # (col4 header used to be a raw R expr)
write.csv(new_grow, 'data/growth/growth_increments_from_master.csv', row.names = FALSE)

ass_grow <- read.csv('data/growth/growth_increments_base.csv')
keepers <- ass_grow
colnames(keepers)  <- c("pre", "sex", "inc", "cv")
colnames(new_grow) <- c("pre", "sex", "inc", "cv")
for (x in 1:nrow(new_grow)) {
  check <- new_grow[x, ]
  takeit <- 1
  for (y in 1:length(ass_grow)) {
    matched <- sum(!is.na(match(check, ass_grow[y, ])))
    if (matched == 4)
      takeit <- 0
  }
  if (takeit == 1)
    keepers <- rbind(keepers, check)
}

colnames(keepers) <- c("premolt", "sex", "increment", "cv")
write.csv(keepers, 'data/growth/growth_increments.csv', row.names = FALSE)
