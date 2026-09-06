# Helpers specific to the 2026 targets pipeline (see _targets.R).
#
# The 2026 EPC open-data release changed the raw file layout:
#   * England & Wales are now delivered as one CSV PER YEAR inside a single
#     zip (certificates-2014.csv ... certificates-2026.csv), with LOWER-CASE
#     column names, and BUILDING_REFERENCE_NUMBER / LMK_KEY replaced by a
#     single `certificate_number`.
#   * Scotland is now delivered as 7-Zip (.7z) archives (per-year CSVs for
#     domestic, one combined CSV for non-domestic) instead of .zip.  The
#     two-row header (machine names then friendly names) is unchanged, so the
#     friendly-name schema the old scripts expect still works with skip = 1.
#
# This file only holds NEW helpers; the shared cleaning helpers and the
# free-text vocabularies are still provided by R/functions.R and
# R/translate_welsh.R, which the pipeline also sources.

# ---------------------------------------------------------------------------
# Column spec for the England & Wales certificates (2026 layout)
# ---------------------------------------------------------------------------
# Re-use the carefully tuned England/Wales `col_types` from functions.R, but
# key it by the new lower-case column names and drop the column that no longer
# exists (building_reference_number), adding certificate_number instead.
# Reusing the original object guarantees the type/factor choices stay in sync
# with functions.R rather than being re-typed (and drifting) here.
make_col_types_2026 <- function() {
  if (!exists("col_types", inherits = TRUE)) {
    stop("col_types not found - source('R/functions.R') before make_col_types_2026()")
  }
  ct <- get("col_types", inherits = TRUE)
  names(ct$cols) <- tolower(names(ct$cols))
  ct$cols[["building_reference_number"]] <- NULL   # gone in 2026 layout
  ct$cols[["county"]] <- NULL                       # not in the 2026 domestic layout
  ct$cols[["certificate_number"]] <- readr::col_character()
  ct
}

# ---------------------------------------------------------------------------
# Validate the cleaned domestic free-text columns against their vocabularies
# ---------------------------------------------------------------------------
# Like validate() in functions.R, but checks ALL columns in one pass and, on
# failure, reports every unknown value across every column together (so a run
# reveals the full list of 2026 additions to make, instead of one column at a
# time).  The valid-value vectors are read from the global environment, where
# R/domestic_dictionaries_2026.R and R/domestic_vocab_2026_additions.R define
# them.  On success each column is converted to a factor to save memory.
# TRUE if `x` is a concatenation of >= 2 of the `known` single-system
# descriptions joined by ", ". Used to auto-accept the England & Wales compound
# heating descriptions (multiple systems in one dwelling) verbatim, without
# enumerating every combination, while still rejecting genuinely-new single
# systems (typos, new fuels) for review. Backtracks over all matching prefixes
# (longest first) so it does not dead-end when a longer prefix is a valid
# single but would leave an un-splittable remainder (e.g.
# "boiler, radiators, electric underfloor heating" splits at "boiler, radiators,").
.decomposes_into <- function(x, known_desc, depth = 1L) {
  hits <- known_desc[startsWith(x, known_desc)]
  if (!length(hits)) return(FALSE)
  for (k in hits[order(-nchar(hits))]) {
    if (identical(x, k)) {
      if (depth >= 2L) return(TRUE) else next
    }
    rest <- substring(x, nchar(k) + 1L)
    if (startsWith(rest, ", ") &&
        .decomposes_into(substring(rest, 3L), known_desc, depth + 1L)) {
      return(TRUE)
    }
  }
  FALSE
}

