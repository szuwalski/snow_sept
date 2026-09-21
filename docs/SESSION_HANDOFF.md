# Session handoff — September 2026 snow crab SAFE

Pick-up doc for the September 2026 EBS snow crab SAFE in `snow_sept`. See `../README.md` for the full
repo layout and run commands; this file tracks *state and next steps*.

> **Report build plan (added 2026-07-30):** planning + drafts for the SAFE *report* live in this folder —
> start with `SEPT2026_CLAUDE_CODE_HANDOFF.md` (build steps + canonical section outline), then
> `PHASE1_SECTION_SKETCHES.md` (draft Rmd per section) and `SEPT2026_SNOW_CRAB_BUILD_PLAN.md` (scope,
> direction, guideline reconciliation).

## 2026-09-17 — catch accounting corrected; full model rerun pending (READ THIS FIRST)

The September ADF&G delivery of `data/new_catch/bssc_discards.csv` (now through 2025) exposed 2
accounting errors in `scripts/01_prep_fishery_data.R`, both inherited from the 2025 script and
confirmed with C. Szuwalski on 2026-09-17. The agreed accounting, in tonnes for 2025/26 males:

```r
retained    <- tot_retained_wt                 # kept in the snow crab fishery + kept incidentally in other crab fisheries (4125.5)
dir_discard <- QO_total - dir_retained_wt      # snow crab fishery's own discard (6643.2 - 3950.9 = 2692.4; was QO_total - tot_retained_wt = 2517.7)
inc_discard <- QT_total - inc_retained_wt      # other crab fisheries' discard of snow crab (1261.1 - 174.6; QT_total is really the sum over all non-QO codes)
dir_mort    <- 0.3 * dir_discard               # applied INSIDE GMACS (discard_mortality = 0.3 on fleet-1 rows); the .dat carries dir_discard
inc_mort    <- 0.3 * inc_discard               # applied in 01 (was 0.3 * QT_total, which counted the retained crab a second time)
nondirected <- inc_mort + 0.8 * trawl_bycatch  # fleet-2 series in the .dat, discard_mortality = 1
```

Effects: directed discard rises by `inc_retained_wt` in 11 crab years (2005-07, 2013-15, 2017-18,
2021, 2024-25; 0.376 kt total, +6.9% in 2025/26); non-directed bycatch mortality falls by
0.7 x inc (0.052 kt in 2025/26, <= 0.016 kt earlier). Retained series unchanged. 2025/26 total
catch 7.10 -> 7.22 kt; non-directed bycatch mortality 0.422 -> 0.369 kt (the 0.422 figure was sent to
C. Allen on 2026-09-17 and needs correcting). `dir_retained_wt` is NA for 1989-2004, where 01 falls
back to `tot_retained_wt` (equals the ADF&G file in all 16 years). 01 now validates the directed
retained and discard series against `bssc_discards.csv` in every shared year.

Rmd updated (Section A items 1-2, Section D catch data and handling mortality, Section F overfishing
paragraph, Executive Summary overfishing line now computed from `.dc`/`.bc`).

**Total catch convention (GA, 2026-09-18): the overfishing determination uses TOTAL FISHING MORTALITY**,
retained + 0.3 x directed discards (both sexes) + non-directed bycatch mortality, computed at knit
time by `.total_mort()` in the mgmt-performance chunk for all 5 crab years: 3.15, 0.06, 0.11, 2.44,
5.31 kt. Tables 1 and 2 show it beside "Total catch (SSC)", the adopted values (3.60, 0.05, 0.07, 2.81,
NA), whose 2024/25 entry is retained + full male discard with no handling mortality and no bycatch
(the 2016/17-2018/19 rows of the same SSC table were mortalities). `management_performance.csv`
2025/26 total_catch is NA (no adopted value yet). 2025/26 on the old convention would be 7.22 kt.

Reconciliation of the adopted "Total catch" (traced 2026-09-18 through the 2022, 2024 and 2025 SAFEs):
| Crab year | Adopted | Built as (SAFE vintage) | Recomputed mortality |
|---|---|---|---|
| 2016/17-2019/20 | 11.0-20.8 | retained + 0.3 x discards + bycatch (2022 SAFE Table 9, mortalities applied) | same convention |
| 2020/21 | 26.2 | 20.41 + 5.8 RAW discard + 0.07 bycatch (2022 SAFE; the 5.8 is raw although the table header says mortalities applied) | n/a (not in our 5-year window) |
| 2021/22 | 3.6 | 2.48 + 1.16 raw discard, no bycatch (2022 SAFE) | 3.15 (2.52 + 0.3 x 1.69 + 0.13; 2025-vintage data) |
| 2022/23 | 0.05 | bycatch only, 2024 SAFE value | 0.06 (2025 data) |
| 2023/24 | 0.07 | bycatch only, 2024 SAFE value | 0.11 (2025 data; the 2025 SAFE Table 14 already showed 0.11) |
| 2024/25 | 2.81 | 2.15 + 0.66 raw discard, no bycatch (2025 SAFE Table 14, header "no mortalities applied") | 2.44 |
The 2024 SAFE Table 9 has its "Discarded females" and "Discarded males" headers swapped (1982: 1.27 under females).

**Table 2 (current-status) rebuilt 2026-09-18 to the CPT whiteboard layout:** one assessment per row,
keyed to the crab year it specified (2022/23 .. 2026/27), columns Crab year, Assessment, Tier, MSST, MMB,
MMB/B_MSY, F_OFL, OFL, ABC. The 2025/26 row is the SSC-adopted October 2025 values; the 2026/27 row is
this assessment ("G" on the board). Catch and mortality columns live in Table 1 only. The 2025/26
overfished determination (109.30 vs 73.14) is read off the 2026/27 row and the text says so. Table 3
(basis-ofl) keeps the same row structure with B_MSY, its window, M and the buffer.

**Full document review 2026-09-18** (4 reviewers over the Executive Summary, A-D, E-F, G-J + captions; findings applied): year-convention paragraph corrected (the September assessment sets the crab year already under way since 1 July); Table 1 caption timing fixed the same way; Table 1 "Total catch (SSC)" caption now says the adopted values are on 3 different conventions; Table 3 caption no longer claims a one-row offset from Table 2; Tier 3 projection is now labelled as MMB at mating in crab year 2026/27 (was "February 2026"); Executive Summary states the rule and equation behind the OFL; OFL-distribution text corrected (density steps up, does not "change slope"); Section A item 4 comparison rewritten on the 2025/26 basis (ramped + linear), item 2 says 6 corrections; B_MSY window is 1982-2026 (07 BMSY_WINDOW_END = 2027), which the text already said; `ofl_w24` switched to the linear equation (was Baranov, so the window comparison mixed equations); Section C maturity and B_MSY text no longer describe the legacy method as current; Section D non-directed mortality sentence corrected (was "taken as total"); discard series start described as 1982/83 with ADF&G files from 1990/91; Section F ramp description fixed (rule steps to zero at beta = 0.25, ramp does not reach zero there); Baranov gap quoted one way (20% below linear); pulse-fishery formula explained; "sloped" -> "ramped" everywhere; "Model 26.1b (accepted)" -> "(author-preferred)" in Appendix B labels and captions; risk-table caption untangled; Section H names the 2024/25 determination; recruitment years and jitter/retro terminal years print as crab years.

