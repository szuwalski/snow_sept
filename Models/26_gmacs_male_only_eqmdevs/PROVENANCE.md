# Models/26_gmacs_male_only_eqmdevs -- provenance

Built 2026-08-30 by `00f_build_maleonly_eqmdevs_model.R` from
`Models/26_gmacs_male_only/`. **Inputs only -- not fit.** Not a core model
folder; not registered in `0-models.R`.

## What this is

Model 26.2 (male-only) with the equilibrium-backbone initialisation added
(GMACS mode 6, EQMDEVS -- Rceattle initMode 2 ported in). The 44 initial
numbers-at-length become log-deviations around an unfished equilibrium scaled
by `exp(logRini)`, penalised at the recruitment sd via ctl emphasis 5.

## Why this combination

Male-only is the ONLY configuration that reliably recovers its own best fit
(25.3% against ~1-3% for every two-sex configuration; Fisher p < 0.0001).
What still moves in it is dominated by shared recruitment deviations -- 51.7%
of a much smaller total (1.82 against the two-sex 64.04) -- concentrated in
`Rec_dev_est_2019` and `Rec_dev_est_2020`, the COVID survey-gap years. The
equilibrium backbone anchors the early population those deviations trade
against, and under mode 6 male-parameter movement fell 83% (10.11 -> 1.76) in
the two-sex model. So this applies the fix that demonstrably worked on the
structural side to the only configuration with a healthy surface to build on.

## Executable

`GMACs/GMACS_tpl-cpp_code_eqmdevs/gmacs`, used unchanged. Its other patch --
the sex-ratio deviation penalty sd 2.0 -> 1.0 -- is a **no-op** here:
`gmacsbase.TPL:1651` sets `rec_prop_phz = -1` when `nsex == 1`, so
`logit_rec_prop_est` is never active. Confirm after fitting that the
sex-ratio likelihood component is zero.

`gmacs.exe` is deliberately absent -- the Windows binary is stock 2.20.34 and
has no mode 6 at all.

## Expectations

npar should be 235: male-only's 234 plus `logRini`, with the 44 initial-N
parameters re-interpreted rather than added or removed.

nll is NOT comparable to male-only's -14010.6636 -- the parameterisation and
the penalty set both changed. Compare reference points, and compare recovery
against male-only's 25.3%, not against the two-sex models.
