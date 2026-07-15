# =============================================================
# 10_county_rollup_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Roll the full 1990-2024 national tract panel up to county level.
#           County rate = sum the counts, then divide (population-weighted)
#           = the true county attainment rate. Resident-attainment side of
#           the eventual brain-drain comparison.
# Input   : data/cleaned/us_ed_panel_full_1990_2024.rds
# Output  : data/cleaned/us_ed_county_panel_1990_2024.rds
#           data/cleaned/us_ed_county_panel_1990_2024.dta
#           data/cleaned/us_county_baplus_growth.dta
#           output/tables/us_county_baplus_growth.csv
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here", "tidycensus")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)
library(tidycensus)

cleaned_dir <- here("data", "cleaned")
table_dir   <- here("output", "tables")
dir.create(table_dir, showWarnings = FALSE, recursive = TRUE)

# ----- 1. Load full tract panel ------------------------------------
panel <- readRDS(file.path(cleaned_dir, "us_ed_panel_full_1990_2024.rds"))

cat("Tract panel rows:", nrow(panel), "\n")
cat("Years:           ", paste(sort(unique(panel$year)), collapse = ", "), "\n\n")

# ----- 2. Roll tracts up to counties -------------------------------
# County FIPS = first 5 chars of the 11-digit tract GEOID
# (state 2 digits + county 3 digits).
county_panel <- panel %>%
  mutate(county_fips = substr(geoid, 1, 5),
         state_fips  = substr(geoid, 1, 2)) %>%
  group_by(county_fips, state_fips, year) %>%
  summarise(
    pop25plus      = sum(pop25plus,      na.rm = TRUE),
    ba_plus        = sum(ba_plus,        na.rm = TRUE),
    somecoll_assoc = sum(somecoll_assoc, na.rm = TRUE),
    hs_or_less     = sum(hs_or_less,     na.rm = TRUE),
    n_tracts       = n(),
    .groups = "drop"
  ) %>%
  mutate(
    pct_baplus     = if_else(pop25plus > 0, 100 * ba_plus        / pop25plus, NA_real_),
    pct_somecoll   = if_else(pop25plus > 0, 100 * somecoll_assoc / pop25plus, NA_real_),
    pct_hs_or_less = if_else(pop25plus > 0, 100 * hs_or_less     / pop25plus, NA_real_)
  )

cat("County-year rows:", nrow(county_panel), "\n")
cat("Unique counties: ", n_distinct(county_panel$county_fips), "\n")
cat("(Expected ~3,140 U.S. counties + county-equivalents)\n\n")

# ----- 3. Attach county and state names ----------------------------
# fips_codes ships with tidycensus, no API call needed.
county_names <- fips_codes %>%
  transmute(
    county_fips = paste0(state_code, county_code),
    county      = sub(" County$", "", county),
    state       = state_name,
    state_abb   = state
  )

county_panel <- county_panel %>%
  left_join(county_names, by = "county_fips") %>%
  relocate(county, state, state_abb, .after = county_fips)

# Verify all counties got names
n_unmatched <- sum(is.na(county_panel$county))
cat("Counties without name match:", n_unmatched, "\n\n")

saveRDS(county_panel,  file.path(cleaned_dir, "us_ed_county_panel_1990_2024.rds"))
write_dta(county_panel, file.path(cleaned_dir, "us_ed_county_panel_1990_2024.dta"))

# ----- 4. Wide summary: BA+ growth at benchmark years --------------
growth <- county_panel %>%
  filter(year %in% c(1990, 2000, 2012, 2024)) %>%
  select(county_fips, county, state, state_abb, state_fips, year, pct_baplus) %>%
  pivot_wider(names_from = year, values_from = pct_baplus, names_prefix = "ba_") %>%
  mutate(
    growth_1990_2024  = ba_2024 - ba_1990,        # total pp change, 34 years
    growth_per_decade = growth_1990_2024 / 3.4    # 34 yrs = 3.4 decades
  ) %>%
  arrange(desc(growth_1990_2024))

growth_clean <- growth %>% filter(!is.na(ba_1990), !is.na(ba_2024))

cat("\nBottom 10 (non-NA):\n")
print(tail(growth_clean %>%
             select(county, state_abb, ba_1990, ba_2024, growth_1990_2024), 10))

write_dta(growth, file.path(cleaned_dir, "us_county_baplus_growth.dta"))
write.csv(growth, file.path(table_dir, "us_county_baplus_growth.csv"),
          row.names = FALSE)

# ----- 5. Peek: fastest and slowest counties (national) ------------
cat("Top 10 U.S. counties by BA+ growth, 1990-2024:\n")
print(head(growth %>%
             select(county, state_abb, ba_1990, ba_2024, growth_1990_2024), 10))

cat("\nBottom 10:\n")
print(tail(growth %>%
             select(county, state_abb, ba_1990, ba_2024, growth_1990_2024), 10))

cat(sprintf("\nCounties: %d | mean county BA+ growth 1990-2024: %.1f pp\n",
            nrow(growth), mean(growth$growth_1990_2024, na.rm = TRUE)))

# ----- 6. Kentucky subset (replication) ----------------------------
ky_growth <- growth %>% filter(state_fips == "21") %>%
  arrange(desc(growth_1990_2024))

cat("\n--- Kentucky county replication ---\n")
cat("Top 8 KY counties by BA+ growth, 1990-2024:\n")
print(head(ky_growth %>%
             select(county, ba_1990, ba_2024, growth_1990_2024), 8))
cat("\nBottom 8 KY counties:\n")
print(tail(ky_growth %>%
             select(county, ba_1990, ba_2024, growth_1990_2024), 8))
cat(sprintf("\nKY counties: %d | mean KY county BA+ growth: %.1f pp\n",
            nrow(ky_growth), mean(ky_growth$growth_1990_2024, na.rm = TRUE)))

message("\nSaved:")
message("  ", file.path(cleaned_dir, "us_ed_county_panel_1990_2024.rds"))
message("  ", file.path(cleaned_dir, "us_ed_county_panel_1990_2024.dta"))
message("  ", file.path(cleaned_dir, "us_county_baplus_growth.dta"))
message("  ", file.path(table_dir,   "us_county_baplus_growth.csv"))