**Numbers still typed that must be refreshed after the model rerun:** 26.1c jitter (10 minima, 1.1%) at Section B; "1.1 to 6.1 percent" (Section B); 26.1b/26.2 B_MSY and OFL pairs (144.06/130.47, 82.46/74.03 in Section E; 172.7/162.5/143.5, 43.8/54.0/80.4/72.5 in Section F); Tier 3 OFL range 43.8-80.4/146.9 (Section G); risk-table "1.27 units ... 12.8 percent"; Section H recruitment series (0.086 ... 1.23 billion); Model 25.3 gradient 0.00134.

**GA edit 2026-09-18 (merged):** the catch-accounting correction is carried by 26.1a, 26.1b, 26.2, 26.1c and Appendix B; 25.3 and 26.1 KEEP their earlier catch series (roll-forward and May baselines). So 00g_patch_catch_accounting.R is to be run on 4 directories, not 6. **Table 1 (mgmt-performance) dropped MSST and MMB the same day** (they were the following-October determination, one row offset from Table 2); its columns are now Crab year, Tier, OFL, ABC, TAC, Retained, Total catch (SSC), Total mortality. The basis-ofl chunk asserts that Tables 2 and 3 agree on Crab year, MMB, F_OFL, OFL and ABC row for row.

**Model-result numbers in the prose are now derived, not typed (2026-09-18).** A new
`model-results-setup` chunk (just before the lists of tables) builds `ref_table` (moved from the
`stepchange` chunk, which now only formats it) and reads gmacs.par (`.par_header`: npar, nll, max
gradient), gmacs.eva (`.eva`: min/max/condition number/non-positive count), gmacs.std joined to the
"Estimated parameters" table of Gmacsall.out (`.partab`: ADMB name, GMACS name, bounds, status flag
"*+"/"*-"), the SE diagnostic (`.se_diag`), parameters at bounds (`.sel_at_ub`), the immature-male M
offset and implied rate, `M_pars_est[15]`/[14], the sex-allocation logits, the Summary block
(`.gmacs_summary`: terminal MMB, first-year SSB, recruitment in billions), the Model 26.1 promotion
(`_pre078_backup` against the current fit), and the per-model jitter block (`conv_files`, `conv_tab`,
`.jstat`/`cv_js`, moved up from `conv-appendix-setup`; `.jstat` gained nmodes, n_at_best, n_ok,
n_runs). About 45 typed values in Sections B, E, F, G, H, the risk table and Appendix B were replaced
with inline code; several were already stale (B_MSY 144.06 vs 143.53 in the file, 26.2 smallest
eigenvalue 120 vs 116, M_pars_est[2] 0.30 vs 0.22, recruitment 0.086/0.062 vs 0.083/0.056, 26.1c now 6
minima and 0 runs at its best fit on the 2026-09-17 jitter). Sentences whose VERBS depend on the
numbers ("lowered", "raised", "among the lowest", "better conditioned", "at its lower bound") print a
visible `[[CHECK: ...]]` flag when the refit no longer supports them; grep the knit for `[[CHECK`.
Recruitment in Section H now reads the Gmacsall.out Summary of the author-preferred model (the same
block 03 copies into reslst). The chunk and every new inline expression were evaluated against the
2026-09-17/18 model files outside the knit; all resolve. Still typed: nothing model-derived that the
review listed; GMACS versions now come from Gmacsall.out line 1.

**Review round 3 (2026-09-19, on the 2026-09-18 evening knit; 4 reviewers; ~70 edits applied).**
Substantive: (1) Table 28 scored Model 26.1 against its pre-promotion base (its jitter summary has no
`reported_nll`), crediting mode A as "best fit found 5 (6.1%)"; `.rep_nll()` now reads the nll from the
model directory's gmacs.par (new `conv_dirs` map) when it matches the jitter's base or best run, so 26.1
prints 0 runs at its reported fit and drops out of `cv_same_best` ("only 2 rows"); the table note explains
the promoted-run case. (2) Tables 29/30 (movement decomposition) were written from an EARLIER jitter set
(31/32/28/61 retained minima vs 43/21/29/62 near-optimal runs in Table 28); the movement-table note now
prints a caveat when `mv_n_opt != near(26.1b)`. **Rerun 05b_jitter_movement_decomposition.R after the
rejitter.** (3) M_pars_est[15] is now described consistently in Section B, Section E (natural mortality
results), Appendix B pathology 1 and caveat 3: estimated at 1.84 (SE 0.58) in the accepted fit, drifts to
its bound from default starts, identifiability open. (4) Table 23 note: bycatch is NOT common to both
models (25.3 keeps the earlier pool); note and code comment corrected. (5) Section C fishery history:
peak years were 1990/91, 1991/92, 1998/99 (was 1991/92, 1992/93 with calendar-season years); the 2000/01
figure labelled; Tier 3 recruitment window now cites Table basis-ofl (1984 start in the 2024 assessment).
(6) ADF&G rule: alpha defined (0.10), prose reconciled with the equation (u = 0.0375 at 25% of the proxy).
(7) Exec Summary: "Neither value is in the stock status table" corrected (71.40 is there); MSST sentence in
item 3 no longer says "lowers"; management-performance note no longer duplicates the convention
paragraph; minima counts everywhere say "well-populated minima (clusters of >= 3 runs) besides the
reported fit". (8) Section E: mode A is the BEST lettered cluster, not the most populated; "No jitter run
improved materially" replaced by the 1-of-77 statement; typed parameter counts (407/412/386/234), the
"5 at bound", "4 were jittered", the bycatch/retained means (now from .bc/.dc) derived; OFL and MMB
ranges split into comparable models vs truncated run, with the sentence that the 3 models ending 2024/25
give a 2025/26 OFL; "directed-fishery OFL" defined against the total OFL; 26.1a role lists 3 corrections;
subtier b sentence; confidence interval wording unified (Table 16 caption and F text). (9) Section G/H:
buffer sentence no longer blames the equation for the lag; ESP sentence no longer says "juvenile";
recruitment narrative now includes 2017/18 and 2023/24. (10) Figures: imm_v_mat.png is now a numbered
figure (fig:imm-v-mat); Figures 15-17 captions say what they are (data inventories); Figure 36 caption
(maturity is data, no black line); Figure 37 recruits scaled to billions with axis labels; growth and
selectivity axes labelled; size-comp captions name which models are plotted (25.3 alone on the legacy
ogive); mmbfits caption reason for excluding 25.3 fixed; Figure 69 "2019/20". (11) Appendix B: several
self-cancelling sentences rewritten; "only structural experiment" (26.2 also improved on its parent);
"All 4 jittered experiments require modified source"; 26.d3 gradient disclosure added; OFL-spread column
says total OFL. (12) 0-models.R purposes: crab-year notation and "author-preferred". (13) Mullowney and
Baker (2021) added to the literature (ICES JMS 78(2): 516-533). Table 6 (datayears) fishery rows print as
crab years.
NOT done, for GA: 24 uncited literature entries (Conan & Comeau 1986; Ennis et al. 1988; Fournier &
Archibald 1982; McAllister & Ianelli 1997; McBride 1982; Methot 1990; Murphy et al. 2017; Myers 1998;
Restrepo et al. 1998; Rodionov 2004; Somerton & Otto 1999; Szuwalski & Punt 2012, 2013; Szuwalski 2017
to 2022, 10 entries; Watson 1972): prune or cite. Figures 66/67 duplicate Figures 18-22 for 26.1b.
Notes to the REMA figure and Figure 26 break across pages in the PDF.

