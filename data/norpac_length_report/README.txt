Place the AKFIN export here as:  norpac_length_report.csv

Source : AKFIN "Observer data" > "NORPAC Length Report - Haul & Length"
Filters: Species Name = OPILIO TANNER CRAB;  FMP Area = BSAI (Bering Sea)
Range  : export the FULL available time series -- 01_prep_fishery_data.R slices
         by crab year internally (terminal crab year 2025 = Jul 1 2025 ..
         Jun 30 2026; advance each cycle).
Format : save the raw CSV AS-IS, keeping AKFIN's "Parameter Value(s)" preamble.
         01 reads it via read_norpac(), which auto-detects the column-header row
         (the line starting with the quoted Year column) -- do NOT strip the
         preamble or hard-code a skip=. Date column is d-b-y (e.g. 15-Jul-25).

Large file (~100 MB): re-download fresh each cycle rather than editing in place.
