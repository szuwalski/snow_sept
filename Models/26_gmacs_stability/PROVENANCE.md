# Models/26_gmacs_stability -- provenance

Built 2026-08-29 by `00b_build_stability_model.R` from
`Models/26_gmacs_update_newmat_plus_group/`, to address the jitter
instability diagnosed 2026-08-29. **This directory holds INPUTS ONLY -- it has
not been fit.**

## Data

`26_snow_update_newmat_plus_group.dat` and `snow.prj` are **byte-identical** to the 26 model
(md5-checked at build time). This model differs in structure only.

## The three changes

| # | Where | From | To | Why |
|---|---|---|---|---|
| 1 | `snow.ctl:399` M 2019 immature-female | phase 4, est. 1.826 | phase -4, fixed **0.0** | The only one of 412 parameters that moved while the objective did not. |
| 2 | `snow.ctl:74-156` Initial_logN | phase 1 (83 rows) | phase 2 | Took 83 of the 259 parameters out of the phase-1 solve. |
| 3 | `snow.ctl:671` emphasis 7 | 3 | 0 | Mean sex-ratio penalty off; annual deviations now carry it. |
| 3 | forked `gmacsbase.TPL` sex-ratio penalty | `dnorm(x, 2.0)` | `dnorm(x, 1.0)` | sd is hardcoded, not a ctl input. |

Change 1 removes the 2019 mortality event for immature females entirely
(M 2.65 -> 0.427 /yr, annual survival 0.071 -> 0.652) while immature males
(dev 2.03) and mature females (dev 1.33) keep theirs. That is a deliberate
structural assumption, not a neutral fix, and it will move MMB and OFL.

## Executable

Built from `GMACs/GMACS_tpl-cpp_code_recprop_sd1/`, a fork of the shared tree
carrying exactly two changed lines: the sex-ratio penalty sd and the version
stamp. The shared tree is verified unchanged at build time, so no later
rebuild can carry this patch into the accepted model's binary.

Version string: `## GMACS Version 2.20.34-recprop-sd1; ** AEP **; Compiled 2026-01-15`

`gmacs.exe` is deliberately **absent**. The Windows binary is unpatched stock
2.20.34 and would silently fit a different model (sd 2.0) in this directory.

### The recompile was proven to change exactly one thing

Both binaries were run on **identical inputs** — the 26 model's `.dat`/`.ctl`/`.prj`
plus its accepted `gmacs.pin` — with `-maxfn 0 -nohess`, so ADMB steps through all
four phases at zero iterations and evaluates at the accepted parameter vector.
Of ~6,500 lines of `Gmacsall.out`, **7 differ**, and each is a direct consequence
of the one changed line:

| quantity | stock 2.20.34 | recprop-sd1 |
|---|---|---|
| sex-ratio deviation penalty | 91.15836879 | **121.33968499** |
| `nloglike[4]` block sum | 197.75878291 | 227.94009911 |
| **Total** | -23546.34579341 | **-23516.16447721** |

Predicted independently from the 44 parameter values before the run —
`0.5*n*log(2*pi*sd^2) + norm2(x)/(2*sd^2)` with n = 44, `norm2(x)` = 161.812779 —
gives 121.339685 and a total of -23516.164477. Agreement to 8 decimals.

Every catch, index, size-composition and growth likelihood, every other penalty,
and every derived quantity is **bit-identical**. The remaining 4 differing lines
are the version stamp and two timestamps.

## Result: the changes did NOT improve convergence

Fit 2026-08-29 (cold start, 7.8 min), then jittered 100 runs (28.5 min, 4 workers).
The jitter found a fit 9.217 nll better than the cold start and promoted it
(`jitter/082`, seed 20260903, see `jitter/PROMOTION.md`). **Accepted fit:**
npar 411, nll **-23542.505687**, max\|grad\| **0.00362** (still fails 1e-3),
BMSY **156.76648**, OFL(tot) **89.53416**, terminal MMB **150.4187**,
Bcurr/BMSY **1.25492**.

Measured against the 26 model on the same 100-seed jitter:

| | 26 two-sex | **26 stability** | male-only |
|---|---|---|---|
| runs meeting 1e-3 | 10/100 | **3/100** | 9/100 |
| usable (max\|grad\| < 1e-2) | 79 | **74** | 83 |
| reached mode A (05's metric) | 5.1% | **4.1%** | 25.3% |
| reached the lowest nll found | 1% | 3% | 24% |
| nll span over usable runs | 301.6 | **311.8** | 128.7 |
| distinct modes | 6 | **7** | 2 |

The configuration is **no better behaved than the two-sex model it came from**,
and on most metrics slightly worse. The OFL band over usable runs does narrow
(10.1% -> 7.1%), but partly because fewer runs are usable.

The interpretation matters for the model ladder. 69.8% of the 26 model's
across-optima parameter movement is female or sex-allocation, so constraining
that machinery looked like it should recover male-only's behaviour. It does not:
**male-only's advantage comes from removing 178 parameters, not from
constraining the female/sex-ratio machinery.** That is a useful negative result
and the reason this directory exists; it is not a specification candidate.

Change 3 did do what it was designed to do -- sex-ratio logits with \|x\| > 2 fell
from 13/44 to 4/44, max \|logit\| 4.24 -> 3.00, sum of squares 161.8 -> 67.1 --
it simply did not buy convergence.

## Not done

- Not registered in `0-models.R`; it does not reach the SAFE.
- No retrospective, no Tier 4. Not worth running unless the model is kept.
- The jitter's own outputs are kept as `Models/rda_jitter_stability.RData` and
  `plots/*_stability.png`. `05_run_jitter.R` writes `Models/rda_jitter.RData`
  and five fixed plot paths regardless of `--model`, so the 26 model's copies
  were restored from a checksummed snapshot after this run.
