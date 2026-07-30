# =============================================================
# 18_pull_acs_demographics.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL - COVARIATE #3a: ACS demographics
# Purpose : Pull county-level demographics from ACS 5-year (2012-2024).
#           Variables: median HH income, race/ethnicity, housing
#           tenure, poverty rate.
# Note    : County-level for now. Can be re-pulled at tract level if
#           the tract panel needs these too.
# Output  : data/cleaned/acs_demographics_county_2012_2024.rds
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidycensus", "tidyverse", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidycensus)
library(tidyverse)
library(here)

cleaned_dir <- here("data", "cleaned")

# ----- 1. Variable specifications ----------------------------------
# For each table we pull, we compute the shares/values we need.
#
# B19013_001: Median household income (dollars)
# B03002:     Hispanic origin by race
#   _001: Total
#   _003: NH White alone
#   _004: NH Black alone
#   _006: NH Asian alone
#   _012: Hispanic or Latino
# B25003:     Tenure
#   _001: Total occupied HU
#   _002: Owner-occupied
#   _003: Renter-occupied
# B17001:     Poverty status
#   _001: Total population for whom poverty status determined
#   _002: Below poverty level

vars <- c(
  "B19013_001",           # median HH income
  "B03002_001",           # total pop
  "B03002_003",           # NH white
  "B03002_004",           # NH Black
  "B03002_006",           # NH Asian
  "B03002_012",           # Hispanic
  "B25003_001",           # total occupied HU
  "B25003_002",           # owner-occupied
  "B25003_003",           # renter-occupied
  "B17001_001",           # poverty universe
  "B17001_002"            # below poverty
)

years <- 2012:2024

# ----- 2. Pull loop -----------------------------------------------
cat("Pulling ACS 5-year county demographics, 2012-2024...\n")
t0 <- Sys.time()

acs_list <- list()
for (yr in years) {
  message("=== Year ", yr, " (elapsed: ",
          format(round(Sys.time() - t0, 1)), ") ===")
  
  d <- tryCatch(
    get_acs(
      geography = "county",
      variables = vars,
      year      = yr,
      survey    = "acs5",
      output    = "wide"
    ),
    error = function(e) {
      warning("Failed for year ", yr, ": ", e$message)
      NULL
    }
  )
  
  if (!is.null(d)) {
    d$year <- yr
    acs_list[[as.character(yr)]] <- d
    message("  ", yr, " done: ", nrow(d), " counties")
  }
}

acs_raw <- bind_rows(acs_list)
cat("\nTotal rows pulled:", nrow(acs_raw), "\n")
cat("Total elapsed    :", format(round(Sys.time() - t0, 1)), "\n\n")

# ----- 3. Compute the covariates ----------------------------------
acs_demog <- acs_raw %>%
  transmute(
    county_fips  = GEOID,
    year,
    median_hh_income = B19013_001E,
    pop_total        = B03002_001E,
    pct_white        = if_else(B03002_001E > 0,
                               100 * B03002_003E / B03002_001E, NA_real_),
    pct_black        = if_else(B03002_001E > 0,
                               100 * B03002_004E / B03002_001E, NA_real_),
    pct_asian        = if_else(B03002_001E > 0,
                               100 * B03002_006E / B03002_001E, NA_real_),
    pct_hispanic     = if_else(B03002_001E > 0,
                               100 * B03002_012E / B03002_001E, NA_real_),
    total_hu         = B25003_001E,
    pct_owner        = if_else(B25003_001E > 0,
                               100 * B25003_002E / B25003_001E, NA_real_),
    pct_renter       = if_else(B25003_001E > 0,
                               100 * B25003_003E / B25003_001E, NA_real_),
    poverty_universe = B17001_001E,
    pct_poverty      = if_else(B17001_001E > 0,
                               100 * B17001_002E / B17001_001E, NA_real_)
  ) %>%
  arrange(county_fips, year)

# ----- 4. Sanity checks --------------------------------------------
cat("--- Counties per year ---\n")
acs_demog %>%
  group_by(year) %>%
  summarise(
    n_counties = n(),
    mean_income = mean(median_hh_income, na.rm = TRUE),
    mean_pct_white = mean(pct_white, na.rm = TRUE),
    mean_pct_owner = mean(pct_owner, na.rm = TRUE),
    mean_pct_poverty = mean(pct_poverty, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print(n = Inf)

# Benchmark: 2023 national medians (approximate published values):
#   median HH income: ~$78,000
#   % white non-Hispanic: ~58%
#   % Black non-Hispanic: ~12%
#   % Hispanic: ~19%
#   % owner-occupied HU: ~65%
#   % below poverty: ~11%
cat("\n--- 2023 population-weighted national totals ---\n")
acs_demog %>%
  filter(year == 2023) %>%
  summarise(
    natl_median_income = weighted.mean(median_hh_income, pop_total,
                                       na.rm = TRUE),
    natl_pct_white     = weighted.mean(pct_white, pop_total, na.rm = TRUE),
    natl_pct_black     = weighted.mean(pct_black, pop_total, na.rm = TRUE),
    natl_pct_hispanic  = weighted.mean(pct_hispanic, pop_total, na.rm = TRUE),
    natl_pct_owner     = weighted.mean(pct_owner, total_hu, na.rm = TRUE),
    natl_pct_poverty   = weighted.mean(pct_poverty, poverty_universe,
                                       na.rm = TRUE)
  ) %>%
  print()

# ----- 5. Save ----------------------------------------------------
saveRDS(acs_demog,
        file.path(cleaned_dir, "acs_demographics_county_2012_2024.rds"))
message("\nSaved: ",
        file.path(cleaned_dir, "acs_demographics_county_2012_2024.rds"))



