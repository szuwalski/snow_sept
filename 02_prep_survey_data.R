# =============================================================================
# 02_prep_survey_data.R  --  EBS snow crab, September 2026 SAFE
#
# PURPOSE
#   Pull the EBS summer bottom-trawl SURVEY specimen data from crabpack and
#   derive the survey-side model inputs:
#     * male size compositions by shell condition (new / old), 5-mm bins
#     * male terminal-molt (maturity) ogive
#     * mature / immature male survey size comps and biomass indices
#     * several diagnostic figures
#   Outputs land in data/derived/ (then hand-pasted into the model .DAT),
#   data/survey/, and plots/.
#
# OUTPUTS  (consumed downstream -- keep these paths in sync with the .DAT paste
#           step and the Rmd if you ever rename them)
#   data/survey/survey_large_male_index_derived.csv   large/preferred male index
#   data/derived/index_female_biomass_male_cv.csv     female biomass + CVs
#   data/derived/2prob_term_molt_males_new.csv        male prob-terminal-molt array
#   data/derived/2surv_len_comp_male_mat_newmat.txt   mature male size comp
#   data/derived/2surv_len_comp_male_imm_newmat.txt   immature male size comp
#   data/derived/2index_mmb_new_mat.txt               mature male biomass index
#   data/derived/2index_imm_male_new_mat.txt          immature male biomass index
#   plots/size_bins_comp_Kodiak_m.png, maturity_facet.png,
#   plots/maturity_facet_all.png, plots/imm_v_mat.png
#
# PREREQUISITES
#   * R 4.5.1; run from the repo root.
#   * crabpack API access (channel = 'API') AND the target survey year loaded in
#     the API. The terminal survey year is the 2026 in get_specimen_data() below.
#   * data/maturity/snow_ogives.csv -- Ryznar's smoothed maturity ogive (Section 5).
#     Must cover the same terminal year as the survey pull, or Section 6 misaligns.
#
# NOTES
#   * Section 2's mature-female pull (`mat_fem_snow_ind`) was restored 2026-07
#     from Cody's snow_crab hybrid script (it had been dropped when this script
#     was copied into snow_sept).
#   * Section 5 builds the maturity array by RESHAPING that ogive onto the model
#     bins -- no GAM refit; the old pre-baked SNOW_male_pmolt_array.csv and the
#     unused get_male_maturity() API pull were removed 2026-08.
# =============================================================================

# ---- Libraries --------------------------------------------------------------
library(crabpack)                        # survey pull + bioabundance
library(dplyr); library(tidyr); library(reshape2)   # data wrangling
library(ggplot2); library(ggridges); library(patchwork)  # figures
library(png); library(grid)              # raster/image helpers

# ---- Helpers ----------------------------------------------------------------
# annotation_custom2(): place a grob (e.g. a background image) on a ggplot facet.
# NOTE: currently UNUSED in this script (kept from a prior version that overlaid
#       a snow-crab image; see the commented readPNG below). Safe to delete if
#       the background image is not coming back.
annotation_custom2 <- function(grob, xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, data) {
  layer(data = data,
        stat = StatIdentity,
        position = PositionIdentity,
        geom = ggplot2:::GeomCustomAnn,
        inherit.aes = TRUE,
        params = list(grob = grob, xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax))
}
# in_png_opie <- readPNG('continuity/snowcrab.png')   # (background image; unused)


# =============================================================================
# 1. PULL SURVEY SPECIMEN DATA  (crabpack API)
# =============================================================================
# years = 1982:2026  ->  terminal year = the 2026 summer survey (advance each
# cycle). Requires API access; everything below derives from `specimen_data`.
specimen_data <- crabpack::get_specimen_data(species = "SNOW",
                                             region  = "EBS",
                                             years   = c(1982:2026),
                                             channel = 'API')


