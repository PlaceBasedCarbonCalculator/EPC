# Read in EPC Data
# Settings ---------------------------------------------------------------

# Setup ---------------------------------------------------------------
library(dplyr)
library(readr)
source("R/translate_welsh.R", encoding="UTF-8")
source("R/funtions.R", encoding="UTF-8")

path = "../inputdata/epc/"

dir.create(file.path(tempdir(),"epc"))
unzip(file.path(path,"Scotland_NonDomestic_EPC_data_2014-2024Q2.zip"), 
      exdir = file.path(tempdir(),"epc"))

files <- list.files(file.path(tempdir(),"epc"), recursive = TRUE, full.names = TRUE)
files_certs <- files[grepl(".csv", files)]

# Import  -------------------------------------------------------------
certs_all = list()


for(i in seq(1, length(files_certs))){
  message(i," ", files_certs[i])
  certs <- readr::read_csv(files_certs[i], skip = 1)
  
  certs_all[[i]] = certs
  
}

certs_all = dplyr::bind_rows(certs_all)


saveRDS(certs_all, "epc_scotland_nondomestic_all_raw.Rds")


