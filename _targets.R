# targets pipeline for the England/Wales + Scotland EPC processing (2026 data).
#
# Replaces the standalone scripts in R/ (import_*.R, clean_*.R, merge_epcs.R,
# uprn_classifications.R).  The original scripts are kept for reference; the
# pipeline logic lives in R/tar_functions.R and R/tar_merge.R, with the shared
# domestic free-text vocabulary in R/domestic_dictionaries_2026.R.
#
# Run with:   targets::tar_make()
# Visualise:  targets::tar_visnetwork()
#
# NB: the full run reads the entire GB EPC corpus and needs a very large
# machine (~256 GB RAM); this is inherent to the original design.

library(targets)

tar_option_set(
  packages = c("dplyr", "readr", "sf", "future", "furrr",
               "lubridate", "stringi", "stringr"),
  format = "rds",
  memory = "transient",
  garbage_collection = TRUE
)

# Attach readr so the unqualified col_character() calls inside functions.R's
# col_types resolve when the helper files are sourced, then load all helpers.
suppressPackageStartupMessages(library(readr))
# encoding = "UTF-8": functions_2026.R and translate_welsh.R contain Welsh text
# with accented characters and U+2019 apostrophes that must be read as UTF-8.
source("R/functions.R", encoding = "UTF-8")
source("R/translate_welsh.R", encoding = "UTF-8")
source("R/functions_2026.R", encoding = "UTF-8")
source("R/tar_functions.R", encoding = "UTF-8")
source("R/tar_merge.R", encoding = "UTF-8")

epc_dir   <- "../inputdata/epc"

# uprn_historical is built by the LandOwnership repo, which owns all UPRN /
# address work as of July 2026 (it was previously read from ../build, which
# no longer builds it). Tracked as a file so an OS Open UPRN refresh over
# there re-triggers the cleaning steps here.
lo_obj    <- "../LandOwnership/_targets/objects"

# Helper for the "write a canonical .Rds and track it as a file" publish steps
save_rds_file <- function(object, path) {
  saveRDS(object, path)
  path
}

list(

  # ---- Raw input files (tracked so re-downloads re-trigger the pipeline) ----
  tar_target(dom_zip,    file.path(epc_dir, "domestic-csv-20260630.zip"),     format = "file"),
  tar_target(nondom_zip, file.path(epc_dir, "non-domestic-csv-20260630.zip"), format = "file"),
  tar_target(dec_zip,    file.path(epc_dir, "display-csv-20260630.zip"),      format = "file"),
  tar_target(scot_dom_7z,
             file.path(epc_dir, "EPC Data - Q1 2026 Extract - EPD Extended Historic Data Publication Note - Domestic Buildings.7z"),
             format = "file"),
  tar_target(scot_nondom_7z,
             file.path(epc_dir, "Non-domestic EPC - Extended Historic Data to 2026 Q1.7z"),
             format = "file"),
  tar_target(uprn_hist_file, file.path(lo_obj, "uprn_historical"), format = "file"),

  # ---- UPRN point locations ----
  # uprn_historical is the superset (older + newer UPRNs), so it is the single
  # source of UPRN locations for every step in the workflow.
  tar_target(uprn_hist, prep_uprn_historical(readRDS(uprn_hist_file))),

  # ---- Import (raw, full-column) ----
  tar_target(raw_dom,         import_ew_domestic(dom_zip)),
  tar_target(raw_dom_reccs,   import_ew_domestic_reccs(dom_zip)),
  tar_target(raw_nondom,      import_ew_nondomestic(nondom_zip)),
  tar_target(raw_dec,         import_dec(dec_zip)),
  tar_target(raw_scot_dom,    import_scot_domestic(scot_dom_7z)),
  tar_target(raw_scot_nondom, import_scot_nondomestic(scot_nondom_7z)),

  # ---- Clean ----
  tar_target(clean_dom,         clean_ew_domestic(raw_dom, uprn_hist)),
  tar_target(clean_scot_dom,    clean_scot_domestic(raw_scot_dom, uprn_hist)),
  tar_target(clean_nondom,      clean_ew_nondomestic(raw_nondom, uprn_hist)),
  tar_target(clean_scot_nondom, clean_scot_nondomestic(raw_scot_nondom, uprn_hist)),
  tar_target(clean_decs,        clean_dec(raw_dec, uprn_hist)),

  # ---- Merge to GB ----
  tar_target(gb_domestic,    merge_gb_domestic(clean_dom, clean_scot_dom)),
  tar_target(gb_nondomestic, merge_gb_nondomestic(clean_nondom, clean_scot_nondom)),

  # ---- UPRN -> building type / tenure classification ----
  tar_target(uprn_building_type,
             classify_uprns(raw_dom, raw_nondom, raw_scot_dom, raw_scot_nondom, raw_dec, uprn_hist)),

  # ---- Publish canonical outputs consumed by the rest of the project ----
  tar_target(file_clean_dom,
             save_rds_file(clean_dom, file.path(epc_dir, "epc_domestic_clean.Rds")), format = "file"),
  tar_target(file_clean_scot_dom,
             save_rds_file(clean_scot_dom, file.path(epc_dir, "epc_scotland_domestic_clean.Rds")), format = "file"),
  tar_target(file_clean_nondom,
             save_rds_file(clean_nondom, file.path(epc_dir, "epc_nondomestic_clean.Rds")), format = "file"),
  tar_target(file_clean_scot_nondom,
             save_rds_file(clean_scot_nondom, file.path(epc_dir, "epc_scotland_nondomestic_clean.Rds")), format = "file"),
  tar_target(file_clean_decs,
             save_rds_file(clean_decs, file.path(epc_dir, "dec_clean.Rds")), format = "file"),
  tar_target(file_gb_domestic,
             save_rds_file(gb_domestic, file.path(epc_dir, "GB_domestic_epc.Rds")), format = "file"),
  tar_target(file_gb_nondomestic,
             save_rds_file(gb_nondomestic, file.path(epc_dir, "GB_nondomestic_epc.Rds")), format = "file"),
  tar_target(file_uprn_building_type,
             save_rds_file(uprn_building_type, "uprn_with_buidling_type.Rds"), format = "file")#,
  # tar_target(file_uprn_building_type_gpkg, {
  #   path <- "uprn_with_buidling_type.gpkg"
  #   sf::st_write(uprn_building_type, path, delete_dsn = TRUE, quiet = TRUE)
  #   path
  # }, format = "file")
)
