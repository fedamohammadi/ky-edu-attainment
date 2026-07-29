# =============================================================
# 15_pull_merge_rucc.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL - COVARIATE #1: USDA RUCC
# Purpose : Read USDA Rural-Urban Continuum Codes from six editions
#           (1974, 1983, 1993, 2003, 2013, 2023), build one long
#           county-edition table, and merge into the long county
#           attainment panel using the closest-edition rule.
# Inputs  : data/raw/usda_rucc/*.xlsx
#           data/cleaned/us_ed_county_panel_long_1940_2024.rds
# Output  : data/cleaned/rucc_by_county_edition.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_rucc.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_rucc.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here", "readxl")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)
library(readxl)

rucc_dir    <- here("data", "raw", "usda_rucc")
cleaned_dir <- here("data", "cleaned")

# ----- 1. Helper: standardize a RUCC table -------------------------
# Each edition file has a slightly different column setup, but we
# only need: 5-digit FIPS (as character) + RUCC code (integer 1-9).
standardize_rucc <- function(df, fips_col, rucc_col, edition_year) {
  df %>%
    transmute(
      county_fips = str_pad(as.character(.data[[fips_col]]), 5, pad = "0"),
      rucc        = as.integer(.data[[rucc_col]]),
      rucc_edition = edition_year
    ) %>%
    filter(!is.na(rucc), county_fips != "NA")
}

# ----- 2. Read each edition ----------------------------------------
# Helper: find the file whether it's .xls or .xlsx
find_rucc_file <- function(basename) {
  for (ext in c(".xlsx", ".xls")) {
    f <- file.path(rucc_dir, paste0(basename, ext))
    if (file.exists(f)) return(f)
  }
  stop("No .xls or .xlsx found for: ", basename)
}

r1974 <- read_excel(find_rucc_file("ruralurbancodes1974"),
                    sheet = "RuralUrbanCont1974") %>%
  standardize_rucc(fips_col = "FIPS Code",
                   rucc_col = "1974 Rural-urban Continuum Code",
                   edition_year = 1974)

# 1983 and 1993 both live in cd8393
cd8393 <- read_excel(find_rucc_file("cd8393"), sheet = "cd8393")

r1983 <- cd8393 %>%
  standardize_rucc(fips_col = "FIPS",
                   rucc_col = "1983 Rural-urban Continuum Code",
                   edition_year = 1983)

r1993 <- cd8393 %>%
  standardize_rucc(fips_col = "FIPS",
                   rucc_col = "1993 Rural-urban Continuum Code",
                   edition_year = 1993)

r2003 <- read_excel(find_rucc_file("ruralurbancodes2003"),
                    sheet = "beale03") %>%
  standardize_rucc(fips_col = "FIPS Code",
                   rucc_col = "2003 Rural-urban Continuum Code",
                   edition_year = 2003)

r2013 <- read_excel(find_rucc_file("ruralurbancodes2013"),
                    sheet = "Rural-urban Continuum Code 2013") %>%
  standardize_rucc(fips_col = "FIPS",
                   rucc_col = "RUCC_2013",
                   edition_year = 2013)

r2023 <- read_excel(find_rucc_file("ruralurbancodes2023"),
                    sheet = "Rural-urban Continuum Code 2023") %>%
  standardize_rucc(fips_col = "FIPS",
                   rucc_col = "RUCC_2023",
                   edition_year = 2023)

# ----- 3. Stack all editions --------------------------------------
rucc_long <- bind_rows(r1974, r1983, r1993, r2003, r2013, r2023) %>%
  arrange(county_fips, rucc_edition)

cat("--- RUCC by edition ---\n")
rucc_long %>%
  group_by(rucc_edition) %>%
  summarise(n_counties = n(),
            mean_rucc  = mean(rucc, na.rm = TRUE),
            .groups = "drop") %>%
  print(n = Inf)

# ----- 4. Load the long county panel and pick edition per year ----
panel <- readRDS(file.path(cleaned_dir,
                           "us_ed_county_panel_long_1940_2024.rds"))

# Year-to-edition mapping (nearest available edition)
edition_for <- function(yr) {
  case_when(
    yr <= 1974            ~ 1974L,
    yr >= 1975 & yr <= 1984 ~ 1983L,
    yr >= 1985 & yr <= 1994 ~ 1993L,
    yr >= 1995 & yr <= 2004 ~ 2003L,
    yr >= 2005 & yr <= 2014 ~ 2013L,
    yr >= 2015            ~ 2023L,
    TRUE                  ~ NA_integer_
  )
}

panel <- panel %>%
  mutate(rucc_edition = edition_for(year))

cat("\n--- Year-to-edition mapping applied ---\n")
panel %>%
  distinct(year, rucc_edition) %>%
  arrange(year) %>%
  print(n = Inf)

# ----- 5. Merge ---------------------------------------------------
panel_rucc <- panel %>%
  left_join(rucc_long, by = c("county_fips", "rucc_edition"))

# ----- 6. Match quality check -------------------------------------
match_summary <- panel_rucc %>%
  group_by(year) %>%
  summarise(
    n_counties    = n(),
    n_missing_rucc = sum(is.na(rucc)),
    pct_missing    = 100 * mean(is.na(rucc)),
    .groups = "drop"
  )

cat("\n--- Missing RUCC by year (should be low; some drift expected) ---\n")
print(match_summary, n = Inf)

# Add urban/rural three-way classification for convenience
panel_rucc <- panel_rucc %>%
  mutate(
    metro_status = case_when(
      rucc %in% 1:3 ~ "Metro",
      rucc %in% 4:7 ~ "Nonmetro with city",
      rucc %in% 8:9 ~ "Rural",
      TRUE          ~ NA_character_
    )
  )

# ----- 7. Sanity: national BA+ share by metro status --------------
cat("\n--- BA+ share by metro status, selected years ---\n")
panel_rucc %>%
  filter(year %in% c(1970, 1990, 2000, 2024), !is.na(metro_status)) %>%
  group_by(year, metro_status) %>%
  summarise(
    popwtd_baplus = 100 * sum(ba_plus, na.rm = TRUE) /
      sum(pop25plus, na.rm = TRUE),
    n_counties    = n(),
    .groups = "drop"
  ) %>%
  print(n = Inf)

# ----- 8. Save ----------------------------------------------------
labs <- c(
  rucc         = "USDA Rural-Urban Continuum Code (1-9 scale)",
  rucc_edition = "Edition of RUCC used for this observation (nearest to year)",
  metro_status = "Three-way classification: Metro (1-3), Nonmetro with city (4-7), Rural (8-9)"
)
for (v in names(labs)) {
  if (v %in% names(panel_rucc)) attr(panel_rucc[[v]], "label") <- labs[[v]]
}

saveRDS(rucc_long,
        file.path(cleaned_dir, "rucc_by_county_edition.rds"))
saveRDS(panel_rucc,
        file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_rucc.rds"))
write_dta(panel_rucc,
          file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_rucc.dta"))

message("Saved:")
message("  ", file.path(cleaned_dir, "rucc_by_county_edition.rds"))
message("  ", file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_rucc.rds"))
message("  ", file.path(cleaned_dir, "us_ed_county_panel_long_1940_2024_rucc.dta"))




