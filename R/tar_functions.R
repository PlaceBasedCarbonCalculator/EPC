# Pipeline functions for the 2026 targets workflow (see _targets.R).
#
# These are new, function-wrapped versions of the standalone scripts in R/
# (import_*.R, clean_*.R, merge_epcs.R, uprn_classifications.R), adapted for
# the 2026 EPC data layout.  The originals are left untouched.
#
# Free-text standardisation for the domestic data still uses the large
# vocabularies in R/domestic_dictionaries_2026.R (auto-generated verbatim from
# clean_epc.R) together with the td_*/sub_*/validate helpers in R/functions.R.
# Those helpers read and re-assign a data frame called `certs` in the GLOBAL
# environment, so run_domestic_dictionaries() drives them via .GlobalEnv.

# ===========================================================================
# UPRN location helpers
# ===========================================================================

# uprn_historical is the single source of UPRN point locations for the whole
# workflow: it is the superset of older and newer UPRNs, so it is used for the
# domestic, non-domestic, DEC and classification steps alike.
prep_uprn_historical <- function(uprn) {
  uprn <- sf::st_as_sf(uprn, coords = c("LONGITUDE", "LATITUDE"), crs = 4326)
  uprn[, c("UPRN", "date_first", "date_last")]
}

# ===========================================================================
# IMPORT - England & Wales (one CSV per year inside the 2026 zips)
# ===========================================================================