validate_domestic <- function(certs) {
  cols <- c("FLOOR_DESCRIPTION", "HOTWATER_DESCRIPTION", "WINDOWS_DESCRIPTION",
            "MAINHEATCONT_DESCRIPTION", "MAINHEAT_DESCRIPTION", "MAIN_FUEL",
            "ROOF_DESCRIPTION", "WALLS_DESCRIPTION")

  # Auto-accept compound MAINHEAT descriptions (kept verbatim) that decompose
  # into known single systems, so they pass validation and become factor levels.
  mh <- get("MAINHEAT_DESCRIPTION", envir = .GlobalEnv)
  known_mh <- mh[!is.na(mh) & nzchar(mh)]
  cand <- unique(certs$MAINHEAT_DESCRIPTION)
  cand <- cand[!is.na(cand) & !cand %in% mh]
  if (length(cand)) {
    ok <- vapply(cand, .decomposes_into, logical(1), known_desc = known_mh)
    if (any(ok)) assign("MAINHEAT_DESCRIPTION", c(mh, cand[ok]), envir = .GlobalEnv)
  }

  unknown <- list()
  for (nm in cols) {
    vals <- get(nm, envir = .GlobalEnv)
    bad <- unique(certs[[nm]][!certs[[nm]] %in% vals])
    bad <- bad[!is.na(bad)]
    if (length(bad)) unknown[[nm]] <- bad
  }
  if (length(unknown)) {
    msg <- paste(vapply(names(unknown), function(nm) {
      paste0("  ", nm, " (", length(unknown[[nm]]), " unknown): ",
             paste0("'", utils::head(unknown[[nm]], 50), "'", collapse = ", "))
    }, character(1)), collapse = "\n")
    stop("Values not in the 2026 domestic vocabulary; add mappings to ",
         "R/domestic_vocab_2026_additions.R:\n", msg, call. = FALSE)
  }
  for (nm in cols) {
    # unique(): several original vocabulary vectors contain duplicate entries
    # (e.g. "cob, as built" twice in WALLS_DESCRIPTION), and factor() rejects
    # duplicated levels.  The original validate() never tripped this because it
    # always stopped earlier on an unknown value.
    certs[[nm]] <- factor(certs[[nm]], levels = unique(get(nm, envir = .GlobalEnv)))
  }
  certs
}

# ---------------------------------------------------------------------------
# `|` handling: take the first element as the main part of the building
# ---------------------------------------------------------------------------
# The original splitwelsh() assumed "|" separated an English|Welsh duplicate and
# kept the first half (2-part), or concatenated alternate halves (even-part) /
# left the value untouched (odd-part). In the 2026 data that assumption no
# longer holds:
#   * England & Wales certificates contain NO "|" at all (checked across years);
#     any Welsh-only text has no "|" and is handled by translatewelsh().
#   * The Scottish data uses "|" to separate MULTIPLE building elements - very
#     often exact duplicates ("From main system | From main system") but also
#     genuinely different parts ("Cavity wall, ... | Timber frame, ..."), with
#     up to six parts. The old logic left 3/5-part values unchanged (keeping the
#     "|", which then failed validation) and mangled 4/6-part values by
#     concatenating halves with no separator.
# Agreed rule: take the FIRST element as the MAIN part of the building (and the
# one to categorise on). Taking the first element also happens to drop any
# legacy English|Welsh second half. This preserves the full detail of the
# chosen element (we do not collapse its wording); only the secondary elements
# are dropped. It is overridden here (functions_2026.R is sourced after
# functions.R) so both the pipeline and the shared vocabulary see the new rule.
splitwelsh <- function(x){
  if(is.na(x)){
    return(x)
  }
  if(grepl("|", x, fixed = TRUE)){
    return(trimws(strsplit(x, "|", fixed = TRUE)[[1]][1]))
  }
  x
}

