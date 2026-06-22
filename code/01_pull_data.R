# =============================================================
# 01_pull_data.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
# Purpose : Pull RAW ACS 5-year educational attainment (table B15003)
#           for every Kentucky census tract, 2012-2024, and save to data/raw/.
#           This script ONLY pulls and verifies. No cleaning, no shares here.
# Source  : American Community Survey, 5-year estimates, table B15003.
# Output  : data/raw/acs_b15003_2012_2024_raw.rds
# =============================================================

# ----- 0. Packages -------------------------------------------------
# Installs anything missing, then loads. Safe to run every time.
pkgs <- c("tidycensus", "tidyverse")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidycensus)
library(tidyverse)


# ----- 1. Settings -------------------------------------------------
state_fips <- "21"          # Kentucky
years      <- 2012:2024     # B15003 in the 5-year file begins in 2012
vars       <- paste0("B15003_", sprintf("%03d", 1:25))  # all 25 table lines

# ----- 2. Pull each year and stack into one long table -------------
# output = "wide" returns one column per estimate (..._001E) and one per
# margin of error (..._001M). We keep both; margins matter at tract level.
acs_list <- list()
for (yr in years) {
  message("Pulling ACS 5-year B15003 for ", yr, " ...")
  d <- get_acs(
    geography = "tract",
    variables = vars,
    state     = state_fips,
    year      = yr,
    survey    = "acs5",
    output    = "wide"
  )
  d$year <- yr
  acs_list[[as.character(yr)]] <- d
}
acs_raw <- bind_rows(acs_list)

# ----- 3. Adding-up check (the test the old pipeline skipped) ------
# Lines _002 to _025 are mutually exclusive and must sum to the total (_001)
# in every tract, every year. If they don't, the pull is misaligned.
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

cat("\n--- Adding-up check by year ---\n")
print(check_by_year, n = Inf)

if (max(check_by_year$max_abs_diff, na.rm = TRUE) > 0) {
  warning("ADDING-UP CHECK FAILED for at least one year. ",
          "Inspect rows where diff != 0 before trusting the data.")
} else {
  message("Adding-up check passed: categories sum to the total in every year.")
}

# ----- 4. Save raw -------------------------------------------------
# Saved as .rds (preserves R types) for the cleaning step (02_build_panel.R).
# data/raw/ is gitignored, so this stays off GitHub.
dir.create("data/raw", showWarnings = FALSE, recursive = TRUE)
saveRDS(acs_raw, "data/raw/acs_b15003_2012_2024_raw.rds")
message("Saved: data/raw/acs_b15003_2012_2024_raw.rds  (", nrow(acs_raw), " rows)")
