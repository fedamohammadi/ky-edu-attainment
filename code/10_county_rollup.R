# 10_county_rollup.R ------------------------------------------------------------
# Roll the full 1990-2024 tract panel up to county level.
# County rate = sum the counts, then divide (population-weighted) = the true
# county attainment rate. This is the resident-attainment side of the eventual
# brain-drain comparison.
# -------------------------------------------------------------------------------

library(here)
library(dplyr)
library(tidyr)
library(haven)
library(tidycensus)   # only for the county-name lookup (no API call)

cleaned_dir <- here("data", "cleaned")
table_dir   <- here("output", "tables")

panel <- readRDS(file.path(cleaned_dir, "ky_ed_panel_full_1990_2024.rds"))

# County FIPS = first 5 chars of the 11-digit tract GEOID (state 21 + county 3).
county_panel <- panel |>
  mutate(county_fips = substr(geoid, 1, 5)) |>
  group_by(county_fips, year) |>
  summarise(
    pop25plus      = sum(pop25plus,      na.rm = TRUE),
    ba_plus        = sum(ba_plus,        na.rm = TRUE),
    somecoll_assoc = sum(somecoll_assoc, na.rm = TRUE),
    hs_or_less     = sum(hs_or_less,     na.rm = TRUE),
    n_tracts       = n(),
    .groups = "drop"
  ) |>
  mutate(
    pct_baplus   = 100 * ba_plus / pop25plus,
    pct_somecoll = 100 * somecoll_assoc / pop25plus
  )

# Attach county names (fips_codes ships with tidycensus, no API call).
ky_names <- fips_codes |>
  filter(state_code == "21") |>
  transmute(county_fips = paste0(state_code, county_code),
            county      = sub(" County$", "", county))

county_panel <- county_panel |>
  left_join(ky_names, by = "county_fips") |>
  relocate(county, .after = county_fips)

saveRDS(county_panel,  file.path(cleaned_dir, "ky_ed_county_panel_1990_2024.rds"))
write_dta(county_panel, file.path(cleaned_dir, "ky_ed_county_panel_1990_2024.dta"))

# Wide summary: BA+ level at the benchmark years + growth over the full span.
growth <- county_panel |>
  filter(year %in% c(1990, 2000, 2012, 2024)) |>
  select(county_fips, county, year, pct_baplus) |>
  pivot_wider(names_from = year, values_from = pct_baplus, names_prefix = "ba_") |>
  mutate(
    growth_1990_2024  = ba_2024 - ba_1990,        # total pp change, 34 years
    growth_per_decade = growth_1990_2024 / 3.4    # 34 yrs = 3.4 decades
  ) |>
  arrange(desc(growth_1990_2024))

write_dta(growth, file.path(cleaned_dir, "ky_county_baplus_growth.dta"))
write.csv(growth, file.path(table_dir, "county_baplus_growth.csv"), row.names = FALSE)

# Peek: fastest and slowest counties on resident BA+ growth.
cat("\nTop 8 counties by BA+ growth, 1990-2024:\n")
print(head(growth, 8))
cat("\nBottom 8:\n")
print(tail(growth, 8))
cat(sprintf("\nCounties: %d | mean county BA+ growth 1990-2024: %.1f pp\n",
            nrow(growth), mean(growth$growth_1990_2024, na.rm = TRUE)))



