# ---------------------------------------------------------------
# 13_ipeds_pilot_2024.R
#
# Pilot pull of IPEDS Completions for one year (2024), Kentucky.
# Verifies the pipeline (filter, join, aggregate) on one year
# before scaling to 34 years.
#
# Inputs (place in data/raw/ipeds/):
#   c2024_a.csv  - Completions "A" file (awards by CIP x award level)
#   hd2024.csv   - Institutional directory (with county FIPS)
#
# Output: data/cleaned/ipeds_ky_county_2024.rds
# ---------------------------------------------------------------

library(tidyverse)

# --- 1. Paths --------------------------------------------------
ipeds_dir <- "data/raw/ipeds"
clean_dir <- "data/cleaned"

# --- 2. Load HD (institutional directory) ---------------------
# Key columns:
#   UNITID    institution ID
#   INSTNM    institution name
#   STABBR    state abbreviation
#   COUNTYCD  5-digit county FIPS (this is what we aggregate to)
#   COUNTYNM  county name
hd <- read_csv(
  file.path(ipeds_dir, "hd2024.csv"),
  show_col_types = FALSE,
  locale = locale(encoding = "latin1")   # IPEDS often uses Latin-1
)

hd_ky <- hd %>%
  filter(STABBR == "KY") %>%
  select(UNITID, INSTNM, COUNTYCD, COUNTYNM)

cat("KY institutions in HD 2024:", nrow(hd_ky), "\n")

# --- 3. Load Completions --------------------------------------
# Key columns:
#   UNITID   institution ID
#   CIPCODE  program field (6-digit CIP)
#   MAJORNUM 1 = first major, 2 = second major
#            Filter to 1 to avoid double-counting students with two majors.
#   AWLEVEL  award level. Common codes in recent years:
#              3  = Associate's
#              5  = Bachelor's
#              7  = Master's
#              17 = Doctorate (research/scholarship)
#              18 = Doctorate (professional practice)
#            Check the dictionary that came with c2024_a.zip
#            since codes have shifted historically.
#   CTOTALT  total awards conferred (across all demographics)
comp <- read_csv(
  file.path(ipeds_dir, "c2024_a.csv"),
  show_col_types = FALSE,
  locale = locale(encoding = "latin1")
)

comp_ky <- comp %>%
  filter(UNITID %in% hd_ky$UNITID) %>%
  filter(MAJORNUM == 1)

cat("KY completion rows (first-major only):", nrow(comp_ky), "\n")

# --- 4. Join + aggregate to county x award level --------------
county_panel <- comp_ky %>%
  left_join(hd_ky, by = "UNITID") %>%
  group_by(COUNTYCD, COUNTYNM, AWLEVEL) %>%
  summarise(n_awards = sum(CTOTALT, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(year = 2024)

# --- 5. Sanity checks -----------------------------------------
# Top-10 KY institutions by bachelor's production.
# Expect: UK, U of L, WKU, EKU, Murray State, NKU, Morehead State,
# Berea, plus a couple of privates. If those don't appear at the top,
# something is wrong upstream.
cat("\n--- Top 10 KY institutions by bachelor's degrees (2024) ---\n")
top_bachelors <- comp_ky %>%
  filter(AWLEVEL == 5) %>%
  left_join(hd_ky, by = "UNITID") %>%
  group_by(UNITID, INSTNM, COUNTYNM) %>%
  summarise(total_bachelors = sum(CTOTALT, na.rm = TRUE),
            .groups = "drop") %>%
  arrange(desc(total_bachelors)) %>%
  head(10)
print(top_bachelors)

cat("\n--- County x award level panel (first 15 rows) ---\n")
print(head(county_panel, 15))

cat("\nTotal county x awardlevel rows:", nrow(county_panel), "\n")
cat("Distinct KY counties producing degrees:",
    length(unique(county_panel$COUNTYCD)), "\n")
cat("Distinct award levels observed:",
    length(unique(county_panel$AWLEVEL)), "\n")

# --- 6. Save --------------------------------------------------
if (!dir.exists(clean_dir)) dir.create(clean_dir, recursive = TRUE)
saveRDS(county_panel, file.path(clean_dir, "ipeds_ky_county_2024.rds"))
cat("\nSaved: data/cleaned/ipeds_ky_county_2024.rds\n")



comp_ky %>%
  left_join(hd_ky, by = "UNITID") %>%
  filter(COUNTYCD == 21001, AWLEVEL == 7) %>%
  group_by(UNITID, INSTNM) %>%
  summarise(n = sum(CTOTALT, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(n))





