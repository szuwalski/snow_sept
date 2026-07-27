# Tyler correspondence — 2026 retained-composition prior-year change (RESOLVED)

## Resolution (verified 2026-07)
Tyler forwarded his authentic **8/4/2025** delivery; Grant saved it to `data/bssc_202425 (8 4 2025)/`.
A three-way reconciliation settled where the prior-year change came from:

- Our archived `data/adfg_removals/2024_25/` snapshot is **content-identical** to Tyler's authentic
  8/4/2025 delivery (normalized diff = 0 across all 6 files; the raw 2×N line diffs were just row-order/
  quoting from a re-save). **So nothing was wrong on our end.**
- Tyler's **8/4/2025 vs 2026** deliveries **do** differ in `retained_catch_composition.csv` — 779
  prior-year lines — despite his "no line differences" check (he likely diffed a different file/pair).
- The difference is an early-1990s **crab_year offset** in the 8/4/2025 data: directed-retained rows
  with fishery `QO91` (the 1990 season) were tagged `crab_year 1992`, and `QO92` tagged `1993` — so
  1990/1991 read as empty. Smoking-gun line present in the 8/4 file: `1992,QO91,88,new,1,BSSC`.
- The **2026 delivery corrects it** (QO91→1990, QO92→1991). Independently confirmed correct by the
  retained **totals** file: 1990 and 1991 had ~265M and ~227M crab landed, so their composition must be
  non-zero. The 2026 version is authoritative and has been adopted into `data/new_catch/`.

No further action needed from Tyler on the data. Optional courtesy reply below to close the loop.

---

## Optional reply to Tyler

Hi Tyler,

Thanks for digging that up. I reconciled the three versions and it's sorted out — no problem on your
end with the forwarded file (it matches our archived copy of your 8/4/2025 delivery exactly).

The one spot that did change between your 8/4/2025 and 2026 sends is `retained_catch_composition.csv`:
in the 2025 version the early-1990s directed-retained rows were tagged a couple crab-years late (e.g.
fishery `QO91`, the 1990 season, showed up under crab_year 1992), so 1990 and 1991 looked empty. The
2026 file assigns them correctly to 1990/1991 — which now matches the retained-catch totals, so the
2026 version is the right one. That's the ~779 lines a straight file diff would flag; a quick check on
`retained_catch_composition.csv` specifically should show it.

Nothing you need to do — we'll use the 2026 data and note the small historical correction in the SAFE.
Thanks again!
Grant

---

## Minor open item
- `bssc_discards.csv` was in the 8/4/2025 delivery but not the 2026 set. It's **not used** in the
  assessment pipeline (script 01 reads it into an unused variable), so no action needed unless we want
  the file for completeness.
