# =============================================================
# 21_merge_demographics.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL - COVARIATE #3 (final merge)
# Purpose : Stack the 1990/2000 decennial demographics with the
#           ACS 2012-2024 demographics into one continuous file,
#           then merge onto the long county panel (which already
#           has attainment + RUCC + LAUS).
# Inputs  : data/cleaned/decennial_demographics_county_1990_2000.rds
#           data/cleaned/acs_demographics_county_2012_2024.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_rucc_laus.rds
# Output  : data/cleaned/demographics_county_1990_2024.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_full.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_full.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)

cleaned_dir <- here("data", "cleaned")

# ----- 1. Load the two demographic files ---------------------------
decennial <- readRDS(file.path(cleaned_dir,
                               "decennial_demographics_county_1990_2000.rds"))
acs       <- readRDS(file.path(cleaned_dir,
                               "acs_demographics_county_2012_2024.rds"))

cat("Decennial (1990, 2000): ", nrow(decennial), " rows\n", sep = "")
cat("ACS (2012-2024):        ", nrow(acs),       " rows\n\n", sep = "")

# ----- 2. Align schemas --------------------------------------------
# The two files should already share the same columns. Check first.
common <- intersect(names(decennial), names(acs))
only_dec <- setdiff(names(decennial), names(acs))
only_acs <- setdiff(names(acs), names(decennial))

cat("Columns in both files:   ", length(common), "\n")
cat("Columns only in decennial:", length(only_dec),
    if (length(only_dec) > 0) paste0(" (", paste(only_dec, collapse = ", "), ")") else "", "\n")
cat("Columns only in ACS:     ", length(only_acs),
    if (length(only_acs) > 0) paste0(" (", paste(only_acs, collapse = ", "), ")") else "", "\n\n")

# Keep only the shared columns from each side, so bind_rows is clean.
demog <- bind_rows(
  decennial %>% select(all_of(common)),
  acs       %>% select(all_of(common))
) %>%
  arrange(county_fips, year)

cat("Stacked demographic panel: ", nrow(demog), " rows, ",
    n_distinct(demog$year), " years\n", sep = "")

# Save the standalone demographic panel for future use.
saveRDS(demog,
        file.path(cleaned_dir, "demographics_county_1990_2024.rds"))

# ----- 3. Load the long panel and merge ----------------------------
panel <- readRDS(file.path(cleaned_dir,
                           "us_ed_county_panel_long_1940_2024_rucc_laus.rds"))

cat("\nLong panel before merge: ", nrow(panel),
    " rows, ", n_distinct(panel$year), " years\n", sep = "")

# demog has state_fips too — drop it from the join partner so it
# doesn't create a state_fips.x / state_fips.y collision.
panel_full <- panel %>%
  left_join(demog, by = c("county_fips", "year"))

cat("Long panel after merge:  ", nrow(panel_full),
    " rows (should be unchanged)\n\n", sep = "")

# ----- 4. Match quality check --------------------------------------
# We only expect demographic coverage for 1990, 2000, and 2012-2024.
# Pre-1990 and 2001-2011 years should have NA on demographic columns.
cat("--- Demographic coverage by year ---\n")
panel_full %>%
  group_by(year) %>%
  summarise(
    n_counties      = n(),
    n_with_income   = sum(!is.na(median_hh_income)),
    n_with_race     = sum(!is.na(pct_white)),
    n_with_poverty  = sum(!is.na(pct_poverty)),
    n_with_tenure   = sum(!is.na(pct_owner)),
    .groups = "drop"
  ) %>%
  print(n = Inf)

# ----- 5. Sanity: cross-covariate summary --------------------------
# Population-weighted national demographic values by year.
cat("\n--- Weighted national demographics, selected years ---\n")
panel_full %>%
  filter(year %in% c(1990, 2000, 2012, 2019, 2024), !is.na(pop_total)) %>%
  group_by(year) %>%
  summarise(
    median_income   = weighted.mean(median_hh_income, pop_total, na.rm = TRUE),
    pct_white       = weighted.mean(pct_white,        pop_total, na.rm = TRUE),
    pct_hispanic    = weighted.mean(pct_hispanic,     pop_total, na.rm = TRUE),
    pct_owner       = weighted.mean(pct_owner,        total_hu,   na.rm = TRUE),
    pct_poverty     = weighted.mean(pct_poverty,      poverty_universe, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

# ----- 6. Cross-check: BA+ vs demographics -------------------------
# Quick descriptive: BA+ share by poverty quartile in 2024.
# Confirms the covariates behave sensibly relative to attainment.
cat("\n--- 2024: BA+ share by poverty quartile ---\n")
panel_full %>%
  filter(year == 2024, !is.na(pct_poverty), !is.na(pct_baplus)) %>%
  mutate(pov_quartile = ntile(pct_poverty, 4)) %>%
  group_by(pov_quartile) %>%
  summarise(
    mean_poverty = mean(pct_poverty),
    mean_baplus  = mean(pct_baplus),
    n_counties   = n(),
    .groups = "drop"
  ) %>%
  print()

# ----- 7. Save -----------------------------------------------------
saveRDS(panel_full,
        file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_full.rds"))
write_dta(panel_full,
          file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_full.dta"))

message("\nSaved:")
message("  ", file.path(cleaned_dir, "demographics_county_1990_2024.rds"))
message("  ", file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_full.rds"))
message("  ", file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_full.dta"))






