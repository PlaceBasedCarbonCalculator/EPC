# 2026 vocabulary additions for the domestic EPC free-text fields.
#
# The strict validate step (validate_domestic()) stops when a cleaned value is
# not in the England/Wales vocabulary carried over from clean_epc.R.  Every EPC
# release introduces new/changed free-text values, so this file is where the
# 2026 additions live.  run_domestic_dictionaries() sources it into the global
# environment AFTER R/domestic_dictionaries_2026.R (so the td_*/sub_* helpers
# and the valid-value vectors already exist) and BEFORE validate_domestic().
#
# PROVENANCE / STATUS: derived by cleaning the WHOLE domestic corpus - the
# Scottish (3.7M certs) and England & Wales (23.6M certs) datasets - and driving
# the remaining unknown values to zero (0 for Scotland; England & Wales clears
# every column, with compound MAINHEAT values accepted by decomposition in
# validate_domestic()). Mappings that re-map values (rather than accept them
# verbatim) are best-effort and should be reviewed by the data owner; the
# verbatim additions deliberately keep the full descriptive detail for the
# per-building tool layer. A future data release may add a few more values -
# validate_domestic() reports them all at once.

# --- FLOOR_DESCRIPTION -------------------------------------------------------
# 2026 emits the bare category with no trailing qualifier; canonical form keeps
# the trailing comma (e.g. "solid,", "suspended,").
td_FLOOR_DESCRIPTION("solid", "solid,")
td_FLOOR_DESCRIPTION("suspended", "suspended,")

# --- ROOF_DESCRIPTION --------------------------------------------------------
# New loft-insulation thickness bands, plus a new "(same dwelling above)" value
# mirrored on the existing "(other dwelling above)" -> "(another ...)" rule.
td_ROOF_DESCRIPTION("(same dwelling above)", "(another dwelling above)")
ROOF_DESCRIPTION <- c(ROOF_DESCRIPTION,
                      "pitched, 125 mm loft insulation",
                      "pitched, 175 mm loft insulation",
                      "pitched, 225 mm loft insulation")

# --- WALLS_DESCRIPTION -------------------------------------------------------
WALLS_DESCRIPTION <- c(WALLS_DESCRIPTION, "basement wall")

# --- HOTWATER_DESCRIPTION ----------------------------------------------------
# Welsh "o'r brif system" = "from the main system" (translatewelsh misses it).
# Handle both the straight and the curly (U+2019) apostrophe.
td_HOTWATER_DESCRIPTION("o'r brif system", "from main system,")  # apostrophe already straightened

# --- MAINHEATCONT_DESCRIPTION ------------------------------------------------
td_MAINHEATCONT_DESCRIPTION("programmer room thermostat and trvs",
                            "programmer, room thermostat and trvs")
MAINHEATCONT_DESCRIPTION <- c(MAINHEATCONT_DESCRIPTION,
                              "room thermostat and trvs",
                              "flat rate charging, room thermostat and trvs",
                              "charging system linked to use of community heating, room thermostat and trvs")

# --- MAIN_FUEL ---------------------------------------------------------------
# These raw fuel strings are further normalised in merge_gb_domestic() (the
# "gas: "/"oil: " prefixes and "... community network" text are stripped there),
# so they only need to pass validation at the clean stage.
MAIN_FUEL <- c(MAIN_FUEL,
               "gas: mains gas",
               "oil: heating oil",
               "biodiesel from vegetable oil only (not community)",
               "to be used only when there is no heating/hot-water system or data is from a community network")

