# Promoted jitter fit

On 2026-08-29, `05_run_jitter.R` found a jitter run that fit better than the base
fit, and promoted it into this model directory.

- source run      : jitter/082
- seed            : 20260903
- nll before      : -23533.288733
- nll after       : -23542.505687  (improvement 9.216954)
- max|grad| after : 0.00362
- jitter sd       : 0.1 over 100 runs
- executable      : gmacs, md5 c1831591dc2dc14a3eb5abef64c6ac4b, ## GMACS Version 2.20.34-recprop-sd1; ** AEP **; Compiled 2026-01-15

The previous fit is in `jitter/base_prepromotion/`.

`gmacs.pin` is retained deliberately: it is the winner's parameter vector and
is what makes this fit reproducible. ADMB reads it automatically on any further
run in this directory.

**Downstream work must be re-run against this fit** -- `03_build_results_object.R`,
the retrospective peels, Tier 4, and the report.
