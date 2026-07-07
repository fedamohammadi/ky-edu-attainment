# =============================================================
# 05_harmonize.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
# Purpose : Put ALL years on common 2020 tract boundaries.
#           2012-2019 sit on 2010 tracts -> crosswalk them to 2020 tracts
#           using NHGIS adult-population weights (wt_adult).
#           2020-2024 are already on 2020 tracts -> pass through unchanged.
# Method  : Move COUNTS across the crosswalk (count * weight), sum onto 2020
#           tracts, THEN recompute shares. Never crosswalk a percentage.
# Weight  : wt_adult = expected share of a source tract's 18+ population in the
#           target tract. Closest match to our 25+ universe (see codebook note).
# Inputs  : data/cleaned/ky_ed_panel_2012_2024.rds   (from 02)
#           data/raw/nhgis_tr2010_tr2020_21.csv       (NHGIS KY crosswalk)
# Output  : data/cleaned/ky_ed_panel_harmonized_2012_2024.rds
#           data/cleaned/ky_ed_panel_harmonized_2012_2024.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)

# ----- 1. Load inputs ----------------------------------------------
panel <- readRDS("data/cleaned/ky_ed_panel_2012_2024.rds")

# Force GEOIDs to character on read so leading zeros / digits never get lost.
cw <- read_csv("data/raw/nhgis_tr2010_tr2020_21.csv",
               col_types = cols(tr2010ge = col_character(),
                                tr2020ge = col_character(),
                                .default = col_guess())) %>%
  select(geoid_2010 = tr2010ge, geoid_2020 = tr2020ge, wt_adult)

panel <- panel %>% mutate(geoid = as.character(geoid))

# ----- 2. Split the panel by vintage -------------------------------
# 2020-2024 already on 2020 tracts: keep as-is.
# 2012-2019 on 2010 tracts: must be crosswalked.
panel_2020on <- panel %>% filter(year >= 2020)
panel_pre    <- panel %>% filter(year <= 2019)

# ----- 3. Crosswalk the 2012-2019 COUNTS onto 2020 tracts ----------
# Join each 2010 tract-year to every 2020 piece it maps to, multiply the
# counts by wt_adult, then sum the pieces by (2020 tract, year).
harmonized_pre <- panel_pre %>%
  select(geoid, year, pop25plus, ba_plus, somecoll_assoc, hs_or_less) %>%
  inner_join(cw, by = c("geoid" = "geoid_2010")) %>%
  mutate(
    pop25plus      = pop25plus      * wt_adult,
    ba_plus        = ba_plus        * wt_adult,
    somecoll_assoc = somecoll_assoc * wt_adult,
    hs_or_less     = hs_or_less     * wt_adult
  ) %>%
  group_by(geoid = geoid_2020, year) %>%
  summarise(
    pop25plus      = sum(pop25plus,      na.rm = TRUE),
    ba_plus        = sum(ba_plus,        na.rm = TRUE),
    somecoll_assoc = sum(somecoll_assoc, na.rm = TRUE),
    hs_or_less     = sum(hs_or_less,     na.rm = TRUE),
    .groups = "drop"
  )

# ----- 4. Conservation check: did we lose any people? --------------
# Total population each year should be (almost) identical before vs after
# crosswalking. Small differences come from tract pieces that cross the KY
# border; large differences mean something is wrong.
check <- panel_pre %>%
  group_by(year) %>%
  summarise(pop_before = sum(pop25plus, na.rm = TRUE), .groups = "drop") %>%
  left_join(
    harmonized_pre %>%
      group_by(year) %>%
      summarise(pop_after = sum(pop25plus, na.rm = TRUE), .groups = "drop"),
    by = "year"
  ) %>%
  mutate(pct_diff = 100 * (pop_after - pop_before) / pop_before)

cat("\n--- Conservation check: total 25+ population before vs after ---\n")
print(check, n = Inf)
if (max(abs(check$pct_diff), na.rm = TRUE) > 1) {
  warning("Population changed by >1% in some year after crosswalking. Investigate before trusting.")
} else {
  message("Conservation check passed: population preserved within 1% every year.")
}

# ----- 5. Recombine, recompute shares on 2020 geography ------------
panel_2020on_counts <- panel_2020on %>%
  select(geoid, year, pop25plus, ba_plus, somecoll_assoc, hs_or_less)

harmonized <- bind_rows(harmonized_pre, panel_2020on_counts) %>%
  mutate(
    boundary_vintage = "2020 (harmonized)",
    pct_baplus     = if_else(pop25plus > 0, 100 * ba_plus        / pop25plus, NA_real_),
    pct_somecoll   = if_else(pop25plus > 0, 100 * somecoll_assoc / pop25plus, NA_real_),
    pct_hs_or_less = if_else(pop25plus > 0, 100 * hs_or_less     / pop25plus, NA_real_)
  ) %>%
  arrange(geoid, year)

# ----- 6. Quick sanity: mean BA+ by year should match 02's numbers --
cat("\n--- Mean tract BA+ by year (harmonized) ---\n")
harmonized %>%
  group_by(year) %>%
  summarise(mean_baplus = mean(pct_baplus, na.rm = TRUE),
            n_tracts = n(), .groups = "drop") %>%
  print(n = Inf)

# ----- 7. Save -----------------------------------------------------
labs <- c(
  geoid            = "Census tract GEOID (2020 boundaries, harmonized)",
  year             = "ACS 5-year estimate end year",
  boundary_vintage = "Geography (all years harmonized to 2020 tracts)",
  pop25plus        = "Population 25 years and over (harmonized)",
  ba_plus          = "Count: bachelor's or higher (harmonized)",
  somecoll_assoc   = "Count: some college or associate's (harmonized)",
  hs_or_less       = "Count: high school or less (harmonized)",
  pct_baplus       = "Share with BA or higher (%)",
  pct_somecoll     = "Share with some college / associate (%)",
  pct_hs_or_less   = "Share with HS or less (%)"
)
for (v in names(labs)) if (v %in% names(harmonized)) attr(harmonized[[v]], "label") <- labs[[v]]

saveRDS(harmonized,   "data/cleaned/ky_ed_panel_harmonized_2012_2024.rds")
write_dta(harmonized, "data/cleaned/ky_ed_panel_harmonized_2012_2024.dta")
message("Saved harmonized panel: ", nrow(harmonized), " tract-year rows on 2020 boundaries.")




