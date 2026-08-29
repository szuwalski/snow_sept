# Running GMACS on macOS

Built and validated 2026-08-24 on Apple Silicon (arm64, macOS 25.3, ADMB 13.2, clang).
The Windows workflow is unchanged; this is additive.

## What is where

| | |
|---|---|
| Source | `GMACs/GMACS_tpl-cpp_code/` (untracked; GMACS 2.20.34 ** AEP **, compiled 2026-01-15) |
| Build script | `GMACs/GMACS_tpl-cpp_code/compile_gmacs_mac.sh` |
| Binary | `gmacs` (Mach-O arm64, 3.5 MB) |
| Installed into | `Models/25_gmacs_rightFALSE/`, `…_growthfix/`, `25_gmacs_update_newmat_plus_group/`, `26_gmacs_update_newmat_plus_group/` |

Each model dir now holds **both** binaries side by side: `gmacs.exe` (Windows, 8,872,135 bytes —
the one that produced every fit currently in `Models/`) and `gmacs` (macOS). Neither overwrites the
other. `Models/25_gmacs` gets no macOS binary: it was fit with GMACS **2.20.22**, a different
version, so a 2.20.34 binary would not reproduce it.

The R drivers pick the right one through `gmacs_exe_name()` (`R/gmacs_io.R`, section 8). Nothing
else in `05`/`06` needs to know the platform.

## One-time machine setup

The macOS ADMB installer ships the contrib library under the plain name `libadmb-contrib.a`, but
the `admb` driver looks for the platform-suffixed name. When it does not find it, it silently omits
`-I$ADMB_HOME/include/contrib` and `-DUSE_ADMB_CONTRIBS`, `statsLib.h` never loads, and every
vector `dnorm()` call in `gmacs.cpp` fails to resolve — ~20 errors that look like a source problem
and are not. Fix once:

```sh
ln -sf /usr/local/admb/lib/libadmb-contrib.a \
       /usr/local/admb/lib/libadmb-contrib-arm64-macos-clang.a
```

## Building

```sh
cd GMACs/GMACS_tpl-cpp_code && zsh ./compile_gmacs_mac.sh
```

Do **not** use the upstream `compile_gmacs.sh` on macOS. It copies `src/*.cpp` to the top level,
but those files pick their headers by platform — the Windows branch (`include\nloglike.h`) resolves
from the top level, which is why `make_win.bat` works, while the Apple branch
(`../include/nloglike.h`) needs the source to sit one level *below* `include/`. The mac script
stages them into `src_mac/` instead. (Building in `src/` directly fails too: the distributed
`src/` and `include/` are mode 555, so clang cannot write object files there.)

## Two macOS-only run behaviours

**1. Exit status 134 is normal.** The debug build (`admb -g`, matching the flags `make_win.bat`
used) reports its accumulated floating-point exception flags and aborts *after* the model has
finished and written every output file:

```
--Number of function evaluations: 3966
Error: Detected division by zero.
Error: Detected invalid argument.
Error: Detected underflow.
```

Measured on the 26 model: run completes, and `gmacs.std` / `gmacs.rep` / `gmacs.rep1` /
`personal.rep` / `checkfile.rep` / `Gmacsall.std` all have line counts identical to the Windows
run. `is_benign_gmacs_exit()` (`R/gmacs_io.R`) excuses exactly these three messages and only when
the finish banner is present; any other error line still fails the run, and it always returns
FALSE on Windows.

**2. The executable must be called as `./gmacs`.** A bare `gmacs` is resolved on `PATH`, not in the
working directory, so `system2()` would report a failure having run nothing. `gmacs_exe_call()`
handles this. ADMB derives its output filenames from `argv[0]`, so the binary stays *in* the run
directory rather than being called by absolute path.

## Cold starts do not reproduce the Windows fit — and that is the model, not the port

Validated on `Models/26_gmacs_update_newmat_plus_group`, 2026-08-24.

**Given the same parameter vector, the two builds are the same model.** Seeding the macOS binary
with the Windows `gmacs.par` as `gmacs.pin` reproduces:

| | Windows | macOS, pinned |
|---|---|---|
| Objective function | -23545.5363970914 | -23545.5363970918 |
| BMSY | 149.51794249 | 149.51794248 |
| OFL(tot) | 86.95426329 | 86.95426327 |
| Terminal MMB | 144.271941 | 144.271941 |

All **975** sdreport quantities in `gmacs.std` agree to every digit that file records.

**A cold start does not.** Starting both platforms from the control file's initial values:

| | Windows | macOS cold |
|---|---|---|
| Objective function | -23545.536 | -23542.768 |
| Max gradient | 0.00254 | 0.00739 |
| BMSY | 149.51794249 | 149.67883570 |
| OFL(tot) | 86.95426329 | 86.69453799 |
| Terminal MMB | 144.27194 | 147.08343 (+1.95%) |

Median MMB difference 2.2%, max 10% in one year; 39% of the 975 sdreport quantities differ by
more than 1%.