# Domestic certificates + recommendations.
import_ew_domestic <- function(zip_path) {
  col_types <- make_col_types_2026()
  certs <- read_ew_csvs(zip_path, "certificates", col_types = col_types)

  # Dump unneeded columns (only those present in the 2026 layout)
  for (nm in c("CONSTITUENCY", "CONSTITUENCY_LABEL", "ADDRESS")) certs[[nm]] <- NULL

  # Y/N flags -> logical
  certs$SOLAR_WATER_HEATING_FLAG <- yn2logical(certs$SOLAR_WATER_HEATING_FLAG)
  certs$MAINS_GAS_FLAG           <- yn2logical(certs$MAINS_GAS_FLAG)
  certs$FLAT_TOP_STOREY          <- yn2logical(certs$FLAT_TOP_STOREY)

  # Round numbers where decimals are data errors
  certs$ENERGY_CONSUMPTION_POTENTIAL <- as.integer(certs$ENERGY_CONSUMPTION_POTENTIAL)
  certs$LIGHTING_COST_CURRENT        <- as.integer(certs$LIGHTING_COST_CURRENT)
  certs$LIGHTING_COST_POTENTIAL      <- as.integer(certs$LIGHTING_COST_POTENTIAL)
  certs$HEATING_COST_CURRENT         <- as.integer(certs$HEATING_COST_CURRENT)
  certs$HEATING_COST_POTENTIAL       <- as.integer(certs$HEATING_COST_POTENTIAL)
  certs$HOT_WATER_COST_CURRENT       <- as.integer(certs$HOT_WATER_COST_CURRENT)
  certs$HOT_WATER_COST_POTENTIAL     <- as.integer(certs$HOT_WATER_COST_POTENTIAL)

  certs$MAIN_HEATING_CONTROLS[certs$MAIN_HEATING_CONTROLS == "%%MAINHEATCONTROL%%"] <- NA
  certs$MAIN_HEATING_CONTROLS <- as.integer(certs$MAIN_HEATING_CONTROLS)

  # Missing-data codes -> NA
  certs$FLOOR_LEVEL[certs$FLOOR_LEVEL %in% c("NO DATA!", "NODATA!")] <- NA
  certs$ENERGY_TARIFF[certs$ENERGY_TARIFF %in% c("NO DATA!", "INVALID!")] <- NA
  certs$GLAZED_TYPE[certs$GLAZED_TYPE %in% c("NO DATA!", "INVALID!")] <- NA
  certs$GLAZED_AREA[certs$GLAZED_AREA == "NO DATA!"] <- NA
  certs$FLOOR_ENERGY_EFF[certs$FLOOR_ENERGY_EFF %in% c("NO DATA!", "N/A")] <- NA
  certs$FLOOR_ENV_EFF[certs$FLOOR_ENV_EFF %in% c("NO DATA!", "N/A")] <- NA
  certs$ROOF_ENERGY_EFF[certs$ROOF_ENERGY_EFF == "N/A"] <- NA
  certs$ROOF_ENV_EFF[certs$ROOF_ENV_EFF == "N/A"] <- NA
  certs$MECHANICAL_VENTILATION[certs$MECHANICAL_VENTILATION == "NO DATA!"] <- NA
  certs$MAIN_FUEL[certs$MAIN_FUEL %in% c("NO DATA!", "INVALID!")] <- NA
  certs$HOT_WATER_ENERGY_EFF[certs$HOT_WATER_ENERGY_EFF == "N/A"] <- NA
  certs$HOT_WATER_ENV_EFF[certs$HOT_WATER_ENV_EFF == "N/A"] <- NA
  certs$MAINHEAT_ENERGY_EFF[certs$MAINHEAT_ENERGY_EFF == "N/A"] <- NA
  certs$MAINHEAT_ENV_EFF[certs$MAINHEAT_ENV_EFF == "N/A"] <- NA
  certs$MAINHEATC_ENERGY_EFF[certs$MAINHEATC_ENERGY_EFF == "N/A"] <- NA
  certs$MAINHEATC_ENV_EFF[certs$MAINHEATC_ENV_EFF == "N/A"] <- NA
  certs$LIGHTING_ENERGY_EFF[certs$LIGHTING_ENERGY_EFF == "N/A"] <- NA
  certs$LIGHTING_ENV_EFF[certs$LIGHTING_ENV_EFF == "N/A"] <- NA
  certs$WINDOWS_ENERGY_EFF[certs$WINDOWS_ENERGY_EFF == "N/A"] <- NA
  certs$WINDOWS_ENV_EFF[certs$WINDOWS_ENV_EFF == "N/A"] <- NA
  certs$WALLS_ENERGY_EFF[certs$WALLS_ENERGY_EFF == "N/A"] <- NA
  certs$WALLS_ENV_EFF[certs$WALLS_ENV_EFF == "N/A"] <- NA
  certs$SHEATING_ENERGY_EFF[certs$SHEATING_ENERGY_EFF == "N/A"] <- NA
  certs$SHEATING_ENV_EFF[certs$SHEATING_ENV_EFF == "N/A"] <- NA
  certs$CURRENT_ENERGY_RATING[certs$CURRENT_ENERGY_RATING == "INVALID!"] <- NA
  certs$POTENTIAL_ENERGY_RATING[certs$POTENTIAL_ENERGY_RATING == "INVALID!"] <- NA

  # Collapse all-NA columns to a single logical NA to save memory
  if (all(is.na(certs$SHEATING_ENERGY_EFF))) certs$SHEATING_ENERGY_EFF <- NA
  if (all(is.na(certs$SHEATING_ENV_EFF)))    certs$SHEATING_ENV_EFF    <- NA

  certs
}

import_ew_domestic_reccs <- function(zip_path) {
  read_ew_csvs(zip_path, "recommendations", col_types = NULL)
}

# Non-domestic certificates.
import_ew_nondomestic <- function(zip_path) {
  certs <- read_ew_csvs(zip_path, "certificates", col_types = NULL)
  for (nm in c("CONSTITUENCY", "CONSTITUENCY_LABEL", "ADDRESS", "COUNTY",
               "LOCAL_AUTHORITY", "LOCAL_AUTHORITY_LABEL", "POSTTOWN")) certs[[nm]] <- NULL
  certs
}

import_ew_nondomestic_reccs <- function(zip_path) {
  read_ew_csvs(zip_path, "recommendations", col_types = NULL)
}

