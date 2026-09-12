data/survey/ -- NMFS EBS summer bottom-trawl survey inputs

SNOW_specimen_EBS.rds
  THE SURVEY INPUT. Staff-delivered 2026-09-12: the object crabpack::get_specimen_data()
  returns (list: specimen, haul, sizegroups), EBS, 1982-2026, WITH the net-mensuration
  correction to 2024-2026 area swept (~4% lower biomass and abundance in those three years
  only; every earlier year is identical to the API pull). Read by
  scripts/02_prep_survey_data.R section 1 and scripts/07_calc_tier4.R section 3. Once the
  crabpack API carries the correction, the API call quoted in 02 can replace it.

survey_large_male_index_derived.csv, survey_recruit_index_derived.csv
  Written by 02 from the file above (large/preferred-male and recruit indices). Outputs,
  not inputs -- never edit by hand.

EBSCrab_AB_Sizegroup.csv
  Legacy AKFIN size-group export. No script reads it (2026-09); kept for reference only.
