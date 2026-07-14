# =============================================================
# 05_harmonize_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Put ALL ACS years on common 2020 tract boundaries, nationally.
#           2012-2019 sit on 2010 tracts -> crosswalk them to 2020 tracts
#           using NHGIS adult-population weights (wt_adult).
#           2020-2024 are already on 2020 tracts -> pass through unchanged.
# Method  : Move COUNTS across the crosswalk (count * weight), sum onto 2020
#           tracts, THEN recompute shares. Never crosswalk a percentage.
# Weight  : wt_adult = expected share of a source tract's 18+ population in
#           the target tract. Closest match to our 25+ universe.
# Inputs  : data/cleaned/us_ed_panel_2012_2024.rds  (from 02_us)
#           data/raw/nhgis_national/nhgis_tr2010_tr2020.csv (national)
# Output  : data/cleaned/us_ed_panel_harmonized_2012_2024.rds
#           data/cleaned/us_ed_panel_harmonized_2012_2024.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)

# ----- 1. Load inputs ----------------------------------------------
panel <- readRDS(here("data", "cleaned", "us_ed_panel_2012_2024.rds"))

# National tr2010 -> tr2020 crosswalk. NHGIS names it without a state suffix.
# Fall back to finding by pattern if the exact name differs on your machine.
cw_dir <- here("data", "raw", "nhgis_national")
cw_hits <- list.files(cw_dir, pattern = "tr2010.*tr2020",
                      full.names = TRUE, ignore.case = TRUE)
cw_hits <- cw_hits[grepl("\\.csv$", cw_hits, ignore.case = TRUE)]
stopifnot(length(cw_hits) >= 1)
cw_file <- cw_hits[1]
cat("Crosswalk file:", cw_file, "\n")

cw <- read_csv(cw_file,
               col_types = cols(tr2010ge = col_character(),
                                tr2020ge = col_character(),
                                .default = col_guess())) %>%
  select(geoid_2010 = tr2010ge, geoid_2020 = tr2020ge, wt_adult)

# Exclude Puerto Rico from the crosswalk. Our ACS panel has no PR either.
cw <- cw %>% filter(substr(geoid_2010, 1, 2) != "72",
                    substr(geoid_2020, 1, 2) != "72")

panel <- panel %>% mutate(geoid = as.character(geoid))

cat("Panel rows:     ", nrow(panel), "\n")
cat("Crosswalk rows: ", nrow(cw),    "\n\n")

# ----- 2. Split the panel by vintage -------------------------------
panel_2020on <- panel %>% filter(year >= 2020)
panel_pre    <- panel %>% filter(year <= 2019)

cat("Pre-2020 rows (need crosswalk):", nrow(panel_pre),    "\n")
cat("2020+ rows (already 2020 vintage):", nrow(panel_2020on), "\n\n")

# ----- 3. Crosswalk the 2012-2019 COUNTS onto 2020 tracts ----------
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
# National totals should be preserved within ~0.1% (no state-border loss
# to worry about at the national level, unlike KY-only).
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

cat("--- Conservation check: total 25+ population before vs after ---\n")
print(check, n = Inf)

if (max(abs(check$pct_diff), na.rm = TRUE) > 0.5) {
  warning("National population changed by >0.5% in some year. Investigate.")
} else {
  message("Conservation check passed: national population preserved within 0.5% every year.")
}

# ----- 5. Recombine and recompute shares on 2020 geography ---------
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

# ----- 6. Sanity: mean BA+ by year, national + KY ------------------
cat("\n--- Mean tract BA+ by year (harmonized, national) ---\n")
harmonized %>%
  group_by(year) %>%
  summarise(mean_baplus     = mean(pct_baplus, na.rm = TRUE),
            popwtd_baplus   = 100 * sum(ba_plus, na.rm = TRUE) /
              sum(pop25plus, na.rm = TRUE),
            n_tracts        = n(),
            .groups = "drop") %>%
  print(n = Inf)

cat("\n--- KY subset check (should match your existing KY harmonized file) ---\n")
harmonized %>%
  filter(substr(geoid, 1, 2) == "21") %>%
  group_by(year) %>%
  summarise(ky_popwtd_baplus = 100 * sum(ba_plus, na.rm = TRUE) /
              sum(pop25plus, na.rm = TRUE),
            ky_tracts = n(),
            .groups = "drop") %>%
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
for (v in names(labs)) {
  if (v %in% names(harmonized)) attr(harmonized[[v]], "label") <- labs[[v]]
}

dir.create(here("data", "cleaned"), showWarnings = FALSE, recursive = TRUE)
saveRDS(harmonized,
        here("data", "cleaned", "us_ed_panel_harmonized_2012_2024.rds"))
write_dta(harmonized,
          here("data", "cleaned", "us_ed_panel_harmonized_2012_2024.dta"))
message("Saved harmonized panel: ", nrow(harmonized),
        " tract-year rows on 2020 boundaries.")



