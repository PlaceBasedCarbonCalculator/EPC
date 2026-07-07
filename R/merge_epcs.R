# Merge the England & Wales and Scotland cleaned EPC datasets into single
# Great Britain domestic and non-domestic datasets, harmonising the
# differences between them (e.g. Scottish construction age bands are mapped
# to the England & Wales bands) and shortening column names for publication.
# Input:  the four *_clean.Rds files (from the clean_* scripts)
# Output: ../inputdata/epc/GB_domestic_epc.Rds
#         ../inputdata/epc/GB_nondomestic_epc.Rds

library(sf)
library(dplyr)

certs_dom = readRDS("../inputdata/epc/epc_domestic_clean.Rds")
certs_nondom = readRDS("../inputdata/epc/epc_nondomestic_clean.Rds")
scot_dom = readRDS("../inputdata/epc/epc_scotland_domestic_clean.Rds")
scot_nondom = readRDS("../inputdata/epc/epc_scotland_nondomestic_clean.Rds")

# Old Variaibles
# Address: 36, Maxey Road
# EPC Score: 74 (C)                                                   Note two variaibles
# Potential EPC Score: 77
# Building type: End-Terrace Flat
# Constructed: 1950-1966
# Last assessed: 2017
# Floor area: 85m2
# Main fuel: mains gas
# Walls: cavity wall, filled cavity (Good)                            Note two variaibles
# Roof: (another dwelling above) (dwelling above)
# Floors: solid, no insulation (assumed)
# Windows: full double glazing (Good)                                 Note two variaibles
# Heating: boiler, radiators, mains gas (Good)                        Note two variaibles
# Heating Controls: programmer, room thermostat and trvs (Good)       Note two variaibles
# Hot water: from main system, (Good)                                 Note two variaibles
# Lighting: Average

# Link to full EPC? England and Wales
#https://find-energy-certificate.service.gov.uk/energy-certificate/2841-6153-5491-2581-8111
# Scotland
#https://www.scottishepcregister.org.uk/CustomerFacingPortal/Download/4490-4599-0729-6198-1003 
# IDs not in data

names(certs_dom)[!names(certs_dom) %in% names(scot_dom)]
names(scot_dom)[!names(scot_dom) %in% names(certs_dom)]
names(certs_nondom)[!names(certs_nondom) %in% names(scot_nondom)]
names(scot_nondom)[!names(scot_nondom) %in% names(certs_nondom)]

certs_dom = certs_dom[,names(scot_dom)]
dom_all = rbind(certs_dom, scot_dom)

#rm(certs_nondom, scot_nondom, certs_dom, scot_dom)

