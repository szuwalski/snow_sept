# Keeping the CPT deck and the SAFE in sync

EBS snow crab, September 2026 cycle. Written 2026-09-16, after the deck
(`docs/2026_snowcrab_CPT_presentation.pptx`, 52 slides) and the document
(`2026_snowcrab_safe_draft.Rmd`, 5,171 lines) were worked on in parallel for a
week. Line numbers are against the Rmd as of 2026-09-16 02:29.

## 1. How far apart they actually are

Of 109 distinct numeric claims on the slides, 104 reproduce exactly in the
knitted SAFE (`2026_snowcrab_safe_draft.docx`, 2026-09-14). The two do not
disagree about the arithmetic. What differs is structure, basis and coverage:

- 1 quantity is computed on 2 different bases and prints as 2 different numbers
  (Section 2.1).
- 4 tables present the same underlying data in different shapes, and the
  deck's shapes are better (Section 2.2).
- 6 pieces of deck content have no counterpart in the document (Section 2.4).
- 1 figure caption in the document describes something its own code does not
  produce (Section 2.3).

The deeper asymmetry is that every number in the SAFE is computed at knit time
from named R objects, while every number on a slide is typed by hand. The
document cannot go stale against the data. The deck can, silently, and did
several times this week. Section 3 proposes a fix that costs about an hour.

## 2. Specific changes to the Rmd

### 2.1 Stock status basis (RESOLVED 2026-09-16)

`current-status` reported `109.30 / 142.79 = 0.765`, the deck reported
`109.30 / 146.29 = 0.747`. The document was following written guidance. The May
2026 CPT report, p. 3:

> The stock status table (SSC Table 1, CPT new Table 3) uses MSST and BMSY, with
> MSST and BMSY originating from two different model years. The MSST is from the
> most recent model/assessment whereas the Bmsy value in this table is from the
> previous year/assessment.

The SSC's own Table 1 has not applied that pairing to this stock. October 2025,
EBS snow crab: MSST 71.40 against a proxy of 142.79, and 71.40 is half of 142.79,
so both came from the 2025 assessment. October 2024: MSST 95.90 is half of
191.81. Of the 8 Tier 1-4 rows in the October 2025 table, 7 have MSST equal to
half the B~MSY~ on the same row; EBS Tanner crab is the only exception, and it is
the one row consistent with the two-assessment pairing.

**Resolved:** status is reported on the current assessment's proxy, 0.747, in
both documents. The reasons are that it is the current estimate of the quantity
status measures, and it is the proxy the control rule acts on in Section F, so
the Executive Summary and the specification agree. The CPT's version is not
hidden: the caption gives 0.765 and names the departure, a paragraph after the
table sets out both bases, and slide 6 carries the same point in one footnote.
Neither basis changes a determination, since MMB of 109.30 kt is above MSST of
73.14 kt and below the rebuilt threshold on both, so this is a procedural
question for the Plan Team rather than a number in dispute.

### 2.2 Port the slide 6 and slide 7 table layouts into the Rmd

The deck's tables are more intuitive than the document's, and the document
already spends 3 long footnote paragraphs (L862, and the prose after
`current-status`) explaining the confusion the deck's layout removes. The May
2026 CPT report also asks for a 5-year history: "in crab SAFE Executive Summary
tables, Table 1 should show a 5-year history".

**Slide 6 replaces 3 tables with 1.** The document currently has
`mgmt-performance-kt` (L852), `mgmt-performance-lb` (L858) and `current-status`
(L887), and the reader has to hold all 3 together to see what happened in any
given year. Slide 6 keys the table on the **October SSC meeting** and splits the
columns into 3 labelled blocks:

| block | columns | meaning |
|---|---|---|
| Status determination | Crab year, MSST, MMB, Status | for the crab year that just ended |
| Catch | Retained, Total | that crab year, as reported |
| Specification | Crab year, OFL, ABC, TAC | for the crab year ahead |

