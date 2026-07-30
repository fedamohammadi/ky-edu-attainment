# =============================================================
# 19_pull_decennial_demographics.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL - COVARIATE #3b: 1990/2000 demographics
# Purpose : Pull county-level demographics from 1990 STF3 and 2000 SF3b
#           via NHGIS API. Compute median HH income, race, tenure,
#           poverty. Save to a single county-year file.
# Output  : data/raw/nhgis_demographics/  (downloaded raw)
#           data/cleaned/decennial_demographics_county_1990_2000.rds
# =============================================================


# =============================================================
# To check the table codes before pulling the data, run this. 

library(ipumsr)

# Check 1990 STF3 tables
meta_1990 <- get_metadata_nhgis(dataset = "1990_STF3")
meta_1990$data_tables %>%
  dplyr::filter(grepl("Race|Hispanic|Income|Poverty|Tenure",
                      description, ignore.case = TRUE)) %>%
  print(n = Inf)

# Check 2000 SF3b (county level)
meta_2000 <- get_metadata_nhgis(dataset = "2000_SF3b")
meta_2000$data_tables %>%
  dplyr::filter(grepl("Race|Hispanic|Income|Poverty|Tenure",
                      description, ignore.case = TRUE)) %>%
  print(n = Inf)
# =============================================================



