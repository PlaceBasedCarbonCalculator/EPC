ncores = 10
certs <- readRDS("epc_nondomestic_all_raw.Rds")
uprn <- readRDS("../build/_targets/objects/uprn")
uprn <- sf::st_as_sf(uprn)

library(future)
library(furrr)
library(readr)

source("R/funtions.R")
source("R/translate_welsh.R")

# Subset to key variables
certs <- certs[,c("UPRN","ADDRESS1","ADDRESS2","ASSET_RATING",
                  "PROPERTY_TYPE",
               "ASSET_RATING_BAND","TRANSACTION_TYPE",
               "FLOOR_AREA",
               "INSPECTION_DATE",
               "MAIN_HEATING_FUEL")]

# Only those with UPRNs
certs <- certs[!is.na(certs$UPRN),]
certs$UPRN <- as.numeric(certs$UPRN)

# Get most recent EPC
certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE),]
certs <- certs[!duplicated(certs$UPRN),] 


certs <- dplyr::left_join(certs, uprn, by = c("UPRN" = "UPRN"))
certs <- sf::st_as_sf(certs)
certs <- certs[!sf::st_is_empty(certs),]

# long strings

# Time consuming parts ----------------------------------------------------

#table(certs$MAIN_HEATING_FUEL)
#table(certs$ASSET_RATING_BAND)

# Finish Up ---------------------------------------------------------------

saveRDS(certs,"../inputdata/epc/epc_nondomestic_clean.Rds")


