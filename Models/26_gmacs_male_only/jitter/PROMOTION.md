# Promoted jitter fit

On 2026-08-28, `05_run_jitter.R` found a jitter run that fit better than the base
fit, and promoted it into this model directory.

- source run      : jitter/095
- seed            : 20260916
- nll before      : -14010.363162
- nll after       : -14010.663584  (improvement 0.300422)
- max|grad| after : 0.000705
- jitter sd       : 0.1 over 100 runs
- executable      : gmacs, md5 a160a90b6f08cd5ce720d5f67f7e254a, ## GMACS Version 2.20.34; ** AEP **; Compiled 2026-01-15

The previous fit is in `jitter/base_prepromotion/`.

`gmacs.pin` is retained deliberately: it is the winner's parameter vector and
is what makes this fit reproducible. ADMB reads it automatically on any further
run in this directory.

**Downstream work must be re-run against this fit** -- `03_build_results_object.R`,
the retrospective peels, Tier 4, and the report.
