#!/usr/bin/env Rscript
## ============================================================================
## 07_calc_tier4.R
##
## Tier 4 OFL for EBS snow crab. F_OFL from stock status under the NPFMC crab
## control rule, applied to survey biomass -- no assessment model. This is the
## 2026 harvest-specification basis, so these numbers become the catch limit.
##
## Currencies (mature-male survey biomass, 1,000 t):
##   morphometric   THE RECOMMENDATION
##   >101 mm        "preferred"  ) comparison only
##   >95 mm         "large"      )
## Each is run on the raw survey series (S4) and REMA-smoothed (S6). S6 is what
## the SAFE reports.
##
## IN   crabpack API; data/derived/survey_indices.csv; data/new_catch/retained_catch.csv
## OUT  data/tier4/{tier4_by_currency,rema_predictions,observed_exploitation}.csv
##      plots/{tier_4,tier4_status,obs_exploit_rate,rema_tier_4_ssc}.png
##
## TERMINAL-YEAR KNOBS: SURVEY_YEARS, BMSY_WINDOW_END (both Section 1)
##
## OFL BASIS (settled 2026-08-28; backlog 7d, 7e). Two independent choices, both
## switchable at the top of Section 1, with all four combinations reported:
##   HCR_RAMP = FALSE  flat F_OFL = M above the beta closure (no linear ramp).
##                     The ramp is retained and reported as OFL_ramp.
##   OFL_EQN  = linear OFL = F_OFL * B, matching other BSAI crab Tier 4
##                     assessments. Baranov is reported as OFL_baranov and is
##                     the author recommendation for future cycles.
## Morphometric, 2026: reported 30.765 / ramp 22.867 / Baranov 23.772 /
## both 18.239 kt.
##
## Basis for flat M (per Grant, 2026-08-28): it follows the GROUNDFISH TIER 5
## FMP, where the OFL is F = M applied to the biomass with no status-based ramp.
## Not from the June 2026 SSC report -- that document never mentions a ramp.
## ============================================================================

options(warn = 1)
suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(crabpack); library(rema)
})

## ---------------------------------------------------------------------------
## 1. Configuration
## ---------------------------------------------------------------------------
## Keep in sync BY HAND with the identical pull in 02_prep_survey_data.R --
## nothing checks it (backlog item 5).
SURVEY_YEARS <- 1982:2026

## Base mature-male M (yr^-1), the prior median; also the Tier-4 target F.
NAT_M <- 0.27

## Control rule: beta is the status below which directed fishing is prohibited,
## alpha sets the ramp slope between beta and 1.
BETA  <- 0.25
ALPHA <- 0.10

## Which F_OFL the REPORTED OFL uses (settled 2026-08-28, per Grant: flat, on
## the basis that it follows the groundfish Tier 5 FMP -- backlog 7d).
## FALSE = flat F_OFL = M above the beta closure. The ramp is retained and
## reported alongside as a sensitivity, never dropped.
##
## "No ramp" is taken to mean the LINEAR RAMP between beta and 1 is removed, not
## that the beta closure is removed: below beta directed fishing is still
## prohibited. This assumption changes nothing in 2026 -- all three currencies
## sit above beta (morphometric 0.769, >95 mm 0.279, >101 mm 0.255) -- but note
## that >101 mm clears beta by only 0.005, so the two readings could diverge in
## a future year.
HCR_RAMP <- FALSE

## Which OFL equation the REPORTED column uses (backlog 7e). "linear" = F_OFL*B,
## matching other BSAI crab Tier 4 assessments. "baranov" is the author
## recommendation for future cycles and is reported alongside either way.
OFL_EQN <- "linear"
stopifnot("OFL_EQN must be 'linear' or 'baranov'" = OFL_EQN %in% c("linear", "baranov"))

## B_MSY proxy = mean biomass over years strictly before this one. Deliberately
## a literal: widening it moves B_MSY, status and the OFL. Advance consciously.
BMSY_WINDOW_END <- 2025

for (d in c("data/tier4", "plots")) dir.create(d, recursive = TRUE, showWarnings = FALSE)

## ---------------------------------------------------------------------------
## 2. Control rule
## ---------------------------------------------------------------------------
## RAMPED rule (retained as the sensitivity, backlog 7d):
##   status >= 1        F_OFL = M
##   beta < status < 1  F_OFL = M (status - alpha)/(1 - alpha)
##   status <= beta     F_OFL = 0   (directed closure)
## Verified equivalent to the original nested if() at every boundary.
tier4_fofl_ramp <- function(status, m = NAT_M, alpha = ALPHA, beta = BETA) {
  ifelse(status >= 1, m,
         ifelse(status > beta, m * (status - alpha) / (1 - alpha), 0))
}

