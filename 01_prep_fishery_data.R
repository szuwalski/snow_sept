# =============================================================================
# 01_prep_fishery_data.R  --  EBS snow crab, September 2026 SAFE
#
# PURPOSE
#   Turn the ADFG fishery-removal files + NORPAC observer downloads into the
#   fishery-side model inputs: directed discard estimates, directed-fishery size
#   compositions (retained / total male / total female), trawl-bycatch size
#   compositions, non-directed bycatch weights, and growth increments.
#   Outputs land in data/derived/ (then hand-pasted into the model .DAT -- Cody's
#   existing workflow, flagged for future automation) and data/growth/.
#
# OUTPUTS
#   data/derived/dir_disc_m_f.csv                directed discard (male) + female catch
#   data/derived/ret_sc.csv                      retained size composition
#   data/derived/tot_sc_f.csv, tot_sc_m.csv      total catch size comp (female / male)
#   data/derived/bycatch_len_comps_f_then_m.txt  latest-year trawl bycatch size comp
#   data/derived/bycatch_len_comps_f.txt, _m.txt all-years trawl bycatch size comps
#   data/derived/bycatch_wt_total.csv            total non-directed bycatch weight
#   data/growth/growth_increments_from_master.csv, growth_increments_final.csv
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
#   * total-MALE size comp bins with right = TRUE, while retained and total-female
#     use right = FALSE -- an endpoint-inclusion inconsistency worth confirming.
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
# 2. DIRECTED-FISHERY DISCARD ESTIMATES  -> dir_disc_m_f.csv
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

# columns: crab_year, directed male discard (t), directed female total catch (t)
write.csv(cbind(directed_discard$crab_year, directed_discard$use_disc, filter(fems, fish == 'QO')$total_catch_wt / 1000),
          "data/derived/dir_disc_m_f.csv")


# =============================================================================
# 3. DIRECTED-FISHERY SIZE COMPOSITIONS  -> ret_sc / tot_sc_f / tot_sc_m
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

# NOTE: retained AND total-catch comps still need zeros inserted for
# unrepresented size classes -- currently done by hand at the .DAT paste step.
output <- dcast(normalized_data_ret, crab_year ~ bin, id.var = 'normalized_crab')
output[is.na(output)] <- 0
rownames(output) <- output[, 1]
write.csv(output[, -1], "data/derived/ret_sc.csv")

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

output <- dcast(normalized_data_tot, crab_year ~ bin, id.var = 'normalized_crab')
output[is.na(output)] <- 0
rownames(output) <- output[, 1]
write.csv(output[, -1], "data/derived/tot_sc_f.csv")

# ---- 3c. total MALE size comp (sex == 1) ------------------------------------
# >>> NOTE (inconsistency): this block cuts with right = TRUE, whereas the
#     retained (3a) and total-female (3b) blocks use right = FALSE. That changes
#     which crab fall on a bin boundary. Preserved as-is (matches prior cycles);
#     worth confirming with Cody whether the difference is intentional.
data <- filter(tot_cat_sc, sex == 1) %>%
  group_by(crab_year, size) %>%
  dplyr::summarize(tot_crab = sum(total))

data <- data %>%
  dplyr::mutate(bin = cut(size, breaks = bin_edges, include.lowest = TRUE, right = TRUE, labels = midpoints))

binned_data <- data %>%
  group_by(crab_year, bin) %>%
  dplyr::summarize(tot_crab_sum = sum(tot_crab), .groups = 'drop')

normalized_data_tot <- binned_data %>%
  group_by(crab_year) %>%
  dplyr::mutate(total_crab_year = sum(tot_crab_sum),
         normalized_crab = tot_crab_sum / total_crab_year) %>%
  ungroup()

output <- dcast(normalized_data_tot, crab_year ~ bin, id.var = 'normalized_crab')
output[is.na(output)] <- 0
rownames(output) <- output[, 1]
write.csv(output[, -1], "data/derived/tot_sc_m.csv")


# =============================================================================
# 4. TRAWL-BYCATCH SIZE COMPOSITIONS  (NORPAC "Length Report")
# =============================================================================
# Source: AKFIN "Observer data" tab -> "NORPAC Length Report - Haul & Length",
# snow crab, for July 1 (prev yr) .. June 30 (this yr). Binned 25..135 mm with a
# 130-mm plus group; normalised by sex.
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

# ---- 4a. latest crab year only ----------------------------------------------
# CHECK DATES: crab year 2025 = Jul 1 2025 .. Jun 30 2026 (advance each cycle).
LenDat <- LenDatBig[LenDatBig$Haul.Offload.Date >= "2025-07-01" & LenDatBig$Haul.Offload.Date <= "2026-06-30" & LenDatBig$Species.Name == "OPILIO TANNER CRAB", ]

