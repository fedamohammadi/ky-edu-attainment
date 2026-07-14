# =============================================================
# 07_harmonize_decennial_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Put the 1990 and 2000 U.S. educational-attainment counts onto
#           2020 census tract boundaries, so they stack onto the harmonized
#           2012-2024 ACS panel.
#
# THE CHAIN (simpler than KY because national data is at TRACT level, not BGP):
#   1990 tract  --wt_adult-->  2010 tract  --wt_adult-->  2020 tract
#   2000 tract  --wt_adult-->  2010 tract  --wt_adult-->  2020 tract
# Rule: always crosswalk COUNTS, compute shares only at the end.
#
# Inputs : data/raw/nhgis_national/ed_1990_us_raw.rds     (from 06_us)
#          data/raw/nhgis_national/ed_2000_us_raw.rds     (from 06_us)
#          data/raw/nhgis_national/nhgis_tr1990_tr2010.csv
#          data/raw/nhgis_national/nhgis_tr2000_tr2010.csv
#          data/raw/nhgis_national/nhgis_tr2010_tr2020.csv
# Outputs: data/cleaned/us_ed_decennial_1990_2000.rds
#          data/cleaned/us_ed_decennial_1990_2000.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here", "stringr")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)
library(stringr)

# ----- 1. Paths and file finder ------------------------------------
raw_dir     <- here("data", "raw", "nhgis_national")
cleaned_dir <- here("data", "cleaned")

find_cw <- function(pattern) {
  hits <- list.files(raw_dir, pattern = pattern,
                     full.names = TRUE, ignore.case = TRUE)
  hits <- hits[grepl("\\.csv$", hits, ignore.case = TRUE)]
  stopifnot(length(hits) >= 1)
  hits[1]
}

cw_1990_file <- find_cw("tr1990.*tr2010")
cw_2000_file <- find_cw("tr2000.*tr2010")
cw_1020_file <- find_cw("tr2010.*tr2020")

cat("Crosswalks:\n")
cat("  1990->2010:", cw_1990_file, "\n")
cat("  2000->2010:", cw_2000_file, "\n")
cat("  2010->2020:", cw_1020_file, "\n\n")

# ----- 2. Load raw decennial data (from 06_pull_decennial_us) ------
ed_1990 <- readRDS(file.path(raw_dir, "ed_1990_us_raw.rds"))
ed_2000 <- readRDS(file.path(raw_dir, "ed_2000_us_raw.rds"))

# Add some-college / associate and HS-or-less measures. Only ba_plus
# and pop_25plus were computed in step 06.
edu_cols_1990 <- paste0("E33", sprintf("%03d", 1:7))
edu_cols_2000 <- paste0("GKT", sprintf("%03d", 1:32))

ed_1990 <- ed_1990 %>%
  mutate(
    somecoll_assoc = E33004 + E33005,   # some coll no degree + associate
    hs_or_less     = E33001 + E33002 + E33003  # <9th + 9-12 no dip + HS grad
  )

ed_2000 <- ed_2000 %>%
  mutate(
    # Some college <1yr + some college 1+ no degree + associate, M and F
    somecoll_assoc = GKT010 + GKT011 + GKT012 +
      GKT026 + GKT027 + GKT028,
    # Everything below some college: no schooling through HS grad, M and F
    hs_or_less     = rowSums(across(all_of(paste0("GKT", sprintf("%03d", 1:9))))) +
      rowSums(across(all_of(paste0("GKT", sprintf("%03d", 17:25)))))
  )

cat("1990 rows:", nrow(ed_1990), " | 2000 rows:", nrow(ed_2000), "\n\n")

# ----- 3. Read the three crosswalks --------------------------------
cw_1990 <- read_csv(cw_1990_file,
                    col_types = cols(tr1990gj = col_character(),
                                     tr1990ge = col_character(),
                                     tr2010gj = col_character(),
                                     tr2010ge = col_character(),
                                     .default = col_guess())) %>%
  select(src = tr1990gj, tr2010ge, wt_adult)

cw_2000 <- read_csv(cw_2000_file,
                    col_types = cols(tr2000gj = col_character(),
                                     tr2000ge = col_character(),
                                     tr2010gj = col_character(),
                                     tr2010ge = col_character(),
                                     .default = col_guess())) %>%
  select(src = tr2000gj, tr2010ge, wt_adult)

cw_1020 <- read_csv(cw_1020_file,
                    col_types = cols(tr2010gj = col_character(),
                                     tr2010ge = col_character(),
                                     tr2020gj = col_character(),
                                     tr2020ge = col_character(),
                                     .default = col_guess())) %>%
  select(tr2010ge, tr2020ge, wt_adult)

# Filter Puerto Rico from all crosswalks. Not in our national panel.
cw_1990 <- cw_1990 %>% filter(substr(tr2010ge, 1, 2) != "72")
cw_2000 <- cw_2000 %>% filter(substr(tr2010ge, 1, 2) != "72")
cw_1020 <- cw_1020 %>% filter(substr(tr2010ge, 1, 2) != "72",
                              substr(tr2020ge, 1, 2) != "72")

cat("Crosswalk rows (post-PR filter):\n")
cat("  1990->2010:", nrow(cw_1990), "\n")
cat("  2000->2010:", nrow(cw_2000), "\n")
cat("  2010->2020:", nrow(cw_1020), "\n\n")