## FLAT rule -- what the SSC wants and what the SAFE reports:
##   status >  beta     F_OFL = M
##   status <= beta     F_OFL = 0   (directed closure retained; see HCR_RAMP)
tier4_fofl_flat <- function(status, m = NAT_M, beta = BETA) {
  ifelse(status > beta, m, 0)
}

## The rule the reported numbers use.
tier4_fofl <- function(status, ...) {
  if (HCR_RAMP) tier4_fofl_ramp(status, ...) else tier4_fofl_flat(status, ...)
}

## Converting F_OFL to a catch (backlog 7e, settled 2026-08-28).
##
## REPORTED: OFL = F_OFL * B, for consistency with how other BSAI crab Tier 4
## assessments compute it. Comparability across stocks won here, not because the
## linear form is the better approximation -- it is not.
##
## ALTERNATIVE, and the author recommendation for future cycles: Baranov. F_OFL
## is an INSTANTANEOUS rate (yr^-1, the same scale as M, which is why Tier 4 can
## set F_OFL = M), and natural mortality acts over the same year, so the yield is
## F's share of total mortality Z = F + M. F*B is only the first-order
## approximation to that and always overstates the catch: at flat F = M it gives
## 30.765 kt against Baranov's 23.772 kt. The gap is at its widest precisely
## here, because F_OFL = M means fishing is exactly half of Z.
##
## Both are computed every run and reported side by side; OFL_EQN selects which
## one populates the reported `OFL` column. F = 0 (closure) returns 0 in both.
## NB both are called with a SCALAR fofl and a VECTOR biomass (Section 4 passes
## a whole survey series). ifelse() returns a result the length of its TEST, so
## ifelse(fofl <= 0, ...) with a scalar fofl silently returns length 1 and the
## series collapses -- that is a real bug this code shipped with for one run on
## 2026-08-28 (Section 4's data.frame failed with "differing number of rows:
## 132, 89", i.e. 1 + 44 + 44). Mask after the arithmetic instead, which
## recycles correctly whether fofl is scalar or a vector.
tier4_ofl_linear <- function(fofl, biomass, m = NAT_M) {
  out <- fofl * biomass
  out[fofl <= 0] <- 0
  out
}
tier4_ofl_baranov <- function(fofl, biomass, m = NAT_M) {
  z   <- fofl + m
  out <- (fofl / z) * biomass * (1 - exp(-z))
  out[fofl <= 0] <- 0            # also clears any NaN from z == 0
  out
}
tier4_ofl <- function(fofl, biomass, m = NAT_M) {
  if (OFL_EQN == "baranov") tier4_ofl_baranov(fofl, biomass, m)
  else                      tier4_ofl_linear(fofl, biomass, m)
}

## ---------------------------------------------------------------------------
## 3. Survey biomass by currency
## ---------------------------------------------------------------------------
specimen_data <- crabpack::get_specimen_data(species = "SNOW", region = "EBS",
                                             years = SURVEY_YEARS, channel = 'API')

male_snow_ind <- crabpack::calc_bioabund(crab_data = specimen_data,
                                         species = "SNOW", region = "EBS",
                                         crab_category = c("all_categories"))

surv_yr <- unique(male_snow_ind$YEAR)

## which() drops NA rows, matching the dplyr::filter() this replaced. Plain
## logical indexing would return an NA row instead, silently lengthening the
## series and misaligning it against surv_yr.
.cat <- function(category, field) {
  male_snow_ind[[field]][which(male_snow_ind$CATEGORY == category &
                               male_snow_ind$YEAR > 1981)]
}
com_male    <- .cat("preferred_male", "BIOMASS_MT")      # >101 mm
com_male_cv <- .cat("preferred_male", "BIOMASS_MT_CV")
lg_male     <- .cat("large_male",     "BIOMASS_MT")      # >95 mm
lg_male_cv  <- .cat("large_male",     "BIOMASS_MT_CV")

## Morphometric MMB + CV, already in 1,000 t. Reading survey_indices.csv
## replaced stale index_mmb.txt reads that lagged a cycle -- the bug that once
## ran Tier 4 on last year's MMB.
survey_indices <- read.csv("data/derived/survey_indices.csv")
mmb_tab    <- survey_indices[survey_indices$sex == "male" &
                             survey_indices$maturity == "mature", ]