Every field is already in `data/historical/management_performance.csv`
(`crab_year, msst, mmb, tac, retained, total_catch, ofl, abc, mmb_basis,
source`). The layout change is a reshape in `mp_table()` (L827-844), not new
data. The only addition is the status ratio, which needs a B~MSY~ column in the
CSV, or the MSST column doubled, with the basis stated.

Two cautions if you port it:

- The million-pound rendering is a checklist requirement, so keep both, or state
  in the caption that the units are given elsewhere. Do not lose the lb table by
  accident.
- On slide 6 the OFL on each row is the specification for the year **ahead**,
  while the catch on the same row is for the year that **ended**. The footnote
  "Total catch was below the specified OFL in all 5 completed years" is true, but
  a reader comparing across a single row compares 7.10 kt against 16.98 kt when
  the correct comparison is 7.10 against 20.11. Either add a "OFL for the year
  ended" column or move that footnote so it cannot be read off the row. This
  applies to the slide as it stands, not only to the port.

**Slide 7 and `basis-ofl` (DONE 2026-09-16).** Both are now keyed on the
assessment that set each specification rather than on the crab year, with the
crab year kept alongside. That is what makes the B~MSY~ difference against the
status table legible instead of looking like a contradiction: a row labelled
Sept 2024 obviously carries Sept 2024's numbers.

The Buffer and ABC columns were added on 2026-09-16, so the table now shows how
the OFL became the ABC. The buffer is computed from the OFL and the ABC on the
same row rather than typed, so it cannot disagree with them, and it reproduces
the buffer history table (25, 50, 65, 40, 20 percent).

The 2026/27 row already fills from the Tier 4 scalars at knit, which is exactly
the pattern Section 3 generalizes.

### 2.3 Figure caption describes a colour split the code does not make (FIXED by GA, 2026-09-16)

`growthfits` (L4153) captions the figure "Black dots are historical
observations; red dots are new data for 2025." The chunk at L4165 is a single
`geom_point(data = grow_dat, aes(x = premolt, y = increment), alpha = .4)` with
no colour aesthetic, so every point is drawn the same colour.
`data/growth/growth_increments.csv` carries `premolt, sex, increment, cv` and no
year or source column, so the caption cannot be made true from that file as it
stands.

**Fixed.** The caption now states that all observations are drawn in the same
colour and describes the provenance: the increment set used in previous
assessments plus the non-duplicate records of the specimen master, studies 2016
to 2021. That is the right call on the evidence. `SnowCrabGrowthMaster.csv`
carries a `Study_Year` column and its 370 records are 2016 (5), 2017 (192), 2019
(4) and 2021 (169), so there is no 2025 growth data at all and the original
sentence could not have been made true.

### 2.4 Deck content with no counterpart in the SAFE

Ranked by how likely it is to come up at the meeting:

1. **Incoming-recruitment evidence for the 20% buffer.** Slide 41 argues the
   buffer partly on the immature 56-75 mm pre-recruit window sitting 36% above
   its long-term mean. The document's buffer justification (L2091) gives only 2
   reasons, the ESP and the Tier 3 comparison. The index now exists
   (`data/survey/survey_prerecruit_index_derived.csv`, written by section 5b of
   `scripts/02_prep_survey_data.R`), so this is a paragraph and a figure, not new
   analysis. If the CPT presses on the buffer, the SAFE should carry the same
   evidence the slide does.
2. **Model 26.1c diagnostics.** Slide 39 gives MMB rho +0.06, male recruitment
   rho 4.6, 89 of 100 runs converged, 1.1% at the best fit, 10 minima against 6,
   386 parameters against 412. The Rmd names 26.1c in 15 places but none of these
   numbers appear, and "recruitment rho" appears nowhere in the document. The CPT
   asked for this diagnostic, so its results belong in Section E or Appendix B.
3. **The molt-to-years mapping.** Slide 41 states 25% growth per molt, 1 molt a
   year, and windows 1 to 2, 2 to 3 and 3 to 4 years from the preferred size.
   These follow from the Model 26.1b growth matrix and the estimated molt
   probability of 1, and they are what makes a pre-recruit index interpretable.
   Worth a sentence wherever 2.4.1 lands.
