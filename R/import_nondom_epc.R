# Read in EPC Data
# Settings ---------------------------------------------------------------

# Setup ---------------------------------------------------------------
library(dplyr)
library(readr)
source("R/translate_welsh.R", encoding="UTF-8")
source("R/funtions.R", encoding="UTF-8")

path = "../inputdata/epc/"

dir.create(file.path(tempdir(),"epc"))
unzip(file.path(path,"all-non-domestic-certificates-single-file-20240630.zip"), 
      exdir = file.path(tempdir(),"epc"))

files <- list.files(file.path(tempdir(),"epc"), recursive = TRUE, full.names = TRUE)
files_certs <- files[grepl("certificates.csv", files)]
files_reccs <- files[grepl("recommendations.csv", files)]


# Import  -------------------------------------------------------------

certs <- readr::read_csv(files_certs)

# Dump unneeded columns
certs$CONSTITUENCY <- NULL
certs$CONSTITUENCY_LABEL <- NULL
certs$ADDRESS <- NULL
certs$COUNTY <- NULL
certs$LOCAL_AUTHORITY <- NULL
certs$LOCAL_AUTHORITY_LABEL <- NULL
certs$POSTTOWN <- NULL

saveRDS(certs, "epc_nondomestic_all_raw.Rds")

reccs <- readr::read_csv(files_reccs)
saveRDS(reccs, "epc_nondomestic_reccs_all_raw.Rds")