# Display Energy Certificates (DECs).
import_dec <- function(zip_path) {
  certs <- read_ew_csvs(zip_path, "certificates", col_types = NULL)
  for (nm in c("CONSTITUENCY", "CONSTITUENCY_LABEL", "ADDRESS", "COUNTY",
               "LOCAL_AUTHORITY", "LOCAL_AUTHORITY_LABEL", "POSTTOWN")) certs[[nm]] <- NULL
  certs
}

# ===========================================================================
# IMPORT - Scotland (per-year / combined CSVs inside .7z archives)
# ===========================================================================

# Scottish domestic: one CSV per year, two-row header (skip = 1 -> friendly
# names).  Per-file pre-cleaning matches import_epc_scotland.R.
import_scot_domestic <- function(archive_path) {
  exdir <- tempfile("scot_dom_")
  files_certs <- extract_7z(archive_path, exdir, pattern = "\\.csv$")
  files_certs <- files_certs[order(basename(files_certs))]

  nas <- c("NO DATA!", "N/A", "N/A | N/A", "N/A | N/A | N/A")
  certs_all <- vector("list", length(files_certs))

  for (i in seq_along(files_certs)) {
    message(i, " ", basename(files_certs[i]))
    certs <- readr::read_csv(files_certs[i], skip = 1, progress = FALSE, show_col_types = FALSE)

    # Drop unneeded columns if present (no-op if the friendly header lacks them)
    for (nm in c("CONSTITUENCY", "CONSTITUENCY_LABEL", "ADDRESS")) certs[[nm]] <- NULL

    certs$`Wind Turbines Count`  <- as.integer(certs$`Wind Turbines Count`)
    certs$`Open Fireplaces Count`<- as.integer(certs$`Open Fireplaces Count`)

    for (nm in c("FLOOR_ENERGY_EFF", "ROOF_ENERGY_EFF", "ROOF_ENV_EFF",
                 "HOT_WATER_ENERGY_EFF", "HOT_WATER_ENV_EFF",
                 "MAINHEAT_ENERGY_EFF", "MAINHEAT_ENV_EFF",
                 "MAINHEATC_ENERGY_EFF", "MAINHEATC_ENV_EFF",
                 "LIGHTING_ENERGY_EFF", "LIGHTING_ENV_EFF",
                 "WINDOWS_ENERGY_EFF", "WINDOWS_ENV_EFF",
                 "WALL_ENERGY_EFF", "WALL_ENV_EFF",
                 "SHEATING_ENERGY_EFF", "SHEATING_ENV_EFF")) {
      if (nm %in% names(certs)) certs[[nm]][certs[[nm]] %in% nas] <- NA
    }

    if (all(is.na(certs$SHEATING_ENERGY_EFF))) certs$SHEATING_ENERGY_EFF <- NA
    if (all(is.na(certs$SHEATING_ENV_EFF)))    certs$SHEATING_ENV_EFF    <- NA

    certs_all[[i]] <- certs
  }
  dplyr::bind_rows(certs_all)
}

# Scottish non-domestic: single combined CSV, two-row header.
import_scot_nondomestic <- function(archive_path) {
  exdir <- tempfile("scot_nondom_")
  files_certs <- extract_7z(archive_path, exdir, pattern = "\\.csv$")

  certs_all <- lapply(files_certs, function(f) {
    message(basename(f))
    certs <- readr::read_csv(f, skip = 1, progress = FALSE, show_col_types = FALSE)
    # The 2026 Scotland "Lodgement Date" is dd/mm/yyyy HH:MM:SS (not ISO), so
    # parse with dmy_hms - ymd_hms silently turns every value into NA.
    if (inherits(certs$`Lodgement Date`, "character")) {
      certs$`Lodgement Date` <- lubridate::dmy_hms(certs$`Lodgement Date`)
    }
    certs
  })
  dplyr::bind_rows(certs_all)
}

# ===========================================================================
# CLEAN - shared domestic free-text standardisation
# ===========================================================================

