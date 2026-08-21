---
description: Parse-check every R script and validate the data/derived contract
---

Run a read-only health check on the repo. Report findings; do not fix anything unless asked.

## 1. Parse-check every R script

Run from the repo root:

```powershell
$RS = "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe"
& $RS -e "for (f in c(list.files('.', '\\.R$'), list.files('R', '\\.R$', full.names=TRUE))) { r <- tryCatch({parse(f); 'OK'}, error=function(e) paste('PARSE ERROR:', conditionMessage(e))); cat(sprintf('%-32s %s\n', f, r)) }"
```

## 2. Validate the `data/derived/` contract

All six files must be present, and every comp row must have 22 bins summing to 1:

`directed_catch.csv`, `bycatch_catch.csv`, `fishery_size_comps.csv`,
`survey_size_comps.csv`, `survey_indices.csv`, `male_maturity_ogive.csv`

For the three comp files, check: exactly 22 `m*` columns; each row sums to 1 within 1e-6; no `NA`.
For `survey_indices.csv`, check biomass and cv are finite. Report the max year in each file and
whether they agree with the crab-year convention (fishery ≤ END_YEAR, survey ≤ END_YEAR + 1).

## 3. Report model-directory state

For each dir under `Models/`, report whether `gmacs.exe` is present, and compare the mtime of
`Gmacsall.out` against the model `.dat`. **An output older than its input means stale artifacts** —
per `docs/SESSION_HANDOFF.md` the three newest dirs were seeded from a template and hold results
from a different model. Flag those loudly.

## 4. Check the known traps

Confirm whether each is still live (see `docs/CLEANUP_BACKLOG.md` for the full list):

- Is `R/gmacs_io.R` tracked in git yet? (`git ls-files R/`)
- Do any two scripts write the same file under `plots/`?
- Do the crabpack year ranges in `02_prep_survey_data.R` and `07_calc_tier4.R` still agree?

## Output

A short status table, then only the problems — ranked, with `file:line`. If everything passes, say
so in one line.
