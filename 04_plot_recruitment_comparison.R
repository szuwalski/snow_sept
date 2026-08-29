#!/usr/bin/env Rscript
## ============================================================================
## 04_plot_recruitment_comparison.R
##
## Survey-observed recruitment against the model's estimated recruitment, both
## scaled to mean 0 / sd 1 so the TIMING of year classes can be compared when
## the two series are on different absolute scales.
##
## Replaces the recruitment block of 04_plot_numbers_at_length.R, retired
## 2026-08-27. That block could not run: it referenced `snowad.rep`, `M` and `x`,
## none of which are defined anywhere in this repo, and hardcoded 1978-2017 /
## 1982-2019 year ranges with matching rep() counts that went stale six years
## ago. Its numbers-at-length figures moved to 02_prep_survey_data.R (sections
## 3a and 6c), which draws them from the live crabpack pull.
##
## INPUTS
##   data/survey/survey_recruit_index_derived.csv   45-55 mm male abundance,
##                                                  written by 02 section 3b
##   Models/<model>/Gmacsall.out                    Recruit_male, from the fit
##                                                  itself -- NOT
##                                                  Models/rda_ModelsResLst.RData,
##                                                  which lags the accepted fit
##                                                  until 03 is re-run
## OUTPUT
##   plots/recruitment_survey_vs_model.png
##
## USAGE (from the snow_sept repo root)
##   Rscript 04_plot_recruitment_comparison.R [model_dir]
## ============================================================================

options(warn = 1)
suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
})

## ---------------------------------------------------------------------------
## 1. Configuration
## ---------------------------------------------------------------------------
args      <- commandArgs(trailingOnly = TRUE)
MODEL_REL <- if (length(args) >= 1) args[1] else "Models/26_gmacs_update_newmat_plus_group"

REPO_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(REPO_ROOT, "R", "gmacs_io.R")))
  stop("Run this from the snow_sept repo root (no R/gmacs_io.R under ", REPO_ROOT, ").")
source(file.path(REPO_ROOT, "R", "gmacs_io.R"))

MODEL_DIR    <- normalizePath(file.path(REPO_ROOT, MODEL_REL), winslash = "/", mustWork = TRUE)
SURVEY_INDEX <- file.path(REPO_ROOT, "data", "survey", "survey_recruit_index_derived.csv")
PLOT_DIR     <- file.path(REPO_ROOT, "plots")
dir.create(PLOT_DIR, recursive = TRUE, showWarnings = FALSE)

## ---------------------------------------------------------------------------
## 2. Read both series
## ---------------------------------------------------------------------------
if (!file.exists(SURVEY_INDEX))
  stop("No ", basename(SURVEY_INDEX), " in data/survey/. It is written by ",
       "02_prep_survey_data.R section 3b -- run 02 first.")

survey <- read.csv(SURVEY_INDEX, stringsAsFactors = FALSE)
stopifnot("survey index needs year + recruit_abundance" =
            all(c("year", "recruit_abundance") %in% names(survey)))

ga <- file.path(MODEL_DIR, "Gmacsall.out")
if (!file.exists(ga))
  stop("No Gmacsall.out in ", MODEL_REL, ". Fit the model before comparing to it.")
fit <- read_gmacsall_summary(ga)
if (!"Recruit_male" %in% names(fit))
  stop("Gmacsall.out summary block has no Recruit_male column in ", MODEL_REL)

## ---------------------------------------------------------------------------
## 3. Scale and combine
## ---------------------------------------------------------------------------
## Scaled, not raw: the survey index is abundance of 45-55 mm males on the
## survey grid while the model's recruitment is an estimated absolute number at
## the model's recruitment size, so the levels are not comparable. What IS
## comparable is when the peaks fall.
##
## Each series is scaled over its OWN years. Restricting both to the overlap
## first would let the survey's pre-model years shift its mean, which would move
## the curve for a reason that has nothing to do with recruitment.
.scaled <- function(x) as.numeric(scale(x))

plot_dat <- rbind(
  data.frame(year   = survey$year,
             value  = .scaled(survey$recruit_abundance),
             series = "Survey (45-55 mm males)", stringsAsFactors = FALSE),
  data.frame(year   = fit$Year,
             value  = .scaled(fit$Recruit_male),
             series = "Model (estimated recruits)", stringsAsFactors = FALSE)
)

overlap <- intersect(survey$year, fit$Year)
if (!length(overlap))
  stop("The survey index and the model share no years -- check that both cover ",
       "the same assessment cycle.")

cat(sprintf("\n=== 04_plot_recruitment_comparison.R ===\n"))
cat(sprintf("model        : %s\n", MODEL_REL))
cat(sprintf("survey years : %d-%d   model years: %d-%d   overlap: %d-%d (%d yr)\n",
            min(survey$year), max(survey$year), min(fit$Year), max(fit$Year),
            min(overlap), max(overlap), length(overlap)))
cat(sprintf("correlation over the overlap (scaled): %.3f\n",
            stats::cor(.scaled(survey$recruit_abundance)[survey$year %in% overlap],
                       .scaled(fit$Recruit_male)[fit$Year %in% overlap])))

## ---------------------------------------------------------------------------
## 4. Figure
## ---------------------------------------------------------------------------
p <- ggplot(plot_dat, aes(x = year, y = value, colour = series)) +
  geom_line(linewidth = 1.1) +
  scale_colour_brewer(name = NULL, palette = "Set1") +
  labs(x = NULL, y = "Scaled recruitment (mean 0, sd 1)",
       title = "Survey-observed vs model-estimated recruitment",
       subtitle = sprintf("%s; each series scaled over its own years", MODEL_REL)) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom")

png(file.path(PLOT_DIR, "recruitment_survey_vs_model.png"),
    height = 5, width = 9, res = 400, units = "in")
print(p)
dev.off()

cat(sprintf("  wrote %s\n\nDone.\n", file.path("plots", "recruitment_survey_vs_model.png")))
