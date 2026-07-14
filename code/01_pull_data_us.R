# =============================================================
# 01_pull_data_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Pull RAW ACS 5-year educational attainment (table B15003)
#           for every U.S. census tract (50 states + DC), 2012-2024.
#           This script ONLY pulls and verifies. No cleaning, no shares here.
# Source  : American Community Survey, 5-year estimates, table B15003.
# Output  : data/raw/acs_b15003_2012_2024_us_raw.rds
# Note    : Puerto Rico (FIPS 72) and other territories are excluded.
#           Runtime is roughly 30-90 minutes depending on API load.
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidycensus", "tidyverse")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidycensus)
library(tidyverse)

# ----- 1. Settings -------------------------------------------------
# 50 states + DC. Territories (PR=72, VI=78, GU=66, AS=60, MP=69) excluded
# because tract-level ACS is not consistently available for them.
state_list <- tidycensus::fips_codes %>%
  distinct(state_code) %>%
  filter(as.integer(state_code) <= 56) %>%
  pull(state_code)

years <- 2012:2024
vars  <- paste0("B15003_", sprintf("%03d", 1:25))

cat("States to pull :", length(state_list), "\n")
cat("Years to pull  :", length(years), "\n")
cat("State-year jobs:", length(state_list) * length(years), "\n\n")

# ----- 2. Pull each state-year and stack ---------------------------
# tidycensus's get_acs() at tract level requires a state argument in
# older years, so we loop states inside years. This is robust across
# all 13 years, at the cost of ~50x more API calls per year.
acs_list <- list()
t0 <- Sys.time()

for (yr in years) {
  message("=== Year ", yr, " (elapsed: ",
          format(round(Sys.time() - t0, 1)), ") ===")
  yr_list <- list()
  
  for (st in state_list) {
    d <- tryCatch(
      get_acs(
        geography = "tract",
        variables = vars,
        state     = st,
        year      = yr,
        survey    = "acs5",
        output    = "wide"
      ),
      error = function(e) {
        warning("Failed: state ", st, " year ", yr, ": ", e$message)
        NULL
      }
    )
    if (!is.null(d)) yr_list[[st]] <- d
  }
  
  d_yr <- bind_rows(yr_list)
  d_yr$year <- yr
  acs_list[[as.character(yr)]] <- d_yr
  
  message("  Year ", yr, " done: ", nrow(d_yr), " tracts")
}

acs_raw <- bind_rows(acs_list)

cat("\nTotal rows pulled:", nrow(acs_raw), "\n")
cat("Total elapsed    :", format(round(Sys.time() - t0, 1)), "\n\n")

# ----- 3. Adding-up check ------------------------------------------
# Lines _002 to _025 are mutually exclusive and must sum to the total
# (_001) in every tract, every year. If they don't, the pull is misaligned.
est_cats <- paste0("B15003_", sprintf("%03d", 2:25), "E")

check <- acs_raw %>%
  transmute(
    year,
    cat_sum = rowSums(across(all_of(est_cats)), na.rm = TRUE),
    total   = B15003_001E,
    diff    = cat_sum - total
  )

check_by_year <- check %>%
  group_by(year) %>%
  summarise(
    tracts       = n(),
    max_abs_diff = max(abs(diff), na.rm = TRUE),
    n_bad        = sum(abs(diff) > 0, na.rm = TRUE),
    .groups = "drop"
  )

cat("--- Adding-up check by year ---\n")
print(check_by_year, n = Inf)

if (max(check_by_year$max_abs_diff, na.rm = TRUE) > 0) {
  warning("ADDING-UP CHECK FAILED for at least one year. ",
          "Inspect rows where diff != 0 before trusting the data.")
} else {
  message("Adding-up check passed: categories sum to the total in every year.")
}

# ----- 4. Kentucky replication check -------------------------------
# The KY subset of this national file must match the existing KY file.
# Compare tract counts by year here; deeper comparison happens later.
ky_check <- acs_raw %>%
  filter(substr(GEOID, 1, 2) == "21") %>%
  group_by(year) %>%
  summarise(ky_tracts = n(), .groups = "drop")

cat("\n--- Kentucky tract counts by year ---\n")
print(ky_check, n = Inf)
cat("(These should match the KY-only pull row counts from 01_pull_data.R)\n")

# ----- 5. Save raw -------------------------------------------------
dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
saveRDS(acs_raw, "data/raw/acs_b15003_2012_2024_us_raw.rds")
message("Saved: data/raw/acs_b15003_2012_2024_us_raw.rds  (",
        nrow(acs_raw), " rows)")