4. **The Baranov bias illustration.** Slide 24 holds F~OFL~ = M so only the
   equation changes: 29.51 kt linear against 22.80 kt Baranov, and 21.22 against
   16.98 under the recommended rule. The document explains the change at L2056
   and tabulates the linear OFL in `tier4-currencies`, but never shows the size
   of the bias in one comparison. One sentence.
5. **The 2018 historical-revision series.** Slide 37 gives mature male biomass at
   mating for 2018 as 111.4 kt (2019 assessment), 71.2 kt (2021) and 188.5 kt
   (2025), the same pattern as 2020 without a collapse to explain it. The
   document (L1914) carries the 2020 series only. The 2018 series is the stronger
   argument, because no mortality event confounds it.
6. **The deck's "Table 11" cross-reference.** Slide 24 says the linear values
   stay in Table 11. The linear column lives in the `tier4-currencies` chunk
   (L2010), which is the 9th bookmarked table in source order. Table numbers are
   auto-generated by `officer::run_autonum`, so any table added before it shifts
   the number and the slide silently becomes wrong. Cite the table by name on the
   slide, not by number.

### 2.5 Rounding

The document prints the Tier 4 currency table at 3 decimals (146.290, 109.302,
16.977, 85.203, 4.908) and the deck at 2 (146.29, 109.30, 16.98, 85.20, 4.91).
Nothing is wrong, but 2 renderings of the same table at different precision
invites a question that costs meeting time. `colformat_double(digits = 3)` at
L2019 is the only place this happens; 2 decimals would match every other table
in the document and the deck.

## 3. The structural fix: stop typing numbers twice

Everything in Section 2.4 and most of 2.1 exists because the deck is a
hand-maintained copy of values the Rmd already computes. The setup chunks
(L110-320) already name every one of them: `ofl_2026`, `abc_2026`, `mmb_2026`,
`bmsy_2026`, `msst_2026`, `status_2026`, `fofl_2026`, `ofl_2026_lci`,
`ofl_2026_uci`, `ofl_2026_linear`, `ofl_2026_flat`, `ABC_buffer`, and the jitter
and movement scalars at L659-710 and L1561.

### 3.1 Export them

Add a chunk at the end of the setup block that writes
`data/derived/safe_headline_values.csv` with 4 columns: `name`, `value`,
`units`, `source`. Roughly:

```r
# ---- Headline values, for anything outside this document -------------------
# The CPT deck, the leadership briefing and the ESP summary all quote numbers
# computed here. Writing them out means those documents can be checked against
# this one mechanically instead of by eye.
headline <- tibble::tribble(
  ~name,             ~value,           ~units,    ~source,
  "ofl_2026",        ofl_2026,         "kt",      "Tier 4, ramped rule, Baranov",
  "abc_2026",        abc_2026,         "kt",      "ofl_2026 * ABC_buffer",
  "abc_buffer",      1 - ABC_buffer,   "fraction","author recommendation",
  "mmb_2026",        mmb_2026,         "kt",      "REMA terminal, morphometric",
  "bmsy_2026",       bmsy_2026,        "kt",      "REMA mean 1982-2026",
  "msst_2026",       msst_2026,        "kt",      "0.5 * bmsy_2026",
  "status_2026",     status_2026,      "ratio",   "mmb_2026 / bmsy_2026",
  "status_2026_spec",mmb_2026/cs_bmsy_prev,"ratio","mmb_2026 / 2025/26 specified proxy",
  "fofl_2026",       fofl_2026,        "per yr",  "ramped crab-FMP rule",
  "ofl_2026_lci",    ofl_2026_lci,     "kt",      "REMA CI propagated",
  "ofl_2026_uci",    ofl_2026_uci,     "kt",      "REMA CI propagated"
)
write.csv(headline, "data/derived/safe_headline_values.csv", row.names = FALSE)
```

Both status values go in, named, which makes 2.1 impossible to get wrong again.

### 3.2 Check the deck against it

A short Python script reading the pptx and the CSV. The deck is a zip of XML and
the text lives in `<a:t>` runs, so this is about 30 lines:

```python
# scripts/check_deck_vs_safe.py
# Reports any headline value in data/derived/safe_headline_values.csv that does
# not appear on the slide deck, and any slide number that no longer matches.
import csv, re, zipfile

deck = zipfile.ZipFile("docs/2026_snowcrab_CPT_presentation.pptx")
text = " ".join(
    t for n in deck.namelist() if re.match(r"ppt/slides/slide\d+\.xml$", n)
    for t in re.findall(r"<a:t>(.*?)</a:t>", deck.read(n).decode("utf8")))

for row in csv.DictReader(open("data/derived/safe_headline_values.csv")):
    v = float(row["value"])
    forms = {f"{v:.0f}", f"{v:.1f}", f"{v:.2f}", f"{v:.3f}"}
    if not any(re.search(rf"(?<![\d.]){re.escape(f)}(?![\d])", text) for f in forms):
        print(f"MISSING from deck: {row['name']} = {row['value']} {row['units']}")
```

Run it after every knit and before every deck save. This week it would have
caught the status mismatch, the stale pre-recruit figure and the 2 occasions a
number changed in the model output and not on the slide.

Do not try to generate the deck from the document. The slides are laid out and
edited by hand and that is the right way to build them. A checker that reports
drift is worth having; a generator that fights PowerPoint is not.

### 3.3 Figure parity

The deck rebuilt 14 figures this cycle at smaller `figsize` with larger fonts,
because a figure sized for a page is illegible at the back of a room. Those
rebuilds live in throwaway scripts and will be lost by January. If a figure is
worth showing at the CPT it is worth keeping:

- Put the plotting code for the shared figures in `R/safe_figures.R`, taking a
  `for_slides = FALSE` argument that switches `figsize`, base font size and line
  and point sizes.
- Have the Rmd call it with the default and a small `scripts/06_make_slide_figures.R`
  call it with `for_slides = TRUE`, writing PNGs into `plots/slides/`.
- The deck then embeds files that regenerate from the same code as the document's
  figures, so a data change cannot leave the 2 showing different things.

Highest value first: the REMA rebuilding figure (slide 44), the pre-recruit
windows (slide 41), the retrospective panels (slides 34, 36) and the survey
biomass by maturity definition (slide 16). The rebuilding figure in particular
has no counterpart in Section H at all, and Section H is the part of the SAFE the
SSC has asked for twice.

## 4. Order of work for the next cycle

The trouble this cycle came from building the deck after the document was
already written, then discovering during deck work that some of the document's
choices were hard to present. Slides 6, 7 and 44 all improved under that
pressure, and none of those improvements flowed back until now.

Suggested order for January and for September 2027:

1. Knit the document.
2. Export the headline values (3.1).
3. Build the deck against the exported values, not against the knitted PDF.
4. Where a slide turns out clearer than the document, log it, and port it back
   before the next knit rather than after the meeting.
5. Run the checker (3.2) before sending either one out.

Step 4 is the one that matters. Slides 6, 7 and 44 are all clearer than their
counterparts in the document, and that is a normal result of having to present
something rather than write it. It only pays off if it flows back.

## 5. Already done, 2026-09-16

- Settled the status basis (Section 2.1) and reported both bases in the document
  and on slide 6.
- Extended `current-status` from 1 row to the 5-year history the May 2026 CPT
  asks for, one row per crab year, 2021/22 to 2025/26. Each row pairs MSST and
  B~MSY~ from the assessment that made that determination; the pairing is
  asserted at knit (`MSST == 0.5 * B_MSY` on every row) rather than assumed, and
  the terminal row fills from the Tier 4 scalars instead of the CSV, whose
  2025/26 row carries the October 2025 specification and no determination. The
  ratios reproduce slide 6 exactly: 0.225, 0.593, 0.555, 0.421, 0.747. Unlike
  slide 6, the OFL column is each year's own OFL, which is the correct
  comparison for that year's catch.