# =============================================================================
# 2. MALE ABUNDANCE / BIOMASS INDICES
# =============================================================================
# Legal males (used only as a rough MMB-CV proxy, below) and large + preferred
# males (the >101 mm index written out for the report/model).
male_snow_ind <- crabpack::calc_bioabund(crab_data = specimen_data,
                                         species = "SNOW",
                                         region  = "EBS",
                                         crab_category = c("legal_male"))

big_male_snow_ind <- crabpack::calc_bioabund(crab_data = specimen_data,
                                             species = "SNOW",
                                             region  = "EBS",
                                             crab_category = c("large_male", "preferred_male"))

write.csv(big_male_snow_ind, "data/survey/survey_large_male_index_derived.csv")

# Mature-female survey biomass index (morphometric maturity).
# RESTORED 2026-07: this definition was dropped when the script was copied into
# snow_sept, which is why Section 2 previously errored on an undefined
# `mat_fem_snow_ind`. Taken verbatim from Cody's working
# snow_crab/02_make_DAT_file_hybrid.R (the `newmature` ancestor relied on this
# object lingering in the session from a prior run of the hybrid script).
mat_fem_snow_ind <- crabpack::calc_bioabund(crab_data = specimen_data,
                                            species = "SNOW",
                                            region  = "EBS",
                                            crab_category   = c("mature_female"),
                                            female_maturity = "morphometric")

# Survey female biomass + CVs written for the model: female biomass (kt), female
# CV, and legal-male CV as a stand-in for the MMB CV (no direct MMB CV; ~>76 mm).
write.csv(cbind(mat_fem_snow_ind$BIOMASS_MT / 1000,
                mat_fem_snow_ind$BIOMASS_MT_CV,
                male_snow_ind$BIOMASS_MT_CV),
          "data/derived/index_female_biomass_male_cv.csv")


# =============================================================================
# 3. MALE NUMBERS-AT-SIZE  (1-mm bins, all shell conditions)
# =============================================================================
# Fine-scale (1-mm) male numbers-at-size; feeds the diagnostic ridge plot here
# and is re-binned to 5 mm in Section 4.
male_snow <- crabpack::calc_bioabund(crab_data = specimen_data,
                                     species = "SNOW",
                                     region  = "EBS",
                                     sex = 'male',
                                     shell_condition = "all_categories",
                                     size_min = 25,
                                     bin_1mm  = TRUE)

# ---- 3a. Diagnostic figure: numbers-at-size ridges --------------------------
# Full range (left panel) beside a >100 mm zoom (right panel).
natl_viz <- male_snow %>%
  group_by(YEAR, SIZE_1MM) %>%
  summarize(tot_n = sum(ABUNDANCE))

p <- ggplot(dat = natl_viz)
p <- p + geom_density_ridges(aes(x = SIZE_1MM, y = YEAR, height = tot_n,
                                 group = YEAR,
                                 fill = stat(y), alpha = .9999), stat = "identity", scale = 5, fill = '#619CFF') +
  theme_bw() +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 90)) +
  labs(x = "Carapace width (mm)") +
  xlim(25, 135)

# NOTE: natl_viz_b (the >100 mm subset) is computed but not used -- the zoom
#       panel `ap` below re-uses natl_viz with xlim(100,135). Kept as-is.
natl_viz_b <- filter(male_snow, SIZE_1MM > 100) %>%
  group_by(YEAR, SIZE_1MM) %>%
  summarize(tot_n = sum(ABUNDANCE))

ap <- ggplot(dat = natl_viz)
ap <- ap + geom_density_ridges(aes(x = SIZE_1MM, y = YEAR, height = tot_n,
                                   group = YEAR,
                                   fill = stat(y), alpha = .9999), stat = "identity", scale = 5, fill = '#00BA38') +
  theme_bw() +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 90)) +
  labs(x = "Carapace width (mm)") +
  xlim(100, 135)

png("plots/size_bins_comp_Kodiak_m.png", height = 9, width = 6, res = 400, units = 'in')
(p | ap) + plot_layout(widths = c(2.5, 1))
dev.off()

