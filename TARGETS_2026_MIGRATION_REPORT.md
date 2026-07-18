# EPC processing: `targets` migration + 2026 data adaptation

This report covers the three tasks:

1. a new [`targets`](https://books.ropensci.org/targets/) workflow that replaces
   the standalone scripts in `R/` (the old scripts are left in place, untouched);
2. adapting the code to the **2026** EPC data downloaded on 2026-07-15 into
   `../inputdata/epc/`; and
3. an audit of the new code, with the bugs found and fixed.

---

## 1. What was built

New files (nothing existing was overwritten):

| File | Role |
|------|------|
| `_targets.R` | Pipeline definition (30 targets: raw files → import → clean → merge → classify → publish). |
| `R/functions_2026.R` | 2026-specific helpers: lower-case `col_types`, 7-Zip extraction, per-year CSV reader, `validate_domestic()`, trailing-space fix. |
| `R/tar_functions.R` | Function-wrapped import/clean steps (adapted from `import_*.R`, `clean_*.R`). |
| `R/tar_merge.R` | Function-wrapped `merge_epcs.R` and `uprn_classifications.R`. |
| `R/domestic_dictionaries_2026.R` | The shared domestic free-text vocabulary, **auto-generated verbatim** from `clean_epc.R` (with one bug fix, see §3.3). Regenerate with `scratchpad/gen_dict.R` logic if `clean_epc.R` changes. |
| `R/domestic_vocab_2026_additions.R` | New/changed 2026 free-text values (see §4). |

The old scripts (`R/functions.R`, `R/translate_welsh.R`, the `import_*`/`clean_*`
scripts, etc.) are still sourced/reused, so the large cleaning vocabularies and
the `td_*/sub_*` helpers are not re-typed.

Run with:

```r
targets::tar_make()          # full pipeline
targets::tar_visnetwork()    # dependency graph
```

> The full run reads the entire GB EPC corpus and needs a very large machine
> (~256 GB RAM). This is inherent to the original design, not the migration.

### Pipeline shape

```
*_zip / *_7z (file targets)         uprn_hist  (uprn_historical: all UPRNs)
        │                                   │
   import_* ─────────────► raw_dom, raw_nondom, raw_dec,
        │                  raw_scot_dom, raw_scot_nondom
        ├───────────────► clean_* ─► clean_dom, clean_scot_dom, clean_nondom,
        │                             clean_scot_nondom, clean_decs
        │                                   │
        │                             merge_gb_* ─► gb_domestic, gb_nondomestic
        └───────────────► classify_uprns ─► uprn_building_type
                                            │
        file_* targets write the canonical outputs to ../inputdata/epc/
        (epc_*_clean.Rds, GB_*_epc.Rds) and uprn_with_buidling_type.Rds/.gpkg
```

---

## 2. 2026 data-format changes that had to be adapted

The 2026 download changed the raw layout substantially. These are adaptations,
not bugs, but the old scripts would not have run without them.

### England & Wales (`domestic-csv-…zip`, `non-domestic-csv-…zip`, `display-csv-…zip`)

* **One CSV per year** (`certificates-2012.csv … certificates-2026.csv`, and the
  matching `recommendations-YYYY.csv`) instead of one big `certificates.csv`.
  The old glob `grepl("certificates.csv", files)` does **not** match
  `certificates-2026.csv`, so the new reader (`read_ew_csvs()`) globs
  `certificates-\d{4}\.csv` and row-binds all years.
* **Column names are now lower-case** (`current_energy_rating`, `uprn`, …). The
  new import upper-cases them (`toupper`) so the rest of the pipeline, which
  expects `UPRN`, `CURRENT_ENERGY_RATING`, etc., is unchanged.
* **`BUILDING_REFERENCE_NUMBER` and `LMK_KEY` are gone**, replaced by a single
  hyphenated `certificate_number`. `col_types` is re-keyed to lower-case,
  `building_reference_number`/`county` are dropped, `certificate_number` is added
  as character. Downstream code that referenced those IDs (only in
  `uprn_classifications.R`) was updated to drop them.
* **No `COUNTY`** column in the 2026 domestic file (removed from the clean subset).

### Scotland (`… Domestic Buildings.7z`, `… Non-domestic … 2026 Q1.7z`)

* Delivered as **7-Zip (`.7z`)** rather than `.zip`. `unzip()` cannot read these,
  so `extract_7z()` shells out to `7z.exe` (auto-located; the archives also
  contain a PDF, which is filtered out).
* Domestic = **per-year CSVs** (`2008.csv … 2026.csv`); non-domestic = a single
  `AltHistoricExtract2013to2026ND.csv`.
* The two-row header (machine names then friendly names) is unchanged, so
  `read_csv(skip = 1)` still yields the friendly-name schema the old Scotland
  code expects.

---

## 3. Bugs found and fixed (audit)

All of the following were verified by running the functions on ~4,000-row
samples of the real 2026 files (see §5).

### 3.1 Scotland non-domestic lodgement date parsed as all-`NA` — **fixed**

`import_nondom_epc_scotland.R` parsed `Lodgement Date` with
`lubridate::ymd_hms()`. The 2026 value is **`dd/mm/yyyy HH:MM:SS`**
(e.g. `11/02/2014 20:59:26`), so `ymd_hms()` silently returns `NA` for every
row. Fixed in `import_scot_nondomestic()` → `dmy_hms()`.

### 3.2 `classify_uprns()` ordered Scottish records by date **strings** — **fixed**

The "most recent certificate per UPRN" logic ordered Scotland by the
`Lodgement Date` **character** column. Because the 2026 Scottish dates are
`dd/mm/yyyy`, a lexicographic sort orders by day-of-month, not by date, and the
subsequent `rbind` mixed character and `POSIXct` columns across sources. Fixed
with a `to_dt()` helper that coerces every source's lodgement timestamp to
`POSIXct` (handling ISO, `dd/mm/yyyy`, and already-parsed values) before
ordering and binding, so the classification really does pick the most recent
certificate.

### 3.3 Vectorised `gsub` silently dropped three substitutions — **fixed**

`clean_epc.R` (England/Wales) contained:

```r
sub_mainheat_description(c("full double glazed","full secondary glazing",
                           "partial double glazing","single glazed"), "")
```

`sub_*` calls `gsub(from, to, …)`. Base `gsub` uses only `from[1]` and warns
*"argument 'pattern' has length > 1"*, so only `"full double glazed"` was ever
removed — the other three glazing strings leaked into `MAINHEAT_DESCRIPTION`.
(The Scotland script had already split these into four scalar calls.) The
generated `domestic_dictionaries_2026.R` splits them into four scalar calls.

### 3.4 Duplicate factor levels crash `validate()` — **fixed**

Several vocabulary vectors contain duplicate entries — e.g. `"cob, as built"`
appears twice in `WALLS_DESCRIPTION`, `"boiler and, mains gas"` twice in
`MAINHEAT_DESCRIPTION`. `validate()` does `factor(x, levels = vals)`, and
`factor()` **errors** on duplicated levels. The original never hit this because
`validate()` always stopped earlier on an unknown value; but as soon as a
column's values are all known, it crashes. `validate_domestic()` de-duplicates
the levels (`unique()`).

### 3.5 Trailing whitespace failed validation — **fixed**

The 2026 Scottish export pads some free-text fields with a trailing space
(e.g. `"solid, no insulation (assumed) "`). `standardclean()` collapses double
spaces but never trimmed the ends, so these failed the strict validation.
`standardclean()` is now wrapped to `trimws()` its output (internal spacing
untouched). This alone resolved the large majority of the Scottish
domestic-clean failures.

### 3.6 Usability improvement — one-shot vocabulary report

The original `validate()` stops at the **first** offending column. On a fresh
data release you fix one column, re-run the (very long) job, hit the next
column, and so on. `validate_domestic()` checks **all** columns in one pass and
reports every unknown value across every column together, so a single run tells
you the full list of additions to make.

### 3.7 `|` free-text handling rewritten (main-part rule) — **fixed**

The `|` character has two very different meanings in the data, and the original
`splitwelsh()` only handled one of them:

* In **England & Wales** the 2026 export contains **no `|` at all** (verified
  across all years and every free-text field) — bilingual English|Welsh pairs
  are gone; Welsh-only text has no `|` and is handled by `translatewelsh()`.
* In **Scotland**, `|` separates **multiple building elements** — very often an
  exact duplicate (`"From main system | From main system"`) but also genuinely
  different parts (`"Cavity wall, … | Timber frame, …"`), up to six parts. `|`
  appears in a large share of Scottish rows (walls 26.7%, roofs 18.2%, floors
  11.8%, and 5–6% of heating/controls/hot-water/lighting).

The old `splitwelsh()` kept the first half of a 2-part value but left **3- and
5-part values unchanged** (so the `|` survived and validation failed) and
**mangled 4- and 6-part values** by concatenating alternate halves with no
separator (producing garbage like `"cavity wall…as built, no insulation…"`).

Per the agreed rule, `splitwelsh()` now takes the **first element as the main
part of the building** (the one to categorise on). Across the full Scottish
dataset the first element is always a single clean value (0% still contain `|`),
collapsing to a small, in-vocabulary category set (e.g. 26 distinct first-part
floors, 70 roofs, 86 walls). The full descriptive wording of that element is
kept — only the secondary elements are dropped. This rule is also applied to
`MAINHEATCONT_DESCRIPTION` (previously cleaned with `split = FALSE`, so its
Scottish `|` values were never split).

> **Downstream note (`build` repo):** `../build/R/epc_summary.R` currently maps
> any cleaned `wall_d`/`roof_d`/`floor_d` containing `|` to `"multiple types"`
> (and counts `walld_multiple`). With this rule there is no `|` left in the
> cleaned output, so those buildings are now categorised by their **main
> element** instead — the intended behaviour. The `"multiple types"` bucket
> becomes empty and can be removed there.

### 3.8 England & Wales compound heating — kept verbatim (decomposition)

Unlike Scotland's `|`, England & Wales joins **multiple heating systems with
commas** (`"boiler, radiators, oil, electric storage heaters"`), and a single
system already contains commas, so there is no clean delimiter. ~1,520 such
compound `MAINHEAT_DESCRIPTION` values appear. Per the data owner's decision to
**keep the full text**, `validate_domestic()` auto-accepts (verbatim) any
`MAINHEAT` value that decomposes into a concatenation of known single systems
(`.decomposes_into()`, backtracking over all matching prefixes), so the
compounds pass validation and are kept for the per-building layer, while
genuinely-new *single* systems are still flagged. No enumeration of the ~1,500
combinations is needed, and it stays robust to new combinations in future
releases.

For decomposition to reach *inside* a compound, the single-system spellings
must be normalised there too, so `domestic_vocab_2026_additions.R` re-applies
the relevant substring rules (the dictionary's exact-match `td_` rules only fire
on a whole value): e.g. `"electricaire"`→`"electric"`, `"boiler&underfloor"`
(→`"boilerand"` after `&`→`and`) →`"boiler, underfloor heating,"`,
`"systems with radiators"`→`"radiators"`, `"heat pump fan coil units"`→
`"heat pump, fan coil units"`. Across the full dataset this takes the residual
from ~1,520 to **5** genuinely-odd values, which are accepted verbatim.

### 3.9 Welsh free-text encoding — **fixed** (curly apostrophe + missing phrases)

The 2026 England & Wales Welsh text uses a **curly apostrophe (U+2019, UTF-8
`E2 80 99`)**, e.g. `"wedi'i inswleiddio"`, but `translate_welsh.R`'s patterns
use a straight `'`, so the Welsh was never translated and failed validation.
`standardclean()` now normalises U+2019/U+2018 to a straight `'` before
`translatewelsh()` runs, which lets the existing dictionary fire. A wrapper adds
the handful of complete Welsh phrases the dictionary still lacked
(`"i'r awyr y tu allan"` → "to external air", etc. — best-effort, for
Welsh-speaker review as `translate_welsh.R` already invites). Remaining
**truncated/corrupt Welsh fragments** in the source (e.g. `"'i inswleiddio"`)
and mangled unit tokens are set to `NA`. Helper files are now sourced with
`encoding = "UTF-8"`.

---

## 4. Known limitations / remaining maintenance

### 4.1 Domestic free-text vocabulary — 2026 additions

The strict validation is intentional: every EPC release introduces new/changed
free-text values, and a human decides how to map them. The 2026 additions live
in `R/domestic_vocab_2026_additions.R`. They were completed by cleaning the
**whole 3.7M-cert Scottish domestic dataset** and checking every distinct
cleaned value against the vocabulary: after the additions, **0 unknown values
remain** for Scotland (and 0 `|` characters). The additions split into:

* **Systematic cleaning rules** (genuine improvements, not just look-ups):
  * decode `&amp;` before `&`→`and` (§3.7 note below is separate) — fixes ~483
    mangled `"boiler andamp; underfloor…"` rows;
  * blank strings and `"(error)"` tokens → `NA`;
  * **roof text in the walls field** → `NA` — ~9,150 Scottish rows (0.25%)
    carry a roof description in `WALL_DESCRIPTION` (a **source-data error**);
    these are set to unknown rather than polluting the wall categories
    (flagged for the data owner);
  * strip the Scottish `"group N: <category> "` prefix on heating controls;
  * assorted typo/synonym fixes (`"imited"`→`"limited"`,
    `"celect type"`→`"celect-type"`, `"(another premises above)"`→
    `"(another dwelling above)"`, missing commas, etc.).
* **New categories accepted verbatim** (to keep detail for the per-building
  layer): new loft-insulation thickness bands; `basement`/`full exposed`
  floors; `curtain wall`/`basement wall` types; new hot-water descriptions
  (gas-warm-air circulators, solar re-orderings); new heating/fuel combinations
  (`lng`, `bioethanol`, `boiler with radiators, …`); new Scottish `MAIN_FUEL`
  strings (normalised further in `merge_gb_domestic()`).

England & Wales was checked the same way against the **whole 23.6M-cert dataset**.
After the compound-heating decomposition (§3.8), the Welsh encoding fix (§3.9),
the same systematic rules, and accepting the new English categories
(hot-water/wall variants, U-values, `basement`/`curtain wall`, new fuels), the
remaining unknowns are handled in the "Full-England-&-Wales-run additions"
block. Anything the pipeline still can't confidently classify (truncated Welsh
fragments, mangled unit tokens) is set to `NA`.