# ---------------------------------------------------------------------------
# Trim leading/trailing whitespace during free-text standardisation
# ---------------------------------------------------------------------------
# The 2026 Scottish export pads some free-text fields with a trailing space
# (e.g. "solid, no insulation (assumed) "), which the original standardclean()
# did not strip, so those values failed validation.  Wrap standardclean() to
# trim the outside; internal spacing is untouched.  (Sourced after functions.R,
# so `standardclean` already exists.)
if (exists("standardclean", inherits = TRUE) && !isTRUE(attr(standardclean, "trims_2026"))) {
  .standardclean_base <- standardclean
  standardclean <- function(x) {
    # Decode the HTML entity "&amp;" BEFORE the base standardclean() turns "&"
    # into "and" - otherwise "Boiler &amp; underfloor" becomes the mangled
    # "boiler andamp; underfloor" (seen ~483 times in the Scottish data).
    x <- gsub("&amp;", "&", x, fixed = TRUE)
    # Normalise the curly apostrophe (U+2019) and curly quotes to a straight
    # apostrophe. The 2026 England & Wales Welsh text uses U+2019 (e.g.
    # "wedi'i inswleiddio"), but translate_welsh.R's patterns use a straight
    # "'", so without this the Welsh is never translated. Harmless for English.
    # \u escapes so this works regardless of the source-file encoding.
    x <- gsub("’", "'", x)
    x <- gsub("‘", "'", x)
    trimws(.standardclean_base(x))
  }
  attr(standardclean, "trims_2026") <- TRUE
}

# ---------------------------------------------------------------------------
# Additional Welsh -> English translations for the 2026 data
# ---------------------------------------------------------------------------
# translate_welsh.R covers many phrases but the 2026 England & Wales data
# includes Welsh phrases it does not, which then fail validation. Wrap
# translatewelsh() to apply these afterwards. Apostrophes are already normalised
# to a straight "'" by standardclean() before translatewelsh() runs.
# BEST-EFFORT (machine-inferred, cross-checked against the English vocabulary) -
# Welsh speakers are invited to review, as in translate_welsh.R.
if (exists("translatewelsh", inherits = TRUE) && !isTRUE(attr(translatewelsh, "welsh_2026"))) {
  .translatewelsh_base <- translatewelsh
  # Complete Welsh phrases the base dictionary lacks (apostrophes already
  # straightened by standardclean). ŵ = w-circumflex, ô = o-circumflex.
  .welsh_2026_map <- c(
    "i'r awyr y tu allan"                                       = "to external air",
    "rheolyddion i wresogyddion storio sy'n cadw llawer o wres" = "controls for high heat retention storage heaters",
    "programmer, trvs a rheolydd ynni ar y bwyler"             = "programmer, trvs and boiler energy manager",
    "adfer gwres dŵr gwastraff"                            = "waste water heat recovery",
    "rheolaeth parthau tymheredd"                               = "temperature zone control",
    "rheolaeth celect"                                          = "celect-type controls",
    "bwyler/cylchredydd nwy"                                    = "gas boiler/circulator",
    "popty estynedig oil"                                       = "oil range cooker",
    "o gynllun cymunedol"                                       = "community scheme",
    "pwmp gwres"                                                = "heat pump"
  )
  .welsh_2026_from <- names(.welsh_2026_map)[order(-nchar(names(.welsh_2026_map)))]
  translatewelsh <- function(x) {
    x <- .translatewelsh_base(x)
    if (is.na(x)) return(x)
    for (from in .welsh_2026_from) x <- gsub(from, .welsh_2026_map[[from]], x, fixed = TRUE)
    x
  }
  attr(translatewelsh, "welsh_2026") <- TRUE
}

# ---------------------------------------------------------------------------
# Locate the 7-Zip executable (Scotland archives are .7z)
# ---------------------------------------------------------------------------
find_7z <- function() {
  cand <- c(
    Sys.which("7z"),
    Sys.which("7za"),
    "C:/Program Files/7-Zip/7z.exe",
    "C:/Program Files (x86)/7-Zip/7z.exe"
  )
  cand <- cand[nzchar(cand)]
  cand <- cand[file.exists(cand)]
  if (length(cand) == 0) {
    stop("7-Zip not found - install 7-Zip or add 7z to PATH (needed for the Scotland .7z archives)")
  }
  unname(cand[1])
}