# Runs the big shared vocabulary (R/domestic_dictionaries_2026.R) plus the
# 2026 additions (R/domestic_vocab_2026_additions.R) over the global `certs`,
# using the td_*/sub_* helpers, then validates it.  PHOTO_SUPPLY is handled by
# the caller beforehand.  The helpers operate on a global `certs`, so the two
# vocabulary files are sourced into .GlobalEnv.
run_domestic_dictionaries <- function(certs) {
  needed <- c("td_FLOOR_DESCRIPTION", "sub_FLOOR_DESCRIPTION", "common_clean", "validate_domestic")
  if (!all(vapply(needed, exists, logical(1), inherits = TRUE))) {
    stop("domestic clean helpers missing - source('R/functions.R'), ",
         "'R/translate_welsh.R' and 'R/functions_2026.R' before cleaning")
  }
  assign("certs", certs, envir = .GlobalEnv)
  sys.source("R/domestic_dictionaries_2026.R", envir = .GlobalEnv)
  add_file <- "R/domestic_vocab_2026_additions.R"
  if (file.exists(add_file)) sys.source(add_file, envir = .GlobalEnv)
  validate_domestic(get("certs", envir = .GlobalEnv))
}

# Shared subset of columns kept for the cleaned domestic outputs (the set the
# Scotland file provides; merge_gb_domestic() harmonises to exactly these).
.dom_keep <- c(
  "UPRN", "ADDRESS1", "ADDRESS2", "ADDRESS3", "POSTCODE",
  "CURRENT_ENERGY_RATING", "CURRENT_ENERGY_EFFICIENCY", "POTENTIAL_ENERGY_EFFICIENCY",
  "INSPECTION_DATE", "BUILT_FORM", "PROPERTY_TYPE", "TENURE", "CONSTRUCTION_AGE_BAND",
  "TOTAL_FLOOR_AREA", "MAIN_FUEL", "MAINHEAT_DESCRIPTION",
  "GLAZED_TYPE",
  "FLOOR_DESCRIPTION", "FLOOR_ENERGY_EFF",
  "HOTWATER_DESCRIPTION", "HOT_WATER_ENERGY_EFF",
  "WINDOWS_DESCRIPTION", "WINDOWS_ENERGY_EFF",
  "WALLS_DESCRIPTION", "WALLS_ENERGY_EFF",
  "ROOF_DESCRIPTION", "ROOF_ENERGY_EFF",
  "MAINHEAT_ENERGY_EFF",
  "MAINHEATCONT_DESCRIPTION", "MAINHEATC_ENERGY_EFF",
  "LIGHTING_ENERGY_EFF", "PHOTO_SUPPLY", "SOLAR_WATER_HEATING_FLAG"
)

# Most-recent-per-UPRN + attach UPRN point locations, shared by both countries.
.dom_dedupe_join <- function(certs, uprn_hist) {
  certs <- certs[!is.na(certs$UPRN), ]
  certs$UPRN <- as.numeric(certs$UPRN)
  # Impossible dates would win the most-recent-per-UPRN sort below; NA loses it.
  certs$INSPECTION_DATE <- valid_inspection_date(certs$INSPECTION_DATE)
  certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE), ]
  certs <- certs[!duplicated(certs$UPRN), ]
  certs <- dplyr::left_join(certs, uprn_hist, by = c("UPRN" = "UPRN"))
  certs <- sf::st_as_sf(certs)
  certs[!sf::st_is_empty(certs), ]
}