# Quick interactive diagnostic (abundance by shell text over time); not saved.
yarp <- male_snow %>%
  group_by(YEAR, SHELL_TEXT) %>%
  summarize(tot_n = sum(ABUNDANCE))

ggplot(yarp) +
  geom_line(aes(x = YEAR, y = tot_n, col = SHELL_TEXT)) + theme_bw()


# =============================================================================
# 4. MALE SIZE COMPOSITIONS BY SHELL CONDITION  (5-mm bins, 27.5-132.5 + plus grp)
# =============================================================================
# Re-bin the 1-mm male numbers to 5-mm bins separately for new-shell
# (new_hardshell + soft_molting) and old-shell (oldshell + very_oldshell), then
# reshape wide, constrain to the model's 27.5-132.5 bins with a 132.5+ plus
# group, and convert to millions of crab -> MaleNew, MaleOld.
# NB: keep endpoint inclusion (right = FALSE) consistent with every other data
#     source that bins carapace width.

# ---- new-shell males --------------------------------------------------------
new_male_snow <- filter(male_snow, SHELL_TEXT %in% c('new_hardshell', 'soft_molting')) %>%
  group_by(YEAR, group = cut(SIZE_1MM, breaks = seq(0, max(SIZE_1MM), 5), right = FALSE)) %>%
  summarise(n = sum(ABUNDANCE),
            data = 'crabpack')

# derive the numeric bin midpoint from the "[lo,hi)" factor label
tmp <- strsplit(as.character(new_male_snow$group), ',')
new_male_snow$mid_pts <- NA
for (x in 1:length(tmp)) {
  in1 <- as.numeric(substr(unlist(tmp[x])[1], 2, nchar(unlist(tmp[x])[1])))
  in2 <- as.numeric(substr(unlist(tmp[x])[2], 1, nchar(unlist(tmp[x])[2]) - 1))
  new_male_snow$mid_pts[x] <- sum(in1, in2) / 2
}

# ---- old-shell males --------------------------------------------------------
old_male_snow <- filter(male_snow, SHELL_TEXT %in% c('oldshell', 'very_oldshell')) %>%
  group_by(YEAR, group = cut(SIZE_1MM, breaks = seq(0, max(SIZE_1MM), 5), right = FALSE)) %>%
  summarise(n = sum(ABUNDANCE),
            data = 'crabpack')

tmp <- strsplit(as.character(old_male_snow$group), ',')
old_male_snow$mid_pts <- NA
for (x in 1:length(tmp)) {
  in1 <- as.numeric(substr(unlist(tmp[x])[1], 2, nchar(unlist(tmp[x])[1])))
  in2 <- as.numeric(substr(unlist(tmp[x])[2], 1, nchar(unlist(tmp[x])[2]) - 1))
  old_male_snow$mid_pts[x] <- sum(in1, in2) / 2
}

# ---- reshape to year x size-bin matrices ------------------------------------
in_old <- old_male_snow[, c(1, 3, 5)]
old_male_wide <- dcast(in_old, YEAR ~ mid_pts, value.var = c("n"))

in_new <- new_male_snow[, c(1, 3, 5)]
new_male_wide <- dcast(in_new, YEAR ~ mid_pts, value.var = c("n"))

# ---- constrain to the model size bins + 132.5 plus group --------------------
# (Cody's note: this bin-constraining is awkward and should eventually move into
#  the data pull.) Everything above 132.5 mm is summed into the top bin.
sizes <- seq(27.5, 132.5, 5)

use_old_male <- old_male_wide[, which(!is.na(match(as.numeric(colnames(old_male_wide)), sizes)))]
rownames(use_old_male) <- (old_male_wide[, 1])
use_old_male[, ncol(use_old_male)] <- use_old_male[, ncol(use_old_male)] +
  apply(old_male_wide[, which(as.numeric(colnames(old_male_wide)) > 132.5)], 1, sum)