# --- MAINHEAT_DESCRIPTION ----------------------------------------------------
# 2026 introduces compound heating descriptions (two or more systems joined by
# commas). Per the "keep full text" decision these are kept verbatim:
# validate_domestic() auto-accepts any MAINHEAT value that decomposes into known
# single systems (see .decomposes_into() in functions_2026.R), so they do NOT
# need to be listed or collapsed here. The few sample-era compounds below are
# harmless (already covered by decomposition) and kept only for documentation.
MAINHEAT_DESCRIPTION <- c(MAINHEAT_DESCRIPTION,
                          "air source heat pump, radiators and underfloor, electric",
                          "air source heat pump ,radiators, electric",
                          "boiler, radiators, oil, boiler, underfloor heating, mains gas",
                          "boiler, radiators, mains gas, boiler, underfloor heating, mains gas",
                          "boiler, underfloor heating, mains gas, boiler, radiators, mains gas",
                          "boiler, radiators, oil, boiler, underfloor heating, oil",
                          "boiler, underfloor heating, oil, boiler, radiators, oil",
                          "boiler with radiators, underfloor heating, mains gas",
                          "boiler with radiators, underfloor heating, oil",
                          "electric storage heaters, boiler, radiators, oil",
                          "boiler, radiators, mains gas, electric underfloor heating",
                          "room heaters, mains gas, room heaters, electric",
                          "ground source heat pump, radiators and underfloor, electric",
                          "ground source heat pump ,underfloor, electric",
                          "air source heat pump, warm air, electric, electric storage heaters",
                          "ground source heat pump, radiators, electric, ground source heat pump, underfloor heating, electric",
                          "air source heat pump, radiators, electric, air source heat pump, underfloor heating, electric",
                          "boiler, underfloor heating, mains gas, air source heat pump, warm air, electric",
                          "boiler, radiators, mains gas, air source heat pump, radiators, electric",
                          "boiler, radiators, mains gas, boiler, radiators, lpg",
                          "boiler, radiators, mains gas, room heaters, dual fuel (mineral and wood)")


# ===========================================================================
# Full-Scotland-run additions (2026-07-16)
# ===========================================================================
# The following were found by cleaning the WHOLE Scottish domestic dataset
# (3.7M certs) after the "|" main-part rule (section 3.7 of the migration report).
# They fall into: (a) systematic cleaning rules, and (b) genuinely-new
# categories accepted verbatim to preserve detail (the data owner may later
# choose to re-map some of these to existing categories).

# --- (a1) Universal: blank and "(error)" tokens become NA -------------------
local({
  desc_cols <- c("FLOOR_DESCRIPTION", "WALLS_DESCRIPTION", "ROOF_DESCRIPTION",
                 "MAINHEAT_DESCRIPTION", "MAINHEATCONT_DESCRIPTION",
                 "HOTWATER_DESCRIPTION", "WINDOWS_DESCRIPTION", "MAIN_FUEL")
  for (nm in desc_cols) {
    v <- certs[[nm]]
    v[!is.na(v) & (v == "" | grepl("error", v, fixed = TRUE))] <- NA
    certs[[nm]] <- v
  }
  assign("certs", certs, envir = .GlobalEnv)
})

# --- (a2) WALLS: roof text in the wall field is a SOURCE DATA ERROR ----------
# ~9,150 Scottish rows (0.25%) carry a roof description in WALL_DESCRIPTION
# (e.g. "pitched, 250 mm loft insulation"). These are wrong, not a wall type,
# so they are set to NA (unknown wall) rather than polluting the wall
# categories. Flagged for the data owner.
local({
  w <- certs$WALLS_DESCRIPTION
  roofish <- !is.na(w) & grepl("^(pitched|flat|roof room|thatched|\\(another dwelling above\\))", w)
  w[roofish] <- NA
  certs$WALLS_DESCRIPTION <- w
  assign("certs", certs, envir = .GlobalEnv)
})

# --- (a3) MAINHEATCONT: strip the Scottish "group N: <category> " prefix -----
td_MAINHEATCONT_DESCRIPTION("group 1: boiler systems with radiators or underfloor heating programmer, room thermostat and trvs", "programmer, room thermostat and trvs")
td_MAINHEATCONT_DESCRIPTION("group 4: electric storage systems manual charge control", "manual charge control")
td_MAINHEATCONT_DESCRIPTION("group 5: warm air systems (including heat pumps with warm air distribution) programmer and room thermostat", "programmer and room thermostat")
td_MAINHEATCONT_DESCRIPTION("not applicable (heating provides dhw only)", "not relevant (supplies dhw only)")
td_MAINHEATCONT_DESCRIPTION("celect type controls", "celect-type controls")
td_MAINHEATCONT_DESCRIPTION("charging system linked to use of community heating, programmer a trvs", "charging system linked to use of community heating, programmer and trvs")
td_MAINHEATCONT_DESCRIPTION("charging system linked to use of community heating, programmer, and two room thermostats", "charging system linked to use of community heating, programmer and at least two room thermostats")
td_MAINHEATCONT_DESCRIPTION("flat rate charging room thermostat and trvs", "flat rate charging, room thermostat and trvs")
MAINHEATCONT_DESCRIPTION <- c(MAINHEATCONT_DESCRIPTION,
                              "not relevant",
                              "charging system linked to use of heating, room thermostat and trvs")

