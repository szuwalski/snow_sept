# Promoted jitter fit

On 2026-08-27, `05_run_jitter.R` found a jitter run that fit better than the base
fit, and promoted it into this model directory.

- source run      : jitter/088
- seed            : 20260909
- nll before      : -23542.767706
- nll after       : -23546.345793  (improvement 3.578087)
- max|grad| after : 0.000931
- jitter sd       : 0.1 over 100 runs
- executable      : gmacs, md5 a160a90b6f08cd5ce720d5f67f7e254a, ## GMACS Version 2.20.34; ** AEP **; Compiled 2026-01-15

The previous fit is in `jitter/base_prepromotion/`.

`gmacs.pin` is retained deliberately: it is the winner's parameter vector and
is what makes this fit reproducible. ADMB reads it automatically on any further
run in this directory.

**Downstream work must be re-run against this fit** -- `03_build_results_object.R`,
the retrospective peels, Tier 4, and the report.

## 2026-09-12: refit on the corrected survey (this pin is now a STARTING point)

The 2024-2026 survey was corrected (net mensuration; `data/survey/SNOW_specimen_EBS.rds`). The model was
refit on the new `.dat` with this `gmacs.pin` as the starting vector, then polished with
`./gmacs -binp gmacs.bar -hess_step 5 -nox`:

- nll -23548.6971760082 (not comparable to the values above: different data)
- max|grad| 0.0037 before the polish, 0 after (step 0 of `hess_step.log`)
- BMSY 144.056, OFL(tot) 82.463, terminal MMB 137.437

A 100-run jitter on the new data (`--force`, seeds 20260822-20260921) found no better fit and did
not promote: 1 of 78 converged runs recover it. So the pin above no longer IS the fit; the fit is
`gmacs.par`. The pre-correction fit is in `../_pre_netcorr_backup/`.