# ---- England & Wales domestic ----
clean_ew_domestic <- function(raw, uprn_hist, ncores = 25) {
  certs <- raw[, .dom_keep]
  certs <- .dom_dedupe_join(certs, uprn_hist)

  future::plan(future::multisession, workers = ncores)
  on.exit(future::plan(future::sequential), add = TRUE)

  certs$FLOOR_DESCRIPTION       <- furrr::future_map_chr(certs$FLOOR_DESCRIPTION, common_clean, .progress = TRUE)
  certs$WALLS_DESCRIPTION       <- furrr::future_map_chr(certs$WALLS_DESCRIPTION, common_clean, .progress = TRUE)
  certs$ROOF_DESCRIPTION        <- furrr::future_map_chr(certs$ROOF_DESCRIPTION, common_clean, .progress = TRUE)
  # split = TRUE so the "|" main-part rule (splitwelsh) also applies here - the
  # Scottish MAINHEATCONT field is "|"-separated too.
  certs$MAINHEATCONT_DESCRIPTION<- furrr::future_map_chr(certs$MAINHEATCONT_DESCRIPTION, common_clean, .progress = TRUE, split = TRUE, fix = FALSE)
  certs$MAINHEAT_DESCRIPTION    <- furrr::future_map_chr(certs$MAINHEAT_DESCRIPTION, common_clean, .progress = TRUE, fix = FALSE)
  certs$HOTWATER_DESCRIPTION    <- furrr::future_map_chr(certs$HOTWATER_DESCRIPTION, common_clean, .progress = TRUE, fix = FALSE)
  certs$WINDOWS_DESCRIPTION     <- furrr::future_map_chr(certs$WINDOWS_DESCRIPTION, common_clean, .progress = TRUE, fix = FALSE)
  certs$MAIN_FUEL               <- furrr::future_map_chr(certs$MAIN_FUEL, standardclean, .progress = TRUE)

  certs$FLOOR_DESCRIPTION <- furrr::future_map_chr(certs$FLOOR_DESCRIPTION, splitwelsh, .progress = TRUE)
  certs$FLOOR_DESCRIPTION <- furrr::future_map_chr(certs$FLOOR_DESCRIPTION, standardclean, .progress = TRUE)
  certs$FLOOR_DESCRIPTION <- furrr::future_map_chr(certs$FLOOR_DESCRIPTION, translatewelsh, .progress = TRUE)
  certs$FLOOR_DESCRIPTION <- furrr::future_map_chr(certs$FLOOR_DESCRIPTION, fix_wm2k, .progress = TRUE)

  future::plan(future::sequential)

  # PHOTO_SUPPLY (England & Wales coding): the raw column is the percentage of
  # roof area covered by PV, read as a number, so compare numerically.  The old
  # string test against "0.0" never matched (as.character(0) is "0"), which put
  # every 0% record in the "yes" branch.
  certs$PHOTO_SUPPLY <- pv_flag_number(certs$PHOTO_SUPPLY)

  run_domestic_dictionaries(certs)
}

# ---- Scotland domestic ----
# Rename the friendly Scottish columns to the England/Wales names, then run the
# same cleaning as England & Wales.
standardise_scot_domestic_names <- function(certs) {
  ren <- c(
    "OSG_UPRN" = "UPRN",
    "Current energy efficiency rating band" = "CURRENT_ENERGY_RATING",
    "Current energy efficiency rating" = "CURRENT_ENERGY_EFFICIENCY",
    "Potential Energy Efficiency Rating" = "POTENTIAL_ENERGY_EFFICIENCY",
    "Date of Assessment" = "INSPECTION_DATE",
    "Built Form" = "BUILT_FORM",
    "Property Type" = "PROPERTY_TYPE",
    "Tenure" = "TENURE",
    "Part 1 Construction Age Band" = "CONSTRUCTION_AGE_BAND",
    "Main Heating 1 Fuel Type" = "MAIN_FUEL",
    "Multiple Glazing Type" = "GLAZED_TYPE",
    "WALL_DESCRIPTION" = "WALLS_DESCRIPTION",
    "WALL_ENERGY_EFF" = "WALLS_ENERGY_EFF",
    "Photovoltaic Supply" = "PHOTO_SUPPLY",
    "Solar Water Heating" = "SOLAR_WATER_HEATING_FLAG",
    "Postcode" = "POSTCODE",
    "POST_TOWN" = "ADDRESS3"
  )
  for (from in names(ren)) names(certs)[names(certs) == from] <- ren[[from]]
  # "Total floor area (m^2)" - the ^2 is stored in a non-UTF-8 encoding, so
  # match by prefix rather than the exact (encoding-dependent) string.
  names(certs)[grepl("^Total floor area", names(certs))] <- "TOTAL_FLOOR_AREA"
  certs
}

