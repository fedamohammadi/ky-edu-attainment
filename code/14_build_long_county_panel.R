# =============================================================
# 14_build_long_county_panel.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL (Phase 1, final step)
# Purpose : Stack the 1940/1970/1980 county attainment file with the
#           existing 1990-2024 county panel to build one long panel
#           spanning nearly 85 years. Handle the definitional break
#           between "years of school" (pre-1990) and "degree-based"
#           (1990+) BA+ measures via a clear flag.
# Inputs  : data/raw/nhgis0003_csv/county_ed_1940_1980_us_raw.rds  (from 13)
#           data/cleaned/us_ed_county_panel_1990_2024.rds          (from 10_us)
# Outputs : data/cleaned/us_ed_county_panel_long_1940_2024.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)

raw_dir     <- here("data", "raw", "nhgis0003_csv")
cleaned_dir <- here("data", "cleaned")

# ----- 1. Load both panels ----------------------------------------
pre1990 <- readRDS(file.path(raw_dir, "county_ed_1940_1980_us_raw.rds"))
post1990 <- readRDS(file.path(cleaned_dir, "us_ed_county_panel_1990_2024.rds"))

cat("Pre-1990 rows:  ", nrow(pre1990),  " (", n_distinct(pre1990$year),  " years)\n", sep = "")
cat("Post-1990 rows: ", nrow(post1990), " (", n_distinct(post1990$year), " years)\n\n", sep = "")

# ----- 2. Align schemas -------------------------------------------
# Common columns kept across the two eras. Everything else dropped.
# Add attainment_measure flag so downstream users know the definitional
# break at 1990 and don't compare apples to oranges accidentally.

pre1990_aligned <- pre1990 %>%
  transmute(
    county_fips,
    state_fips,
    state,
    county,
    year,
    pop25plus = pop_25plus,
    ba_plus,
    pct_baplus,
    attainment_measure = "4+ years of college"
  )

post1990_aligned <- post1990 %>%
  transmute(
    county_fips,
    state_fips,
    state,
    county,
    year,
    pop25plus,
    ba_plus,
    pct_baplus,
    attainment_measure = "Bachelor's degree or higher"
  )

# ----- 3. Stack ---------------------------------------------------
long_county <- bind_rows(pre1990_aligned, post1990_aligned) %>%
  arrange(county_fips, year)

cat("--- Long county panel ---\n")
cat("Total rows:      ", nrow(long_county),                     "\n")
cat("Total counties:  ", n_distinct(long_county$county_fips),   "\n")
cat("Years covered:   ", paste(sort(unique(long_county$year)),
                               collapse = ", "), "\n\n")

# ----- 4. Coverage table by year ----------------------------------
cat("--- Counties per year ---\n")
coverage <- long_county %>%
  group_by(year, attainment_measure) %>%
  summarise(
    n_counties      = n(),
    natl_popwtd_ba  = 100 * sum(ba_plus, na.rm = TRUE) /
      sum(pop25plus, na.rm = TRUE),
    .groups = "drop"
  )
print(coverage, n = Inf)

# ----- 5. Save ----------------------------------------------------
labs <- c(
  county_fips        = "5-digit county FIPS (state + county)",
  state_fips         = "2-digit state FIPS",
  state              = "State name",
  county             = "County name",
  year               = "Census / ACS year",
  pop25plus          = "Population 25 years and over",
  ba_plus            = "Count with BA+ (see attainment_measure)",
  pct_baplus         = "Share with BA+ (%) (see attainment_measure)",
  attainment_measure = "Definition: '4+ years of college' (pre-1990) or 'Bachelor's degree or higher' (1990+)"
)
for (v in names(labs)) {
  if (v %in% names(long_county)) attr(long_county[[v]], "label") <- labs[[v]]
}

saveRDS(long_county,
        file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024.rds"))
write_dta(long_county,
          file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024.dta"))

message("Saved:")
message("  ", file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024.rds"))
message("  ", file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024.dta"))




