# Merge / classification functions for the 2026 targets workflow.
# Function-wrapped, adapted versions of merge_epcs.R and
# uprn_classifications.R.  See _targets.R.

# ===========================================================================
# Age-band harmonisation (Scotland -> England & Wales bands)
# ===========================================================================
simple_ages <- function(x) {
  y <- as.integer(x)
  z <- rep(NA_character_, length(y))
  z[y < 1900] <- "before 1900"
  z[y >= 1900 & y <= 1929] <- "1900-1929"
  z[y >= 1930 & y <= 1949] <- "1930-1949"
  z[y >= 1950 & y <= 1966] <- "1950-1966"
  z[y >= 1967 & y <= 1975] <- "1967-1975"
  z[y >= 1976 & y <= 1982] <- "1976-1982"
  z[y >= 1983 & y <= 1990] <- "1983-1990"
  z[y >= 1991 & y <= 1995] <- "1991-1995"
  z[y >= 1996 & y <= 2002] <- "1996-2002"
  z[y >= 2003 & y <= 2006] <- "2003-2006"
  z[y >= 2007 & y <= 2011] <- "2007-2011"
  z[y >= 2012 & y <= 2021] <- "2012-2021"
  z[y >= 2022] <- "2022 onwards"

  x <- dplyr::if_else(is.na(z), x, z)
  x[x == "before 1919"] <- "before 1900"
  x[x == "1919-1929"] <- "1900-1929"
  x[x == "1950-1964"] <- "1950-1966"
  x[x == "1965-1975"] <- "1967-1975"
  x[x == "1976-1983"] <- "1976-1982"
  x[x == "1984-1991"] <- "1983-1990"
  x[x == "1992-1998"] <- "1991-1995"
  x[x == "1999-2002"] <- "1996-2002"
  x[x == "2003-2007"] <- "2003-2006"
  x[x == "2007 onwards"] <- "2007-2011"
  x[x == "2008 onwards"] <- "2007-2011"
  x[x == "2012 onwards"] <- "2012-2021"
  x
}

