# Read in EPC Data
# Settings ---------------------------------------------------------------

# Setup ---------------------------------------------------------------
library(dplyr)
library(readr)
source("R/translate_welsh.R", encoding="UTF-8")
source("R/funtions.R", encoding="UTF-8")

path = "../inputdata/epc/"

dir.create(file.path(tempdir(),"epc"))
unzip(file.path(path,"Scotland_Domestic_EPC_data_2014-2024Q2.zip"), 
      exdir = file.path(tempdir(),"epc"))

files <- list.files(file.path(tempdir(),"epc"), recursive = TRUE, full.names = TRUE)
files_certs <- files[grepl(".csv", files)]

# Import  -------------------------------------------------------------
certs_all = list()


for(i in seq(1, length(files_certs))){
  message(i," ", files_certs[i])
  certs <- readr::read_csv(files_certs[i], skip = 1)
  
  # Dump unneeded columns
  certs$CONSTITUENCY <- NULL
  certs$CONSTITUENCY_LABEL <- NULL
  certs$ADDRESS <- NULL
  
  
  
  # Clean up some of those names
  #certs$SOLAR_WATER_HEATING_FLAG <- yn2logical(certs$SOLAR_WATER_HEATING_FLAG)
  #certs$MAINS_GAS_FLAG <- yn2logical(certs$MAINS_GAS_FLAG)
  #certs$FLAT_TOP_STOREY <- yn2logical(certs$FLAT_TOP_STOREY)
  
  #round numbers where decimals are errors
  #certs$ENERGY_CONSUMPTION_POTENTIAL <- as.integer(certs$ENERGY_CONSUMPTION_POTENTIAL)
  #certs$LIGHTING_COST_CURRENT <- as.integer(certs$LIGHTING_COST_CURRENT)
  #certs$LIGHTING_COST_POTENTIAL <- as.integer(certs$LIGHTING_COST_POTENTIAL)
  #certs$HEATING_COST_CURRENT <- as.integer(certs$HEATING_COST_CURRENT)
  #certs$HEATING_COST_POTENTIAL <- as.integer(certs$HEATING_COST_POTENTIAL)
  #certs$HOT_WATER_COST_CURRENT <- as.integer(certs$HOT_WATER_COST_CURRENT)
 # certs$HOT_WATER_COST_POTENTIAL <- as.integer(certs$HOT_WATER_COST_POTENTIAL)
  
  #certs$MAIN_HEATING_CONTROLS[certs$MAIN_HEATING_CONTROLS == "%%MAINHEATCONTROL%%"] <- NA
  #certs$MAIN_HEATING_CONTROLS <- as.integer(certs$MAIN_HEATING_CONTROLS)
  
  certs$`Wind Turbines Count` <- as.integer(certs$`Wind Turbines Count`)
  certs$`Open Fireplaces Count` <- as.integer(certs$`Open Fireplaces Count`)
  
  # Clean missign data flats
  nas = c("NO DATA!","N/A","N/A | N/A","N/A | N/A | N/A")
  
  certs$FLOOR_ENERGY_EFF[certs$FLOOR_ENERGY_EFF %in% nas] <- NA
  certs$ROOF_ENERGY_EFF[certs$ROOF_ENERGY_EFF %in% nas] <- NA
  certs$ROOF_ENV_EFF[certs$ROOF_ENV_EFF %in% nas] <- NA
  
  #certs$MECHANICAL_VENTILATION[certs$MECHANICAL_VENTILATION == "NO DATA!"] <- NA
  #certs$MAIN_FUEL[certs$MAIN_FUEL == "NO DATA!"] <- NA
  #certs$MAIN_FUEL[certs$MAIN_FUEL == "INVALID!"] <- NA
  certs$HOT_WATER_ENERGY_EFF[certs$HOT_WATER_ENERGY_EFF %in% nas] <- NA
  certs$HOT_WATER_ENV_EFF[certs$HOT_WATER_ENV_EFF %in% nas] <- NA
  certs$MAINHEAT_ENERGY_EFF[certs$MAINHEAT_ENERGY_EFF %in% nas] <- NA
  certs$MAINHEAT_ENV_EFF[certs$MAINHEAT_ENV_EFF %in% nas] <- NA
  certs$MAINHEATC_ENERGY_EFF[certs$MAINHEATC_ENERGY_EFF %in% nas] <- NA
  certs$MAINHEATC_ENV_EFF[certs$MAINHEATC_ENV_EFF %in% nas] <- NA
  certs$LIGHTING_ENERGY_EFF[certs$LIGHTING_ENERGY_EFF %in% nas] <- NA
  certs$LIGHTING_ENV_EFF[certs$LIGHTING_ENV_EFF %in% nas] <- NA
  certs$WINDOWS_ENERGY_EFF[certs$WINDOWS_ENERGY_EFF %in% nas] <- NA
  certs$WINDOWS_ENV_EFF[certs$WINDOWS_ENV_EFF %in% nas] <- NA
  certs$WALL_ENERGY_EFF[certs$WALL_ENERGY_EFF %in% nas] <- NA
  certs$WALL_ENV_EFF[certs$WALL_ENV_EFF %in% nas] <- NA
  
  certs$SHEATING_ENERGY_EFF[certs$SHEATING_ENERGY_EFF %in% nas] <- NA
  certs$SHEATING_ENV_EFF[certs$SHEATING_ENV_EFF %in% nas] <- NA
  
  #certs$CURRENT_ENERGY_RATING[certs$CURRENT_ENERGY_RATING == "INVALID!"] <- NA
  #certs$POTENTIAL_ENERGY_RATING[certs$POTENTIAL_ENERGY_RATING == "INVALID!"] <- NA
  
  # If all NAs then make logical to reduce memory use
  if(all(is.na(certs$SHEATING_ENERGY_EFF))){
    certs$SHEATING_ENERGY_EFF <- NA
  }
  
  if(all(is.na(certs$SHEATING_ENV_EFF))){
    certs$SHEATING_ENV_EFF <- NA
  }
  certs_all[[i]] = certs
  
}

certs_all = dplyr::bind_rows(certs_all)


saveRDS(certs_all, "epc_scotland_domestic_all_raw.Rds")