### 4.2 Scotland `|`-separated descriptions — resolved by the main-part rule

This was previously flagged as needing a decision. That decision has been made
and implemented (§3.7): **take the first `|` element as the main part.** Applied
to the full Scottish dataset, this removes every `|` from the cleaned output and
leaves only single, in-vocabulary values, so it is no longer a blocker — the
remaining work is the ordinary per-release vocabulary top-up in §4.1.

### 4.3 Best-effort Welsh translations for review

The Welsh phrases added in the `translatewelsh()` wrapper (§3.9) are
machine-inferred and cross-checked against the English vocabulary, in the spirit
of `translate_welsh.R`'s existing note. A Welsh speaker should review them. Any
Welsh the pipeline cannot translate is set to `NA`, so Welsh-only certificates
with unusual/corrupt text lose those descriptions rather than blocking the run.

---

## 5. What was tested

Correctness was checked at three levels: on ~4,000-row samples cut from the real
2026 archives, on the **whole domestic free-text corpus** (Scotland 3.7M certs,
England & Wales 23.6M certs) for vocabulary coverage, and with static DAG checks.
The full end-to-end pipeline still needs ~256 GB RAM to run in one pass.

* **`tar_validate()` / `tar_manifest()`** — pipeline builds a valid 30-target DAG.
* **Whole-dataset free-text coverage** — after the cleaning rules and 2026
  vocabulary additions, **0 unknown values remain** for Scotland domestic, and
  for England & Wales every column reaches 0 except the compound `MAINHEAT`
  values, which `validate_domestic()` accepts by decomposition (§3.8). 0 `|`
  characters remain in any cleaned field.
* **Imports (all five)** — parse the real 2026 headers/rows; `UPRN` numeric,
  `INSPECTION_DATE` a date, flags → logical, upper-casing correct.
* **`clean_ew_domestic`** — full run incl. free-text standardisation and
  validation passes (3,880 rows, 36 cols on the sample).
* **`clean_ew_nondomestic`, `clean_scot_nondomestic`, `clean_dec`** — pass.
* **`clean_scot_domestic`** — now passes on the sample (3,855 rows). The
  free-text cleaning was additionally validated against the **whole 3.7M-cert
  Scottish domestic dataset**: after the `|` main-part rule and the 2026
  additions, **0 unknown values remain** across all eight free-text columns
  (and 0 residual `|`).
* **`merge_gb_domestic`** — verified end-to-end on real cleaned England/Wales +
  Scotland data (7,735 rows, years 2016–2026): year, `pv`, `tenure`, `fuel`,
  and age-band harmonisation all correct.
* **`merge_gb_nondomestic`** and **`classify_uprns`** — run and produce the
  expected shapes (the date-parse fix in §3.2 exercised).

A full production run still requires (a) completing the 2026 vocabulary
(§4.1) and (b) the §4.2 Scotland decision.
