# =============================================================
# 02_build_panel_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Turn the raw national B15003 pull into a clean tract-year panel
#           with the attainment measures defined in docs/codebook.md, then
#           export it for both R (.rds) and Stata (.dta).
# Input   : data/raw/acs_b15003_2012_2024_us_raw.rds  (from 01_pull_data_us.R)
# Output  : data/cleaned/us_ed_panel_2012_2024.rds
#           data/cleaned/us_ed_panel_2012_2024.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)

# ----- 1. Load raw -------------------------------------------------
acs_raw <- readRDS(here("data", "raw", "acs_b15003_2012_2024_us_raw.rds"))

cat("Raw rows:", nrow(acs_raw), "\n")
cat("Years:   ", paste(sort(unique(acs_raw$year)), collapse = ", "), "\n\n")

# ----- 2. Build measures (definitions live in docs/codebook.md) ----
# BA+             = bachelor's + master's + professional + doctorate (_022..._025)
# Some coll/assoc = some college <1yr + some college 1+ no degree + associate (_019..._021)
# HS or less      = lines _002 ... _018
# Shares are in PERCENT. A zero-population tract gets a MISSING share, not 0/0.
hs_cols <- paste0("B15003_", sprintf("%03d", 2:18), "E")

panel <- acs_raw %>%
  mutate(
    pop25plus      = B15003_001E,
    ba_plus        = B15003_022E + B15003_023E + B15003_024E + B15003_025E,
    somecoll_assoc = B15003_019E + B15003_020E + B15003_021E,
    hs_or_less     = rowSums(across(all_of(hs_cols)), na.rm = TRUE),
    
    pct_baplus     = if_else(pop25plus > 0, 100 * ba_plus        / pop25plus, NA_real_),
    pct_somecoll   = if_else(pop25plus > 0, 100 * somecoll_assoc / pop25plus, NA_real_),
    pct_hs_or_less = if_else(pop25plus > 0, 100 * hs_or_less     / pop25plus, NA_real_),
    
    # Which boundary vintage each year sits on. Years <= 2019 are 2010 tracts;
    # 2020+ are 2020 tracts. Carry this flag so cross-vintage tracts are never
    # silently compared one-to-one before harmonization.
    boundary_vintage = if_else(year <= 2019, "2010", "2020"),
    
    # State FIPS from first 2 chars of GEOID. Useful for state-level filters
    # and later joins to state-level covariates (RUCC, higher-ed policy, etc.).
    state_fips = substr(GEOID, 1, 2)
  ) %>%
  transmute(
    geoid          = GEOID,
    state_fips,
    tract_name     = NAME,
    year,
    boundary_vintage,
    pop25plus,
    ba_plus,
    somecoll_assoc,
    hs_or_less,
    pct_baplus,
    pct_somecoll,
    pct_hs_or_less
  ) %>%
  arrange(geoid, year)

# ----- 3. National sanity check ------------------------------------
# Population-weighted BA+ share should match published national ACS totals.
# 2012: ~28.5%, 2018: ~31.5%, 2023: ~35.7%. If wildly off, stop.
sanity <- panel %>%
  group_by(year) %>%
  summarise(
    n_tracts          = n(),
    n_zero_pop        = sum(pop25plus == 0, na.rm = TRUE),
    mean_tract_baplus = mean(pct_baplus, na.rm = TRUE),
    popwtd_baplus     = 100 * sum(ba_plus, na.rm = TRUE) /
      sum(pop25plus, na.rm = TRUE),
    .groups = "drop"
  )

cat("--- National sanity check by year ---\n")
print(sanity, n = Inf)
cat("Population-weighted BA+ should track published ACS totals:\n")
cat("  2012 ~28.5%, 2018 ~31.5%, 2023 ~35.7%\n\n")

# ----- 4. Kentucky replication check -------------------------------
# The KY subset should match your existing KY panel numbers.
ky_check <- panel %>%
  filter(state_fips == "21") %>%
  group_by(year) %>%
  summarise(
    ky_tracts         = n(),
    ky_mean_baplus    = mean(pct_baplus, na.rm = TRUE),
    ky_popwtd_baplus  = 100 * sum(ba_plus, na.rm = TRUE) /
      sum(pop25plus, na.rm = TRUE),
    .groups = "drop"
  )

cat("--- Kentucky replication check ---\n")
print(ky_check, n = Inf)
cat("Compare against ky_ed_panel_2012_2024.rds numbers.\n\n")

# ----- 5. Label variables ------------------------------------------
labs <- c(
  geoid            = "Census tract GEOID (11-digit: state+county+tract)",
  state_fips       = "State FIPS code (2-digit)",
  tract_name       = "Census tract name",
  year             = "ACS 5-year estimate end year",
  boundary_vintage = "Tract boundary vintage (2010 or 2020)",
  pop25plus        = "Population 25 years and over (denominator)",
  ba_plus          = "Count: bachelor's degree or higher",
  somecoll_assoc   = "Count: some college or associate's degree",
  hs_or_less       = "Count: high school diploma or less",
  pct_baplus       = "Share with BA or higher (%)",
  pct_somecoll     = "Share with some college / associate (%)",
  pct_hs_or_less   = "Share with HS or less (%)"
)
for (v in names(labs)) attr(panel[[v]], "label") <- labs[[v]]

# ----- 6. Save -----------------------------------------------------
dir.create(here("data", "cleaned"), showWarnings = FALSE, recursive = TRUE)
saveRDS(panel,   here("data", "cleaned", "us_ed_panel_2012_2024.rds"))
write_dta(panel, here("data", "cleaned", "us_ed_panel_2012_2024.dta"))

message("Saved clean panel: ", nrow(panel), " tract-year rows.")
message("  -> data/cleaned/us_ed_panel_2012_2024.rds  (for R / mapping)")
message("  -> data/cleaned/us_ed_panel_2012_2024.dta  (for Stata / analysis)")