clean_scot_domestic <- function(raw, uprn_hist, ncores = 10) {
  certs <- standardise_scot_domestic_names(raw)
  certs <- certs[, .dom_keep]
  certs <- .dom_dedupe_join(certs, uprn_hist)

  future::plan(future::multisession, workers = ncores)
  on.exit(future::plan(future::sequential), add = TRUE)

  certs$FLOOR_DESCRIPTION       <- furrr::future_map_chr(certs$FLOOR_DESCRIPTION, common_clean, .progress = TRUE)
  certs$WALLS_DESCRIPTION       <- furrr::future_map_chr(certs$WALLS_DESCRIPTION, common_clean, .progress = TRUE)
  certs$ROOF_DESCRIPTION        <- furrr::future_map_chr(certs$ROOF_DESCRIPTION, common_clean, .progress = TRUE)
  # split = TRUE so the "|" main-part rule (splitwelsh) also applies here.
  certs$MAINHEATCONT_DESCRIPTION<- furrr::future_map_chr(certs$MAINHEATCONT_DESCRIPTION, common_clean, .progress = TRUE, split = TRUE, fix = FALSE)
  certs$MAINHEAT_DESCRIPTION    <- furrr::future_map_chr(certs$MAINHEAT_DESCRIPTION, common_clean, .progress = TRUE, fix = FALSE)
  certs$HOTWATER_DESCRIPTION    <- furrr::future_map_chr(certs$HOTWATER_DESCRIPTION, common_clean, .progress = TRUE, fix = FALSE)
  certs$WINDOWS_DESCRIPTION     <- furrr::future_map_chr(certs$WINDOWS_DESCRIPTION, common_clean, .progress = TRUE, fix = FALSE)
  certs$MAIN_FUEL               <- furrr::future_map_chr(certs$MAIN_FUEL, standardclean, .progress = TRUE)

  future::plan(future::sequential)

  # PHOTO_SUPPLY (Scotland coding): free text describing the array, e.g.
  # "Array: Roof Area: 40%; Connection: connected to dwelling's electricity
  # meter;  |".  Read the array size out of it rather than whitelisting whole
  # strings: there are >14,000 distinct values and the "Connection:" clause
  # varies independently of the size, so the old two-string list missed ~1.17m
  # zero/blank-array records and flagged them all as having PV.
  certs$PHOTO_SUPPLY <- pv_flag_scotland(certs$PHOTO_SUPPLY)

  run_domestic_dictionaries(certs)
}

# ===========================================================================
# CLEAN - non-domestic and DEC (no free-text vocabularies)
# ===========================================================================

clean_ew_nondomestic <- function(raw, uprn_hist) {
  certs <- raw[, c("UPRN", "ADDRESS1", "ADDRESS2", "ADDRESS3", "POSTCODE", "ASSET_RATING",
                   "PROPERTY_TYPE", "ASSET_RATING_BAND", "TRANSACTION_TYPE",
                   "FLOOR_AREA", "INSPECTION_DATE", "MAIN_HEATING_FUEL")]
  certs <- certs[!is.na(certs$UPRN), ]
  certs$UPRN <- as.numeric(certs$UPRN)
  # Impossible dates would win the most-recent-per-UPRN sort below; NA loses it.
  certs$INSPECTION_DATE <- valid_inspection_date(certs$INSPECTION_DATE)
  certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE), ]
  certs <- certs[!duplicated(certs$UPRN), ]
  certs <- dplyr::left_join(certs, uprn_hist, by = c("UPRN" = "UPRN"))
  certs <- sf::st_as_sf(certs)
  certs[!sf::st_is_empty(certs), ]
}