# ===========================================================================
# GB domestic merge (England & Wales + Scotland)
# ===========================================================================
merge_gb_domestic <- function(certs_dom, scot_dom) {
  # Harmonise to the Scottish column set, then row-bind.
  certs_dom <- certs_dom[, names(scot_dom)]
  dom_all <- rbind(certs_dom, scot_dom)

  dom_all <- dplyr::rename(dom_all,
                           addr = ADDRESS1,
                           cur_rate = CURRENT_ENERGY_RATING,
                           cur_ee = CURRENT_ENERGY_EFFICIENCY,
                           per_ee = POTENTIAL_ENERGY_EFFICIENCY,
                           b_type = BUILT_FORM,
                           p_type = PROPERTY_TYPE,
                           tenure = TENURE,
                           age = CONSTRUCTION_AGE_BAND,
                           area = TOTAL_FLOOR_AREA,
                           fuel = MAIN_FUEL,
                           heat_d = MAINHEAT_DESCRIPTION,
                           g_type = GLAZED_TYPE,
                           floor_d = FLOOR_DESCRIPTION,
                           floor_ee = FLOOR_ENERGY_EFF,
                           water_d = HOTWATER_DESCRIPTION,
                           water_ee = HOT_WATER_ENERGY_EFF,
                           wind_d = WINDOWS_DESCRIPTION,
                           wind_ee = WINDOWS_ENERGY_EFF,
                           wall_d = WALLS_DESCRIPTION,
                           wall_ee = WALLS_ENERGY_EFF,
                           roof_d = ROOF_DESCRIPTION,
                           roof_ee = ROOF_ENERGY_EFF,
                           heat_ee = MAINHEAT_ENERGY_EFF,
                           con_d = MAINHEATCONT_DESCRIPTION,
                           con_ee = MAINHEATC_ENERGY_EFF,
                           light_ee = LIGHTING_ENERGY_EFF,
                           pv = PHOTO_SUPPLY,
                           sol_wat = SOLAR_WATER_HEATING_FLAG,
                           uprn_date_first = date_first,
                           uprn_date_last = date_last)

  dom_all$year <- lubridate::year(lubridate::ymd(dom_all$INSPECTION_DATE))
  dom_all$INSPECTION_DATE <- NULL

  dom_all$cur_rate[!dom_all$cur_rate %in% c("A", "B", "C", "D", "E", "F", "G")] <- NA
  dom_all$b_type[dom_all$b_type == "NO DATA!"] <- NA

  dom_all$tenure[dom_all$tenure == "NO DATA!"] <- "unknown"
  dom_all$tenure[dom_all$tenure == "Not defined - use in the case of a new dwelling for which the intended tenure in not known. It is not to be used for an existing dwelling"] <- "unknown"
  dom_all$tenure <- tolower(dom_all$tenure)
  dom_all$tenure <- gsub("rental", "rented", dom_all$tenure)

  dom_all$age <- gsub("England and Wales: ", "", dom_all$age)
  dom_all$age[dom_all$age %in% c("INVALID!", "NO DATA!")] <- NA
  dom_all$age <- simple_ages(dom_all$age)

  dom_all$area <- round(dom_all$area, 0)

  dom_all$fuel <- tolower(dom_all$fuel)
  dom_all$fuel <- gsub("- this is for backwards compatibility only and should not be used", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("to be used only when there is no heating/hot-water system or data is from a community network", "none", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("to be used only when there is no heating/hot-water system", "none", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("no heating/hot-water system or data is from a community network", "none", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("appliances able to use ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("(not community)", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("solid fuel: ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("gas: ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("electricity: ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("oil: ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("subject to special condition 18", "special condition", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("from heat network data", "heat network", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("heat from boilers that can use", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("heat from boilers using biodiesel from any biomass source", "biodiesel", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("displaced from grid", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub(", unspecified tariff", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("community heating schemes:", "(community)", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("bulk supply in bags, for ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("in bags, for ", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("in bags for secondary heating", "(secondary heating)", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("bulk", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("heat from", "", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("electric: electric", "electric", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("electric", "electricity", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("dual fuel - mineral + wood", "dual fuel mineral + wood", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("dual fuel appliance (mineral and wood)", "dual fuel mineral + wood", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("(community)  mains gas", "mains gas (community)", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("(community)  boilers - biomass", "biomass (community)", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("(community)  electricity heat pump", "electricity (community)", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("(community)  heat pump", "electricity (community)", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("anthracite", "coal", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("wood pellets (main heating)", "wood pellets", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- gsub("no heating/hot-water system", "none", dom_all$fuel, fixed = TRUE)
  dom_all$fuel <- trimws(dom_all$fuel, "both")

  dom_all$heat_d <- tolower(dom_all$heat_d)

  good <- c("Very Good", "Good", "Average", "Poor", "Very Poor")
  for (nm in c("floor_ee", "water_ee", "wind_ee", "wall_ee", "roof_ee", "heat_ee", "con_ee", "light_ee")) {
    dom_all[[nm]][!dom_all[[nm]] %in% good] <- NA
  }

  dom_all$sol_wat[dom_all$sol_wat %in% c("false", "FALSE", "N")] <- "no"
  dom_all$sol_wat[dom_all$sol_wat %in% c("true", "TRUE", "Y")] <- "yes"

  dom_all$wind_d <- trimws(dom_all$wind_d)
  dom_all
}

# ===========================================================================
# GB non-domestic merge
# ===========================================================================
merge_gb_nondomestic <- function(certs_nondom, scot_nondom) {
  certs_nondom <- certs_nondom[, names(certs_nondom) %in% names(scot_nondom)]
  scot_nondom$ADDRESS3 <- ""   # town is not published for England/Wales non-dom

  nondom_all <- rbind(certs_nondom, scot_nondom)

  nondom_all <- dplyr::rename(nondom_all,
                              adr1 = ADDRESS1,
                              adr2 = ADDRESS2,
                              adr3 = ADDRESS3,
                              postcode = POSTCODE,
                              rating = ASSET_RATING,
                              band = ASSET_RATING_BAND,
                              type = PROPERTY_TYPE,
                              transaction = TRANSACTION_TYPE,
                              fuel = MAIN_HEATING_FUEL,
                              area = FLOOR_AREA,
                              uprn_date_first = date_first,
                              uprn_date_last = date_last)
  nondom_all$year <- lubridate::year(lubridate::ymd(nondom_all$INSPECTION_DATE))
  nondom_all$INSPECTION_DATE <- NULL
  nondom_all$band[nondom_all$band == "Carbon Neu"] <- "A+"
  nondom_all$band[nondom_all$band == "INVALID!"] <- NA
  nondom_all$transaction <- gsub(".", "", nondom_all$transaction, fixed = TRUE)
  nondom_all$fuel <- tolower(nondom_all$fuel)
  nondom_all
}

# ===========================================================================
# UPRN classification (building type & tenure from the most recent cert)
# ===========================================================================
classify_uprns <- function(certs_dom, certs_nondom, scot_dom, scot_nondom, decs, uprn_hist) {
  # Lodgement timestamps arrive in three shapes across the sources: ISO strings
  # (England/Wales domestic), POSIXct (England/Wales non-dom & DEC, parsed by
  # readr), and dd/mm/yyyy strings (Scotland).  Coerce everything to POSIXct so
  # "most recent per UPRN" ordering is correct and rbind does not mix types.
  to_dt <- function(x) {
    if (inherits(x, "POSIXct")) return(x)
    if (inherits(x, "Date"))    return(as.POSIXct(x))
    suppressWarnings(lubridate::parse_date_time(
      x, orders = c("Ymd HMS", "Ymd HM", "Ymd", "dmy HMS", "dmy HM", "dmy")))
  }

  # England & Wales domestic: no BUILDING_REFERENCE_NUMBER in the 2026 layout.
  certs_dom <- certs_dom[, c("UPRN", "PROPERTY_TYPE", "TENURE", "LODGEMENT_DATETIME")]
  certs_dom$LODGEMENT_DATETIME <- to_dt(certs_dom$LODGEMENT_DATETIME)
  certs_dom <- certs_dom[order(certs_dom$LODGEMENT_DATETIME, decreasing = TRUE), ]
  certs_dom <- certs_dom[!duplicated(certs_dom$UPRN), ]

  certs_nondom <- certs_nondom[, c("UPRN", "PROPERTY_TYPE", "LODGEMENT_DATETIME")]
  certs_nondom$LODGEMENT_DATETIME <- to_dt(certs_nondom$LODGEMENT_DATETIME)
  certs_nondom <- certs_nondom[order(certs_nondom$LODGEMENT_DATETIME, decreasing = TRUE), ]
  certs_nondom <- certs_nondom[!duplicated(certs_nondom$UPRN), ]

  scot_dom <- scot_dom[, c("Property_UPRN", "Property Type", "Tenure", "Lodgement Date")]
  scot_dom$`Lodgement Date` <- to_dt(scot_dom$`Lodgement Date`)
  scot_dom <- scot_dom[order(scot_dom$`Lodgement Date`, decreasing = TRUE), ]
  scot_dom <- scot_dom[!duplicated(scot_dom$Property_UPRN), ]
  names(scot_dom) <- c("UPRN", "PROPERTY_TYPE", "TENURE", "LODGEMENT_DATETIME")

  scot_nondom <- scot_nondom[, c("Property_UPRN", "Property Type", "Lodgement Date")]
  scot_nondom$`Lodgement Date` <- to_dt(scot_nondom$`Lodgement Date`)
  scot_nondom <- scot_nondom[order(scot_nondom$`Lodgement Date`, decreasing = TRUE), ]
  scot_nondom <- scot_nondom[!duplicated(scot_nondom$Property_UPRN), ]
  names(scot_nondom) <- c("UPRN", "PROPERTY_TYPE", "LODGEMENT_DATETIME")

  # DECs: no LMK_KEY in the 2026 layout.
  decs <- decs[, c("UPRN", "PROPERTY_TYPE", "LODGEMENT_DATETIME")]
  decs$LODGEMENT_DATETIME <- to_dt(decs$LODGEMENT_DATETIME)
  decs <- decs[order(decs$LODGEMENT_DATETIME, decreasing = TRUE), ]
  decs <- decs[!duplicated(decs$UPRN), ]

  certs_nondom$TENURE <- NA
  scot_nondom$TENURE <- NA
  decs$TENURE <- NA

  certs_all <- rbind(certs_dom, certs_nondom, scot_dom, scot_nondom, decs)
  certs_all <- certs_all[order(certs_all$LODGEMENT_DATETIME, decreasing = TRUE), ]
  certs_all <- certs_all[!duplicated(certs_all$UPRN), ]
  certs_all$UPRN <- as.numeric(certs_all$UPRN)

  certs_uprn <- dplyr::left_join(certs_all, uprn_hist, by = "UPRN")
  sf::st_as_sf(certs_uprn)
}
