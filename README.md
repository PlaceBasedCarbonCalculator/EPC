# Parse Energy Performance Certificates and Display Energy Certificates for the UK

In the UK, domestic and non-domestic buildings are required to have an Energy Performance Certificate when they are sold or rented. Certificates are valid for 10 years, and they are the only dataset in the UK where somebody has visited the building and taken measurements and observations.

Publicly accessible buildings are required to have an annual Display Energy Certificate

While there has been a lot of criticism in the UK of EPCs, in particular, they are not very good at predicting actual energy use. They are an invaluable source of data about much of the building stock. 

## Getting the Data

Data for England and Wales is published a Open Data at https://epc.opendatacommunities.org/

Data for Scotland is published at https://www.scottishepcregister.org.uk/

## Purpose of this repo

This repo provides much of the pre-processing of the EPC data that is available on the www.carbon.place website. Specifically, it has 3 functions.

1. To clean and summarise some of the free test fields to aid analysis and understanding of the data
2. To match EPCs with Unique Property Reference Numbers (UPRN) so that they can be mapped
3. To merge the Scottish data with the England and Wales data to produce a single Great Britain dataset.

## Key scripts

Most scripts have self-explanatory names, such as `import_epc.R`, which reads in the raw EPC data for England and Wales, and does some basic pre-cleaning.

An important script is `clean_epc`, which does most of the cleaning on the text variables based on functions defined in `functions.R` and `translate_welsh.R`.

Important cleaning functions include:

1. `fix_wm2k`, which handled the many versions of `watts per square metre kelvin` and unit of heat loss into a standard format.
2. `standardclean`, which removed common errors or inconsistencies (e.g. `&` vs `and`)
3. `yn2logical`, which converts yes/no text variables to logical TRUE/FALSE
4. `splitwelsh`, in some EPCs, the text is provided in both English and Welsh, separated by `|`; this function splits and removes the Welsh version.
5. `translatewelsh` is used when only the Welsh test is available and translates common Welsh phrases to their English equivalents. E.g. "briciau solet" to "solid brick". I used Google Translate for these, and feedback from Welsh speakers is welcome.

While the cleaning is not perfect, it does significantly reduce variation between EPCs, which is useful for analysis. For example, instead of thousands of different Main Fuel Types in the raw data, there are about 40 distinct types in the cleaned data.