# --- (a4) ROOF: typo + premises/dwelling synonym ----------------------------
td_ROOF_DESCRIPTION("flat, imited insulation", "flat, limited insulation")
td_ROOF_DESCRIPTION("(another premises above)", "(another dwelling above)")
ROOF_DESCRIPTION <- c(ROOF_DESCRIPTION,
                      "roof room(s), thatched, ceiling insulated",
                      "roof room(s), thatched insulated")

# --- (a5) MAINHEAT: typo, plus new fuel/system combinations -----------------
# "boiler &amp; underfloor" is fixed upstream by the &amp; decode in
# standardclean(); it lands as "boiler, underfloor heating, ..." (canonical).
td_mainheat_description("boiler, radiators, appliances able to used mineral oil or liquid biofuel",
                        "boiler, radiators, appliances able to use mineral oil or liquid biofuel")
MAINHEAT_DESCRIPTION <- c(MAINHEAT_DESCRIPTION,
                          "community heating",
                          "radiator heating, heat from heat pump",
                          "mains gas",
                          "electric",
                          "electric storage heaters, underfloor heating",
                          "air source heat pump, radiators, anthracite",
                          "boiler, oil",
                          "boiler, lpg",
                          "boiler, radiators, lng",
                          "boiler, underfloor heating, lng",
                          "boiler, underfloor heating, bioethanol",
                          "room heaters, bioethanol",
                          "room heaters, liquid biofuel",
                          "ground source heat pump, radiators, lpg",
                          "water source heat pump, radiators and underfloor, electric",
                          "boiler with radiators, underfloor heating, lpg",
                          "boiler with radiators, underfloor heating, electric",
                          "boiler with radiators, underfloor heating, liquid biofuel",
                          ", radiators, mains gas")

# --- (a6) FLOOR / WALLS: new construction categories (verbatim) --------------
FLOOR_DESCRIPTION <- c(FLOOR_DESCRIPTION, "full exposed", "basement")
WALLS_DESCRIPTION <- c(WALLS_DESCRIPTION,
                       "timber frame",
                       "solid brick",
                       "system built",
                       "sandstone or limestone",
                       "sandstone or limestone, as built",
                       "curtain wall, as built, no insulation (assumed)",
                       "basement wall, as built, no insulation (assumed)",
                       "basement wall, as built, insulated (assumed)",
                       "basement wall, as built, partial insulation (assumed)",
                       "basement wall, as built, limited insulation (assumed)",
                       ", as built, insulated (assumed)",
                       ", filled cavity and internal insulation",
                       "99.00 w/m2k")

# --- (a7) HOTWATER: new descriptions (verbatim) -----------------------------
td_HOTWATER_DESCRIPTION("no hot water system present electric immersion assumed",
                        "no system present: electric immersion assumed")
HOTWATER_DESCRIPTION <- c(HOTWATER_DESCRIPTION,
                          "back boiler (hot water only), gas, no cylinder thermostat",
                          "from a circulator built into a gas warm air system, 1998 or later",
                          "from a circulator built into a gas warm air system, 1998 or later, no cylinder thermostat",
                          "from a circulator built into a gas warm air system, pre 1998",
                          "from a circulator built into a gas warm air system, pre 1998, no cylinder thermostat",
                          "oil range cooker, no cylinder thermostat, plus solar",
                          "electric immersion, plus solar, standard tariff",
                          "oil boiler/circulator, no cylinder thermostat, plus solar",
                          "electric immersion, plus solar, off-peak",
                          "electric heat pump, no cylinder thermostat",
                          "from secondary system, no cylinder thermostat, plus solar",
                          "electric immersion, off-peak, plus solar, no cylinder thermostat",
                          "gas range cooker, plus solar, no cylinder thermostat",
                          "heat pump, no cylinder thermostat",
                          "gas boiler/circulator, plus solar, flue gas heat recovery",
                          "heat pump, plus solar",
                          "community scheme, no cylinder thermostat, waste water heat recovery",
                          "electric instantaneous at point of use, flue gas heat recovery, waste water heat recovery",
                          "solid fuel boiler/circulator for water heating only, plus solar",
                          "community scheme, plus solar, no cylinder thermostat",
                          "electric immersion, standard tariff, plus solar, waste water heat recovery",
                          "electric heat pump for water heating only, no cylinder thermostat, plus solar")