# Extract one or more members of a .7z archive to `exdir` and return the paths
# of the extracted files. `pattern` filters the returned files (default: CSVs).
extract_7z <- function(archive, exdir, pattern = "\\.csv$") {
  dir.create(exdir, showWarnings = FALSE, recursive = TRUE)
  z7 <- find_7z()
  # e = extract (flat), -o = output dir, -y = assume yes, -bd = no progress
  status <- system2(z7,
                    args = c("e", shQuote(archive), paste0("-o", shQuote(exdir)),
                             "-y", "-bd", "*.csv", "-r"),
                    stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) {
    stop("7-Zip extraction failed (exit ", status, ") for ", archive)
  }
  files <- list.files(exdir, pattern = pattern, full.names = TRUE, recursive = TRUE)
  if (length(files) == 0) {
    stop("No files matching '", pattern, "' extracted from ", archive)
  }
  files
}

# ---------------------------------------------------------------------------
# Read all per-year England & Wales certificate/recommendation CSVs from a zip
# ---------------------------------------------------------------------------
# The 2026 zips hold certificates-YYYY.csv and recommendations-YYYY.csv (one
# per year).  `which` selects the family; the files are read and row-bound.
# `col_types` is passed straight to readr (use NULL to let readr guess).
read_ew_csvs <- function(zip_path, which = c("certificates", "recommendations"),
                         col_types = NULL, exdir = NULL) {
  which <- match.arg(which)
  # A fresh directory per call avoids clashing with a previous extraction of a
  # different archive (or a re-run) in the same session.
  if (is.null(exdir)) exdir <- tempfile("ew_")
  dir.create(exdir, showWarnings = FALSE, recursive = TRUE)
  utils::unzip(zip_path, exdir = exdir)

  files <- list.files(exdir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
  # Match "<which>-2014.csv" etc. but not the other family.
  files <- files[grepl(paste0(which, "-\\d{4}\\.csv$"), basename(files))]
  if (length(files) == 0) {
    stop("No ", which, "-YYYY.csv files found in ", zip_path)
  }
  files <- files[order(basename(files))]

  parts <- lapply(files, function(f) {
    message("  reading ", basename(f))
    readr::read_csv(f, col_types = col_types, progress = FALSE)
  })
  out <- dplyr::bind_rows(parts)
  names(out) <- toupper(names(out))
  out
}

# ---------------------------------------------------------------------------
# PHOTO_SUPPLY -> "yes"/"no"
# ---------------------------------------------------------------------------
# Both countries publish the PV field as a QUANTITY (percentage of roof area,
# supply, or peak power in kWp), not as a flag, so the recode has to read the
# number out and treat 0/blank/missing as "no".  Deriving "yes" from a parsed
# positive number - rather than from "anything I do not recognise" - also means
# a future change to the published format fails towards under-counting PV
# instead of silently flagging most of the housing stock as having panels.

# England & Wales: a bare number (percentage of roof area covered by PV).
pv_flag_number <- function(x) {
  size <- suppressWarnings(as.numeric(x))
  ifelse(is.na(size) | size == 0, "no", "yes")
}

# Scotland: free text describing the array.  Three mutually exclusive size
# fields appear across the corpus, so take whichever is present:
#   "Array: Roof Area: 40%; Connection: ...;  |"
#   "Array: Supply: 0;  |"
#   "Array: Peak Power: 2.7; Orientation: ...;  |"
# An empty capture ("Array: Roof Area: %;  |") parses to NA and so reads as
# "no", which is correct - a blank array size means no PV was recorded.
pv_flag_scotland <- function(x) {
  num <- function(pattern) {
    suppressWarnings(as.numeric(stringr::str_match(x, pattern)[, 2]))
  }
  size <- dplyr::coalesce(num("Roof Area: ([0-9.]*)%"),
                          num("Supply: ([0-9.]*)"),
                          num("Peak Power: ([0-9.]*)"))
  # Values that carry no recognisable size field at all are worth knowing about
  # - they would previously have been counted as PV.
  unparsed <- !is.na(x) & is.na(size)
  if (any(unparsed)) {
    message("pv_flag_scotland: ", sum(unparsed), " value(s) with no parseable ",
            "array size, treated as no PV, e.g. ",
            paste(utils::head(unique(x[unparsed]), 3), collapse = " / "))
  }
  ifelse(is.na(size) | size == 0, "no", "yes")
}
