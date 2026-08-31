# Models/26_gmacs_initscaled -- provenance

Built 2026-08-29 by `00c_build_initscaled_model.R` from
`Models/26_gmacs_update_newmat_plus_group/`. **Inputs only -- not fit.**
Not a core model folder and not registered in `0-models.R`.

## What changed

`26_snow_update_newmat_plus_group.dat` and `snow.prj` are byte-identical to the 26 model; the executable is the
same stock 2.20.34 binary. Only the initial-condition parameterisation differs.

| Where | From | To |
|---|---|---|
| `snow.ctl` Initial conditions | 2 (FREEPARS) | **3 (FREEPARSSCALED)** |
| `snow.ctl` logRini | phase -1, ival 15.0 | **phase 1, ival 16.04998** |
| `snow.ctl` initial-N rows | 88 | **87** (reference class dropped) |
| `gmacs.dat` use pin file | 1 | 0 |

## Why

In mode 2 the 88 initial numbers-at-length are log(N) assigned straight into
the 1982 population, and the ONLY term touching them is a first-difference
smoothness penalty (`gmacsbase.TPL:10409`). First differences are invariant to
shifting a whole group, so the overall 1982 abundance of each of the 4 groups
is entirely unpenalised. There is no prior either -- `prior_type 0` is `dunif`,
a constant with zero gradient, and `:2099-2103` discards the ctl's p1/p2 for
uniform priors. The ctl's `15 # Initial_devs` emphasis is dead code; no
`nlogPenalty(5)` exists in the TPL.

Mode 3 pins the reference class to 0, makes the vector a simplex scaled by
`exp(logRini)` so the level is a single bounded parameter, and adds
`TempSS` = sum of squares of the active parameters directly to `objfun`
(`:10438`) as genuine shrinkage.

## Caveat measured before building

`TempSS` is **unweighted** -- no emphasis factor -- and shrinks the size
distribution toward FLAT. At the 26 model's fitted structure the offsets span
-28.4 to +4.3 (51 of 82 exceed |2|) and TempSS would be **~11,637** against an
objective of ~-23,546. The optimiser will flatten the size structure and accept
a worse data fit rather than pay that. Mode 3 fixes the unconstrained level and
buys a very strong, biologically implausible shape prior in exchange. Whether
that trade is worth making is what this model was built to measure.

## Next

- Fit, then jitter, then compare against the 26 model on reference points
  (nll is NOT comparable -- TempSS and the parameterisation both changed).