mmb        <- mmb_tab$biomass[match(surv_yr, mmb_tab$year)]
mmb_cv_vec <- mmb_tab$cv[match(surv_yr, mmb_tab$year)]

stopifnot("series lengths must match surv_yr" =
            all(lengths(list(com_male, lg_male, mmb)) == length(surv_yr)))

## ---------------------------------------------------------------------------
## 4. Tier 4 on the raw survey series
## ---------------------------------------------------------------------------
## No half-year M decrement in any currency (2026-08-27, per Grant). It was
## previously applied to >101/>95 but not morphometric, so the currencies were
## not comparable. mt -> 1,000 t only.
com_male_fish <- com_male / 1000
lg_male_fish  <- lg_male  / 1000

## B_MSY = mean over the whole series; the original wrote this as
## x[which(surv_yr == 1982):length(x)], i.e. from the first year on.
stopifnot("survey must start in 1982" = surv_yr[1] == 1982)
com_male_bmsy <- mean(com_male_fish)
lg_male_bmsy  <- mean(lg_male_fish)

com_male_stat <- com_male_fish / com_male_bmsy
lg_male_stat  <- lg_male_fish  / lg_male_bmsy

## One OFL equation for the whole script now (backlog 7e): tier4_ofl(), which
## follows OFL_EQN. This section previously used B*(1-exp(-F)) while Section 6
## used F*B; that split is what 7e was about.
##
## NB the morphometric series takes F = M directly while the other two go
## through tier4_fofl(), which applies the beta closure. Pre-existing (the
## original hardcoded NAT_M here too), and it only matters if the series drops
## to status <= beta, but the three panels of plots/tier_4.png are therefore not
## built on identical rules. Left as-is: this is the raw-survey diagnostic, not
## the reported OFL, which comes from Section 6.
OFL_com_mmb <- tier4_ofl(tier4_fofl(com_male_stat), com_male_fish)
OFL_lg_mmb  <- tier4_ofl(tier4_fofl(lg_male_stat),  lg_male_fish)
OFL_mmb     <- tier4_ofl(NAT_M, mmb)

## Catches the scalar-fofl length collapse described above, at the point where
## it would otherwise surface as an opaque data.frame() row-count error.
stopifnot("Section 4 OFL series must be one value per survey year" =
            all(lengths(list(OFL_mmb, OFL_com_mmb, OFL_lg_mmb)) == length(surv_yr)))

plot_ofl <- data.frame(
  biomass  = c(mmb, com_male_fish, lg_male_fish),
  ofl      = c(OFL_mmb, OFL_com_mmb, OFL_lg_mmb),
  year     = rep(surv_yr, 3),
  currency = rep(c("Morphometric", ">101 mm", ">95 mm"), each = length(surv_yr)),
  stringsAsFactors = FALSE)

## Replaces two base plot() calls that wrote to Rplots.pdf in the repo root.
stat_df <- data.frame(
  year     = rep(surv_yr, 2),
  status   = c(com_male_stat, lg_male_stat),
  currency = rep(c(">101 mm", ">95 mm"), each = length(surv_yr)),
  stringsAsFactors = FALSE)

png("plots/tier4_status.png", height = 5, width = 8, res = 350, units = "in")
print(
  ggplot(stat_df, aes(year, status, colour = currency)) +
    geom_line(linewidth = 1) + geom_point(size = 1.4) +
    geom_hline(yintercept = BETA, linetype = 2, colour = "red") +
    geom_hline(yintercept = 0.5,  linetype = 2, colour = "darkgreen") +
    ylim(0, 4.2) +
    labs(x = "Year", y = "Status (B / B_MSY)", colour = NULL,
         title = "Tier 4 status on the raw survey series",
         subtitle = sprintf("dashed: beta = %.2f (closure) and 0.5", BETA)) +
    theme_bw()
)
dev.off()

## Dashed line CLAMPED at 125 so it stays on the OFL axis. The flat top is a
## plotting limit, not data.
blup <- plot_ofl[plot_ofl$currency == ">101 mm", ]
blup$biomass[blup$biomass > 125] <- 125

cha <- ggplot(plot_ofl) +
  geom_line(aes(x = year, y = ofl, col = currency), lwd = 1.2) +
  geom_line(data = blup, aes(y = biomass, x = year), lwd = 1.2, lty = 2) +
  theme_bw() + theme(legend.position = c(.8, .8)) +
  ylab("OFL (1,000 t)") + ylim(0, 125)

