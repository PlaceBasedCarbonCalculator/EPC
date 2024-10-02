library(sf)
library(dplyr)

certs_dom = readRDS("../inputdata/epc/epc_domestic_clean.Rds")
certs_nondom = readRDS("../inputdata/epc/epc_nondomestic_clean.Rds")
scot_dom = readRDS("../inputdata/epc/epc_scotland_domestic_clean.Rds")
scot_nondom = readRDS("../inputdata/epc/epc_scotland_nondomestic_clean.Rds")
#decs = readRDS("dec_all_raw.Rds")

#certs_dom = sf::st_drop_geometry(certs_dom)

#uprn <- readRDS("../build/_targets/objects/uprn")
#uprn <- sf::st_as_sf(uprn)

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


certs_dom = certs_dom[,c("BUILDING_REFERENCE_NUMBER","ADDRESS1","UPRN","PROPERTY_TYPE","TENURE","LODGEMENT_DATETIME",
                         "CURRENT_ENERGY_RATING","CURRENT_ENERGY_EFFICIENCY","POTENTIAL_ENERGY_EFFICIENCY","BUILT_FORM",
                         "INSPECTION_DATE",
                         )]
certs_dom = certs_dom[order(certs_dom$LODGEMENT_DATETIME, decreasing = TRUE),]
certs_dom = certs_dom[!duplicated(certs_dom$UPRN),]

certs_nondom = certs_nondom[,c("BUILDING_REFERENCE_NUMBER","ADDRESS1","ADDRESS2","UPRN","PROPERTY_TYPE","LODGEMENT_DATETIME")]
certs_nondom = certs_nondom[order(certs_nondom$LODGEMENT_DATETIME, decreasing = TRUE),]
certs_nondom = certs_nondom[!duplicated(certs_nondom$UPRN),]

scot_dom = scot_dom[,c("ADDRESS1","Property_UPRN","Property Type","Tenure","Lodgement Date")]
scot_nondom = scot_nondom[,c("Address1","Address2","Property_UPRN","Property Type","Lodgement Date")]

scot_dom = scot_dom[order(scot_dom$`Lodgement Date`, decreasing = TRUE),]
scot_nondom = scot_nondom[order(scot_nondom$`Lodgement Date`, decreasing = TRUE),]

scot_dom = scot_dom[!duplicated(scot_dom$Property_UPRN),]
scot_nondom = scot_nondom[!duplicated(scot_nondom$Property_UPRN),]

decs = decs[,c("LMK_KEY","ADDRESS1","ADDRESS2","PROPERTY_TYPE","UPRN","LODGEMENT_DATETIME")]
decs = decs[order(decs$LODGEMENT_DATETIME, decreasing = TRUE),]
decs = decs[!duplicated(decs$UPRN),]


certs_dom = certs_dom[,c("UPRN","PROPERTY_TYPE","TENURE","LODGEMENT_DATETIME")]
certs_nondom = certs_nondom[,c("UPRN","PROPERTY_TYPE","LODGEMENT_DATETIME")]
scot_dom = scot_dom[,c("Property_UPRN","Property Type","Tenure","Lodgement Date")]
scot_nondom = scot_nondom[,c("Property_UPRN","Property Type","Lodgement Date")]
decs = decs[,c("UPRN","PROPERTY_TYPE","LODGEMENT_DATETIME")]

names(scot_dom) = c("UPRN","PROPERTY_TYPE","TENURE","LODGEMENT_DATETIME")
names(scot_nondom) = c("UPRN","PROPERTY_TYPE","LODGEMENT_DATETIME")

certs_nondom$TENURE = NA
scot_nondom$TENURE = NA
decs$TENURE = NA

certs_all = rbind(certs_dom, certs_nondom, scot_dom, scot_nondom, decs)
certs_all = certs_all[order(certs_all$LODGEMENT_DATETIME, decreasing = TRUE),]
certs_all = certs_all[!duplicated(certs_all$UPRN),]
certs_all$UPRN = as.numeric(certs_all$UPRN)


certs_uprn = dplyr::left_join(certs_all, uprn, by = "UPRN")



saveRDS(certs_uprn,"uprn_with_buidling_type.Rds")
sf::st_write(certs_uprn,"uprn_with_buidling_type.gpkg", delete_dsn = TRUE)
