# =============================================================
# 06_pull_decennial_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Read 1990 (STF3) and 2000 (SF3a) educational attainment from
#           the NHGIS extract you already downloaded manually. All U.S.
#           census tracts. Verify structure, run adding-up checks, save
#           to data/raw/ for the harmonization step.
# Source  : NHGIS extract nhgis0002 (manually downloaded, not API pull)
#           - 1990: ds123, table NP57 (E33001-E33007), tract level
#           - 2000: ds151, table NP037C (GKT001-GKT032), tract level
# Output  : data/raw/nhgis_national/ed_1990_us_raw.rds
#           data/raw/nhgis_national/ed_2000_us_raw.rds
# Note    : Unlike the KY script, we do NOT call the NHGIS API here.
#           The files are already on disk. This script just reads,
#           verifies, and saves.
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("ipumsr", "dplyr", "readr", "here", "stringr")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(ipumsr)
library(dplyr)
library(readr)
library(here)
library(stringr)

# ----- 1. Paths ----------------------------------------------------
raw_dir <- here("data", "raw", "nhgis_national")

# NHGIS names extracted CSVs like nhgis0002_ds123_1990_tract.csv.
# If Windows is hiding extensions, they may look extensionless in Explorer
# but are actually .csv. Handle both cases.
find_file <- function(pattern, dir = raw_dir) {
  hits <- list.files(dir, pattern = pattern, full.names = TRUE,
                     ignore.case = TRUE)
  # Prefer .csv over codebook .txt
  csv <- hits[str_detect(hits, "\\.csv$")]
  if (length(csv) >= 1) return(csv[1])
  # Fallback: any file that isn't a codebook
  hits <- hits[!str_detect(hits, "codebook")]
  if (length(hits) >= 1) return(hits[1])
  stop("Could not find file matching pattern: ", pattern)
}

file_1990 <- find_file("ds123_1990_tract")
file_2000 <- find_file("ds151_2000_tract")

cat("1990 file:", file_1990, "\n")
cat("2000 file:", file_2000, "\n\n")

# ----- 2. Read 1990 ------------------------------------------------
# NP57: Educational Attainment, persons 25+, 7 categories
#   E33001: Less than 9th grade
#   E33002: 9th to 12th grade, no diploma
#   E33003: High school graduate (or equivalent)
#   E33004: Some college, no degree
#   E33005: Associate degree
#   E33006: Bachelor's degree
#   E33007: Graduate or professional degree
# BA+ = E33006 + E33007
# Total 25+ = sum(E33001:E33007)

ed_1990 <- read_nhgis(file_1990, verbose = FALSE)

edu_cols_1990 <- paste0("E33", sprintf("%03d", 1:7))
stopifnot("GISJOIN" %in% names(ed_1990),
          all(edu_cols_1990 %in% names(ed_1990)))

ed_1990 <- ed_1990 %>%
  mutate(
    pop_25plus = rowSums(across(all_of(edu_cols_1990)), na.rm = TRUE),
    ba_plus    = E33006 + E33007
  )

cat("--- 1990 read summary ---\n")
cat("Rows (tracts): ", nrow(ed_1990), "\n")
cat("States present:", n_distinct(ed_1990$STATEA), "\n")
cat("Nat'l BA+ share (pop-weighted): ",
    round(sum(ed_1990$ba_plus) / sum(ed_1990$pop_25plus) * 100, 2), "%\n\n")

# ----- 3. Read 2000 ------------------------------------------------
# NP037C: Pop 25+ by Sex by Educational Attainment, 32 columns
#   GKT001-GKT016: Male, 16 education categories
#   GKT017-GKT032: Female, same 16 education categories
# Male BA+   = GKT013 + GKT014 + GKT015 + GKT016
# Female BA+ = GKT029 + GKT030 + GKT031 + GKT032
# Total 25+  = sum(GKT001:GKT032)

ed_2000 <- read_nhgis(file_2000, verbose = FALSE)

edu_cols_2000 <- paste0("GKT", sprintf("%03d", 1:32))
stopifnot("GISJOIN" %in% names(ed_2000),
          all(edu_cols_2000 %in% names(ed_2000)))

ed_2000 <- ed_2000 %>%
  mutate(
    pop_25plus = rowSums(across(all_of(edu_cols_2000)), na.rm = TRUE),
    ba_plus    = GKT013 + GKT014 + GKT015 + GKT016 +   # male
      GKT029 + GKT030 + GKT031 + GKT032     # female
  )

cat("--- 2000 read summary ---\n")
cat("Rows (tracts): ", nrow(ed_2000), "\n")
cat("States present:", n_distinct(ed_2000$STATEA), "\n")
cat("Nat'l BA+ share (pop-weighted): ",
    round(sum(ed_2000$ba_plus) / sum(ed_2000$pop_25plus) * 100, 2), "%\n\n")

# ----- 4. Benchmark against published totals -----------------------
# Published national BA+ (adults 25+):
#   1990 Census: ~20.3%
#   2000 Census: ~24.4%
# Source: NCES Digest of Education Statistics, Table 104.10.
# If our numbers are off by more than 0.5pp, something is wrong.

ba_1990 <- sum(ed_1990$ba_plus) / sum(ed_1990$pop_25plus) * 100
ba_2000 <- sum(ed_2000$ba_plus) / sum(ed_2000$pop_25plus) * 100

cat("--- Benchmark check ---\n")
cat(sprintf("1990: computed %.2f%%   published ~20.3%%   diff %+.2f pp\n",
            ba_1990, ba_1990 - 20.3))
cat(sprintf("2000: computed %.2f%%   published ~24.4%%   diff %+.2f pp\n\n",
            ba_2000, ba_2000 - 24.4))

if (abs(ba_1990 - 20.3) > 0.5 || abs(ba_2000 - 24.4) > 0.5) {
  warning("Benchmark check FAILED. Computed shares are off by more than 0.5pp.")
} else {
  message("Benchmark check passed.")
}

# ----- 5. Kentucky replication check -------------------------------
# The KY subset of this national file must match your existing KY numbers.
# From your Week 1 report: 13.6% BA+ in 1990, 17.1% BA+ in 2000 (KY, pop-wtd).

ky_1990 <- ed_1990 %>% filter(STATEA == "21")
ky_2000 <- ed_2000 %>% filter(STATEA == "21")

ba_ky_1990 <- sum(ky_1990$ba_plus) / sum(ky_1990$pop_25plus) * 100
ba_ky_2000 <- sum(ky_2000$ba_plus) / sum(ky_2000$pop_25plus) * 100

cat("--- Kentucky replication check ---\n")
cat(sprintf("KY 1990: %d tracts, BA+ = %.2f%%   (report: 13.6%%)\n",
            nrow(ky_1990), ba_ky_1990))
cat(sprintf("KY 2000: %d tracts, BA+ = %.2f%%   (report: 17.1%%)\n\n",
            nrow(ky_2000), ba_ky_2000))

# Note: these are pre-harmonization numbers on 1990 and 2000 native tract
# boundaries, not on 2020 boundaries. Small differences from your report
# are expected. Large differences (>1pp) are a red flag.

# ----- 6. Save -----------------------------------------------------
saveRDS(ed_1990, file.path(raw_dir, "ed_1990_us_raw.rds"))
saveRDS(ed_2000, file.path(raw_dir, "ed_2000_us_raw.rds"))

message("Saved:")
message("  ", file.path(raw_dir, "ed_1990_us_raw.rds"),
        "  (", nrow(ed_1990), " tracts)")
message("  ", file.path(raw_dir, "ed_2000_us_raw.rds"),
        "  (", nrow(ed_2000), " tracts)")