sha <- ggplot(plot_ofl) +
  geom_line(aes(x = year, y = biomass, col = currency), lwd = 1.5) +
  geom_line(aes(x = year, y = ofl, col = currency), lwd = 1) +
  theme_bw() + facet_wrap(~currency, ncol = 1) + theme(legend.position = "") +
  ylab("Biomass/OFL (1,000 t)")

png("plots/tier_4.png", height = 7, width = 7, res = 350, units = 'in')
print(cha + sha + plot_layout(ncol = 2, widths = c(4, 1)))
dev.off()

## ---------------------------------------------------------------------------
## 5. Observed exploitation rate
## ---------------------------------------------------------------------------
## Through the large-male rebuild (2000-2011) the retained rate ran ~0.25-0.30,
## then ratcheted up.
ret_cat <- read.csv("data/new_catch/retained_catch.csv")
colnames(ret_cat)[1] <- "year"
compit <- merge(plot_ofl, ret_cat, by = "year")
compit$tot_retained_wt <- compit$tot_retained_wt / 1000
compit$exp_rate <- compit$tot_retained_wt / compit$biomass

png("plots/obs_exploit_rate.png", height = 7, width = 7, res = 350, units = 'in')
print(
  ggplot() +
    geom_point(data = compit, aes(x = year, y = exp_rate, col = currency)) +
    geom_line(data = compit[compit$year < 2020, ],
              aes(x = year, y = exp_rate, col = currency), lwd = 1.2) +
    geom_line(data = compit[compit$year > 2020, ],
              aes(x = year, y = exp_rate, col = currency), lwd = 1.2) +
    theme_bw() + theme(legend.position = c(.8, .8)) +
    ylab("Retained catch / Biomass")
)
dev.off()

## By name; the original used positional c(1,2,4,11), where 11 depended on the
## column order merge() happened to produce.
write.csv(compit[, c("year", "biomass", "currency", "tot_retained_wt")],
          "data/tier4/observed_exploitation.csv", row.names = FALSE)

## ---------------------------------------------------------------------------
## 6. REMA-smoothed Tier 4 -- what the SAFE reports
## ---------------------------------------------------------------------------
## One call per currency, replacing three ~45-line copies that had drifted
## (nat_m assigned 4x and hardcoded 3x, alpha/beta 4x, plots assigned twice).
tier4_hcr <- function(biomass, cv, years, currency, size_label, model_name) {
  dat  <- data.frame(biomass = biomass, cv = cv, year = years, strata = "EBS")
  out  <- tidy_rema(fit_rema(prepare_rema_input(model_name = model_name,
                                                biomass_dat = dat)))
  pred <- out$total_predicted_biomass

  b_curr <- pred$pred[nrow(pred)]
  bmsy   <- mean(pred$pred[pred$year < BMSY_WINDOW_END])
  status <- b_curr / bmsy
  ## Two independent choices, so all four combinations are computed and each
  ## reported column isolates ONE of them (backlog 7d, 7e):
  ##   OFL              reported     F_OFL basis + reported equation
  ##   OFL_ramp         ramp sensitivity  -- changes the HCR only
  ##   OFL_baranov      equation alternative -- changes the equation only
  ##   OFL_ramp_baranov both changed, for completeness
  fofl      <- tier4_fofl(status)
  fofl_ramp <- tier4_fofl_ramp(status)
  ofl              <- tier4_ofl(fofl, b_curr)
  ofl_ramp         <- tier4_ofl(fofl_ramp, b_curr)
  ofl_baranov      <- tier4_ofl_baranov(fofl, b_curr)
  ofl_ramp_baranov <- tier4_ofl_baranov(fofl_ramp, b_curr)

  p <- plot_rema(tidy_rema = out)$biomass_by_strata + theme_bw() +
    ylab("Biomass 1,000 t") +
    annotate("text", x = 2010, y = max(pred$pred) * .9,
             label = paste("OFL = ", round(ofl, 2), sep = ""))

  ## Uncertainty on the biomass the control rule actually uses. The groundfish
  ## guidelines (4.11.2) require at least one measure of it for Tiers 4-5, and
  ## require the derivation to be stated. tidy_rema() returns a 95% interval
  ## (alpha_ci = 0.05), lognormal on the predicted series, so the log-scale SD
  ## is (log(uci) - log(lci)) / (2 * 1.96) and the CV follows from it.
  ##
  ## This is the process-error interval on the SMOOTHED series -- it is not the
  ## survey's own sampling CV, which is an INPUT to the fit (the `cv` column of
  ## `dat`). Reporting one as the other would misstate the uncertainty the OFL
  ## carries, so both names are kept distinct downstream.
  .z        <- qnorm(0.975)
  b_curr_lo <- pred$pred_lci[nrow(pred)]
  b_curr_hi <- pred$pred_uci[nrow(pred)]
  b_curr_sd <- (log(b_curr_hi) - log(b_curr_lo)) / (2 * .z)
  b_curr_cv <- sqrt(exp(b_curr_sd^2) - 1)
  stopifnot("terminal REMA interval does not bracket the point estimate" =
              b_curr_lo <= b_curr && b_curr <= b_curr_hi)

  list(rema = data.frame(Year = pred$year, rema_pred = pred$pred,
                         rema_lci = pred$pred_lci, rema_uci = pred$pred_uci,
                         size = size_label, stringsAsFactors = FALSE),
       ## currency/Bmsy/B_curr/status/M/Fofl/OFL is the interface the PLANNED
       ## `tier4-setup` chunk will read (SEPT2026_CLAUDE_CODE_HANDOFF §15a) --
       ## note that chunk does NOT exist yet; the Rmd has no tier4 reference at
       ## all today. Column order and names kept stable for when it lands; the
       ## alternatives are appended so adding them breaks nothing.
       row  = data.frame(currency = currency, Bmsy = bmsy, B_curr = b_curr,
                         B_curr_lci = b_curr_lo, B_curr_uci = b_curr_hi,
                         B_curr_cv = b_curr_cv,
                         status = status, M = NAT_M, Fofl = fofl, OFL = ofl,
                         Fofl_ramp = fofl_ramp, OFL_ramp = ofl_ramp,
                         OFL_baranov = ofl_baranov,
                         OFL_ramp_baranov = ofl_ramp_baranov,
                         stringsAsFactors = FALSE),
       plot = p)
}

