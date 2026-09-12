data/maturity/ -- male maturity (terminal-molt) inputs

snow_ogives.csv
  Smoothed probability-of-terminal-molt ogive by year and 5-mm size class (Ryznar).
  THE MODEL INPUT: read by scripts/02_prep_survey_data.R section 5 (YEAR, SIZE_5MM,
  PROP_MATURE) and reshaped onto the model bins -> data/derived/male_maturity_ogive.csv.

snow_ogives_staff_2026-09-12.csv
  The same ogive re-sent by survey staff on 2026-09-12 with the net-mensuration data
  correction. PROP_MATURE matches snow_ogives.csv to within 3e-15 in all 987 rows (it
  lacks only the row-number column X). Kept for provenance, NOT read by any script:
  switching to it would move the last printed digit of the derived ogive and so the
  bytes of every model .dat built from it, for no numerical change.

crabpack_ptermmolt.csv, female_prob_terminal_molt.csv, maturity_ogive_median.csv,
proportion_mature_unweighted.csv
  Earlier maturity products retained for comparison figures.
