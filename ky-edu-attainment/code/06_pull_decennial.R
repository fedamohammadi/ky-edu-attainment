# 06_pull_decennial.R ----------------------------------------------------------
# Pull 1990 (STF3) and 2000 (SF3) educational attainment from NHGIS, at the
# BLOCK GROUP PART level, for Kentucky. This is the decennial baseline for the
# 1990-2024 panel (Phase 3).
#
# Why block group part: education is long-form/sample data, which does not exist
# at the block level. The block group part (BGP) is the smallest unit it exists
# at, and it is the source level of the bgp..._tr2010 crosswalks you downloaded.
# The NHGIS data and the crosswalk both carry GISJOIN, which is your join key
# (BGP crosswalks have NO GEOID column, so GISJOIN is the only key available).
# -------------------------------------------------------------------------------

library(ipumsr)
library(dplyr)
library(here)

# NHGIS reads your key from .Renviron automatically (env var IPUMS_API_KEY).
# If it is not set yet, run once: set_ipums_api_key("YOUR_KEY", save = TRUE)
# then restart R. Do NOT paste the key into this script.

# ===============================================================================
# STEP 1 - GET THE REAL CODES FROM METADATA (run this block ALONE, first).
# Read the printed output, then copy the four values into Step 2.
# (If get_metadata_nhgis() errors as an unknown function, your ipumsr is newer:
#  use get_metadata("nhgis", dataset = "1990_STF3") instead.)
# ===============================================================================

meta_1990 <- get_metadata_nhgis(dataset = "1990_STF3")
# Education table code -> read it from the `name` column:
meta_1990$data_tables |> filter(grepl("Educat", description, ignore.case = TRUE)) |> print(n = Inf)
# Block-group-part geog level -> find the row whose description says "Block Group
# Part" and copy its exact `name` (looks like blck_grp_###):
meta_1990$geog_levels |> print(n = Inf)

meta_2000 <- get_metadata_nhgis(dataset = "2000_SF3b")
meta_2000$data_tables |> filter(grepl("Educat", description, ignore.case = TRUE)) |> print(n = Inf)
meta_2000$geog_levels |> print(n = Inf)

# ===============================================================================
# STEP 2 - DEFINE & SUBMIT. Fill these four in from Step 1's output first.
# ===============================================================================

tab_1990 <- "NP57"             # 1990 "Educational Attainment", persons 25+ (7 vars). Confirmed.
geo_1990 <- "blck_grp_598_101" # 1990 block-group-part level (long hierarchy, matches bgp1990gj)
tab_2000 <- "NP037C"           # 2000 "Pop 25+ by Sex by Educational Attainment" (32 vars)
geo_2000 <- "blck_grp_090"     # 2000 block-group-part level (matches bgp2000gj)

ext <- define_extract_agg(
  collection  = "nhgis",
  description = "KY 1990 STF3 + 2000 SF3 educational attainment, BGP level (decennial baseline)",
  datasets = list(
    ds_spec("1990_STF3", data_tables = tab_1990, geog_levels = geo_1990),
    ds_spec("2000_SF3b", data_tables = tab_2000, geog_levels = geo_2000)
  ),
  geographic_extents = "210",   # NHGIS state code for Kentucky = FIPS 21 + "0". NOT "21".
  data_format = "csv_header"
)

ext <- submit_extract(ext)
ext <- wait_for_extract(ext)   # blocks until NHGIS finishes building it

# ===============================================================================
# STEP 3 - DOWNLOAD INTO data/raw/ AND READ, KEEPING GISJOIN
# ===============================================================================

raw_dir <- here("data", "raw")   # same folder as nhgis_bgp1990_tr2010_21.csv etc.

# Download the NHGIS zip straight into data/raw.
zip_path <- download_extract(ext, download_dir = raw_dir, overwrite = TRUE)

# See what's inside, then unzip the raw CSVs + codebook into data/raw so they
# sit next to your crosswalk files. (read_nhgis can read the zip directly, so
# this unzip is just to keep the raw inputs visible alongside everything else.)
ipums_list_files(zip_path)
unzip(zip_path, exdir = raw_dir, overwrite = TRUE)

# Read each layer from the zip. Adjust the matched substrings to what
# ipums_list_files printed above.
# (If your ipumsr is older and file_select errors, use data_layer instead.)
ed_1990 <- read_ipums_agg(zip_path, file_select = matches("1990_blck_grp"))
ed_2000 <- read_ipums_agg(zip_path, file_select = matches("2000_blck_grp"))

# GISJOIN is the join key to the crosswalk. Fail loudly if it is missing.
stopifnot("GISJOIN" %in% names(ed_1990),
          "GISJOIN" %in% names(ed_2000))

# Quick look: confirm the attainment columns are present and counts look sane.
glimpse(ed_1990)
glimpse(ed_2000)




