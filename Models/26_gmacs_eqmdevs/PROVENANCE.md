# Models/26_gmacs_eqmdevs -- provenance

Built 2026-08-29 by `00d_build_eqmdevs_model.R`. **Inputs only -- not fit.**
Not a core model folder; not registered in `0-models.R`.

## What this is

Rceattle's `initMode = 2` ported into GMACS as a new initialisation mode 6
(`EQMDEVS`). The 1982 population becomes

```
d4_N(ig)(syr)(1) = x_equilibrium(ig) * exp(logN0(ig))
```

with `x` the **unfished equilibrium** scaled by `exp(logRini)` (Rceattle's
`R_init`), and `logN0` the 88 log-deviations penalised at the recruitment sd:

```
nlogPenalty(5) = sum_k dnorm(logN0(k) + 0.5*sigmaR^2, sigmaR)
```

weighted by ctl emphasis 5 (`Initial_devs`) -- a slot that was **dead code** in
stock 2.20.34 (no `nlogPenalty(5)` existed). Weight set to 1.0 to mirror
Rceattle, giving an effective sd of sigmaR = exp(-0.9) = 0.407.

With M by size the scalar geometric series `1/(1-exp(-M))` becomes the matrix
Neumann series `(I - S.G)^-1 = sum_k (S.G)^k`, which is what
`calc_brute_equilibrium()` computes by iterating 200 years at constant
recruitment.

## Design points

- Mode number 6, because 4 is already `#define REFPOINTS 4`.
- `bSteadyState = FISHEDEQN` so the equilibrium uses `exp(logRini)`; then
  `log_fimpbar = -100` makes it unfished, matching Rceattle (`Finit = 0` for
  initMode 2).
- The mode does NOT join the `UNFISHEDEQN` branch at `:8418`, which sets
  recruitment for EVERY year. Annual recruitment stays on `logRbar`; only the
  syr equilibrium uses `logRini`.
- The first-difference smoothness penalty `nlogPenalty(10)` is gated OFF:
  `logN0` are deviations here, and Rceattle puts no smoothness on `init_dev`.
- The five rows previously pinned at -19 (absolute log-N, "empty") are pinned
  at 0 instead -- as deviations that means "sit on the equilibrium".

## Verification still owed

Fixing all 88 deviations at 0 must reproduce a pure equilibrium start; that is
the test that the backbone is wired up correctly. Then fit, jitter, and compare
on reference points (nll is NOT comparable across initialisation modes).
