# Clean the England & Wales Display Energy Certificate (DEC) data.
# Keeps the most recent DEC per UPRN and attaches UPRN point locations.
# Input:  dec_all_raw.Rds (from import_dec.R)
#         ../build/_targets/objects/uprn (from the build repo)
# Output: ../inputdata/epc/dec_clean.Rds

ncores = 20
certs <- readRDS("dec_all_raw.Rds")
uprn <- readRDS("../build/_targets/objects/uprn")
uprn <- sf::st_as_sf(uprn)

library(future)
library(furrr)
library(readr)

source("R/functions.R")
source("R/translate_welsh.R")

# Subset to key variables
certs <- certs[,c("UPRN","ADDRESS1","MAIN_HEATING_FUEL",
                  "INSPECTION_DATE","PROPERTY_TYPE",
                  "TOTAL_FLOOR_AREA",
                  "CURRENT_OPERATIONAL_RATING", "OPERATIONAL_RATING_BAND",
                  "ANNUAL_THERMAL_FUEL_USAGE", "ANNUAL_ELECTRICAL_FUEL_USAGE",
                  "BUILDING_ENVIRONMENT"
                  )]

# Only those with UPRNs
#TODO: Lots without a UPRN
#TODO: Multiple buildings with UPRN (seem to be mulit-building sites with shared address (e.g. schools))
#TODO: lots or repete certifactes form muliple years
certs <- certs[!is.na(certs$UPRN),]
certs$UPRN <- as.numeric(certs$UPRN)

# Get most recent DEC
certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE),]
certs <- certs[!duplicated(certs$UPRN),]


certs <- dplyr::left_join(certs, uprn, by = c("UPRN" = "UPRN"))
certs <- sf::st_as_sf(certs)
certs <- certs[!sf::st_is_empty(certs),]


# Time consuming parts ----------------------------------------------------

plan(multisession, workers = ncores)

certs$MAIN_HEATING_FUEL <- future_map_chr(certs$MAIN_HEATING_FUEL, standardclean,  .progress = TRUE)

plan(sequential)

# Finish Up ---------------------------------------------------------------

saveRDS(certs,"../inputdata/epc/dec_clean.Rds")
