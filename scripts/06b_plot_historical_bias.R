#!/usr/bin/env Rscript
## ============================================================================
## 06b_plot_historical_bias.R
##
## Compares estimated mature male biomass across ASSESSMENT VINTAGES -- the
## 2016, 2017, ... 2025 assessments' views of the same historical years.
##
## This is NOT the model retrospective (that is 06_run_retrospective.R, which
## peels data off one model). It reads previously-published time series from
## data/historical/ and shows how successive assessments have revised history.
## The two analyses answer different questions and were previously tangled in
## one file; this script is the historical block lifted out of the old
## 06_run_retrospective.R (lines 422-466) with its missing patchwork dependency
## supplied.
##
## Usage (from the snow_sept repo root):
##   Rscript 06b_plot_historical_bias.R
##
## Output: plots/historical_mating_mmb_est.png
##
## NOT CURRENTLY INCLUDED BY THE SAFE (checked 2026-08-27). 2026_snowcrab_safe_draft.Rmd
## has no reference to this figure, so the script runs and the PNG is written
## but nothing consumes it. The previous header cited "the 2025 reference Rmd,
## line 2631"; there is no Rmd in Reports/, only the published PDFs, so that
## citation could not be checked and has been removed rather than carried
## forward. Add an include chunk to the Rmd, or accept this as a standalone
## diagnostic -- but do not assume it reaches the document.
##
## WHAT THE FIGURE SHOWS, and why the panels end in different years: the survey
## series runs through each assessment's own year, the mating series through the
## year before it (mature biomass at mating needs the following season), so
## panel 1's lines extend one year past panel 2's for the same vintage. That is
## the convention in the source files, not a gap.
##
## The 2020 vintage is the point of the whole figure: it put terminal biomass at
## 486.5, and the 2021 assessment revised that same year to 40.95 -- a 92%
## downward revision, the collapse arriving in the historical record.
## ============================================================================

options(warn = 1)
suppressPackageStartupMessages({
  library(dplyr)
  library(reshape2)
  library(ggplot2)
  library(patchwork)     # supplies `/` and plot_layout(); missing in the original
})

if (!dir.exists("data/historical"))
  stop("Run this from the snow_sept repo root (no data/historical/ under ", getwd(), ").")
dir.create("plots", showWarnings = FALSE)

## check.names = FALSE: the columns are assessment YEARS ("2025", "2024", ...)
## and must not be mangled into X2025.
read_vintage <- function(f) {
  d <- read.csv(file.path("data/historical", f), check.names = FALSE)
  if (!"Year" %in% names(d)) stop(f, " has no 'Year' column")
  melt(d, id.vars = "Year", variable.name = "variable", value.name = "value")
}

## --- Panel 1: biomass at the survey, subject to survey selectivity ----------
pl_survey <- read_vintage("historical_mmb_at_survey_by_assessment.csv")
survey_ess <- ggplot(pl_survey) +
  geom_line(aes(x = Year, y = value, col = variable, group = variable), linewidth = 1.2) +
  theme_bw() + ylab("Biomass (1,000 t)") + labs(color = "Assessment") +
  ggtitle("Morphometrically mature biomass at survey, subject to selectivity")

## --- Panel 2: biomass at mating, not subject to selectivity ----------------
pl_dat <- read_vintage("historical_mmb_mating_by_assessment.csv")
mating_ess <- ggplot(pl_dat) +
  geom_line(aes(x = Year, y = value, col = variable, group = variable), linewidth = 1.2) +
  theme_bw() + ylab("Biomass (1,000 t)") + labs(color = "Assessment") +
  ggtitle("Morphometrically mature biomass at mating, not subject to selectivity")

## --- Panel 3: the same, normalised within each assessment ------------------
## Normalising strips the scale difference so the SHAPE revisions stand out.
df_normalized <- pl_dat %>%
  group_by(variable) %>%
  mutate(normalized_value = value / max(value, na.rm = TRUE)) %>%
  ungroup()

normie <- ggplot(df_normalized) +
  geom_line(aes(x = Year, y = normalized_value, group = variable, col = variable),
            linewidth = 1.2) +
  theme_bw() + ylab("Normalized MMB") + labs(color = "Assessment") +
  ggtitle("Normalized morphometrically mature biomass at mating, not subject to selectivity")

png("plots/historical_mating_mmb_est.png", height = 10, width = 8, res = 400, units = "in")
print(survey_ess / mating_ess / normie + plot_layout(guides = "collect"))
dev.off()

cat(sprintf("Wrote plots/historical_mating_mmb_est.png (%d assessment vintages, years %d-%d)\n",
            length(unique(pl_dat$variable)), min(pl_dat$Year), max(pl_dat$Year)))

## NOTE (2026-08): the two data/historical/*_by_assessment.csv files stop at the
## 2025 assessment column. A 2026 column must be appended from this cycle's
## accepted model before this figure is current for the September 2026 SAFE.
if (!"2026" %in% as.character(unique(pl_dat$variable)))
  cat("NOTE: no 2026 column in data/historical/ yet -- figure shows vintages through 2025.\n")