use_new_male <- new_male_wide[, which(!is.na(match(as.numeric(colnames(new_male_wide)), sizes)))]
rownames(use_new_male) <- (new_male_wide[, 1])
use_new_male[, ncol(use_new_male)] <- use_new_male[, ncol(use_new_male)] +
  apply(new_male_wide[, which(as.numeric(colnames(new_male_wide)) > 132.5)], 1, sum)

MaleOld <- use_old_male / 1000000   # -> millions of crab
MaleNew <- use_new_male / 1000000


# =============================================================================
# 5. MALE TERMINAL-MOLT (MATURITY) OGIVE
# =============================================================================
# Probability of being (terminally) mature at size, by year. The live input is
# Emily Ryznar's SMOOTHED maturity ogive, data/maturity/snow_ogives.csv -- a
# long/tidy table of PROP_MATURE at observed 5-mm sizes (emailed; already the
# fitted product). Because the smoothing is done upstream, we RESHAPE it onto the
# model's 27.5-132.5 bins rather than refitting: pivot to year x bin, then fill
# any bin outside a year's observed size range (immature = 0 below, mature = 1
# above -- the same clamping the ogive itself applies). Years with no ogive at all
# are filled further below with the across-year mean at size.
#
# Historical note: earlier cycles read a pre-baked SNOW_male_pmolt_array.csv that
#   Cody produced by fitting a per-year GAM to this ogive (gam(PROP_MATURE ~
#   s(SIZE_BIN, k = 20)) then predicting onto these bins). That smoothing now lives
#   in Ryznar's product, so we no longer refit -- we only reshape. Re-check the
#   column names if crabpack/Ryznar rename SIZE_5MM / PROP_MATURE.
new_dat <- seq(27.5, 132.5, 5)                       # the 22 model size bins

new_male_mat_dat <- read.csv("data/maturity/snow_ogives.csv") %>%
  filter(SIZE_5MM %in% new_dat) %>%
  select(YEAR, SIZE_5MM, PROP_MATURE) %>%
  tidyr::pivot_wider(names_from = SIZE_5MM, values_from = PROP_MATURE) %>%
  arrange(YEAR) %>%
  as.data.frame()
new_male_mat_dat <- new_male_mat_dat[, c("YEAR", as.character(new_dat))]
# fill model bins outside each year's observed size range (0 below, 1 above)
for (i in seq_len(nrow(new_male_mat_dat))) {
  v   <- as.numeric(new_male_mat_dat[i, -1])
  obs <- new_dat[!is.na(v)]
  if (length(obs)) {
    v[new_dat < min(obs) & is.na(v)] <- 0
    v[new_dat > max(obs) & is.na(v)] <- 1
    new_male_mat_dat[i, -1] <- v
  }
}

# build a (year x size-bin) maturity matrix, filling missing years with the mean
all_yr <- seq(1982, max(new_male_mat_dat[, 1]))
allmat <- matrix(nrow = length(all_yr), ncol = length(new_dat))
rownames(allmat) <- all_yr
colnames(allmat) <- new_dat
yrs <- unique(new_male_mat_dat[, 1])
for (x in 1:length(yrs))
  allmat[match(yrs[x], all_yr), ] <- unlist(new_male_mat_dat[x, 2:ncol(new_male_mat_dat)])

mean_mat <- apply(allmat, 2, mean, na.rm = T)
for (x in which(is.na(allmat[, 1])))
  allmat[x, ] <- mean_mat

write.csv(allmat, "data/derived/2prob_term_molt_males_new.csv")

# ---- 5a. Diagnostic figures: maturity-at-size -------------------------------
male_mat_alt <- melt(allmat)
names(male_mat_alt) <- c("year", "size", "prop_mature")

png("plots/maturity_facet.png", height = 8, width = 8, res = 400, units = 'in')
p <- ggplot(male_mat_alt) +
  geom_line(aes(x = size, y = prop_mature, group = year, col = year), lwd = 2) +
  scale_color_distiller(palette = "RdYlBu", na.value = "grey") +
  xlim(35, 135) + theme_bw() + ylab("Proportion new shell mature") +
  xlab("Carapace width (mm)") +
  theme(legend.position = c(.9, .2))
