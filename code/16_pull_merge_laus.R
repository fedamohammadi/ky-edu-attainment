# =============================================================
# 16_pull_merge_laus.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL - COVARIATE #2: BLS LAUS unemployment
# Purpose : Read annual county-level unemployment rates from BLS LAUS,
#           1990-2024 (35 files), stack them, and merge onto the
#           long county panel (which already has RUCC).
# Inputs  : data/raw/bls_laus/laucnty*.xlsx (35 files)
#           data/cleaned/us_ed_county_panel_long_1940_2024_rucc.rds
# Output  : data/cleaned/laus_annual_1990_2024.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_rucc_laus.rds
#           data/cleaned/us_ed_county_panel_long_1940_2024_rucc_laus.dta
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here", "readxl")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)
library(readxl)

laus_dir    <- here("data", "raw", "bls_laus")
cleaned_dir <- here("data", "cleaned")

# ----- 1. Discover files -------------------------------------------
# Files are named laucnty##.xlsx where ## is a 2-digit year.
# 90-99 = 1990s, 00-24 = 2000s.
files <- list.files(laus_dir, pattern = "^laucnty\\d{2}\\.xlsx$",
                    full.names = TRUE)
cat("Files found:", length(files), "\n")
stopifnot(length(files) == 35)

# ----- 2. Helper: read one file, standardize columns ---------------
read_one_laus <- function(f) {
  # File name -> 4-digit year
  base <- tools::file_path_sans_ext(basename(f))
  yy   <- as.integer(str_extract(base, "\\d{2}$"))
  full_year <- if_else(yy >= 90, 1900L + yy, 2000L + yy)
  
  d <- read_excel(f, skip = 5, col_names = FALSE)
  
  # BLS structure: after skipping headers, columns are:
  # 1=LAUS Code, 2=State FIPS, 3=County FIPS, 4=Name/State,
  # 5=Year, 6=Labor Force, 7=Employed, 8=Unemployed, 9=Rate
  d <- d %>%
    select(
      state_fips_raw = 2,
      county_fips_raw = 3,
      name = 4,
      year_raw = 5,
      labor_force = 6,
      employed = 7,
      unemployed = 8,
      unemp_rate = 9
    ) %>%
    filter(!is.na(state_fips_raw), !is.na(county_fips_raw)) %>%
    mutate(
      state_fips  = str_pad(as.character(state_fips_raw), 2, pad = "0"),
      county_code = str_pad(as.character(county_fips_raw), 3, pad = "0"),
      county_fips = paste0(state_fips, county_code),
      year        = full_year,
      labor_force = as.numeric(labor_force),
      employed    = as.numeric(employed),
      unemployed  = as.numeric(unemployed),
      unemp_rate  = as.numeric(unemp_rate)
    ) %>%
    select(county_fips, state_fips, year, labor_force, employed,
           unemployed, unemp_rate)
  
  d
}

# ----- 3. Read all files -------------------------------------------
cat("Reading LAUS files...\n")
laus_list <- map(files, function(f) {
  d <- read_one_laus(f)
  cat(sprintf("  %s: %d rows, year %d\n",
              basename(f), nrow(d), first(d$year)))
  d
})

laus <- bind_rows(laus_list) %>%
  arrange(county_fips, year)

cat("\n--- LAUS stacked ---\n")
cat("Total rows:", nrow(laus), "\n")
cat("Years:", paste(sort(unique(laus$year)), collapse = ", "), "\n\n")

# ----- 4. Sanity checks --------------------------------------------
# 4a. Counties per year (should be ~3,140)
cat("--- Counties per year ---\n")
laus %>%
  group_by(year) %>%
  summarise(n_counties = n(),
            mean_rate  = mean(unemp_rate, na.rm = TRUE),
            .groups = "drop") %>%
  print(n = Inf)

# 4b. Benchmark against published national unemployment rates.
# National rate = weighted average of county rates by labor force.
# Published U.S. annual civilian unemployment rate (BLS):
#   1990: 5.6%, 2000: 4.0%, 2009: 9.3%, 2012: 8.1%, 2019: 3.7%,
#   2020: 8.1%, 2024: ~4.0%
cat("\n--- National unemployment (LAUS county rollup) ---\n")
laus %>%
  group_by(year) %>%
  summarise(
    natl_rate = 100 * sum(unemployed, na.rm = TRUE) /
      sum(labor_force, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print(n = Inf)

# ----- 5. Save the LAUS panel -------------------------------------
saveRDS(laus, file.path(cleaned_dir, "laus_annual_1990_2024.rds"))

# ----- 6. Merge into the long panel -------------------------------
panel <- readRDS(file.path(cleaned_dir,
                           "us_ed_county_panel_long_1940_2024_rucc.rds"))

# Left join: pre-1990 years will have NA for unemployment.
# Drop the LAUS state_fips (already in panel) to avoid a duplicate column.
panel_laus <- panel %>%
  left_join(laus %>% select(-state_fips),
            by = c("county_fips", "year"))

# Match quality
match_summary <- panel_laus %>%
  filter(year >= 1990) %>%
  group_by(year) %>%
  summarise(
    n_counties      = n(),
    n_missing_unemp = sum(is.na(unemp_rate)),
    pct_missing     = 100 * mean(is.na(unemp_rate)),
    .groups = "drop"
  )

cat("\n--- Missing unemployment by year (1990+) ---\n")
print(match_summary, n = Inf)

# ----- 7. Sanity: unemployment by metro status, selected years ----
cat("\n--- Mean unemployment by metro status, selected years ---\n")
panel_laus %>%
  filter(year %in% c(1990, 2000, 2010, 2019, 2020, 2024),
         !is.na(metro_status), !is.na(unemp_rate)) %>%
  group_by(year, metro_status) %>%
  summarise(
    mean_unemp = mean(unemp_rate, na.rm = TRUE),
    n_counties = n(),
    .groups = "drop"
  ) %>%
  print(n = Inf)

# ----- 8. Save ----------------------------------------------------
labs <- c(
  labor_force = "Total civilian labor force (BLS LAUS)",
  employed    = "Total employed (BLS LAUS)",
  unemployed  = "Total unemployed (BLS LAUS)",
  unemp_rate  = "Unemployment rate (%) (BLS LAUS annual average)"
)
for (v in names(labs)) {
  if (v %in% names(panel_laus)) attr(panel_laus[[v]], "label") <- labs[[v]]
}

saveRDS(panel_laus,
        file.path(cleaned_dir,
                  "us_ed_county_panel_long_1940_2024_rucc_laus.rds"))
write_dta(panel_laus,
          file.path(cleaned_dir,
                    "us_ed_county_panel_long_1940_2024_rucc_laus.dta"))

message("Saved:")
message("  ", file.path(cleaned_dir, "laus_annual_1990_2024.rds"))
message("  ", file.path(cleaned_dir,
                        "us_ed_county_panel_long_1940_2024_rucc_laus.rds"))
message("  ", file.path(cleaned_dir,
                        "us_ed_county_panel_long_1940_2024_rucc_laus.dta"))


