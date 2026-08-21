# =============================================================================
# 02_prep_survey_data.R  --  EBS snow crab, September 2026 SAFE
#
# PURPOSE
#   Pull the EBS summer bottom-trawl SURVEY specimen data from crabpack and
#   derive the survey-side model inputs:
#     * male size compositions by shell condition (new / old), 5-mm bins
#     * male terminal-molt (maturity) ogive
#     * mature / immature male survey size comps and biomass indices
#     * mature / immature FEMALE survey size comps (SNOW-only)
#     * several diagnostic figures
#   Outputs land in data/derived/ (then written into the model .DAT/.CTL by
#   00_advance_model.R), data/survey/, and plots/.
#
# OUTPUTS  (all .csv; header row + explicit `year` column; values in model units)
#   data/survey/survey_large_male_index_derived.csv   large/preferred male index
#   data/derived/survey_size_comps.csv    year, sex, maturity, m27.5..m132.5
#                                         (male + female, mature + immature; rows sum 1)
#   data/derived/survey_indices.csv       year, sex, maturity, biomass (kt), cv
#   data/derived/male_maturity_ogive.csv  year, m27.5..m132.5  (prob terminal molt)
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

write.csv(big_male_snow_ind, "data/survey/survey_large_male_index_derived.csv", row.names = FALSE)

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

# (Female biomass + CV, the male MMB, and the immature-male index are assembled
#  together into data/derived/survey_indices.csv in Section 6, once male_mat_bio
#  exists. The legal-male CV is used there as the MMB-CV proxy; ~>76 mm.)


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
# NB: right = FALSE here (the "previous survey approach"): a crab on a 5-mm cutoff
#     goes to the UPPER bin. Consistent with the fishery comps (2026-08, per Grant).

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

male_maturity_ogive <- data.frame(year = as.numeric(rownames(allmat)), allmat,
                                   check.names = FALSE)
names(male_maturity_ogive) <- c("year", paste0("m", new_dat))
write.csv(male_maturity_ogive, "data/derived/male_maturity_ogive.csv", row.names = FALSE)

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

# normalized MALE size compositions (rows sum to 1)
sc_male_mat <- sweep(male_mature,   1, apply(male_mature,   1, sum, na.rm = T), FUN = "/")
sc_male_imm <- sweep(male_immature, 1, apply(male_immature, 1, sum, na.rm = T), FUN = "/")

# ---- biomass indices (numbers-at-size x weight-at-size) ---------------------
wt_at_size   <- read.csv("data/wt_at_size.csv")
male_mat_bio <- apply(sweep(male_mature,   2, wt_at_size[, 1], FUN = "*"), 1, sum)
male_imm_bio <- apply(sweep(male_immature, 2, wt_at_size[, 1], FUN = "*"), 1, sum)

# quick interactive sanity plot (mature vs immature biomass); not saved.
plot(male_mat_bio, type = 'b', ylim = c(0, 400))
lines(male_imm_bio, type = 'b', col = 2)


# =============================================================================
# 6b. FEMALE SURVEY SIZE COMPOSITIONS  (SNOW-only, morphometric maturity)
# =============================================================================
# The male path above produces no female comps; historically they came from Cody's
# hybrid script (SNOW+HYBRID). Per Grant the accepted basis is SNOW-only, so pull
# female numbers-at-size by maturity from crabpack (SNOW only), bin to the 22 model
# bins (right = FALSE, 132.5+ plus group) and normalize within year.
bin_edges5 <- c(seq(27.5, 132.5, 5) - 2.5, 999)      # 25,30,..,130, then plus group
midpoints5 <- seq(27.5, 132.5, 5)
nas_to_comp22 <- function(nas) {                     # nas: YEAR, SIZE_1MM, ABUNDANCE
  b <- nas %>%
    dplyr::group_by(YEAR, bin = cut(SIZE_1MM, breaks = bin_edges5, include.lowest = TRUE,
                                    right = FALSE, labels = midpoints5)) %>%
    dplyr::summarise(n = sum(ABUNDANCE), .groups = "drop") %>%
    dplyr::filter(!is.na(bin)) %>%
    dplyr::mutate(bin = as.character(bin))
  w <- as.data.frame(tidyr::pivot_wider(b, id_cols = YEAR, names_from = bin,
                                        values_from = n, values_fill = 0))
  for (mm in as.character(midpoints5)) if (!mm %in% names(w)) w[[mm]] <- 0
  m  <- as.matrix(w[, as.character(midpoints5), drop = FALSE])
  rs <- rowSums(m)
  m  <- m / ifelse(rs == 0, 1, rs)                   # normalize; leave empty years at 0
  data.frame(year = w$YEAR, setNames(as.data.frame(m), paste0("m", midpoints5)),
             check.names = FALSE)
}
fem_comp <- list()
for (fm in c("mature_female", "immature_female")) {
  fnas <- crabpack::calc_bioabund(crab_data = specimen_data, species = "SNOW", region = "EBS",
                                  crab_category   = fm,
                                  female_maturity = "morphometric",
                                  size_min = 25, bin_1mm = TRUE)
  fem_comp[[fm]] <- cbind(sex = "female",
                          maturity = ifelse(fm == "mature_female", "mature", "immature"),
                          nas_to_comp22(fnas))
}

# ---- consolidated survey size comps -> survey_size_comps.csv -----------------
# year, sex, maturity, m27.5..m132.5  (rows sum to 1); male + female, mat + imm.
mk_male <- function(sc, maturity)
  data.frame(year = as.numeric(rownames(sc)), sex = "male", maturity = maturity,
             setNames(as.data.frame(sc), paste0("m", midpoints5)), check.names = FALSE)
scomp_order       <- c("year", "sex", "maturity", paste0("m", midpoints5))
survey_size_comps <- rbind(
  mk_male(sc_male_mat, "mature")[,   scomp_order],
  mk_male(sc_male_imm, "immature")[, scomp_order],
  fem_comp[["mature_female"]][,      scomp_order],
  fem_comp[["immature_female"]][,    scomp_order]
)
write.csv(survey_size_comps, "data/derived/survey_size_comps.csv", row.names = FALSE)

# ---- consolidated survey indices -> survey_indices.csv -----------------------
# year, sex, maturity, biomass (kt), cv.  Mature-female biomass + CV from the
# morphometric pull; mature-male (MMB) biomass from male_mat_bio with the legal-
# male CV as the MMB-CV proxy (merged by year); immature-male kept for diagnostics.
mmb_df <- merge(data.frame(year = as.numeric(names(male_mat_bio)), biomass = as.numeric(male_mat_bio)),
                data.frame(year = male_snow_ind$YEAR, cv = male_snow_ind$BIOMASS_MT_CV),
                by = "year", all.x = TRUE)
survey_indices <- rbind(
  data.frame(year = mat_fem_snow_ind$YEAR, sex = "female", maturity = "mature",
             biomass = mat_fem_snow_ind$BIOMASS_MT / 1000, cv = mat_fem_snow_ind$BIOMASS_MT_CV),
  data.frame(year = mmb_df$year, sex = "male", maturity = "mature",
             biomass = mmb_df$biomass, cv = mmb_df$cv),
  data.frame(year = as.numeric(names(male_imm_bio)), sex = "male", maturity = "immature",
             biomass = as.numeric(male_imm_bio), cv = NA_real_)
)
write.csv(survey_indices, "data/derived/survey_indices.csv", row.names = FALSE)

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