# --- (a8) MAIN_FUEL: new Scottish fuel strings (verbatim) --------------------
# These keep their "gas: " / "solid fuel: " / "electric: " prefixes here; the
# prefixes and other wording are normalised later in merge_gb_domestic().
MAIN_FUEL <- c(MAIN_FUEL,
               "gas: bottled lpg",
               "gas: bulk lpg",
               "gas: biogas",
               "solid fuel: wood logs",
               "solid fuel: anthracite",
               "solid fuel: wood chips",
               "solid fuel: wood pellets (in bags, for secondary heating)",
               "solid fuel: wood pellets (bulk supply in bags, for main heating)",
               "solid fuel: dual fuel appliance (mineral and wood)",
               "electric: electric sold to grid",
               "electric: electric displaced from grid",
               "lpg subject to special condition 18",
               "lng",
               "biogas",
               "biogas (not community)",
               "biodiesel from vegetable oil only",
               "from heat network data (community)",
               "heat from boilers using biodiesel from any biomass source (community)",
               "heat from boilers that can use mineral oil or biodiesel (community)",
               "no heating/hot-water system or data is from a community network")


# ===========================================================================
# Full-England-&-Wales-run additions (2026-07-16)
# ===========================================================================
# From cleaning the whole 23.6M-cert E&W domestic dataset. Three kinds:
#  (b1) untranslatable Welsh / corrupt fragments -> NA (best translations are in
#       the translatewelsh() wrapper in functions_2026.R; what remains is either
#       truncated in the source or not confidently translatable);
#  (b2) mechanical fixes;
#  (b3) new English categories accepted verbatim.
# Compound MAINHEAT descriptions are handled automatically by validate_domestic()
# (decomposition), per the "keep full text" decision, so they are not listed.

# --- (b1) Welsh / junk fragments -> NA --------------------------------------
local({
  desc_cols <- c("FLOOR_DESCRIPTION", "WALLS_DESCRIPTION", "ROOF_DESCRIPTION",
                 "MAINHEAT_DESCRIPTION", "MAINHEATCONT_DESCRIPTION",
                 "HOTWATER_DESCRIPTION", "WINDOWS_DESCRIPTION", "MAIN_FUEL")
  # ASCII Welsh stems that only occur in leftover Welsh. English EPC vocabulary
  # never contains these.
  welsh <- paste(c("inswleiddio", "hadeiladwyd", "hadeiladu", "cymunedol",
                   "gynllun", "lenwi", "wresog", "gyfradd", "chysylltu",
                   "ddefnyddio", "cael ei", "rheolydd", "rheolaeth", "parthau",
                   "cadw llawer", "brif system", "haul", "tarddu", "carreg",
                   "ystafell", "ragdyb", "gyda", "fwyaf"), collapse = "|")
  junk <- c("l system, with external insulation", "co with external insulation",
            "description", "nan w/m2k", "heating system", "(ex1 3fs)")
  for (nm in desc_cols) {
    v <- certs[[nm]]
    # grepl("[^ -~]"): any non-ASCII char (accented Welsh a/o/w-circumflex,
    # superscript-2 in mangled units) - kept as an ASCII-safe pattern so this
    # file needs no non-ASCII literals for sys.source().
    v[!is.na(v) & (grepl(welsh, v) | grepl("[^ -~]", v) | v %in% junk)] <- NA
    certs[[nm]] <- v
  }
  assign("certs", certs, envir = .GlobalEnv)
})

# --- (b2) MAINHEAT: normalise non-canonical spellings INSIDE compounds -------
# The dictionary's exact-match td_ rules only normalise a whole value, not a
# system embedded in a compound. These substring rules normalise the same
# spellings wherever they occur, so validate_domestic()'s decomposition can
# then accept the compound. (No effect on the standalone canonical values.)
sub_mainheat_description("electricaire", "electric")
sub_mainheat_description("boilerand ", "boiler and ")   # "boiler&underfloor" (no spaces) -> "&"->"and"
sub_mainheat_description(" ,", ", ")                      # "heat pump ,radiators" -> "..., radiators"
# Re-apply the two underfloor normalisations from the dictionary: the fixes
# above (boilerand->boiler and, " ,"->", ") only run here, AFTER the dictionary,
# so the dictionary's "boiler and underfloor,"/", underfloor," rules never saw
# them. Re-running them here lets those compounds normalise and then decompose.
sub_mainheat_description("boiler and underfloor,", "boiler, underfloor heating,")
sub_mainheat_description(", underfloor,", ", underfloor heating,")
sub_mainheat_description("systems with radiators", "radiators")
sub_mainheat_description("heat pump fan coil units", "heat pump, fan coil units")
sub_mainheat_description("heat from boilers mains gas", "mains gas")
sub_mainheat_description("portable electric heating assumed for most rooms",
                         "portable electric heaters assumed for most rooms")
