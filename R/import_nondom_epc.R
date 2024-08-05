# Read in EPC Data
# Settings ---------------------------------------------------------------

# Setup ---------------------------------------------------------------
library(dplyr)
library(readr)
source("R/translate_welsh.R", encoding="UTF-8")
source("R/funtions.R", encoding="UTF-8")

path = "../inputdata/epc/"

dir.create(file.path(tempdir(),"epc"))
unzip(file.path(path,"all-domestic-certificates-single-file-20240630.zip"), 
      exdir = file.path(tempdir(),"epc"))

files <- list.files(file.path(tempdir(),"epc"), recursive = TRUE, full.names = TRUE)
files_certs <- files[grepl("certificates.csv", files)]
files_reccs <- files[grepl("recommendations.csv", files)]


# Import  -------------------------------------------------------------

certs <- readr::read_csv(files_certs, col_types = col_types)

# Dump unneeded columns
certs$CONSTITUENCY <- NULL
certs$CONSTITUENCY_LABEL <- NULL
certs$ADDRESS <- NULL

# Clean up some of those names
certs$SOLAR_WATER_HEATING_FLAG <- yn2logical(certs$SOLAR_WATER_HEATING_FLAG)
certs$MAINS_GAS_FLAG <- yn2logical(certs$MAINS_GAS_FLAG)
certs$FLAT_TOP_STOREY <- yn2logical(certs$FLAT_TOP_STOREY)

#round numbers where decimals are errors
certs$ENERGY_CONSUMPTION_POTENTIAL <- as.integer(certs$ENERGY_CONSUMPTION_POTENTIAL)
certs$LIGHTING_COST_CURRENT <- as.integer(certs$LIGHTING_COST_CURRENT)
certs$LIGHTING_COST_POTENTIAL <- as.integer(certs$LIGHTING_COST_POTENTIAL)
certs$HEATING_COST_CURRENT <- as.integer(certs$HEATING_COST_CURRENT)
certs$HEATING_COST_POTENTIAL <- as.integer(certs$HEATING_COST_POTENTIAL)
certs$HOT_WATER_COST_CURRENT <- as.integer(certs$HOT_WATER_COST_CURRENT)
certs$HOT_WATER_COST_POTENTIAL <- as.integer(certs$HOT_WATER_COST_POTENTIAL)

certs$MAIN_HEATING_CONTROLS[certs$MAIN_HEATING_CONTROLS == "%%MAINHEATCONTROL%%"] <- NA
certs$MAIN_HEATING_CONTROLS <- as.integer(certs$MAIN_HEATING_CONTROLS)

# Clean missign data flats
certs$FLOOR_LEVEL[certs$FLOOR_LEVEL == "NO DATA!"] <- NA
certs$FLOOR_LEVEL[certs$FLOOR_LEVEL == "NODATA!"] <- NA
certs$ENERGY_TARIFF[certs$ENERGY_TARIFF == "NO DATA!"] <- NA
certs$ENERGY_TARIFF[certs$ENERGY_TARIFF == "INVALID!"] <- NA
certs$GLAZED_TYPE[certs$GLAZED_TYPE == "NO DATA!"] <- NA
certs$GLAZED_TYPE[certs$GLAZED_TYPE == "INVALID!"] <- NA
certs$GLAZED_AREA[certs$GLAZED_AREA == "NO DATA!"] <- NA
certs$FLOOR_ENERGY_EFF[certs$FLOOR_ENERGY_EFF == "NO DATA!"] <- NA
certs$FLOOR_ENERGY_EFF[certs$FLOOR_ENERGY_EFF == "N/A"] <- NA
certs$FLOOR_ENV_EFF[certs$FLOOR_ENV_EFF == "NO DATA!"] <- NA
certs$FLOOR_ENV_EFF[certs$FLOOR_ENV_EFF == "N/A"] <- NA
certs$ROOF_ENERGY_EFF[certs$ROOF_ENERGY_EFF == "N/A"] <- NA
certs$ROOF_ENV_EFF[certs$ROOF_ENV_EFF == "N/A"] <- NA
#certs$HEAT_LOSS_CORRIDOOR[certs$HEAT_LOSS_CORRIDOOR == "NO DATA!"] <- NA
certs$MECHANICAL_VENTILATION[certs$MECHANICAL_VENTILATION == "NO DATA!"] <- NA
certs$MAIN_FUEL[certs$MAIN_FUEL == "NO DATA!"] <- NA
certs$MAIN_FUEL[certs$MAIN_FUEL == "INVALID!"] <- NA
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

# If all NAs then make logical to reduce memory use
if(all(is.na(certs$SHEATING_ENERGY_EFF))){
  certs$SHEATING_ENERGY_EFF <- NA
}

if(all(is.na(certs$SHEATING_ENV_EFF))){
  certs$SHEATING_ENV_EFF <- NA
}

saveRDS(certs, "epc_nondomestic_all_raw.Rds")

reccs <- readr::read_csv(files_reccs)
saveRDS(reccs, "epc_nondomestic_reccs_all_raw.Rds")
