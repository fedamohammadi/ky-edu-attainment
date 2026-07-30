# =============================================================
# 20_parse_decennial_demographics.R  (v2 — final)
# Purpose : Parse 1990 STF3 and 2000 SF3a county demographics.
#           Uses NP12 for 1990 to get non-Hispanic race categories,
#           matching the ACS-era measurement.
# Inputs  : data/raw/nhgis_demographics/nhgis0004_csv/*.csv
#           data/raw/nhgis_demographics/nhgis0005_csv/*.csv (NP12)
# Output  : data/cleaned/decennial_demographics_county_1990_2000.rds
# =============================================================

library(tidyverse)
library(here)

raw_dir     <- here("data", "raw", "nhgis_demographics")
cleaned_dir <- here("data", "cleaned")

# ----- FIPS helper -------------------------------------------------
make_fips <- function(df) {
  df %>%
    mutate(
      state_fips = if_else(nchar(as.character(STATEA)) == 3,
                           str_sub(as.character(STATEA), 1, 2),
                           str_pad(as.character(STATEA), 2, pad = "0")),
      cty_code   = if_else(nchar(as.character(COUNTYA)) == 4,
                           str_sub(as.character(COUNTYA), 1, 3),
                           str_pad(as.character(COUNTYA), 3, pad = "0")),
      county_fips = paste0(state_fips, cty_code)
    ) %>%
    select(-cty_code)
}

# ----- 1. 1990 STF3 (income, poverty, tenure) ---------------------
d90 <- read_csv(file.path(raw_dir, "nhgis0004_csv",
                          "nhgis0004_ds123_1990_county.csv"),
                show_col_types = FALSE) %>%
  filter(YEAR == "1990") %>%   # drop descriptive row
  make_fips() %>%
  mutate(across(c(starts_with("E4S"), starts_with("E07"),
                  starts_with("EZ2"), starts_with("E4U"),
                  starts_with("E0I")),
                as.numeric))

pov_below_cols <- paste0("E070", sprintf("%02d",
                                         c(2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24)))
pov_all_cols   <- paste0("E070", sprintf("%02d", 1:24))

demog_1990_base <- d90 %>%
  transmute(
    county_fips,
    state_fips,
    year = 1990L,
    median_hh_income = E4U001,
    tenure_total  = EZ2001 + EZ2002,
    owner_occ     = EZ2001,
    renter_occ    = EZ2002,
    pov_universe  = rowSums(across(all_of(pov_all_cols)),   na.rm = TRUE),
    pov_below     = rowSums(across(all_of(pov_below_cols)), na.rm = TRUE)
  )

# ----- 2. 1990 NP12 (race by Hispanic origin) ---------------------
# E1A001-E1A005: Not Hispanic (White, Black, AmInd, Asian/PI, Other)
# E1A006-E1A010: Hispanic     (White, Black, AmInd, Asian/PI, Other)
d90_race <- read_csv(file.path(raw_dir, "nhgis0005_csv",
                               "nhgis0005_ds123_1990_county.csv"),
                     show_col_types = FALSE) %>%
  filter(YEAR == "1990") %>%
  make_fips() %>%
  mutate(across(starts_with("E1A"), as.numeric)) %>%
  transmute(
    county_fips,
    pop_total  = E1A001 + E1A002 + E1A003 + E1A004 + E1A005 +
      E1A006 + E1A007 + E1A008 + E1A009 + E1A010,
    nh_white   = E1A001,
    nh_black   = E1A002,
    nh_amind   = E1A003,
    nh_asianpi = E1A004,
    nh_other   = E1A005,
    hispanic   = E1A006 + E1A007 + E1A008 + E1A009 + E1A010
  )

demog_1990 <- demog_1990_base %>%
  left_join(d90_race, by = "county_fips")

# ----- 3. 2000 SF3a -----------------------------------------------
d00 <- read_csv(file.path(raw_dir, "nhgis0004_csv",
                          "nhgis0004_ds151_2000_county.csv"),
                show_col_types = FALSE) %>%
  filter(YEAR == "2000") %>%
  make_fips() %>%
  mutate(across(c(starts_with("GH"),  starts_with("GMX"),
                  starts_with("GN3"), starts_with("F89")),
                as.numeric))

demog_2000 <- d00 %>%
  transmute(
    county_fips,
    state_fips,
    year          = 2000L,
    pop_total     = GHE001,
    nh_white      = GMX001 + GMX009,
    nh_black      = GMX002 + GMX010,
    nh_amind      = GMX003 + GMX011,
    nh_asianpi    = GMX004 + GMX012 + GMX005 + GMX013,
    nh_other      = GMX006 + GMX014 + GMX007 + GMX015,
    hispanic      = GHF002,
    median_hh_income = GN3001,
    tenure_total  = F89001 + F89002,
    owner_occ     = F89001,
    renter_occ    = F89002,
    pov_universe  = GMX001 + GMX002 + GMX003 + GMX004 + GMX005 + GMX006 +
      GMX007 + GMX008 + GMX009 + GMX010 + GMX011 + GMX012 +
      GMX013 + GMX014 + GMX015 + GMX016,
    pov_below     = GMX009 + GMX010 + GMX011 + GMX012 +
      GMX013 + GMX014 + GMX015 + GMX016
  )

# ----- 4. Stack, compute shares -----------------------------------
demog <- bind_rows(demog_1990, demog_2000) %>%
  mutate(
    pct_white    = if_else(pop_total > 0, 100 * nh_white   / pop_total, NA_real_),
    pct_black    = if_else(pop_total > 0, 100 * nh_black   / pop_total, NA_real_),
    pct_asian    = if_else(pop_total > 0, 100 * nh_asianpi / pop_total, NA_real_),
    pct_hispanic = if_else(pop_total > 0, 100 * hispanic   / pop_total, NA_real_),
    pct_owner    = if_else(tenure_total > 0, 100 * owner_occ  / tenure_total, NA_real_),
    pct_renter   = if_else(tenure_total > 0, 100 * renter_occ / tenure_total, NA_real_),
    pct_poverty  = if_else(pov_universe > 0, 100 * pov_below   / pov_universe, NA_real_)
  ) %>%
  select(county_fips, state_fips, year,
         median_hh_income, pop_total,
         pct_white, pct_black, pct_asian, pct_hispanic,
         total_hu = tenure_total,
         pct_owner, pct_renter,
         poverty_universe = pov_universe, pct_poverty) %>%
  arrange(county_fips, year)

# ----- 5. Sanity ---------------------------------------------------
cat("--- Counties per year ---\n")
demog %>%
  group_by(year) %>%
  summarise(n_counties = n(), .groups = "drop") %>%
  print()

cat("\n--- Population-weighted national totals ---\n")
demog %>%
  group_by(year) %>%
  summarise(
    natl_median_income = weighted.mean(median_hh_income, pop_total, na.rm = TRUE),
    natl_pct_white     = weighted.mean(pct_white,    pop_total, na.rm = TRUE),
    natl_pct_black     = weighted.mean(pct_black,    pop_total, na.rm = TRUE),
    natl_pct_hispanic  = weighted.mean(pct_hispanic, pop_total, na.rm = TRUE),
    natl_pct_owner     = weighted.mean(pct_owner,    total_hu,   na.rm = TRUE),
    natl_pct_poverty   = weighted.mean(pct_poverty,  poverty_universe, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

# ----- 6. Save ----------------------------------------------------
saveRDS(demog,
        file.path(cleaned_dir, "decennial_demographics_county_1990_2000.rds"))
message("Saved: ",
        file.path(cleaned_dir, "decennial_demographics_county_1990_2000.rds"))