**Review round 4 (2026-09-19, on the 2026-09-19 knit; 4 reviewers; ~45 edits applied).** No
[[CHECK]] or [[not yet computed]] flags fired and every derived number matched its table. Fixed:
26.1a described as carrying 2 corrections in the Exec Summary and Section B but 3 in A and E (now 3
everywhere); "included in every September model" and "incorporated in every model presented above"
both excluded 25.3 in fact but not in words; Table 30's "Minima" column was runs retained within 2
nll of the best fit (31/32/28/61) while Table 28's "Minima" is lettered clusters (4/6/9/6), so the
column is renamed "Runs retained" and the prose, captions and notes follow; Table 8's row label
"Distinct minima identified" now says "Well-populated minima besides the reported fit"; Appendix B's
"26.d3 changed nothing detectable" contradicted the 2 detectable effects reported in the same
paragraph and on the previous page (now "did not raise the recovery rate"); the 26.d1 explanation was
given twice with an unrelated sentence between, and 306.6 is the widest span, not "among the widest";
"Fits to the non-directed fishery catches were good" sat 1 sentence from "had some of the largest
misfits" (the second is about size compositions and now says so); the bycatch/retained means were
over different windows (new `.ret_mean_over()` zero-fills the closed years: 33.7 kt, not 35.7);
the Section F status-interval sentence compared a ratio bound with a biomass threshold; "the
lowest-likelihood solution" for mode A read backwards; the Tier 3 MMB definition hard-coded 2026/27
where only 2 models project there; the historical-MMB sentence called this cycle's model an accepted
assessment; the risk-table and Section J "base model" meant 26.1b while Section E uses that phrase for
25.3; the ADF&G retained-catch cap was misstated as "capped at 58%"; the third case of the ADF&G
equation left status exactly 1 uncovered; the hybrid TAC add-on pointed at Section C, which does not
mention it; the 44-year preferred-male ranking cited Table 10 (2 years) instead of Table 15; "100
jitters were run" cited the model-overview table instead of the jitter-summary table; Section B's
"0.0 to 1.3 percent" cited Section E for numbers only Appendix B carries; Appendix B cited the
attribution table for a claim about 15 parameters where it lists 10; Figure 27's note was the only
unlabelled one and said the peel "adds no survey information" (it removes data); Figure 26 named
neither of the 2 definitions it plots; "The author's priorities" (2 authors); labelled/labeled.
Layout and figure fixes: the size-composition loop used `\newpage`, which does not flush the pending
float, so every second figure drifted past the next heading and Figure 66 landed inside Appendix B
(now `\clearpage`); the size-comp sort put fleet_full before ogive, which reversed the New/Old order
for the pot fishery alone (now ogive first); crab-year and survey-year axis labels on Figures 16, 17,
30, 36 and 40; Figure 39's subtitle said "2018-2019 Mortality Events".
FLAGGED, NOT CHANGED (needs GA / 5 AAC 35.508): Section C says the State proxy is the average total
mature biomass "from 1983 to present" but gives a FIXED 230 million lb threshold, which is 25 percent
of the 1983-1997 average of 921.6 million lb given 1 page later. A rolling average cannot have a fixed
threshold; one of the 2 descriptions is wrong.
STILL OPEN from round 3: 24 uncited literature entries (12 named plus the 12-entry Szuwalski series;
if the 2018a/b, 2019a/b and 2021a/b/c pairs are pruned rather than cited, drop the surviving letters);
Figures 66/67 duplicate Figures 18-22 for 26.1b.

