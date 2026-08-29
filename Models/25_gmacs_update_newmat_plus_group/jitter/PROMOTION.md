# Promoted jitter fit — Model 25.2c

On 2026-08-28 the fit in this directory was replaced by jitter run **078**, at Grant's
direction: *use 078 if `-hess_step` gets its gradient below 0.001, otherwise keep the
macOS re-fit.* It does, comfortably.

- source run       : `jitter/078`
- nll              : **-19227.1626835733**
- max|grad|        : **0.00000000000000** (was 0.0102545521036421 as the raw jitter run)
- npar             : 407
- executable       : `gmacs`, GMACS 2.20.34, arm64

## How it was produced

This was a **manual** promotion, not `05_run_jitter.R`'s — that run used `--no-promote`
deliberately, so the model directory would not be re-baselined before the choice was made.
Jitter runs use `-nohess` and therefore leave no `admodel.hes`, which `-hess_step` needs to
read the MLE from. So:

1. seeded a fit from `jitter/078/gmacs.par` (`gmacs.pin`, `IsPin = 1`) and ran **with** the
   Hessian — reproduced 078's optimum to 3e-10 (-19227.1626831553 vs -19227.1626831556) and
   improved max|grad| 0.0103 -> 0.00422 on its own;
2. `./gmacs -binp gmacs.bar -hess_step 5` — max|grad| -> exactly 0, nll moved 4e-7.

`gmacs.pin` here is 078's parameter vector and is what makes this reproducible. Do not
delete it.

## What it replaced, and why that matters

Three fits existed for this model. All are preserved:

| fit | nll | max\|grad\| | kept in |
|---|---|---|---|
| May / Windows (SSC-endorsed number) | -19222.4892880162 | 0.00146 | `_may_fit_backup/` |
| macOS cold re-fit, polished | -19225.8954979337 | 0 | `_pre078_backup/` |
| **078, polished (current)** | **-19227.1626835733** | **0** | model directory |

The May fit sat 4.67 nll units below 078. **The reference points are not insensitive to
this**: against the macOS re-fit, 078 moves BMSY +0.62%, Bcurr/BMSY -0.33% and
**OFL(tot) -12.81%** (50.266 -> 43.827 kt). A 1.27 nll improvement is worth 13% of the
OFL, which is the multimodality problem in one number.

## Downstream

- **The retrospective must be re-run** — it was computed against the macOS re-fit, and this
  is a genuinely different optimum, not a polish. (The earlier `-hess_step` polish moved MMB
  by ~4e-7 and did *not* invalidate the retros; this does.)
- `03_build_results_object.R` must be re-run.
- The jitter itself does **not** need re-running: it is what found 078.
