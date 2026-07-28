
# =============================================================
# 13_pull_county_1940_1980.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           LONG COUNTY PANEL (Phase 1: pre-1990)
# Purpose : Read 1940, 1970, and 1980 county-level educational attainment
#           from NHGIS. Harmonize columns to a common BA+ measure and
#           build proper 5-digit county FIPS codes.
#
# Notes on measurement:
#   Pre-1990 census reported "years of school completed," not degrees.
#   Our BA+ measure is "4 or more years of college," the standard historical
#   proxy for BA+. Not identical to a bachelor's degree, but comparable in
#   the literature. Documented in the codebook and report.
#
# Notes on coverage:
#   1960 is not available at county level from NHGIS.
#   1950 uses a 14+ universe, incompatible with 25+, so skipped.
#
# Notes on NHGIS FIPS format:
#   NHGIS pads state and county codes with a trailing "0":
#     STATEA "010"  = FIPS state "01"  (Alabama)
#     COUNTYA "0010" = FIPS county "001" (Autauga)
#   To recover standard FIPS, strip the trailing character.
#   (In some NHGIS extracts the codes come without padding. We handle both.)
#
# Source  : NHGIS extract nhgis0003 (county-level)
#           - 1940: ds78,  table NT15B (BWW001-BWW018)
#           - 1970: ds99,  table NT42  (C2M001-C2M020)
#           - 1980: ds107, table NT48A (DHM001-DHM005)
# Output  : data/raw/nhgis0003_csv/county_ed_1940_1980_us_raw.rds
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("ipumsr", "dplyr", "here", "stringr", "readr")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(ipumsr)
library(dplyr)
library(here)
library(stringr)
library(readr)

# ----- 1. Paths ----------------------------------------------------
raw_dir <- here("data", "raw", "nhgis0003_csv")

find_file <- function(pattern) {
  hits <- list.files(raw_dir, pattern = pattern, full.names = TRUE,
                     ignore.case = TRUE)
  csv <- hits[str_detect(hits, "\\.csv$") & !str_detect(hits, "codebook")]
  if (length(csv) >= 1) return(csv[1])
  stop("Could not find file matching: ", pattern)
}

file_1940 <- find_file("ds78_1940_county")
file_1970 <- find_file("ds99_1970_county")
file_1980 <- find_file("ds107_1980_county")

cat("1940:", file_1940, "\n")
cat("1970:", file_1970, "\n")
cat("1980:", file_1980, "\n\n")

# ----- 2. FIPS helper ---------------------------------------------
# NHGIS pads state (3 chars) and county (4 chars) codes with a trailing "0".
# Strip the trailing char to recover standard 2-digit state / 3-digit county
# FIPS. If codes come in already-standard length (2 or 3), pass through.
make_fips <- function(df) {
  df %>%
    mutate(
      state_fips = if_else(nchar(as.character(STATEA)) == 3,
                           str_sub(as.character(STATEA), 1, 2),
                           str_pad(as.character(STATEA), 2, pad = "0")),
      cty_code   = if_else(nchar(as.character(COUNTYA)) == 4,
                           str_sub(as.character(COUNTYA), 1, 3),
                           str_pad(as.character(COUNTYA), 3, pad = "0")),
      county_fips = paste0(state_fips, cty_code)
    ) %>%
    select(-cty_code)
}

# ----- 3. Read 1940 ------------------------------------------------
# BWW001-BWW009: Male,   9 categories (last = "Not reported")
# BWW010-BWW018: Female, 9 categories (last = "Not reported")
# BA+ = 4+ years of college = BWW008 + BWW017
# Total 25+ = sum of all 18 (including "Not reported")

ed_1940 <- read_nhgis(file_1940, verbose = FALSE) %>% make_fips()

# Drop Yellowstone National Park (Idaho): not a real county, all-NA row.
ed_1940 <- ed_1940 %>%
  filter(!(STATE == "Idaho" & COUNTY == "Yellowstone National Park"))

edu_cols_1940 <- paste0("BWW", sprintf("%03d", 1:18))
stopifnot(all(edu_cols_1940 %in% names(ed_1940)))

ed_1940 <- ed_1940 %>%
  mutate(
    pop_25plus   = rowSums(across(all_of(edu_cols_1940)), na.rm = TRUE),
    ba_plus      = BWW008 + BWW017,
    not_reported = BWW009 + BWW018,
    year         = 1940L
  )

cat("--- 1940 ---\n")
cat("Counties:", nrow(ed_1940), "\n")
cat("Sample FIPS (should be 5-digit):",
    paste(head(ed_1940$county_fips), collapse = ", "), "\n")
cat("Natl BA+ share (pop-wtd, incl. not-reported in denom):",
    round(sum(ed_1940$ba_plus) / sum(ed_1940$pop_25plus) * 100, 2), "%\n")
cat("Natl BA+ share (pop-wtd, excl. not-reported):",
    round(sum(ed_1940$ba_plus) /
            (sum(ed_1940$pop_25plus) - sum(ed_1940$not_reported)) * 100, 2),
    "%\n")
cat("Not-reported share:",
    round(sum(ed_1940$not_reported) / sum(ed_1940$pop_25plus) * 100, 2),
    "%\n\n")

# ----- 4. Read 1970 ------------------------------------------------
# C2M001-C2M010: Male,   10 categories
# C2M011-C2M020: Female, 10 categories
# BA+ = 4+ years of college = C2M009 + C2M010 + C2M019 + C2M020
# Total 25+ = sum of all 20

