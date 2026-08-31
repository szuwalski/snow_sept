# Models/26_gmacs_combined -- provenance

Built 2026-08-30 by `00e_build_combined_model.R`. **Inputs only -- not fit.**
Not a core model folder; not registered in `0-models.R`.

## All three diagnosed pathologies fixed at once

| | M_pars_est[15] | sex ratio | initial-N level | best-nll recovery |
|---|---|---|---|---|
| 26 two-sex (accepted) | flat | saturating | unpenalised | 1.3% |
| 26_gmacs_stability | FIXED | FIXED | left | 4.1% |
| 26_gmacs_eqmdevs | left | left | FIXED | 1.2% |
| **26_gmacs_combined** | **FIXED** | **FIXED** | **FIXED** | to be measured |

Each fix is independently verified: the M parameter provably has zero influence
on the objective; tightening the sex-ratio sd cut saturated years 13/44 -> 4/44;
the equilibrium backbone halved the nll span across usable runs, 301.6 -> 151.8.

`gmacs.exe` is deliberately absent -- the Windows binary is unpatched stock
2.20.34 and would silently fit a different model here.

## Not included, deliberately

Moving `Initial_logN` to phase 2 (a fourth change in `26_gmacs_stability`) is
NOT applied. It was not one of the three pathologies, and its motivation --
phase 1 starting at ~1 crab per size class -- is void under mode 6, where the
deviations start at 0 and phase 1 therefore starts AT the equilibrium.

## Honest expectation

Three individual fixes each failed to move the headline recovery rate. The
combination may too. The argument for trying is that the pathologies are
independent and each fix is verified in isolation. If this does not work, the
conclusion is that the two-sex model's multimodality is not reducible to these
three causes, and male-only's 28.9% reflects something structural about
carrying a female population this weakly informed.