sub_mainheat_description("electric ceiling,", "electric ceiling heating,")
sub_mainheat_description("boiler, dual fuel (mineral and wood)",
                         "boiler, radiators, dual fuel (mineral and wood)")
# New single systems seen only in 2026, added so compounds containing them
# decompose (and so the standalone value validates).
MAINHEAT_DESCRIPTION <- c(MAINHEAT_DESCRIPTION,
                          "warm air",
                          "boiler, coal",
                          "underfloor heating, electric",
                          "ground source heat pump, mains gas",
                          "ground source heat pump, radiators, b30k",
                          "ground source heat pump, underfloor heating, b30k",
                          "solar assisted heat pump, radiators, electric",
                          "solar assisted heat pump, underfloor heating, pipes in screed above insulation, electric",
                          "exhaust source heat pump, radiators, electric",
                          "exhaust source heat pump, underfloor heating, radiators, pipes in screed above insulation, electric",
                          "exhaust air mev source heat pump, underfloor heating, pipes in insulated timber floor, electric",
                          "exhaust air mev source heat pump, underfloor heating, radiators, pipes in insulated timber floor, electric",
                          "mixed exhaust air source heat pump, radiators, electric",
                          "mixed exhaust air source heat pump, underfloor heating, pipes in screed above insulation, electric",
                          "mixed exhaust air source heat pump, underfloor heating, pipes in insulated timber floor, electric",
                          "mixed exhaust air source heat pump, underfloor heating, radiators, pipes in insulated timber floor, electric",
                          "community heat pump, underfloor heating",
                          "community scheme, underfloor heating, electric",
                          "community scheme, radiators, biomass",
                          "community scheme with chp, radiators, mains gas",
                          "boiler, underfloor heating, biogas",
                          "boiler, underfloor heating, heat pump",
                          "electric storage heaters, underfloor",
                          "boiler with radiators, underfloor heating, wood pellets",
                          "boiler with radiators, underfloor heating, b30k",
                          "air source heat pump, radiators and underfloor, mains gas")

# Genuinely-complex compounds that do not decompose into known single systems
# (odd/duplicated fragments) - accepted verbatim to keep the full text.
MAINHEAT_DESCRIPTION <- c(MAINHEAT_DESCRIPTION,
                          "heat pump, warm air, mains gas",
                          "boiler, radiators, community",
                          "boiler, radiators, mains gas, radiators, mains gas",
                          "community scheme, community scheme, biogas",
                          "community scheme, community scheme, underfloor heating, biomass",
                          "room heaters, radiators, wood pellets, room heaters, electric",
                          "electric underfloor heating, underfloor",
                          "boiler, radiators, electric underfloor heating",
                          "exhaust air mev source heat pump, radiators, electric",
                          "room heaters, underfloor heating, electric",
                          "boiler, radiators, oil, water source heat pump, underfloor heating, oil",
                          "electric underfloor heating, underfloor heating, room heaters, electric")

# --- (b2) MAINHEATCONT mechanical fixes -------------------------------------
local({
  v <- certs$MAINHEATCONT_DESCRIPTION
  v <- sub("^[0-9]{4} ", "", v)                              # strip leading code
  v[grepl("^undefined welsh description", v)] <- NA          # code-only, no text
  v[v == "llaw"] <- NA                                        # fragment ("by hand")
  certs$MAINHEATCONT_DESCRIPTION <- v
  assign("certs", certs, envir = .GlobalEnv)
})
td_MAINHEATCONT_DESCRIPTION("time and temperature zone control by device in database", "time and temperature zone control")
td_MAINHEATCONT_DESCRIPTION("flat rate charging, programmer a trvs", "flat rate charging, programmer and trvs")
MAINHEATCONT_DESCRIPTION <- c(MAINHEATCONT_DESCRIPTION,
                              "flat rate charging, no time or thermostatic control of room temperature",
                              "charging system linked to use of heating room thermostat and trvs")

# --- (b2) ROOF mechanical + new categories ----------------------------------
td_ROOF_DESCRIPTION("roof room(s)thatched", "roof room(s), thatched")
td_ROOF_DESCRIPTION("another premises above", "(another dwelling above)")
ROOF_DESCRIPTION <- c(ROOF_DESCRIPTION,
                      "roof room(s), loft insulation",
                      "5.88 w/m2k", "5.45 w/m2k", "43.73 w/m2k")