- Rebuilt slide 7 and `basis-ofl` on one row per assessment, and dropped the
  "Projected MMB" heading from both. It was right for the Tier 3 rows, where MMB
  is projected to the time of mating, and wrong for the Tier 4 rows, where MMB is
  the REMA survey-time estimate and is not projected at all. The SSC's own Table
  2 uses a plain MMB heading with a footnote, and both now do the same.
- Checked the F~OFL~ column after flagging 14.96 (2023/24) and 25.07 (2024/25) as
  implausible. **That flag was wrong.** The September 2024 SAFE, Table 13, gives
  F35% = 49.63 and status 0.555 for the accepted model, and the Tier 3 ramp
  F35% (status - 0.10) / 0.90 returns 25.11 against the 25.07 published. The same
  formula reproduces both rows of the 2025 SAFE Table 16, including the >= 95 mm
  currency where F35% is 0.73 and F~OFL~ is 0.18. These are real directed-fishery
  F values, large because the fishery selects a narrow size range: an F of 25 on
  the selected component still removes only 20% of projected MMB. Back-solving
  2023/24 gives F35% ~ 41.8, in line with the neighbouring years (39.52, 49.63,
  59.72, 61.78). Both slides now footnote what F~OFL~ is and that the column is
  not comparable across rows.
- Settled the 2022/23 value too, from the September 2022 SAFE (added to
  `Reports/` as `2022-09_SAFE_snow_crab.pdf`). Table 13 gives the CPT-selected
  model 22.1a as MMB 41.21, B35% 183.15, **F35% 1.50**, F~OFL~ 0.32, OFL 10.32,
  and the text states F~OFL~ is 22 percent of F35%, which the ramp reproduces at
  a projected status of 0.30. The back-solved estimate of 1.44 was close. So
  **every F~OFL~ on slide 7 is correct as published.** The column spans 0.32 to
  25.07 because F35% itself moved from a range of 1.37 to 2.26 across the 2022
  models to roughly 40 to 60 from the 2023 assessment onward, a factor of about
  30 in one cycle. Both the slide and the `basis-ofl` caption now say so.
- Worth being ready for: what changed between the September 2022 and September
  2023 assessments to move F35% by 30-fold. The September 2023 SAFE is not in
  `Reports/` and is what would answer it.
- Rebuilt slide 6 on one row per crab year, with the B~MSY~ column included, and
  ported the same layout into the Rmd. Everything on a row now belongs to that
  crab year: the determination made in the October after it ended, the OFL, ABC
  and TAC set in the October before it began, and the catch taken during it. The
  overfishing comparison is a same-row read again, and the chunk asserts it
  (`total catch < OFL` in every completed year). A 2026/27 row carries this
  assessment's proposed specification and nothing else.
- Note: `mgmt-performance-kt` is now fully contained in the status table. Only
  the million-lb rendering (`mgmt-performance-lb`) still carries anything the
  status table does not, and that is a unit conversion. Retiring the kt
  rendering means rewriting the paragraph at L862 that introduces it, which is
  not a pre-meeting job. Nothing cross-references either one, so it can be done
  cleanly next cycle.

- Added the Amendment 53 final EA to the reference list (L2356 area) and the
  in-text citation in Section H (L2242). The document had described the
  rebuilding analysis in detail with no citation, and the reference list carried
  only Amendments 14 and 24.
- Corrected the molt counts in `scripts/02_prep_survey_data.R` (45-55 mm is 3 to
  4 molts, not 4; 76-99 mm is 1 to 2, not 1) and recorded where they come from.
- Moved the pre-recruit block from section 3c to 5b so it can weight by the
  maturity ogive, and added the `immature_abundance` column. Original script
  backed up at `~/02_backup.R`.

## 5b. September 2026 CPT decisions, applied 2026-09-16

The CPT adopted the ramped control rule with the **linear** catch equation,
F~OFL~ x B, and a **50 percent** buffer, and asked that the Baranov result be
reported alongside. It also found "flat" and "linear" easy to confuse, and
identified the male-only model as the most promising Tier 3 direction.

**Requires a re-run of `scripts/07_calc_tier4.R` before the next knit.**
`OFL_EQN` is now `"linear"`. The OFL confidence interval re-applies the selected
rule and equation at each biomass bound, so it follows automatically, but only
once 07 has written a new `data/tier4/tier4_by_currency.csv`.