This is the model's known instability, not a build defect. Both points are stationary (gradient
norms 0.0076 and 0.0097) and neither reaches the 1e-3 conventional target — which is why `05`
already screens at `GRAD_USABLE = 1e-2` rather than 1e-3. The surface has flat directions:
`logit_rec_prop_est(2011)` sits at -1.833 on Windows and -0.605 on macOS with a gradient near zero
at *both* points. Tiny floating-point differences in the optimiser path (clang/arm64 vs
mingw/x86-64) are enough to end up on a different part of the same plateau. Function-evaluation
counts are nearly identical: 3932 Windows, 3966 macOS.

## Settled: macOS is the platform for this cycle

**Decided 2026-08-24, per Grant.** The 26 model was re-fit on the Mac and that fit is now
authoritative. The reasoning: a cold-started fit is platform-specific, so the only way to avoid two
optima inside one document is to run every fit on one machine. Mixing is the failure mode
`CLAUDE.md` rule 5 exists to prevent, and it would land squarely in the model-comparison tables.

The 26 base fit was re-run in place on 2026-08-24, and then **superseded on 2026-08-27** by a
jitter winner promoted into the directory (`jitter/088`, seed 20260909):

| | Windows cold start | macOS cold start | **accepted: promoted 088** |
|---|---|---|---|
| Objective function | -23545.5363970914 | -23542.7677063715 | **-23546.3457934123** |
| Max gradient | 0.00253639 | 0.00739405 | **0.000931** |
| Meets 1e-3? | no | no | **yes** |
| BMSY | 149.51794249 | 149.67883570 | **144.97170891** |
| OFL(tot) | 86.95426329 | 86.69453799 | **85.64948279** |
| Terminal MMB | 144.27194 | 147.08343 | **141.52834** |
| Smallest Hessian eigenvalue | — | 1.08e-06 | **34.64** |
| Hessian condition number | — | 4.6e13 | **1.4e06** |

### The cold-start divergence was one unidentified parameter, not the platform

Both cold starts were stuck in the same inferior local optimum, distinguished only by which point
on a flat ridge they happened to reach. The ridge is `M_pars_est[15]` — `snow.ctl`'s natural
mortality row 15, **Females (Immature), Block 2**, phase 4, bounds `[-1, 10]`:

| | base fit | promoted 088 |
|---|---|---|
| `M_pars_est[15]` | **8.707 ± 5351.8** (CV 615) | 1.826 ± 0.581 |

In the base fit it runs to its upper bound with an effectively infinite standard error, producing a
single near-zero Hessian eigenvalue (1.08e-06; the next smallest is 19.78). That one flat direction
is why floating-point differences between clang/arm64 and mingw/x86-64 sent the two platforms to
different answers. In the promoted fit the parameter is identified, consistent with its Block-1
sibling (`M_pars_est[14]` = 1.80 ± 0.21), and the flat direction is gone.

**Only 5.1% of 100 jitter runs found this optimum.** Directed OFL across the 79 usable runs spans
81.8–90.6 kt. See backlog item 5b: whether row 15 should be fixed (`phz = -4`) like rows 4, 8, 12
and 16 is a CPT question, not a code fix.

The Windows outputs are tracked in git *except* `Gmacsall.out`, which `.gitignore`'s `*.out` rule
swallows (backlog item 1). The pre-promotion macOS fit is in `jitter/base_prepromotion/`.

**Everything downstream of the base fit must be re-run on macOS**, because it was derived from the
Windows fit: the retrospective (`retro/base_run.csv` still records the Windows nll and its 931.3 s
runtime), the jitter, Tier 4, the results object, and every SAFE table and figure.

**Still open:** `Models/25_gmacs_rightFALSE`, `..._growthfix` and `25_gmacs_update_newmat_plus_group`
hold Windows fits. Until they are re-fit on macOS, any SAFE table comparing them against the 26
model mixes platforms. `Models/25_gmacs` cannot be brought along at all — GMACS 2.20.22, no
executable — so it is already a version inconsistency independent of platform.

**Reproducing a Windows-era number.** Seed the run rather than cold-starting it:

```sh
cp <the windows gmacs.par> <run_dir>/gmacs.pin
```

Note `R/gmacs_jitter.R` hard-stops on a stray `gmacs.pin` for exactly this reason — a pin silently
overrides jittered starting values. Use pins deliberately, and never leave one in a model dir
without a note explaining it.

## Disk

A finished run directory is 637 MB, of which **620 MB is `cmpdiff.tmp`**, ADMB scratch. `05`'s
100-run jitter therefore used to need ~64 GB, which is what its flat `MIN_DISK_GB <- 50` gate was
sized against. `run_gmacs()` now purges `*.tmp` once the process exits (`purge_gmacs_scratch()`),
so only the concurrent workers hold a copy and `05` computes its gate from the real footprint:

```
N_CORES x 0.62 GB scratch  +  N_RUNS x 0.017 GB output  +  1 GB promotion  +  1.5 GB margin
```

For the standard 100 runs on 4 workers that is **6.7 GB**, down from 50. Do not run the volume to
zero regardless: a full disk corrupts whichever run directory is mid-write, and a half-written peel
still parses.
