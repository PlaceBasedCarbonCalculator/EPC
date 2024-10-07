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
names(certs_nondom)[!names(certs_nondom) %in% names(scot_nondom)]
names(scot_nondom)[!names(scot_nondom) %in% names(certs_nondom)]

certs_dom = certs_dom[,names(scot_dom)]
dom_all = rbind(certs_dom, scot_dom)

nondom_all = rbind(certs_nondom, scot_nondom)
#rm(certs_nondom, scot_nondom, certs_dom, scot_dom)

# Clean up for publication
names(dom_all) = c("UPRN","addr","cur_rate","cur_ee",
                   "per_ee","INSPECTION_DATE","b_type","p_type",
                   "tenure","age","area","fuel",
                   "heat_d","g_type","floor_d","floor_ee",
                   "water_d","water_ee","wind_d","wind_ee",
                   "wall_d","wall_ee","roof_d","roof_ee",
                   "heat_ee","con_d","con_ee","light_ee",
                   "pv","sol_wat","geometry"  )

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
dom_all$fuel = gsub("electric","electricity", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("electricity: ","", dom_all$fuel, fixed = TRUE)
dom_all$fuel = gsub("oil: ","", dom_all$fuel, fixed = TRUE)
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

dom_all$wind_d = gsub("description: ","", dom_all$wind_d, fixed = TRUE)
dom_all$wind_d = tolower(dom_all$wind_d)

dom_all$water_d = tolower(dom_all$water_d)

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
  z[y >= 2012] = "2012 onwards"
  
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
  
  x
  
}



dom_all$age = simple_ages(dom_all$age)


saveRDS(dom_all, "../inputdata/epc/GB_domestic_epc.Rds")


names(nondom_all) = c("UPRN","adr1","adr2","rating","type","band","transaction", 
                      "area","INSPECTION_DATE","fuel","geometry"  )
nondom_all$year = lubridate::year(lubridate::ymd(nondom_all$INSPECTION_DATE))
nondom_all$INSPECTION_DATE  = NULL
nondom_all$band[nondom_all$band == "Carbon Neu"] = "A+"
nondom_all$band[nondom_all$band == "INVALID!"] = NA

nondom_all$transaction = gsub(".","",nondom_all$transaction, fixed = TRUE)
nondom_all$fuel = tolower(nondom_all$fuel)

saveRDS(nondom_all, "../inputdata/epc/GB_nondomestic_epc.Rds")
