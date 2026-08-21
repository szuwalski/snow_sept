---
description: Write data/derived into a GMACS model .DAT/.CTL via 00_advance_model.R
argument-hint: "[template_dir] [out_dir] [end_year]"
---

Build a runnable GMACS model directory from a template plus the current `data/derived/` files.

Arguments given: $ARGUMENTS

## Before running

1. **Confirm `data/derived/` is current.** `00_advance_model.R` transcribes whatever is there. If
   `01`/`02` haven't been re-run for this cycle, the model gets last cycle's data. Run `/check`
   first if unsure.
2. **Confirm the template directory.** The accepted May baseline is
   `Models/25_gmacs_update_newmat_plus_group`.
3. **This overwrites `out_dir` completely** — it always regenerates fresh from the template
   (idempotent by design). Confirm with Grant before running if `out_dir` already exists.

## Invocation

```powershell
$RS = "C:/Program Files/R/R-4.5.1/bin/x64/Rscript.exe"
& $RS 00_advance_model.R <template_dir> <out_dir> <end_year> <out_dat_name> [growth_fix] [repo_root] [survey_end]
```

| Arg | Meaning |
|---|---|
| `template_dir` | model dir to copy from |
| `out_dir` | destination (regenerated fresh every time) |
| `end_year` | crab year. Fishery ≤ `end_year`, survey ≤ `end_year + 1` |
| `out_dat_name` | e.g. `26_snow_update_newmat_plus_group.dat` |
| `growth_fix` | default `TRUE`. Fixes the 26.3 mm crab's molt increment `73` → `7.3`, a `.DAT` transcription typo confirmed against the specimen master. `FALSE` builds the without-fix sensitivity |
| `repo_root` | defaults to cwd |
| `survey_end` | defaults to `end_year + 1`. Only the retrospective driver passes something smaller |

Example — the September model:

```powershell
& $RS 00_advance_model.R Models/25_gmacs_update_newmat_plus_group Models/26_gmacs_update_newmat_plus_group 2025 26_snow_update_newmat_plus_group.dat
```

## After running

The script runs its own post-write verification pass (re-reads the emitted file, reconciles every
declared row count). Report what it printed. Then confirm pre-1990 historical rows were preserved
byte-for-byte — `git diff` on the output `.dat` should show changes only in the year ranges the
derived files cover.

**Do not then run `gmacs.exe` without asking.** That's a separate, consequential step.
