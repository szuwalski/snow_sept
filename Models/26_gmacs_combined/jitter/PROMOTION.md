# Promoted jitter fit

On 2026-08-30, `05_run_jitter.R` found a jitter run that fit better than the base
fit, and promoted it into this model directory.

- source run      : jitter/041
- seed            : 20260862
- nll before      : -23874.700555
- nll after       : -23886.049000  (improvement 11.348445)
- max|grad| after : 0.00227
- jitter sd       : 0.1 over 100 runs
- executable      : gmacs, md5 b677829109fb5bcd996cec5e36e0d17b, ## GMACS Version 2.20.34-combined; ** AEP **; Compiled 2026-01-15

The previous fit is in `jitter/base_prepromotion/`.

`gmacs.pin` is retained deliberately: it is the winner's parameter vector and
is what makes this fit reproducible. ADMB reads it automatically on any further
run in this directory.

**Downstream work must be re-run against this fit** -- `03_build_results_object.R`,
the retrospective peels, Tier 4, and the report.