# ----- 0. Packages -------------------------------------------------
pkgs <- c("ipumsr", "tidyverse", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(ipumsr)
library(tidyverse)
library(here)

raw_dir     <- here("data", "raw", "nhgis_demographics")
cleaned_dir <- here("data", "cleaned")
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

# ----- 1. Define the extract --------------------------------------
ext <- define_extract_agg(
  collection  = "nhgis",
  description = "County demographics 1990 STF3 + 2000 SF3b for long panel",
  datasets = list(
    ds_spec("1990_STF3",
            data_tables = c("NP8", "NP10", "NP80A", "NP117", "NH8"),
            geog_levels = "county"),
    ds_spec("2000_SF3b",
            data_tables = c("NP006A", "NP007A", "NP053A", "NP087B", "NH007A"),
            geog_levels = "county")
  ),
  data_format = "csv_header"
)

ext <- submit_extract(ext)
ext <- wait_for_extract(ext)

# ----- 2. Download and unzip --------------------------------------
zip_path <- download_extract(ext, download_dir = raw_dir, overwrite = TRUE)
ipums_list_files(zip_path)
unzip(zip_path, exdir = raw_dir, overwrite = TRUE)

cat("Files in", raw_dir, ":\n")
print(list.files(raw_dir))




ext <- define_extract_agg(
  collection  = "nhgis",
  description = "County demographics 1990 STF3 + 2000 SF3a for long panel",
  datasets = list(
    ds_spec("1990_STF3",
            data_tables = c("NP8", "NP10", "NP80A", "NP117", "NH8"),
            geog_levels = "county"),
    ds_spec("2000_SF3a",
            data_tables = c("NP004A", "NP005A", "NP052A", "NP086A", "NH005A"),
            geog_levels = "county")
  ),
  data_format = "csv_header"
)

ext <- submit_extract(ext)
ext <- wait_for_extract(ext)

zip_path <- download_extract(ext, download_dir = raw_dir, overwrite = TRUE)
unzip(zip_path, exdir = raw_dir, overwrite = TRUE)

cat("Files in", raw_dir, ":\n")
print(list.files(raw_dir))





files_in <- list.files(file.path(raw_dir, "nhgis0004_csv"),
                       pattern = "\\.csv$", full.names = TRUE)
cat("CSV files:\n")
print(basename(files_in))

# Peek at columns for each
for (f in files_in) {
  cat("\n=== ", basename(f), " ===\n")
  d <- readr::read_csv(f, n_max = 2, show_col_types = FALSE)
  cat("Columns:", paste(names(d), collapse = ", "), "\n")
}





# 1990 file
cb_1990 <- readr::read_lines(
  list.files(file.path(raw_dir, "nhgis0004_csv"),
             pattern = "1990.*codebook.*\\.txt$",
             full.names = TRUE, ignore.case = TRUE)
)
cat("=== 1990 codebook (variable descriptions) ===\n")
cat(cb_1990[grepl("^\\s+[A-Z0-9]+:", cb_1990) |
              grepl("^Table", cb_1990) |
              grepl("^Source code", cb_1990)],
    sep = "\n")

# 2000 file
cb_2000 <- readr::read_lines(
  list.files(file.path(raw_dir, "nhgis0004_csv"),
             pattern = "2000.*codebook.*\\.txt$",
             full.names = TRUE, ignore.case = TRUE)
)
cat("\n=== 2000 codebook (variable descriptions) ===\n")
cat(cb_2000[grepl("^\\s+[A-Z0-9]+:", cb_2000) |
              grepl("^Table", cb_2000) |
              grepl("^Source code", cb_2000)],
    sep = "\n")






cb_2000_full <- readr::read_lines(
  list.files(file.path(raw_dir, "nhgis0004_csv"),
             pattern = "2000.*codebook.*\\.txt$",
             full.names = TRUE, ignore.case = TRUE)
)
# Print sections that define GHE, GHF, GMX, GN3, F89 variables
idx <- grep("^\\s*(GHE|GHF|GMX|GN3|F89)[0-9]+:", cb_2000_full)
if (length(idx) > 0) {
  # Show ~20 lines around each match block to catch table headers
  for (i in seq_along(idx)) {
    if (i == 1) start <- max(1, idx[i] - 10) else start <- idx[i]
    end <- if (i < length(idx)) min(idx[i+1] - 1, idx[i] + 20) else min(length(cb_2000_full), idx[i] + 20)
    if (i == 1) cat(cb_2000_full[start:end], sep = "\n")
  }
}
# Simpler: just print full 2000 codebook body from "Data Dictionary" onward
dd_start <- grep("Data Dictionary", cb_2000_full)[1]
cat(cb_2000_full[dd_start:length(cb_2000_full)], sep = "\n")








# =============================================================
# Fix: read count columns as numeric explicitly
# Add: NP12 (Race by Hispanic Origin, 1990) for clean NH-alone race
# =============================================================

library(ipumsr)
library(tidyverse)
library(here)

raw_dir     <- here("data", "raw", "nhgis_demographics")
cleaned_dir <- here("data", "cleaned")

# ----- 1. Pull NP12 (Race by Hispanic Origin) for 1990 ------------
ext <- define_extract_agg(
  collection  = "nhgis",
  description = "1990 NP12 Race by Hispanic Origin",
  datasets = list(
    ds_spec("1990_STF3",
            data_tables = c("NP12"),
            geog_levels = "county")
  ),
  data_format = "csv_header"
)

ext <- submit_extract(ext)
ext <- wait_for_extract(ext)
zip_path <- download_extract(ext, download_dir = raw_dir, overwrite = TRUE)
unzip(zip_path, exdir = raw_dir, overwrite = TRUE)

cat("Files in", raw_dir, ":\n")
print(list.files(raw_dir, recursive = TRUE))





new_folder <- list.files(raw_dir, pattern = "nhgis0005", full.names = TRUE,
                         include.dirs = TRUE)
new_folder <- new_folder[dir.exists(new_folder)]
np12_file <- list.files(new_folder, pattern = "\\.csv$", full.names = TRUE)
d <- readr::read_csv(np12_file, n_max = 2, show_col_types = FALSE)
cat("Columns:", paste(names(d), collapse = ", "), "\n")

# Also show codebook
cb <- readr::read_lines(
  list.files(new_folder, pattern = "codebook.*\\.txt$", full.names = TRUE)
)
dd_start <- grep("Data Dictionary", cb)[1]
cat(cb[dd_start:length(cb)], sep = "\n")






















