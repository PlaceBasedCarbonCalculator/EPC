# Parse Energy Performance Certificates and Display Energy Certificates for the UK

In the UK, domestic and non-domestic buildings are required to have an Energy Performance Certificate (EPC) when they are sold or rented. Certificates are valid for 10 years, and they are the only dataset in the UK where somebody has visited the building and taken measurements and observations.

Publicly accessible buildings are required to have an annual Display Energy Certificate (DEC).

While there has been a lot of criticism in the UK of EPCs, in particular, they are not very good at predicting actual energy use. They are an invaluable source of data about much of the building stock.

## Getting the Data

Data for England and Wales is published as Open Data at https://epc.opendatacommunities.org/

Data for Scotland is published at https://www.scottishepcregister.org.uk/

## Purpose of this repo

![Screenshot of EPC map](/images/screenshot.jpg)

This repo provides much of the pre-processing of the EPC data that is available on the www.carbon.place website. Specifically, it has 3 functions.

1. To clean and summarise some of the free text fields to aid analysis and understanding of the data
2. To match EPCs with Unique Property Reference Numbers (UPRN) so that they can be mapped
3. To merge the Scottish data with the England and Wales data to produce a single Great Britain dataset.

## Pipeline

The scripts in `R/` are run in this order:

1. **Import** — read the raw CSVs from the downloaded zip files and save them
   as Rds files in the repo root:
   `import_epc.R`, `import_nondom_epc.R`, `import_dec.R` (England & Wales) and
   `import_epc_scotland.R`, `import_nondom_epc_scotland.R` (Scotland).
2. **Clean** — keep the most recent certificate per UPRN, attach UPRN point
   locations, clean the free-text fields, and save to `../inputdata/epc/`:
   `clean_epc.R`, `clean_nondom_epc.R`, `clean_decs.R`,
   `clean_epc_scot.R`, `clean_nondom_epc_scot.R`.
3. **Merge** — `merge_epcs.R` combines the cleaned England & Wales and
   Scotland data into single Great Britain datasets
   (`GB_domestic_epc.Rds`, `GB_nondomestic_epc.Rds`).

Two further analysis scripts use the raw/cleaned data:

- `uprn_classifications.R` classifies UPRNs by building type and tenure using
  the most recent certificate of any kind lodged against each UPRN.
- `epc_over_time.R` produces plots and maps of EPC ratings over time by area
  classification.

## Key cleaning functions

Most of the free-text cleaning is done in `clean_epc.R` and
`clean_epc_scot.R`, based on functions defined in `functions.R` and
`translate_welsh.R`.

Important cleaning functions include:

1. `fix_wm2k`, which converts the many versions of `watts per square metre kelvin` (a unit of heat loss) into a standard format.
2. `standardclean`, which removes common errors or inconsistencies (e.g. `&` vs `and`)
3. `yn2logical`, which converts yes/no text variables to logical TRUE/FALSE
4. `splitwelsh`; in some EPCs, the text is provided in both English and Welsh, separated by `|`; this function splits and removes the Welsh version.
5. `translatewelsh` is used when only the Welsh text is available and translates common Welsh phrases to their English equivalents. E.g. "briciau solet" to "solid brick". I used Google Translate for these, and feedback from Welsh speakers is welcome. Oddly, EPCs in Welsh don't only occur in Wales.
6. `validate`, which checks that a cleaned column only contains values from a
   controlled vocabulary (defined in the clean scripts) and converts it to a
   factor, stopping with a report of any unexpected values.

While the cleaning is not perfect, it does significantly reduce variation between EPCs, which is useful for analysis. For example, instead of thousands of different Main Fuel Types in the raw data, there are about 40 distinct types in the cleaned data.

`merge_epcs.R` resolves differences between the Scotland and England/Wales datasets. Specifically, the different age bands used by Scotland are mapped to the English/Welsh version. This can result in minor errors, e.g. "1992-1998" becomes "1991-1995"

## Usage

Note that these scripts read the whole EPC dataset into memory and so require a PC with a large amount of RAM (e.g. 256 GB).

This repo also works on the assumption that the [build](https://github.com/PlaceBasedCarbonCalculator/build) and [inputdata](https://github.com/PlaceBasedCarbonCalculator/inputdata) repos are available on the same drive to provide inputs (the downloaded zip files and UPRN locations) and as a place for exports.

## Data Download

See the [website](https://www.carbon.place/data/) for public downloads.