**2026-09-21 (GA): uncited literature stays; jitters must show the current runs; rename to
"Tier 4 fallback" following the CPT; remove the repeated figures.**
1. **05b rerun on the current jitters** (the 2026-09-17/18 runs, after the catch patch). No R on the
   device, so the retained runs' Gmacsall.out + gmacs.par (163 runs) were staged and the UNMODIFIED
   scripts/05b_jitter_movement_decomposition.R was run in the cloud. New files:
   data/diagnostics/jitter_movement_by_{class,param}_<model>_2026-09-21.csv (4 models). The
   2026-09-12 files are left in place; the Rmd now keeps only the newest date per model (it
   required exactly 1 file per model, so 2 dated files would have blanked the section).
   Results moved materially. 26.1b: retained 31 -> 43 (now equal to Table 28's near-optimal count,
   so the stale-decomposition caveat no longer prints); sex-allocation share 23.7 -> 38.7 percent;
   female + sex allocation 64.4 -> 67.9 percent; per-parameter ratio 2.4 -> 4.4. The headline
   (the minima disagree mostly about the females and the sex split) is STRONGER.
   **2 Appendix B statements REVERSED and are now written from the data, not typed as verbs:**
   (a) 26.d3 vs 26.1b: the sex-allocation share now FALLS (38.7 -> 24.3); it had risen. The text now
   says the backbone restrained the male side and the sex ratio but the movement shifted onto the
   females (female + sex allocation still rose, 67.9 -> 79.3), so it moves the disagreement rather
   than removing it. (b) 26.d5 vs 26.2: total movement is now 3.73 against 1.81 (was "almost
   unchanged", 1.75 vs 1.81), with the male share 30.8 -> 60.3; the text notes 62 vs 29 retained
   runs and that ranges grow with n. Both sentences pick their verbs from the numbers.
2. **Stale Appendix B figures.** The author-preferred composite (old Figure 66) and its attribution
   panel read plots/_twosex_jitter_backup/ (2026-09-12, before the catch patch), and the male-only
   figures read plots/_male_only_jitter/ (2026-09-12), while 05 wrote the current images to plots/
   on 2026-09-18. Removed the 26.1b composite and its attribution panel (they repeated Section E's
   Figures 18-22, which read the current files); the male-only figures now read plots/. The other 4
   experiments already read current files.
3. **"Tier 4 fallback".** About 40 uses renamed where they mean this approach (43 in the file now, 3 of them already in quoted SSC/CPT text). KEPT as "Tier 4": the
   FMP tier and control rule ("ramped crab FMP Tier 4 control rule", "the Tier 4 control rule ramps
   down"), the tier assignment ("the SSC assigned this stock to Tier 4", "moved from Tier 3 to Tier
   4", "Tier 4b"), other stocks ("other BSAI crab Tier 4 assessments", "the Tier 4 stocks modeled in
   GMACS"), and every quoted SSC/CPT comment in Section B, verbatim. Section F heading is now
   "Tier 4 fallback". The CPT paragraph now says the document follows the CPT's term, the stock
   itself remains in Tier 4, and the FMP Tier 4 control rule sets F_OFL.

**State B_MSY proxy window: RESOLVED 2026-09-19.** Section C said the ADF&G proxy is the average
total mature biomass "from 1983 to present", which cannot be right because the closure threshold it
quotes is a FIXED 230.4 million lb. Cross-referenced against the previous SAFEs and the FMP:
- 2022-09 SAFE: "from 1983 to 1997"
- 2024-09 SAFE: "from 1983 to 1997"
- 2025-09 SAFE: "from 1983 to present"  <- the error, introduced last cycle and inherited here
- 2000-12 Amendment 14 EA: B_MSY = 921.6 million lb (the 1983-1997 average), MSST = 460.8, and
  230.4 million lb is one half of MSST, below which the fishery closes.
So 921.6 x 0.25 = 230.4 reconciles exactly and the window is the fixed 1983-1997 one. The paragraph
now states the fixed window with the 921.6 and 460.8 million lb values, and says in 1 sentence that
the 2025 assessment's "to present" is not correct and why. It also now says the State proxy is a
different quantity from the Federal B_MSY proxy used for the specification.

**Language pass 2026-09-19 (GA: "reword all AI sounding language").** Removed from the rendered
prose: 11 uses of "carries/carried" in the sense of "holds" (now reported, shows, listed, uses,
advanced to, enters, set to, recommended); "sits" x3 (falls, lies, gives a status of); "and the
answer is"; "which is what" x3; "essentially unchanged" x2 (almost unchanged); "the source of its
advantage"; "the configuration these results point toward" (favor); "a real improvement". Left alone
deliberately: "has not been carried out" and "essentially all large males" (the CPT's own argument),
"robust multinomial" (the likelihood's name), and em-dashes inside code/HTML comments, which no
reader sees. A scan for the usual tells (delve, leverage, underscore, pivotal, seamless, testament,
showcase, myriad, holistic) returns nothing in the prose.

**September 2026 CPT report incorporated 2026-09-19** (GA supplied the docx). 4 additions:
1. Section F, after the B_MSY window paragraph: the CPT's discussion of which years belong in the
   proxy. Assessments are inconsistent (snow crab, SMBKC, NSRKC use the whole series; PIBKC and PIRKC
   a subset); the years should in principle be F_MSY years, which are unknown; the FMP leaves the
   period open; the CPT concluded that excluding years without a directed fishery is likely better
   practice but did NOT recommend changing the snow crab window this cycle, and asked the SSC whether
   assessments should report reference points both ways. Flagged in the text as a candidate for the
   next cycle.
2. Section F, after the Tier 4 introduction: the CPT questioned the "Tier 4" label and calls this the
   fallback option, because the FMP reserves Tier 4 for stocks with simulation modeling capturing
   population dynamics and fishery performance (a REMA smooth does neither) and because the OFL
   calculation differs from the GMACS-based Tier 4 stocks (SMBKC, NSRKC). The document KEEPS the
   Tier 4 label (that is the tier the SSC assigned) and records the distinction. **If the SSC picks
   this up in October, the label may need to change document-wide.**
3. Section G: the CPT's 5 stated reasons for the 50 percent buffer, which the document did not have
   (3.5 percent of terminally molting males reached industry-preferred size in 2026; recruitment very
   low; roughly 85 mature females per mature male; morphometric maturity rather than >= 95 mm, which
   changes the OFL by more than an order of magnitude; and the F_OFL x B bias).
4. Section J: the CPT recommended a simplified male-only model with parameters added back in sequence,
   testing convergence at each step, and expects that work at the January 2027 modeling workshop.
Checked and NOT changed: the CPT's "28% decrease in industry preferred males" is ABUNDANCE; the
document's 29.0 percent is BIOMASS, so they do not conflict. The CPT's "changes the OFL 26-fold" does
not reproduce from data/tier4/tier4_by_currency.csv (21.22/0.750 = 28.3 against > 101 mm, 21.22/1.243
= 17.1 against >= 95 mm), so the document says "more than an order of magnitude" and points at the
currency table rather than quoting 26.

**All 6 models are to be rebuilt on the corrected catch** (decision 2026-09-17), with the 4 jitters and
4 retrospectives. The 3 September directories are backed up as `Models/_pre_discardfix_*`. The
May-era models (25.3, 26.1, 26.1a) must NOT be regenerated through `00_advance_model.R` as it stands:
it rebuilds every block from `data/derived`, which would replace their May survey data and binning.
A catch-only mode is being added to 00 for them. The CPT deck (`docs/2026_snowcrab_CPT_presentation_v3.pptx`)
is left as presented (7.10 kt, 0.42 kt bycatch, "trawl bycatch 100%" on slide 17; the code uses 0.8).

## 2026-09-12 — rerun on the net-mensuration-corrected survey (READ THIS FIRST)

The NMFS survey program corrected 2024–2026 EBS area swept (net mensuration). Staff delivered the
crabpack specimen object as `data/survey/SNOW_specimen_EBS.rds`; 02 and 07 now read it instead of the
API. Only 2024–2026 moved (indices −4.0 to −4.1%, comps ≤0.3%). Everything below the TL;DR predates
this and its numbers are **superseded**. Commit `abf9477` (branch `grant`) holds the first half.

| Quantity | Before | After |
|---|---|---|
| Tier 4 morphometric MMB 2026 | 113.94 kt | 109.30 kt |
| Tier 4 status (95% CI upper) | 0.777 (1.04) | 0.747 (0.997) → text now says "not rebuilt" |
| Tier 4 F_OFL / OFL / ABC | 0.2032 / 18.449 / 14.759 kt | 0.1941 / 16.977 / 13.582 kt |
| Survey total abundance 2024/25/26 (M) | 6849.5 / 7234.9 / 6364.2 | 6578.1 / 6945.5 / 6102.9 |
| 26.1b BMSY / OFL(tot) / MMB | 144.97 / 85.65 / 141.53 | 144.06 / 82.46 / 137.44 |
| 26.2 BMSY / OFL(tot) / MMB | 131.34 / 77.00 / 115.90 | 130.47 / 74.03 / 112.33 |
| 26.1b jitter own-best recovery | 1/79 | 1/78 (six modes; base stands) |
| 26.2 jitter own-best recovery | 25.3% | 15.2% (12/79) |
| 26.1b rho MMB std / drop | −0.109 / −0.110 | −0.110 / −0.108 (10 peels each) |
| 26.2 rho MMB std / drop | −0.092 / −0.083 | −0.090 / −0.081 |
| 26.d5 recovery | 41.2% | 23.3% (20/86) |

Appendix B models (26.d1–d5) refit and jittered on the corrected data; every base fit stood. 26.d5 was
then promoted from `jitter/048` (per Grant): the same optimum, gradient 0.00042 vs 0.029, via the new
`05_run_jitter.R --promote-run`. 26.1c (data to 2019) and 25.x were not refit: 26.1c's inputs are unaffected; 26.1/26.1a/25.3
keep the May survey values, which the SAFE now says (input-data changes, retro table caption).

Traps hit, now documented: first `06 peels` after a data change cold-starts (backlog 1g); seeding can
land a peel in a worse optimum than a cold start (26.1b drop_survey peel 1, recovered with
`scripts/06c_recover_peel.R`); a guard that compares against `HEAD` breaks as soon as you commit mid-run.
Hurtado-Ferro bounds: short-lived [−0.22, 0.30] per Grant (paper: `Reports/fsu198.pdf`).

**Status at end of 2026-09-12:** complete. Rendered PDF + DOCX (14/14 post-render checks; three
adversarial reviews — data/refits, jitters, retrospectives/Appendix B — plus a final document review).
Committed `abf9477` + `0148522` here and `3aafbf4` in `afsc-assessments/snow_crab` (neither pushed).
Follow-up `557feb9` (Grant): Tier 3 OFLs compared with the 2026 survey; fishery history moved to 2025;
Table 1/Table 4 notes and precision fixed; one caption per multi-panel figure; counts print as numerals.
26.d5 re-promoted from `jitter/048` (same optimum, lower gradient). Per Grant (2026-09-13): the specimen
`.rds` is published in the AFSC repo too, and its stray untracked `2026_snowcrab_safe_v2.pdf` was deleted.
Nothing open.

## TL;DR — where we are (superseded 2026-09-12 — see above)
**The assessment now runs on macOS** (GMACS 2.20.34 built from source; see `docs/MACOS_GMACS.md`), and
the 26 model's accepted fit was **replaced on 2026-08-27** by a jitter winner: **nll -23546.3457934123,
OFL(tot) 85.649 kt, terminal MMB 141.528**. Jitter, retrospective and Tier 4 have all been re-run
against it. Two OFL questions are open and must be settled before September (backlog 7d/7e). The
**male-only sensitivity now fits** (2026-08-28) — `Models/26_gmacs_male_only/`, converged and
well-conditioned; jitter and retrospective on it are the next step.

## Done & verified
- **macOS GMACS build.** `GMACs/GMACS_tpl-cpp_code/compile_gmacs_mac.sh` → `gmacs` (arm64, 2.20.34),
  installed beside the untouched `gmacs.exe` in the four 2.20.34 model dirs. Verified numerically:
  seeded with the Windows `gmacs.par` it reproduces **all 975 sdreport quantities** to the precision
  `gmacs.std` records. Machine setup + the two build fixes are in `docs/MACOS_GMACS.md`.
- **26 model re-fit and then promoted (2026-08-27).** 100-run jitter: 79/100 usable, **5.1% found the
  best mode**. Winner promoted (`jitter/088`, seed 20260909); provenance in `jitter/PROMOTION.md`.
  Accepted fit: nll **-23546.3457934123**, max|grad| **0.000931** (meets 1e-3, which neither prior fit
  did), BMSY **144.97170891**, OFL(tot) **85.64948279**, terminal MMB **141.52834**, Hessian condition
  **1.4e06**. `gmacs.pin` in that dir is legitimate and documented — do not delete it.
- **Retrospective re-run against the promoted fit.** 22/22 peels ok. Peel 0 reproduces the parent to
  **2.6e-09** max relative MMB difference over 44 years — it did *not* before peels were seeded.
  Mohn's rho MMB **-0.109** (standard) / **-0.110** (drop-survey), inside the Hurtado-Ferro bounds.
  Recruitment rho 7.9–9.5 is the usual terminal-recruitment artefact.
- **Peels are seeded from the accepted fit.** `write_peel_pin()` (`R/gmacs_io.R` §10) shapes each pin
  from a `.par` GMACS itself wrote for that peel — lengths are never inferred, because two blocks do
  not shrink by peel depth (the fishery was closed in 2022/23). Cold-started, peel 0 landed on the
  *rejected* optimum.
- **Tier 4 reorganised.** Three ~45-line REMA blocks → one `tier4_hcr()`. Proven identical to the
  pre-refactor run (**max |diff| 0.000e+00** on every numeric column of both CSVs). The OFL now
  **exists as data** — `data/tier4/tier4_by_currency.csv` — where before it was only text inside a PNG.
  Current: morphometric **OFL 22.867 kt**, status 0.769.
- **Male-only sensitivity fits, jittered and retrospected (2026-08-28).**
  `Models/26_gmacs_male_only/`, built by `scripts/00_advance_model.R ... TRUE` (arg 8) from the 25
  template, `END_YEAR = 2025`, survey to 2026. **Accepted fit promoted from `jitter/095`**
  (seed 20260916; provenance in `jitter/PROMOTION.md`): npar **234**,
  nll **-14010.6635839271**, max|grad| **0.000705** (meets 1e-3), BMSY **131.34304372**,
  OFL(tot) **76.99559354**, Bcurr/BMSY **1.22784236**, terminal MMB **115.90186501**;
  Hessian smallest eigenvalue **42.5**, condition **9.2e05**, no non-positive eigenvalues.
  `Female Spr_rbar` is exactly 0.
  **Jitter:** 100 runs, 83 usable, 9 meet 1e-3, **25.3% reached the best mode** (the two-sex model
  manages 5.1% — the male-only likelihood is markedly better behaved).
  **Retrospective:** 22/22 peels, all seeded. Peel 0 reproduces the parent to a max relative MMB
  difference of **exactly 0** over 44 years. Mohn's rho MMB **-0.0915** (standard) / **-0.0835**
  (drop-survey), inside the Hurtado-Ferro bounds and tighter than the two-sex -0.109/-0.110.
  Recruitment rho 0.72/0.68, far tamer than the two-sex 7.9-9.5.
  Five file-reduction defects fixed plus the female F offset phased off — all detailed in backlog
  **5e**, which is now closed. **The nll is not comparable to the two-sex -23546.35** (different
  likelihood); compare reference points. The two-sex `.DAT`/`.CTL` are **byte-identical** after the
  change, verified with `cmp`. **Adversarially reviewed 2026-08-28** (findings in 5e): kept data
  proven byte-identical to the two-sex model frame by frame, two defects found and fixed in the
  fix itself, and one caveat for the write-up — **the trawl bycatch observation is sex-combined
  but is now predicted by males alone**; measured to be absorbed by the estimated trawl F (fit
  unchanged), so it is interpretive, not a fit problem.
- **Scripts renumbered (2026-08-27): jitter is `05`, retrospective is `06`, bias plot is `06b`.** The
  jitter can promote a better fit and invalidate a retrospective run before it. 56 references updated;
  both drivers smoke-tested; `.gitignore` and README order fixed.
- **`04_plot_numbers_at_length.R` retired.** Could not run (4 independent blockers) and duplicated
  `02`. Female ridgeline moved to `02` §6c; recruitment comparison rebuilt as
  `scripts/04_plot_recruitment_comparison.R`, reading the fit's own `Gmacsall.out`.
  **Neither new figure has been produced yet** — both need `02` to run (crabpack).
- **Written and parsed, NOT yet run:** `02`'s new §3b/§6c, `scripts/04_plot_recruitment_comparison.R`
  (its transformation logic was exercised against the real fit with a synthetic survey vector),
  and the male-only mode of `00`. `03` and `08` have never run on macOS.

## Model numbering — settled 2026-08-28

The September cycle is **renumbered 26.x** rather than carried on as 25.2c (Grant's call). The
letter-based shortnames are what the report shows; the long strings in `model_defs` /
`scripts/03_build_results_object.R` are internal case keys only and never reach a table or figure, which
go through `to_short()`. The five-model September set:

| Shortname | Folder | Role |
|---|---|---|
| Model 25 | `25_gmacs/` | 2025 rolled-forward reference |
| Model 25.2c | `25_gmacs_update_newmat_plus_group/` | May accepted, terminal 2024 |
| Model 25.2e | `25_gmacs_rightFALSE_growthfix/` | binning (right=FALSE) + growth-typo sensitivity |
| **Model 26.1** | `26_gmacs_update_newmat_plus_group/` | **RECOMMENDED**, terminal 2025 |
| Model 26.1a | `26_gmacs_male_only/` | male-only sensitivity of 26.1 |

`25.2e` because **`25.2d` was already the immature-index model**. The Rmd's `accepted_model` now
resolves to Model 26.1 — **it previously named the May folder**, which would have reported a
terminal-2024 fit as the September assessment.

**`scripts/0-models.R` was pruned to these five on 2026-08-28** (the old "TODO(Phase 3)"). Its precondition
— auditing every `model_defs[N]` use — was done first and found no positional indexing anywhere;
the results object is keyed by case name too. The May bracket lives in `../snow_crab/0-models.R`
and git history. `model_jittered` now sits beside the definitions instead of as a positional vector
in the Rmd. **Consequence still open:** the Rmd's Section C narrative (`:447`-`:477`) still
describes the eleven May models, directly under "A total of 5 models were explored" — the approved
replacement is `PHASE1_SECTION_SKETCHES.md` §12. Backlog **4d**.

**The May 2026 CPT minutes call the recommended run "Model 25.2c"**, so the mapping is stated
explicitly in `PHASE1_SECTION_SKETCHES.md` §C and in the CPT-response text. Verbatim CPT quotes
were deliberately left as "25.2c"; every reference that *means the September Tier 3 model* was
renumbered (14 lines). `Model 25.2c` remains a live designation for the May fit, so surviving
mentions of it are lineage statements, not stale text.

## Model 26.1b (data through 2019) — built, fitted, jittered, retrospected 2026-08-28

The May 2026 CPT asked for a run truncated to 2019 to test whether the convergence problems
originate in estimating recruitment after the 2018-19 collapse and across the missing 2020 survey.
**The answer is no — truncating makes the model markedly less stable, not more.**

`Models/26_gmacs_data2019/`, npar **386**, accepted fit promoted from `jitter/089`:
nll **-19740.5096858427**, max|grad| **0.00291** (does *not* meet 1e-3), BMSY **161.28609864**,
Bcurr/BMSY **1.0544**, OFL(tot) **147.27745429**, terminal MMB (2019) **86.90460802**.
Building it required two `00` fixes — see backlog **4e**.
> Corrected 2026-08-28: this row first read BMSY 168.35 / MMB 91.88, which were the
> **pre-promotion cold-start** values recorded next to the **post-promotion** nll. Two fits in one
> row is exactly the error the known-traps list is about. Values above are all from the promoted
> `jitter/089` fit in `Gmacsall.out`.

| | usable | meet 1e-3 | distinct modes | minor | OFL range across jitters |
|---|---|---|---|---|---|
| 26.1 | 79 | 10 | 6 | 58 | 82.1-90.8 kt |
| 26.1a | 83 | 9 | 6 | **4** | 74.0-95.5 kt |
| **26.1b** | 89 | 12 | **10** | 55 | **0.1-159.3 kt** |

More runs converge usably (89) and more meet 1e-3 (12) — it is not that the model fails to fit, it
is that it fits **many different answers**: ten distinct optima, only **3.4%** reaching the best
one (26.1 manages 5.1%), and a directed OFL spanning three orders of magnitude with two runs
collapsing to ~0. Caveat for the write-up: fewer years means less information, so *some*
degradation is expected on principle — but not a 159 kt spread.

**Retrospective** (22 peels, all seeded; peel 0 reproduces the parent to 1.02e-08 over 38 years):

| | Mohn's rho MMB (std / drop-survey) | recruitment rho |
|---|---|---|
| 26.1 | -0.109 / -0.110 | 7.89 / 9.51 |
| 26.1a | -0.091 / -0.083 | 0.72 / 0.68 |
| 26.1b | **+0.056 / +0.069** | 4.62 / 3.55 |

All three sit inside the Hurtado-Ferro bounds. Note the nuance: 26.1b has the **smallest**
retrospective pattern and the **worst** multimodality, so the two diagnostics disagree — the
retrospective is computed at one optimum and says nothing about how many optima there are.

**Side finding:** 26.1a (male-only) is the best-behaved of the three — only **4** runs scatter into
minor modes against 55-58 for the others. Independent support for the SSC's suggestion to strip the
model toward a minimal parameter set.

**Promotion caveat:** run 089's gradient (0.00291) fails 1e-3, and unlike the male-only case this is
a real tradeoff rather than floating-point noise — only one run lies within `NLL_TOL` of the best
nll, and the best run that *does* meet 1e-3 (run 021) is **1.05 nll units worse**. Left as
promoted because 26.1b is a diagnostic run, not a specification model. Flag it in the write-up.

**Artifacts are NOT at the default paths** (backlog 4b): `Models/rda_jitter_data2019.RData`,
`plots/_data2019_jitter/`, `plots/_data2019_retro/`. Two-sex originals restored and verified.

## Model 25.2c — accepted fit is now jitter run 078 (2026-08-28)

Per Grant: *use 078 if `-hess_step` gets its gradient below 0.001, otherwise keep the macOS
re-fit.* It does — **max|grad| exactly 0**, nll **-19227.1626835733**. Installed; provenance in
`jitter/PROMOTION.md`. All three earlier fits preserved (`_may_fit_backup/`, `_pre078_backup/`).

**A 1.27 nll improvement moved the OFL by -12.81%** (50.266 -> 43.827 kt) while BMSY moved +0.62%
and status -0.33%. That is the multimodality problem stated as a management number, and it is now
written into the convergence section of the Rmd.

**Retrospective re-run against 078** (it is a different optimum, not a polish, so the old one
measured the wrong fit). Mohn's rho also moved with the optimum:

| | macOS re-fit | 078 |
|---|---|---|
| MMB rho standard / drop-survey | -0.105 / -0.174 | **-0.124 / -0.197** |
| recruitment rho standard / drop-survey | 0.86 / 1.24 | **3.92 / 4.55** |

Both MMB values remain inside the Hurtado-Ferro bounds, but drop-survey **-0.197** is now close to
the -0.22 limit, and recruitment rho quadrupled. Worth reporting: the retrospective diagnostic is
itself sensitive to which optimum is adopted.

**Known cosmetic warning:** collect now reports *"peel 0 does not reproduce the parent fit (max rel
diff 2e-06)"*. This is an artefact of the parent being `-hess_step` polished while the peels are
not — peel 0 lands on the unpolished optimum, 2e-06 away in relative MMB, which is immaterial. It
will appear for any model whose retrospective is re-run after polishing. Either accept it, or
polish peel 0 as well for consistency.

## Model 25.2c — the earlier three-way choice (superseded by the above)

Run at Grant's request. **`05` re-fit the base automatically** because the preflight found it stale:
`gmacs.dat` names `snow.ctl` but the run record named `25_snow_update_newmat_plus_group.ctl`, which
no longer exists. Before letting that happen the stored par was checked against the *current* files
(pin + `-maxfn 0`): **-19222.4892880158 vs the stored -19222.4892880162**, agreement to 4e-10 — so
the ctl had simply been renamed and the May fit was valid.

**Three candidate fits now exist for 25.2c. Grant's call which is the step-change baseline:**

| fit | nll | max\|grad\| | where |
|---|---|---|---|
| May / Windows | -19222.4892880162 | 0.00146 | `_may_fit_backup/` (preserved) |
| **macOS cold re-fit** | **-19225.8954975112** | 0.00569 | currently in the model dir |
| jitter run 078 | -19227.1627 | 0.0103 | `jitter/078`, NOT promoted |

The May fit was **3.41 nll units** below what a macOS cold start finds, and the jitter found another
1.27 beyond that. None meets 1e-3, and they trade likelihood against gradient in opposite
directions. `--no-promote` was used so run 078 is reported only. The retrospective below was run
against the **macOS re-fit** (same platform as the rest of the set, better optimum); restoring the
May fit and redoing it is a `cp _may_fit_backup/* .` away.

**Jitter:** 82/100 usable, only **7** meet 1e-3, 6.1% reached the best mode, 6 modes + **60**
scattered runs, directed OFL **21.2-73.2 kt**. Comparable instability to 26.3.
**Retrospective:** 22 peels, all seeded, peel 0 reproduces the parent to 9.09e-11 over 43 years.

**All four retrospectives (Mohn's rho, standard / drop-survey):**

| model | MMB rho | recruitment rho |
|---|---|---|
| 25.2c | -0.105 / **-0.174** | 0.86 / 1.24 |
| 25.2e (new data) | -0.109 / -0.110 | 7.89 / 9.51 |
| 26.2 (male-only) | **-0.091 / -0.083** | **0.72 / 0.68** |
| 26.3 (2019) | +0.056 / +0.069 | 4.62 / 3.55 |

All inside the Hurtado-Ferro bounds; 25.2c's drop-survey -0.174 is the largest. Artifacts at
`Models/rda_jitter_25.2c.RData`, `plots/_25.2c_jitter/`, `plots/_25.2c_retro/`.

## Polishing a fit's gradient — `-hess_step` (verified 2026-08-28)

Several models sit above the 1e-3 gradient criterion. ADMB can polish an existing solution with
Newton steps using the inverse Hessian, which removes the gradient concern without moving the fit.
**Verified working on Model 26.3**: max|grad| **0.00291 -> 0.00000000000000**, nll changed by
**3.8e-7**, BMSY 161.28610 vs 161.28610 and OFL 147.27748 vs 147.27745 — same optimum, polished.
Standard errors are preserved and the full sdreport (`gmacs.std`, `Gmacsall.out`, `admodel.hes`)
is regenerated.

```
./gmacs -binp gmacs.bar -hess_step 5 -nox      # run IN the fitted model directory
```

Requirements, both learned the hard way — the first attempt failed with *"Error reading
admodel.hes file to get MLE values"*:
- the directory must already hold the **fitted `admodel.hes`** (it reads the MLE from it), so run
  this after a normal fit, in place;
- pass **`-binp gmacs.bar`**. ADMB warns that without it *"inactive parameters (and thus gradients)
  may not initialize correctly"*.

**`-nr N` is NOT the flag** — despite the name, `gmacs -help` lists it under *"Random effects
options if applicable"*, i.e. the inner Newton-Raphson for random-effects models. GMACS is not
using random effects here.

One caveat: on 26.3 a single parameter moved by 0.042 while the likelihood moved 3.8e-7. That is
`M_pars_est[12]` (immature-female M, block 2), the near-unidentified parameter — a flat direction,
so polishing slides along it freely. Harmless for reported quantities, but it means `-hess_step`
does not fix a poorly-identified parameter, it only zeroes the gradient. Backlog **5b** still
stands.

**APPLIED to all five models that could take it, 2026-08-28** (per Grant). Every gradient is now
exactly zero and every reference point is preserved to **7e-8 or better**:

| model | nll before -> after | max\|grad\| | BMSY rel diff | OFL rel diff |
|---|---|---|---|---|
| 25.2c | -19225.8954975112 -> -19225.8954979337 | 0.00569 -> **0** | 7.3e-08 | 1.9e-08 |
| 25.2e | -22836.0068920176 -> -22836.0068920175 | 0.00120 -> **0** | *(no pre-polish file)* | |
| 25.2e (new data) | -23546.3457934123 -> -23546.3457934121 | 0.000931 -> **0** | 6.9e-11 | 1.8e-08 |
| 26.2 | -14010.6635839271 -> -14010.6635843467 | 0.000705 -> **0** | 9.9e-10 | 1.1e-08 |
| 26.3 | -19740.5096858427 -> -19740.5096862256 | 0.00291 -> **0** | 1.5e-08 | 2.1e-07 |

Pre-polish fits are in each model's `_prehess_backup/`. **Model 25 could NOT be polished** — it has
no macOS executable (GMACS 2.20.22), so it keeps max|grad| 0.00134 and remains the one
platform-mixed model in the set.

**Model 25.2e was missing `Gmacsall.out`** (a complete fit whose run never wrote that file). Since
`-hess_step` starts from the existing MLE it regenerated every output as a side effect, which is
what fixed it. That missing file had killed the render at chunk 18 of 93 with an opaque
`auto_copy(): ... y is NULL`; the `like-index-tot` chunk now names the model instead, because
`dir.exists()` does not catch a folder whose fit merely failed to finish writing.

**`03` must be re-run after polishing** — the results object reads `Gmacsall.out`. Done.

## SAFE checklist gap analysis — 2026-08-28

Audited `2026_snowcrab_safe_draft.Rmd` against `Reports/2026-08_checklist_crab_SAFE_review.pdf` and
`Reports/2026-08_reminders_crab_SAFE_review.pdf`.

**The section lettering does not match the guidelines, and two required sections are absent.**
The checklist requires *"Every section is present (A-K; even if not applicable to the stock)"* with
a fixed lettering. The Rmd uses its own:

| Required | Rmd today |
|---|---|
| *(Executive Summary, unlettered)* | `# A. Executive summary` |
| **A. Summary of Major Changes** | **MISSING** |
| B. Responses to SSC and CPT Comments | `# B.` ✔ |
| C. Introduction | `# D.` |
| D. Data | `# E.` |
| E. Analytic approach | `# F.` (+ `# C. Assessment scenarios` and `# G. Results`, which the guidelines fold in as *Model Selection and Evaluation* and *Results*) |
| F. Calculation of the OFL | `# H.` |
| G. Calculation of the ABC | `# I.` |
| **H. Rebuilding Analyses** | **MISSING** |
| I. Data Gaps and Research Priorities | `# J.` |
| J. Ecosystem Considerations | `# K.` |
| K. Literature Cited | `# M. References` |

**Both missing sections already have drafted text** — `PHASE1_SECTION_SKETCHES.md` §2
(`# A. Summary of Major Changes`) and §6 (`# Rebuilding Analysis and Update`). **Snow crab is under
a rebuilding plan**, and the checklist says that even in a non-reporting year the heading must be
kept with a note on when the next analysis occurs — so H cannot simply be omitted.

**Other checklist items not yet satisfied:**
- **Tier designation must include the subtier** (a/b/c). "Tier 4a" etc. appears nowhere.
- **Buffer history (5 years) + risk table appendix** is required for EBS snow crab. "buffer history"
  appears nowhere in the Rmd or the sketches.
- **Mention appendices in the Executive Summary** — it currently does not.
- Executive Summary items **1-10** are prescribed (stock, catches, data sources, biomass,
  recruitment, management performance table, basis for the OFL table, OFL pdf, ABC basis,
  rebuilding summary). `# A.` is narrative prose, not those items.
- Exec Summary tables 1-3 **for all model options**, including the Tier 4 fallback.
- `BMSY` in the OFL table is the **current season projection minus 1 (t-1)**; relabel
  **'Current MMB' → 'Projected MMB'**; add a **table of projected MMB at realistic catch values**.
- Table captions must carry **units and model number**.

**Model numbering — the checklist states the convention explicitly:** *"If major changes, then
'Model yy.j' … If minor, then 'Model yy.jx' where x is a letter distinguishing from other minor
change models"*, and the parenthetical form is sanctioned only for a **GMACS version** change
(*"26.0 (v34.0)"*). Current shortnames are `Model 25.2e (new data)` — a parenthetical used for a
data update, not a version — and `Model 26.2` / `Model 26.3` (major-change form) for what are
variants of one base. Under the stated convention those would be `26.1`, `26.1a`, `26.1b`.
**Grant's call**, but a reviewer checks numbering against both this convention and the
SSC-endorsed numbers.

## June 2026 SSC report + SAFE review docs — cross-reference, 2026-08-28

Read from `Reports/2026-06_SSC_report.pdf`, `Reports/2026-08_checklist_crab_SAFE_review.pdf` and
`Reports/2026-08_reminders_crab_SAFE_review.pdf` (all three are text-extractable; the latter
two are CID-encoded and need the ToUnicode CMap, not a naive stream dump).

**Scope — read this before planning the October package.**
> *"The SSC recommends that the author **only bring the Tier 4 model forward in October**, to allow
> more time for development of a simpler, viable Tier 3 model."*

The SSC also says *"a Tier 4 model will likely be needed for specifications until convergence
issues are satisfactorily addressed"*. The Tier 3 runs are still wanted as development (the SSC
asks for a stripped-down minimal-parameter model), but the October **specification** package may be
Tier 4 only. This sits alongside the May CPT's three-run request, which is earlier.

**Model numbering — the review guidance cuts against the 26.x renumbering.**
- Checklist: *"Model numbers are consistent … **with those previously endorsed by SSC**"*
- Reminders: *"cross-validated with those **endorsed by the most recent SSC Report**"*
- Checklist: *"if just GMACS update and no model updates, **include in parentheses but do not
  change model number**, e.g., 26.0 (v34.0)"*

The most recent SSC report calls the accepted configuration **Model 25.2c**. Ours is that same
configuration plus a year of data, renumbered 26.1. Either revert or document the rationale — a
reviewer checks this explicitly. (Counterpoint: the same SSC report uses 26.0 for Tanner's
new-cycle model, so cycle renumbering is not unheard of.)

**Standing requests not yet met.**
- *"The SSC continues to request a **yield-per-recruit analysis** that could be used to inform
  development of an alternative harvest control rule."*
- For 2027 Tier 3 models: a focused **convergence section** — which parameters separate the jitter
  clouds, correlation diagnostics, likelihood profiles for terminal MMB / recent recruitment / M /
  OFL, and targeted simplification runs (examples given: fix the recruitment sex ratio at 50:50,
  reduce confounding among growth, M and selectivity). Model 26.1a already speaks to the last one.

**Checklist items affecting tables.** Executive Summary tables 1-3 for **all** model options
including Tier 4 fallbacks; tier designation must show the subtier (a/b/c); BMSY is the current
season projection minus 1 (t-1); relabel 'Current MMB' to 'Projected MMB'; add a table of projected
MMB at realistic catch values.

**What the SSC did NOT say:** nothing about the Tier 4 ramp — see backlog 7d.

## Known flags / gotchas
- **A new model dir already contains the TEMPLATE's results.** `scripts/00_advance_model.R` §8 copies
  `template_dir`, bringing its `gmacs.par`/`Gmacsall.out`/etc. A male-only build that had *failed at
  runtime* showed a complete, plausible fit (407 par, nll -19222.489) that belonged to the 25 model.
  **Check `gmacs.par`'s mtime before believing any number from a new model dir.** Backlog 1e.
- **Peels never produce reference points.** `gmacsbase.TPL:5478` and `:13625` gate the calculation on
  `nyrRetroNo == 0`, so every peel returns all 18 derived quantities as exactly 0. `retro_refpoints.csv`
  no longer exists; the retrospective reports MMB and recruitment only. Applies to the 2025 SAFE too.
- **`M_pars_est[15]`** (immature-female M, block 2) was **8.707 ± 5351.8** in the pre-promotion fit —
  unidentified, at its bound, and the sole near-zero Hessian eigenvalue. It is why the two platforms'
  cold starts disagreed. In the accepted fit it is 1.826 ± 0.581. Whether it should be fixed
  (`phz = -4`) is a CPT question — backlog 5b.
- **`05`'s promotion rollback silently lied once** (2026-08-24), leaving 7 of 9 files holding a
  rejected fit. Now md5-verified and refuses to promote if the backup is incomplete. **Root cause of
  the copy failure is still unexplained** — backlog 1c.
- **`scripts/07_calc_tier4.R` pulls crabpack live with no fallback** and writes three CSVs at separate points;
  a timeout between two writes leaves a mixed `data/tier4/`. Backlog 7c.
- `Models/25_gmacs` was fit with GMACS **2.20.22** and has no executable — it cannot be reproduced by a
  current binary and got no macOS build.
- **`model_defs[N]` index audit** still not done — audit before pruning `scripts/0-models.R`.

## Blocked on decisions (critical path)
1. **Which Tier 4 basis is correct — ramp or flat M?** `07` ramps (status 0.769 → F_OFL 0.201 →
   **22.867 kt**); `CLAUDE.md:169` says the 2026 basis is *flat F = 0.27, no ramp* → **30.765 kt**.
   A **7.90 kt / 26%** difference on the catch limit, and the two are mutually exclusive. Backlog 7d.
2. **Which OFL formula?** `07` §4 uses `B*(1-exp(-F))`, §6 (the reported one) uses `F*B` — **9.4%**
   apart. Backlog 7e.
3. **The three `25_*` comparison models are still Windows fits.** Any SAFE table comparing them with
   the 26 model mixes platforms. ~30 min to re-fit on macOS.
4. `data/historical/` needs a **2026 column** before the vintage-bias figure is current, and the 2025
   vintage records `0.00` for 2020 MMB-at-survey (COVID, no survey) which plots as real. Backlog 5d.
5. ~~`03` does not include the 26 model.~~ **Resolved 2026-08-28** — see "Model numbering" below.

## Resume here (prioritized)
1. **Settle the Tier 4 basis (blocked #1).** Every OFL/ABC number in the SAFE depends on it, and
   `PHASE1_SECTION_SKETCHES.md:80` has `[[value]]` placeholders waiting on it.
2. **Re-run what the promotion invalidated:** `scripts/03_build_results_object.R` (its
   `Models/rda_ModelsResLst.RData` is dated **2026-07-28**, a month older than the accepted fit), then
   `scripts/08_render_report.R`. `05`/`06`/`07` are already current.
3. **Run `02`** to produce the two new figures and `data/survey/survey_recruit_index_derived.csv`, then
   `scripts/04_plot_recruitment_comparison.R`. Needs crabpack (works; `07` used it 2026-08-27).
4. **Male-only sensitivity: wired into the report, needs `03` re-run.** Fit, jitter, retrospective
   and the report wiring are all done (backlog **5e** closed). Added 2026-08-28 as
   **`Model 25.2c (males only)`** — it keeps the 25.2c designation because the CPT asked for it as
   a *sensitivity of* 25.2c, not a new candidate:
   - `scripts/0-models.R` — appended to `model_defs`/`model_shorts` (**appended, not inserted**, so the
     positional `model_defs[N]` references the port note warns about keep their indices; 1-14 are
     unchanged, male-only is 15).
   - `scripts/03_build_results_object.R` — third folder/label, plus a new guard that fails loudly if the
     labels here, in `scripts/0-models.R`, and the folders on disk ever disagree. Negative-tested.
   - `2026_snowcrab_safe_draft.Rmd` — scenario table (`model-overview`; its `Jittered` column is a
     **positional** vector, now 15 long and assertion-guarded), a `Model 25.2c (males only)` entry
     under Model scenarios, the two assumption bullets, and a convergence/retrospective results
     paragraph. `accepted_model`/`reference_model` are untouched.
   Remaining: **re-run `03`** (see blocker 5), then resolve the `[[VERIFY]]` on the
   B<sub>MSY</sub>/OFL comparison, which is deliberately left to `Table \@ref(tab:stepchange)`
   rather than hardcoded. **5f** records why fixing female phases instead would *not* work; **5b**
   (whether `M_pars_est[15]` should be fixed) does not arise here — there is no female M.
   **Its artifacts are NOT at the default paths** — `05`/`06` write model-independent filenames
   (backlog **4b**), so the male-only copies were moved to `Models/rda_jitter_male_only.RData`,
   `plots/_male_only_jitter/` and `plots/_male_only_retro/`, and the two-sex originals restored.
   **Back those up before running `05` or `06` on any non-default model again.**
5. **Port narrative sections** onto the new Rmd (data-independent) — see `docs/PORT_MAP.md`.
6. Install the 6 missing R packages if `04`/`07` are run on a fresh machine (`rema` is GitHub-only).