## Order and `size` labels preserved from the original so the fitted-series file
## stays comparable with earlier cycles.
morph_res <- tier4_hcr(mmb,             mmb_cv_vec,  surv_yr, "morphometric", "morphometric", "morph")
pref_res  <- tier4_hcr(com_male / 1000, com_male_cv, surv_yr, ">101 mm",      "101",          "pref")
large_res <- tier4_hcr(lg_male  / 1000, lg_male_cv,  surv_yr, ">95 mm",       "95",           "large")

keep_rema   <- rbind(morph_res$rema, pref_res$rema, large_res$rema)
by_currency <- rbind(morph_res$row,  pref_res$row,  large_res$row)

## Panel order preserved: morphometric / >95 mm / >101 mm.
png("plots/rema_tier_4_ssc.png", height = 10, width = 7, res = 350, units = 'in')
print(morph_res$plot / large_res$plot / pref_res$plot)
dev.off()

## ---------------------------------------------------------------------------
## 7. Outputs
## ---------------------------------------------------------------------------
## The OFL previously existed only as text inside a PNG annotation.
write.csv(keep_rema,   "data/tier4/rema_predictions.csv",  row.names = FALSE)
write.csv(by_currency, "data/tier4/tier4_by_currency.csv", row.names = FALSE)

cat("\n=== Tier 4 (REMA), B_MSY over years <", BMSY_WINDOW_END, "===\n")
print(format(by_currency, digits = 6), row.names = FALSE)
cat(sprintf("\nREPORTED (morphometric): OFL = %.3f kt   [%s F_OFL = %.4f, %s equation]\n",
            by_currency$OFL[1], if (HCR_RAMP) "ramped" else "flat",
            by_currency$Fofl[1], OFL_EQN))
cat("  alternatives, each changing ONE choice:\n")
cat(sprintf("    ramp HCR      (F_OFL %.4f, %s eqn) : %.3f kt\n",
            by_currency$Fofl_ramp[1], OFL_EQN, by_currency$OFL_ramp[1]))
cat(sprintf("    Baranov eqn   (F_OFL %.4f)          : %.3f kt   <- author recommendation\n",
            by_currency$Fofl[1], by_currency$OFL_baranov[1]))
cat(sprintf("    both changed                         : %.3f kt\n",
            by_currency$OFL_ramp_baranov[1]))
cat("  wrote data/tier4/*.csv and plots/*.png\n\nDone.\n")