| quantity | was | becomes |
|---|---|---|
| OFL | 16.98 kt | 21.22 kt |
| ABC | 13.58 kt (20%) | 10.61 kt (50%) |
| OFL 95% CI | 9.27 to 30.36 | 11.29 to 39.27 |
| OFL vs 2025/26 | -16% | +5.5% |
| ABC vs 2025/26 | +13% | -12.1% |

Changes made:

- `07_calc_tier4.R`: `OFL_EQN <- "linear"`, with the decision and its date
  recorded at the switch and in the header block.
- `ABC_buffer <- 0.5`, with the rationale (the catch-equation bias) in the
  comment beside it.
- **The OFL distribution draws were still Baranov.** `ofl_draws` in the setup
  chunk computed `B (F/Z)(1 - exp(-Z))` independently of 07. Switched to
  `F x B`. The chunk's own assertions compare the reconstructed median and
  tails against 07's, so this would have failed the knit rather than printing a
  figure that disagreed with the OFL beside it, but it had to be changed.
- `tier4_all` now selects `OFL_ramp_baranov` as its third column. While Baranov
  was the basis it selected `OFL_ramp_linear`, which after the switch would have
  duplicated the reported OFL. An assertion now fails if those 2 columns match.
- Currency table column headers name the axis each alternative changes:
  "OFL (ramped rule, F x B)", "Rule changed: flat F_OFL = M", "Equation
  changed: Baranov". The caption defines both axes.
- New table `ofl-rule-equation`: a 2 x 2 of control rule against catch equation
  for the recommended currency, which is what answers the confusion directly.
  Rows are rules, columns are equations, and an assertion ties the ramped-linear
  cell to the reported OFL.
- The catch equation section is rewritten. It now reports the linear form as the
  adopted basis and quantifies **2** upward biases: the equation itself
  (the ratio (1 - exp(-Z))/Z, putting the reported OFL 25 percent above Baranov)
  and the survey-to-fishery lag.
- **Survey-to-fishery lag, reported but not applied.** `SURVEY_TO_FISHERY_MONTHS
  <- 7`, matching the interval the September 2024 assessment used for its own
  Tier 4 calculation. exp(-M x 7/12) = 0.854, so F~OFL~ x B on decremented
  biomass would be 18.13 kt against the 21.22 reported. The decrement is not
  applied: the document reports the adopted basis and quantifies the bias beside
  it.
- Buffer justification rewritten. It previously argued that a larger buffer was
  unnecessary and that 20 percent would be the smallest in the 5-year history.
  It now attributes the 50 percent to the catch-equation bias, notes that it
  matches the 2023/24 buffer and sits above the 41 percent average, and keeps
  the ESP and Tier 3 comparison as secondary considerations.
- Male-only model: the staged simplification now starts from `Model 26.2` rather
  than `Model 26.1b`, per the CPT.

**The deck still shows the author draft**, OFL 16.98, ABC 13.58, a 20 percent
buffer, and slide 24 arguing that Baranov replaces the linear form. That deck is
the record of what was presented, so it has been left as delivered.

## 6. Still open

### Data provenance worth one check

`basis_for_ofl.csv` carries **M = 0.29** for the 2022/23 row. Table 13 of the
September 2022 SAFE gives M = 0.28 for model 22.1a, the model the CPT selected,
under a caption that says the reported natural mortality is for mature males.
The Executive Summary table of that same document prints "0.28, 0.29" for M, and
Table 2 of the October 2022 SSC report reproduces the pair, which is where the
0.29 came from. Every other row of this column is the mature-male M and agrees
with its own SAFE's Table 13. So 0.28 is probably the right value for that cell,
but the cited source does print both and this is a provenance call rather than a
clear error. Left as it stands.



- Temporary files left on disk from earlier deck work:
  `plots/bycatch_gear_agg_tmp.csv` and `plots/_gobs_tmp.txt`.
- Slide 46 carries a note to self, "(ask Andre...)", in a bullet that will be
  projected.