LengthBins <- seq(25, 135, 5)
BycatchFem  <- rep(0, length(LengthBins))
BycatchMale <- rep(0, length(LengthBins))

for (y in 1:(length(LengthBins) - 1)) {
  BycatchFem[y]  <- sum(LenDat$Frequency[LenDat$Length..cm. >= LengthBins[y] & LenDat$Length..cm. < LengthBins[y + 1] & LenDat$Sex == "F"])
  BycatchMale[y] <- sum(LenDat$Frequency[LenDat$Length..cm. >= LengthBins[y] & LenDat$Length..cm. < LengthBins[y + 1] & LenDat$Sex == "M"])
}

# fold everything >= 130 mm into the 130 plus group
upperBnd <- 130
BycatchFem[which(LengthBins == upperBnd)]  <- sum(BycatchFem[(which(LengthBins == upperBnd)):length(LengthBins)])
BycatchFem  <- BycatchFem[1:which(LengthBins == upperBnd)]
BycatchMale[which(LengthBins == upperBnd)] <- sum(BycatchMale[(which(LengthBins == upperBnd)):length(LengthBins)])
BycatchMale <- BycatchMale[1:which(LengthBins == upperBnd)]

# par(mfrow=c(1,2))
# barplot(BycatchFem,names.arg=LengthBins,xlab="Carapace width (mm)",ylab="Count")
# barplot(BycatchMale)

by_f_out <- BycatchFem / sum(BycatchFem)
by_m_out <- BycatchMale / sum(BycatchMale)
write.table(rbind(by_f_out, by_m_out), "data/derived/bycatch_len_comps_f_then_m.txt",
            row.names = FALSE, col.names = F)

# ---- 4b. all years (1991 .. terminal) ---------------------------------------
use_yrs <- seq(1991, 2026)   # advance terminal year each cycle
bycatch_fem_sc  <- NULL
bycatch_male_sc <- NULL
LengthBins <- seq(25, 135, 5)

for (x in 1:(length(use_yrs) - 1)) {
  LenDat <- LenDatBig[LenDatBig$Haul.Offload.Date >= paste(use_yrs[x], "-07-01", sep = "") & LenDatBig$Haul.Offload.Date <= paste(use_yrs[x] + 1, "-06-30", sep = "") & LenDatBig$Species.Name == "OPILIO TANNER CRAB", ]
  BycatchFem  <- rep(0, length(LengthBins))
  BycatchMale <- rep(0, length(LengthBins))

  for (y in 1:(length(LengthBins) - 1)) {
    BycatchFem[y]  <- sum(LenDat$Frequency[LenDat$Length..cm. >= LengthBins[y] & LenDat$Length..cm. < LengthBins[y + 1] & LenDat$Sex == "F"])
    BycatchMale[y] <- sum(LenDat$Frequency[LenDat$Length..cm. >= LengthBins[y] & LenDat$Length..cm. < LengthBins[y + 1] & LenDat$Sex == "M"])
  }

  upperBnd <- 130
  BycatchFem[which(LengthBins == upperBnd)]  <- sum(BycatchFem[(which(LengthBins == upperBnd)):length(LengthBins)])
  BycatchFem  <- BycatchFem[1:which(LengthBins == upperBnd)]
  BycatchMale[which(LengthBins == upperBnd)] <- sum(BycatchMale[(which(LengthBins == upperBnd)):length(LengthBins)])
  BycatchMale <- BycatchMale[1:which(LengthBins == upperBnd)]

  bycatch_fem_sc  <- rbind(bycatch_fem_sc,  round(BycatchFem / sum(BycatchFem), 3))
  bycatch_male_sc <- rbind(bycatch_male_sc, round(BycatchMale / sum(BycatchMale), 3))
}

write.table(bycatch_fem_sc, "data/derived/bycatch_len_comps_f.txt",
            row.names = FALSE, col.names = F)
write.table(bycatch_male_sc, "data/derived/bycatch_len_comps_m.txt",
            row.names = FALSE, col.names = F)


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
write.csv(all_nondir_bycatch, "data/derived/bycatch_wt_total.csv")

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
new_grow <- cbind(use_grow[, c(6, 3, 17)], rep(0.03, nrow(use_grow)))   # cols: premolt CW, sex, molt_inc, + cv
write.csv(new_grow, 'data/growth/growth_increments_from_master.csv')

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

write.csv(keepers, 'data/growth/growth_increments_final.csv')
