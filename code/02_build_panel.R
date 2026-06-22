# =============================================================
# 02_build_panel.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
# Purpose : Turn the raw B15003 pull into a clean tract-year panel with the
#           attainment measures defined in docs/codebook.md, then export it
#           for both R (.rds) and Stata (.dta).
# Input   : data/raw/acs_b15003_2012_2024_raw.rds   (from 01_pull_data.R)
# Output  : data/cleaned/ky_ed_panel_2012_2024.rds
#           data/cleaned/ky_ed_panel_2012_2024.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)

# ----- 1. Loading raw -------------------------------------------------
acs_raw <- readRDS("data/raw/acs_b15003_2012_2024_raw.rds")

# ----- 2. Build measures (definitions live in docs/codebook.md) ----
# BA+            = bachelor's + master's + professional + doctorate (_022..._025)
# Some coll/assoc = some college <1yr + some college 1+ no degree + associate (_019..._021)
# HS or less     = lines _002 ... _018
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
    pct_hs_or_less = if_else(pop25plus > 0, 100 * hs_or_less      / pop25plus, NA_real_),
    
    # Which boundary vintage each year sits on. Years <= 2019 are 2010 tracts;
    # 2020+ are 2020 tracts. Carry this flag so cross-vintage tracts are never
    # silently compared one-to-one before harmonization (Phase 2).
    boundary_vintage = if_else(year <= 2019, "2010", "2020")
  ) %>%
  transmute(
    geoid          = GEOID,
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

# ----- 3. Sanity check: does this look like Natalie's Image 1? -----
# Unweighted mean tract share by year. BA+ mean should drift up from ~11 to ~14
# and some college/associate should sit higher and flatter. If these are wildly
# off, stop and investigate before exporting.
sanity <- panel %>%
  group_by(year) %>%
  summarise(
    mean_pct_baplus   = mean(pct_baplus,   na.rm = TRUE),
    mean_pct_somecoll = mean(pct_somecoll, na.rm = TRUE),
    n_zero_pop_tracts = sum(pop25plus == 0, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n--- Sanity check: mean tract shares by year ---\n")
print(sanity, n = Inf)

# ----- 4. Label variables (so the .dta is self-documenting in Stata) ----
labs <- c(
  geoid            = "Census tract GEOID (11-digit: state+county+tract)",
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

# ----- 5. Save -----------------------------------------------------
dir.create("data/cleaned", showWarnings = FALSE, recursive = TRUE)
saveRDS(panel,    "data/cleaned/ky_ed_panel_2012_2024.rds")
write_dta(panel,  "data/cleaned/ky_ed_panel_2012_2024.dta")

message("Saved clean panel: ", nrow(panel), " tract-year rows.")
message("  -> data/cleaned/ky_ed_panel_2012_2024.rds  (for R / mapping)")
message("  -> data/cleaned/ky_ed_panel_2012_2024.dta  (for Stata / analysis)")