ed_1970 <- read_nhgis(file_1970, verbose = FALSE) %>% make_fips()

edu_cols_1970 <- paste0("C2M", sprintf("%03d", 1:20))
stopifnot(all(edu_cols_1970 %in% names(ed_1970)))

ed_1970 <- ed_1970 %>%
  mutate(
    pop_25plus = rowSums(across(all_of(edu_cols_1970)), na.rm = TRUE),
    ba_plus    = C2M009 + C2M010 + C2M019 + C2M020,
    year       = 1970L
  )

cat("--- 1970 ---\n")
cat("Counties:", nrow(ed_1970), "\n")
cat("Sample FIPS:",
    paste(head(ed_1970$county_fips), collapse = ", "), "\n")
cat("Natl BA+ share (pop-wtd):",
    round(sum(ed_1970$ba_plus) / sum(ed_1970$pop_25plus) * 100, 2), "%\n\n")

# ----- 5. Read 1980 ------------------------------------------------
# DHM001: Elementary (0-8 years)
# DHM002: High school 1-3 years
# DHM003: High school 4 years
# DHM004: College 1-3 years
# DHM005: College 4 or more years  <-- BA+
# Total 25+ = sum of all 5

ed_1980 <- read_nhgis(file_1980, verbose = FALSE) %>% make_fips()

edu_cols_1980 <- paste0("DHM", sprintf("%03d", 1:5))
stopifnot(all(edu_cols_1980 %in% names(ed_1980)))

ed_1980 <- ed_1980 %>%
  mutate(
    pop_25plus = rowSums(across(all_of(edu_cols_1980)), na.rm = TRUE),
    ba_plus    = DHM005,
    year       = 1980L
  )

cat("--- 1980 ---\n")
cat("Counties:", nrow(ed_1980), "\n")
cat("Sample FIPS:",
    paste(head(ed_1980$county_fips), collapse = ", "), "\n")
cat("Natl BA+ share (pop-wtd):",
    round(sum(ed_1980$ba_plus) / sum(ed_1980$pop_25plus) * 100, 2), "%\n\n")

# ----- 6. Benchmark against published census figures ---------------
# Historical published national BA+ (4+ years of college, adults 25+):
#   1940: 4.6%
#   1970: 10.7%
#   1980: 16.2%
# Source: Historical Statistics of the United States;
#         NCES Digest of Education Statistics, Table 104.10.

ba_1940 <- sum(ed_1940$ba_plus) / sum(ed_1940$pop_25plus) * 100
ba_1970 <- sum(ed_1970$ba_plus) / sum(ed_1970$pop_25plus) * 100
ba_1980 <- sum(ed_1980$ba_plus) / sum(ed_1980$pop_25plus) * 100

cat("--- Benchmark check ---\n")
cat(sprintf("1940: %.2f%%  (published ~4.6%%,  diff %+.2f pp)\n",
            ba_1940, ba_1940 - 4.6))
cat(sprintf("1970: %.2f%%  (published ~10.7%%, diff %+.2f pp)\n",
            ba_1970, ba_1970 - 10.7))
cat(sprintf("1980: %.2f%%  (published ~16.2%%, diff %+.2f pp)\n\n",
            ba_1980, ba_1980 - 16.2))

if (any(abs(c(ba_1940 - 4.6, ba_1970 - 10.7, ba_1980 - 16.2)) > 0.5)) {
  warning("At least one benchmark is off by more than 0.5 pp. Investigate.")
} else {
  message("All benchmarks within 0.5 pp of published values.")
}

# ----- 7. Kentucky replication check -------------------------------
# Published KY BA+ (4+ years of college):
#   1940: ~2.5%
#   1970: ~7.2%
#   1980: ~11.1%
ky_ba <- function(df) {
  ky <- df %>% filter(state_fips == "21")
  100 * sum(ky$ba_plus) / sum(ky$pop_25plus)
}

cat("--- Kentucky replication ---\n")
cat(sprintf("KY 1940: %.2f%% (published ~2.5%%)\n",  ky_ba(ed_1940)))
cat(sprintf("KY 1970: %.2f%% (published ~7.2%%)\n",  ky_ba(ed_1970)))
cat(sprintf("KY 1980: %.2f%% (published ~11.1%%)\n\n", ky_ba(ed_1980)))

# ----- 8. Stack ----------------------------------------------------
# Common columns only: FIPS keys, state / county names, year, counts, share.
county_pre1990 <- bind_rows(
  ed_1940 %>% select(county_fips, state_fips, STATE, COUNTY, year,
                     pop_25plus, ba_plus),
  ed_1970 %>% select(county_fips, state_fips, STATE, COUNTY, year,
                     pop_25plus, ba_plus),
  ed_1980 %>% select(county_fips, state_fips, STATE, COUNTY, year,
                     pop_25plus, ba_plus)
) %>%
  rename(state = STATE, county = COUNTY) %>%
  mutate(pct_baplus = if_else(pop_25plus > 0,
                              100 * ba_plus / pop_25plus, NA_real_)) %>%
  arrange(year, county_fips)

cat("--- Stacked panel ---\n")
cat("Total rows:", nrow(county_pre1990), "\n")
cat("Counties per year:\n")
print(county_pre1990 %>% count(year))

# ----- 9. Save -----------------------------------------------------
saveRDS(county_pre1990, file.path(raw_dir, "county_ed_1940_1980_us_raw.rds"))
message("Saved: ", file.path(raw_dir, "county_ed_1940_1980_us_raw.rds"),
        "  (", nrow(county_pre1990), " county-year rows)")