# --- (b3) WALLS new categories (basement / curtain wall, U-values) -----------
WALLS_DESCRIPTION <- c(WALLS_DESCRIPTION,
                       "with external insulation",
                       "basement wall, as built",
                       "basement wall, filled cavity",
                       "basement wall, filled cavity and external insulation",
                       "basement wall, with internal insulation",
                       "basement wall, with external insulation",
                       "curtain wall",
                       "curtain wall, filled cavity",
                       "curtain wall, with internal insulation",
                       "curtain wall, with external insulation",
                       "curtain wall, as built, insulated (assumed)",
                       "11.65 w/m2k", "5.18 w/m2k", "5.81 w/m2k", "5.88 w/m2k")

# --- (b3) MAIN_FUEL new categories ------------------------------------------
MAIN_FUEL <- c(MAIN_FUEL,
               "b30k",
               "solid fuel: coal",
               "solid fuel: manufactured smokeless fuel",
               "biodiesel from vegetable oil only (community)",
               "community heating schemes: heat from electric heat pump",
               "community heating schemes: heat from mains gas")

# --- (b3) HOTWATER new descriptions (verbatim) ------------------------------
HOTWATER_DESCRIPTION <- c(HOTWATER_DESCRIPTION,
                          "from second main heating system, plus solar",
                          "from second main heating system, plus solar, waste water heat recovery",
                          "from second main heating system, flue gas heat recovery",
                          "from second main heating system, flue gas heat recovery, waste water heat recovery",
                          "from second main heating system, waste water heat recovery",
                          "community scheme with chp, no cylinder thermostat",
                          "community scheme with chp, plus solar",
                          "community scheme, flue gas heat recovery",
                          "no hot water system present electric immersion assumed, plus solar",
                          "no hot water system present electric immersion assumed, waste water heat recovery",
                          "solid fuel range cooker, plus solar, no cylinder thermostat",
                          "no system present: electric immersion assumed, flue gas heat recovery",
                          "no system present: electric immersion assumed, waste water heat recovery",
                          "no system present: electric immersion assumed, plus solar, waste water heat recovery",
                          "no system present: assumed electric immersion electric",
                          "electric immersion, on-peak",
                          "electric immersion, off-peak, waste water heat recovery, no cylinder thermostat",
                          "electric immersion, off-peak, flue gas heat recovery",
                          "from hot-water only community scheme boilers, plus solar",
                          "from hot-water only community scheme boilers, flue gas heat recovery",
                          "from hot-water only community scheme boilers, waste water heat recovery",
                          "from hot-water only community scheme heat pump, plus solar",
                          "oil boiler/circulator, plus solar, no cylinder thermostat",
                          "oil boiler/circulator, waste water heat recovery",
                          "oil boiler/circulator, plus solar, waste water heat recovery",
                          "from main system, plus solar, flue gas heat recovery, waste water heat recovery",
                          "from main system, flue gas heat recovery, plus solar, waste water heat recovery",
                          "from main system, plus solar, waste water heat recovery, flue gas heat recovery",
                          "from main system, plus solar, no cylinder thermostat, waste water heat recovery",
                          "from main system, no cylinder thermostat, flue gas heat recovery, waste water heat recovery",
                          "from main system, no cylinder thermostat, flue gas heat recovery, plus solar",
                          "multi-point gas water heater (instantaneous serving several taps), plus solar",
                          "multi-point gas water heater (instantaneous serving several taps), flue gas heat recovery",
                          "room heaters, no cylinder thermostat",
                          "room heaters",
                          "gas multipoint, flue gas heat recovery",
                          "gas multipoint, waste water heat recovery",
                          "heat pump, electric",
                          "heat pump, waste water heat recovery",
                          "solid fuel boiler/circulator, no cylinder thermostat, plus solar",
                          "electric heat pump, waste water heat recovery",
                          "electric heat pump for water heating only, waste water heat recovery",
                          "electric heat pump for water heating only, flue gas heat recovery",
                          "electric heat pump for water heating only, no cylinder thermostat, waste water heat recovery",
                          "gas instantaneous at point of use, waste water heat recovery",
                          "gas boiler/circulator, waste water heat recovery",
                          "gas boiler/circulator, no cylinder thermostat, waste water heat recovery",
                          "hot water system")