# Clean up for publication: rename by name (not position) so this keeps
# working if the column order of the clean files changes
dom_all = dplyr::rename(dom_all,
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

dom_all$year = lubridate::year(lubridate::ymd(dom_all$INSPECTION_DATE))
dom_all$INSPECTION_DATE  = NULL

dom_all$cur_rate[!dom_all$cur_rate %in% c("A","B","C","D","E","F","G")] = NA
dom_all$b_type[dom_all$b_type == "NO DATA!"] = NA

dom_all$tenure[dom_all$tenure == "NO DATA!"] = "unknown"
dom_all$tenure[dom_all$tenure == "Not defined - use in the case of a new dwelling for which the intended tenure in not known. It is not to be used for an existing dwelling"] = "unknown"
dom_all$tenure = tolower(dom_all$tenure)
dom_all$tenure = gsub("rental","rented", dom_all$tenure)

dom_all$age = gsub("England and Wales: ","", dom_all$age)
dom_all$age[dom_all$age %in% c("INVALID!","NO DATA!")] = NA

#Simplify ages
simple_ages = function(x){
  y = as.integer(x)
  z = rep(NA_character_, length(y))
  z[y < 1900] = "before 1900"
  z[y >= 1900 & y <= 1929] = "1900-1929"
  z[y >= 1930 & y <= 1949] = "1930-1949"
  z[y >= 1950 & y <= 1966] = "1950-1966"
  z[y >= 1967 & y <= 1975] = "1967-1975"
  z[y >= 1976 & y <= 1982] = "1976-1982"
  z[y >= 1983 & y <= 1990] = "1983-1990"
  z[y >= 1991 & y <= 1995] = "1991-1995"
  z[y >= 1996 & y <= 2002] = "1996-2002"
  z[y >= 2003 & y <= 2006] = "2003-2006"
  z[y >= 2007 & y <= 2011] = "2007-2011"
  z[y >= 2012 & y <= 2021] = "2012-2021"
  z[y >= 2022] = "2022 onwards"
  
  x = dplyr::if_else(is.na(z),x,z)
  x[x == "before 1919"] = "before 1900"
  x[x == "1919-1929"] = "1900-1929"
  
  x[x == "1950-1964"] = "1950-1966"
  x[x == "1965-1975"] = "1967-1975"
  x[x == "1976-1983"] = "1976-1982"
  x[x == "1984-1991"] = "1983-1990"
  x[x == "1992-1998"] = "1991-1995"
  x[x == "1999-2002"] = "1996-2002"
  x[x == "2003-2007"] = "2003-2006"
  x[x == "2007 onwards"] = "2007-2011"
  x[x == "2008 onwards"] = "2007-2011"
  x[x == "2012 onwards"] = "2012-2021"
  
  x
  
}

dom_all$age = simple_ages(dom_all$age)

dom_all$area = round(dom_all$area, 0)


dom_all$fuel = tolower(dom_all$fuel)
dom_all$fuel = gsub("- this is for backwards compatibility only and should not be used","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("to be used only when there is no heating/hot-water system or data is from a community network","none", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("to be used only when there is no heating/hot-water system","none", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("no heating/hot-water system or data is from a community network","none", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("appliances able to use ","", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("(not community)","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("solid fuel: ","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("gas: ","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("electricity: ","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("oil: ","", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("subject to special condition 18","special condition", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("from heat network data","heat network", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("heat from boilers that can use","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("heat from boilers using biodiesel from any biomass source","biodiesel", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("displaced from grid","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub(", unspecified tariff","", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("community heating schemes:","(community)", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("bulk supply in bags, for ","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("in bags, for ","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("in bags for secondary heating","(secondary heating)", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("bulk","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("heat from","", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("electric: electric","electric", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("electric","electricity", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("dual fuel - mineral + wood","dual fuel mineral + wood", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("dual fuel appliance (mineral and wood)","dual fuel mineral + wood", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("(community)  mains gas","mains gas (community)", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("(community)  boilers - biomass","biomass (community)", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("(community)  electricity heat pump","electricity (community)", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("(community)  heat pump","electricity (community)", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("anthracite","coal", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("wood pellets (main heating)","wood pellets", dom_all$fuel, fixed = TRUE)

dom_all$fuel = gsub("no heating/hot-water system","none", dom_all$fuel, fixed = TRUE)

dom_all$fuel = trimws(dom_all$fuel, "both")

dom_all$heat_d = tolower(dom_all$heat_d)

dom_all$floor_ee[!dom_all$floor_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$water_ee[!dom_all$water_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$wind_ee[!dom_all$wind_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$wall_ee[!dom_all$wall_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$roof_ee[!dom_all$roof_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$heat_ee[!dom_all$heat_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$con_ee[!dom_all$con_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA
dom_all$light_ee[!dom_all$light_ee %in% c("Very Good","Good","Average","Poor","Very Poor")] = NA

dom_all$sol_wat[dom_all$sol_wat %in% c("false","FALSE","N")] = "no"
dom_all$sol_wat[dom_all$sol_wat %in% c("true","TRUE","Y")] = "yes"

dom_all$wind_d = trimws(dom_all$wind_d)

#dom_all$pv <- ifelse(is.na(dom_all$pv),"no","yes")
table(dom_all$pv, useNA = "always")

saveRDS(dom_all, "../inputdata/epc/GB_domestic_epc.Rds")

certs_nondom = certs_nondom[,names(certs_nondom) %in% names(scot_nondom)]
scot_nondom$ADDRESS3 = "" #Town in Scotland and not town in England/Wales

nondom_all = rbind(certs_nondom, scot_nondom)


# Rename by name (not position) so this keeps working if the column order
# of the clean files changes
nondom_all = dplyr::rename(nondom_all,
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
nondom_all$year = lubridate::year(lubridate::ymd(nondom_all$INSPECTION_DATE))
nondom_all$INSPECTION_DATE  = NULL
nondom_all$band[nondom_all$band == "Carbon Neu"] = "A+"
nondom_all$band[nondom_all$band == "INVALID!"] = NA

nondom_all$transaction = gsub(".","",nondom_all$transaction, fixed = TRUE)
nondom_all$fuel = tolower(nondom_all$fuel)

saveRDS(nondom_all, "../inputdata/epc/GB_nondomestic_epc.Rds")