standardise_scot_nondomestic_names <- function(certs) {
  ren <- c(
    "Address1" = "ADDRESS1",
    "Address2" = "ADDRESS2",
    "OSG_UPRN" = "UPRN",
    "Energy Band" = "ASSET_RATING_BAND",
    "Current Energy Performance Rating" = "ASSET_RATING",
    "Date of Assessment" = "INSPECTION_DATE",
    "Property Type" = "PROPERTY_TYPE",
    "Main Heating Fuel" = "MAIN_HEATING_FUEL",
    "Transaction Type" = "TRANSACTION_TYPE",
    "POST_TOWN" = "ADDRESS3",
    "Post Town" = "ADDRESS3",
    "Postcode" = "POSTCODE"
  )
  for (from in names(ren)) names(certs)[names(certs) == from] <- ren[[from]]
  names(certs)[grepl("^Total floor area", names(certs))] <- "FLOOR_AREA"
  certs
}

clean_scot_nondomestic <- function(raw, uprn_hist, ncores = 20) {
  certs <- standardise_scot_nondomestic_names(raw)
  certs <- certs[, c("UPRN", "ADDRESS1", "ADDRESS2", "ADDRESS3", "POSTCODE", "ASSET_RATING",
                     "PROPERTY_TYPE", "ASSET_RATING_BAND", "TRANSACTION_TYPE",
                     "FLOOR_AREA", "INSPECTION_DATE", "MAIN_HEATING_FUEL")]
  certs <- certs[!is.na(certs$UPRN), ]
  certs$UPRN <- as.numeric(certs$UPRN)
  # Impossible dates would win the most-recent-per-UPRN sort below; NA loses it.
  certs$INSPECTION_DATE <- valid_inspection_date(certs$INSPECTION_DATE)
  certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE), ]
  certs <- certs[!duplicated(certs$UPRN), ]
  certs <- dplyr::left_join(certs, uprn_hist, by = c("UPRN" = "UPRN"))
  certs <- sf::st_as_sf(certs)
  certs <- certs[!sf::st_is_empty(certs), ]

  future::plan(future::multisession, workers = ncores)
  on.exit(future::plan(future::sequential), add = TRUE)
  certs$MAIN_HEATING_FUEL <- furrr::future_map_chr(certs$MAIN_HEATING_FUEL, standardclean, .progress = TRUE)
  future::plan(future::sequential)

  certs
}

clean_dec <- function(raw, uprn_hist, ncores = 20) {
  certs <- raw[, c("UPRN", "ADDRESS1", "MAIN_HEATING_FUEL",
                   "INSPECTION_DATE", "PROPERTY_TYPE", "TOTAL_FLOOR_AREA",
                   "CURRENT_OPERATIONAL_RATING", "OPERATIONAL_RATING_BAND",
                   "ANNUAL_THERMAL_FUEL_USAGE", "ANNUAL_ELECTRICAL_FUEL_USAGE",
                   "BUILDING_ENVIRONMENT")]
  certs <- certs[!is.na(certs$UPRN), ]
  certs$UPRN <- as.numeric(certs$UPRN)
  # Impossible dates would win the most-recent-per-UPRN sort below; NA loses it.
  certs$INSPECTION_DATE <- valid_inspection_date(certs$INSPECTION_DATE)
  certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE), ]
  certs <- certs[!duplicated(certs$UPRN), ]
  certs <- dplyr::left_join(certs, uprn_hist, by = c("UPRN" = "UPRN"))
  certs <- sf::st_as_sf(certs)
  certs <- certs[!sf::st_is_empty(certs), ]

  future::plan(future::multisession, workers = ncores)
  on.exit(future::plan(future::sequential), add = TRUE)
  certs$MAIN_HEATING_FUEL <- furrr::future_map_chr(certs$MAIN_HEATING_FUEL, standardclean, .progress = TRUE)
  future::plan(future::sequential)

  certs
}