print(p)
dev.off()

med_mat <- male_mat_alt %>%
  group_by(size) %>%
  summarize(prop_mature = median(prop_mature))

png("plots/maturity_facet_all.png", height = 10, width = 8, res = 400, units = 'in')
p <- ggplot(male_mat_alt) +
  geom_line(data = male_mat_alt, aes(x = size, y = prop_mature, group = year, col = year), lwd = 2) +
  geom_line(data = med_mat, aes(x = size, y = prop_mature), col = 'red', lwd = 1.2) +
  xlim(35, 135) + theme_bw() + ylab("Proportion new shell mature") +
  xlab("Carapace width (mm)") +
  facet_wrap(~year)
print(p)
dev.off()


# =============================================================================
# 6. MATURE / IMMATURE SIZE COMPOSITIONS + BIOMASS INDICES
# =============================================================================
# Split new-shell males into mature/immature via the ogive (dropping 2020, the
# cancelled-survey COVID year, so `in_mat` aligns with MaleNew's years), add all
# old-shell males to the mature pool, then normalize to size comps and weight by
# weight-at-size to get biomass indices.
in_mat        <- allmat[-which(rownames(allmat) == 2020), ]
MaleNewMature <- MaleNew * in_mat
male_immature <- MaleNew * (1 - in_mat)
male_mature   <- MaleNewMature + MaleOld

# normalized size compositions (rows sum to 1)
sc_male_mat <- sweep(male_mature,   1, apply(male_mature,   1, sum, na.rm = T), FUN = "/")
sc_male_imm <- sweep(male_immature, 1, apply(male_immature, 1, sum, na.rm = T), FUN = "/")

write.table(round(sc_male_mat, 4), "data/derived/2surv_len_comp_male_mat_newmat.txt", row.names = FALSE, col.names = F)
write.table(round(sc_male_imm, 4), "data/derived/2surv_len_comp_male_imm_newmat.txt", row.names = FALSE, col.names = F)

# ---- biomass indices (numbers-at-size x weight-at-size) ---------------------
wt_at_size   <- read.csv("data/wt_at_size.csv")
male_mat_bio <- apply(sweep(male_mature,   2, wt_at_size[, 1], FUN = "*"), 1, sum)
male_imm_bio <- apply(sweep(male_immature, 2, wt_at_size[, 1], FUN = "*"), 1, sum)

# quick interactive sanity plot (mature vs immature biomass); not saved.
plot(male_mat_bio, type = 'b', ylim = c(0, 400))
lines(male_imm_bio, type = 'b', col = 2)

write.table(male_mat_bio, "data/derived/2index_mmb_new_mat.txt",      row.names = FALSE, col.names = F)
write.table(male_imm_bio, "data/derived/2index_imm_male_new_mat.txt", row.names = FALSE, col.names = F)

# ---- 6a. Diagnostic figure: mature vs immature numbers-at-size --------------
lng_mat <- melt(as.matrix(male_mature));   lng_mat$maturity <- "mature"
lng_imm <- melt(as.matrix(male_immature)); lng_imm$maturity <- "immature"

big_mat <- rbind(lng_mat, lng_imm)
colnames(big_mat) <- c("year", 'Size', 'Abundance', 'maturity')
imm_v_mat <- ggplot(big_mat, aes(x = Size, y = Abundance, fill = maturity)) +
  geom_bar(stat = "identity", position = "stack") +
  labs(title = "Numbers at size by maturity state by year",
       x = "Carapace width (mm)",
       y = "Survey abundance",
       fill = "Maturity") +
  facet_wrap(~year, ncol = 5) + theme_bw() +
  theme(legend.position = c(.9, .05))
png("plots/imm_v_mat.png", height = 10, width = 8, res = 400, units = 'in')
print(imm_v_mat)
dev.off()
