ncores = 20
certs <- readRDS("dec_all_raw.Rds")
uprn <- readRDS("../build/_targets/objects/uprn")
uprn <- sf::st_as_sf(uprn)

library(future)
library(furrr)
library(readr)

source("R/funtions.R")
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

# Get most recent EPC
certs <- certs[order(certs$INSPECTION_DATE, decreasing = TRUE),]
certs <- certs[!duplicated(certs$UPRN),] 


certs <- dplyr::left_join(certs, uprn, by = c("UPRN" = "UPRN"))
certs <- sf::st_as_sf(certs)
certs <- certs[!sf::st_is_empty(certs),]


# long strings

# Time consuming parts ----------------------------------------------------

plan(multisession, workers = ncores)


certs$MAIN_FUEL <- future_map_chr(certs$MAIN_FUEL, standardclean,  .progress = TRUE)




# MAIN_FUEL ---------------------------------------------------------------

sub_MAIN_FUEL(" this is for backwards compatibility only and should not be used"," (unknown)")
td_MAIN_FUEL("to be used only when there is no heating/hot-water system","no heating/hot-water system")
td_MAIN_FUEL("community heating schemes: heat from boilers biomass","community heating schemes: heat from boilers - biomass")

MAIN_FUEL <- c("anthracite",
               "appliances able to use mineral oil or liquid biofuel",
               "biogas (community)",
               "biogas landfill (unknown)",
               "biomass (community)",
               "biomass (unknown)",
               "bioethanol",
               "biodiesel from any biomass source",
               "biodiesel from used cooking oil only",
               "rapeseed oil",
               "community heating schemes: heat from boilers - biomass",
               "community heating schemes: waste heat from power stations",
               "community heating schemes: heat from heat pump",
               "bulk wood pellets",
               "dual fuel mineral + wood",
               "electric (unknown)", 
               "electric (community)",
               "electric (not community)",
               "electric: electric, unspecified tariff",
               "coal (community)",
               "coal (not community)",
               "coal (unknown)",
               "lpg (unknown)",
               "lpg (not community)",
               "lpg (community)",
               "lpg special condition",
               "bottled lpg",
               "mains gas (unknown)",
               "mains gas (community)",
               "mains gas (not community)",
               "oil (unknown)",
               "oil (community)",
               "oil (not community)",
               "smokeless coal",
               "no heating/hot-water system",
               "wood chips",
               "wood logs",
               "wood pellets in bags for secondary heating",
               "waste combustion (unknown)",
               "waste combustion (community)",
               "b30d (community)",
               "b30k (not community)",
               NA)









# Finish Up ---------------------------------------------------------------

saveRDS(certs,"../inputdata/epc/epc_scotland_nondomestic_clean.Rds")

validate(MAIN_FUEL,"MAIN_FUEL")