# ----- 4. GISJOIN match rate check ---------------------------------
m1990 <- mean(ed_1990$GISJOIN %in% cw_1990$src)
m2000 <- mean(ed_2000$GISJOIN %in% cw_2000$src)
cat(sprintf("GISJOIN match rate: 1990 = %.4f, 2000 = %.4f\n", m1990, m2000))
stopifnot(m1990 > 0.98, m2000 > 0.98)

# ----- 5. The harmonizer -------------------------------------------
harmonize_one <- function(ed, cw_src, yr) {
  
  # 1. Reduce to key + counts
  src <- ed %>%
    transmute(
      src            = GISJOIN,
      ba_plus,
      somecoll_assoc,
      hs_or_less,
      pop_25plus
    )
  tot_in <- sum(src$pop_25plus)
  
  # 2. Leg 1: source tract -> 2010 tract, weighted by wt_adult, summed
  leg1 <- src %>%
    inner_join(cw_src, by = "src",
               relationship = "many-to-many") %>%
    mutate(across(c(ba_plus, somecoll_assoc, hs_or_less, pop_25plus),
                  ~ .x * wt_adult)) %>%
    group_by(tr2010ge) %>%
    summarise(across(c(ba_plus, somecoll_assoc, hs_or_less, pop_25plus),
                     ~ sum(.x, na.rm = TRUE)),
              .groups = "drop")
  
  # 3. Leg 2: 2010 tract -> 2020 tract
  leg2 <- leg1 %>%
    inner_join(cw_1020, by = "tr2010ge",
               relationship = "many-to-many") %>%
    mutate(across(c(ba_plus, somecoll_assoc, hs_or_less, pop_25plus),
                  ~ .x * wt_adult)) %>%
    group_by(geoid = tr2020ge) %>%
    summarise(across(c(ba_plus, somecoll_assoc, hs_or_less, pop_25plus),
                     ~ sum(.x, na.rm = TRUE)),
              .groups = "drop")
  
  # 4. Conservation check
  drift <- abs(sum(leg2$pop_25plus) - tot_in) / tot_in
  cat(sprintf("[%d] pop in = %.0f | after leg1 = %.0f | after leg2 = %.0f | drift = %.4f%%\n",
              yr, tot_in, sum(leg1$pop_25plus), sum(leg2$pop_25plus), drift * 100))
  
  # 5. Compute shares on 2020 tracts. Zero-pop -> NA, not 0/0.
  leg2 %>%
    rename(pop25plus = pop_25plus) %>%
    mutate(
      year             = yr,
      boundary_vintage = "2020 (harmonized)",
      state_fips       = substr(geoid, 1, 2),
      pct_baplus       = if_else(pop25plus > 0, 100 * ba_plus        / pop25plus, NA_real_),
      pct_somecoll     = if_else(pop25plus > 0, 100 * somecoll_assoc / pop25plus, NA_real_),
      pct_hs_or_less   = if_else(pop25plus > 0, 100 * hs_or_less     / pop25plus, NA_real_)
    )
}

cat("--- Harmonizing 1990 ---\n")
panel_1990 <- harmonize_one(ed_1990, cw_1990, 1990L)

cat("--- Harmonizing 2000 ---\n")
panel_2000 <- harmonize_one(ed_2000, cw_2000, 2000L)

decennial <- bind_rows(panel_1990, panel_2000) %>%
  arrange(year, geoid)

# ----- 6. National benchmark check ---------------------------------
# Published national BA+ (adults 25+):
#   1990 ~20.3%, 2000 ~24.4%
cat("\n--- National benchmark (post-harmonization, pop-weighted) ---\n")
decennial %>%
  group_by(year) %>%
  summarise(
    n_tracts     = n(),
    popwtd_baplus = 100 * sum(ba_plus, na.rm = TRUE) /
      sum(pop25plus, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print(n = Inf)
cat("Should be close to 20.3 (1990) and 24.4 (2000).\n\n")

# ----- 7. Kentucky replication check -------------------------------
cat("--- Kentucky replication check (post-harmonization) ---\n")
decennial %>%
  filter(state_fips == "21") %>%
  group_by(year) %>%
  summarise(
    ky_tracts        = n(),
    ky_popwtd_baplus = 100 * sum(ba_plus, na.rm = TRUE) /
      sum(pop25plus, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print(n = Inf)
cat("Report figures: KY 1990 = 13.6%, KY 2000 = 17.1% (on 2020 boundaries).\n\n")

# ----- 8. Save -----------------------------------------------------
labs <- c(
  geoid            = "Census tract GEOID (2020 boundaries, harmonized)",
  state_fips       = "State FIPS code (2-digit)",
  year             = "Decennial census year",
  boundary_vintage = "Geography (harmonized to 2020 tracts)",
  pop25plus        = "Population 25 years and over (harmonized)",
  ba_plus          = "Count: bachelor's or higher (harmonized)",
  somecoll_assoc   = "Count: some college or associate's (harmonized)",
  hs_or_less       = "Count: high school or less (harmonized)",
  pct_baplus       = "Share with BA or higher (%)",
  pct_somecoll     = "Share with some college / associate (%)",
  pct_hs_or_less   = "Share with HS or less (%)"
)
for (v in names(labs)) {
  if (v %in% names(decennial)) attr(decennial[[v]], "label") <- labs[[v]]
}

dir.create(cleaned_dir, showWarnings = FALSE, recursive = TRUE)
saveRDS(decennial,
        file.path(cleaned_dir, "us_ed_decennial_1990_2000.rds"))
write_dta(decennial,
          file.path(cleaned_dir, "us_ed_decennial_1990_2000.dta"))

message("Saved harmonized decennial panel: ", nrow(decennial), " tract-year rows.")


