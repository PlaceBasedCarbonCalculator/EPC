ncores = 20
certs <- readRDS("epc_scotland_nondomestic_all_raw.Rds")
uprn <- readRDS("../build/_targets/objects/uprn")
uprn <- sf::st_as_sf(uprn)

library(future)
library(furrr)
library(readr)

source("R/funtions.R")
source("R/translate_welsh.R")

# Rename to England names
names(certs)[names(certs) == "Address1"] = "ADDRESS1"
names(certs)[names(certs) == "Address2"] = "ADDRESS2"
names(certs)[names(certs) == "OSG_UPRN"] = "UPRN"
names(certs)[names(certs) == "Energy Band"] = "ASSET_RATING_BAND"
names(certs)[names(certs) == "Current Energy Performance Rating"] = "ASSET_RATING"
names(certs)[names(certs) == "Date of Assessment"] = "INSPECTION_DATE"
names(certs)[names(certs) == "Property Type"] = "PROPERTY_TYPE"
names(certs)[names(certs) == "Total floor area (m²)"] = "FLOOR_AREA"
names(certs)[names(certs) == "Main Heating Fuel"] = "MAIN_HEATING_FUEL"
names(certs)[names(certs) == "Transaction Type"] = "TRANSACTION_TYPE"

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




certs$MAIN_HEATING_FUEL <- future_map_chr(certs$MAIN_HEATING_FUEL, standardclean,  .progress = TRUE)




#



# Finish Up ---------------------------------------------------------------

saveRDS(certs,"../inputdata/epc/epc_scotland_nondomestic_clean.Rds")

