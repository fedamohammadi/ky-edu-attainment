# =============================================================
# 22_parse_merge_cbp.R  (v2 — aggregate up from 6-digit)
# Fix: The 2-digit sector rows "NN----" only exist in the raw file
# for 1990-1997 and are partial. We aggregate up from ALL sub-codes
# to the 2-digit sector level using the first 2 characters of naics12.
# =============================================================

library(data.table)
library(tidyverse)
library(haven)
library(here)

cbp_file    <- here("data", "raw", "eckert_cbp", "efsy_panel_naics.csv")
cleaned_dir <- here("data", "cleaned")

# ----- 1. Read ----------------------------------------------------
cat("Reading Eckert CBP file...\n")
t0 <- Sys.time()
cbp <- fread(cbp_file,
             select = c("fipstate", "fipscty", "naics12", "emp", "year"))
cat("Read in", format(round(Sys.time() - t0, 1)), "\n")

# ----- 2. Filter to years we care about, drop pre-aggregated rows -
# Eckert coverage is truly usable only for 1998-2016:
#   - 1990-1997 use SIC codes reshaped as NAICS, producing artificial
#     breaks in manufacturing shares (28% pre-1998 vs 16% post).
#   - 2017-2018 use a different Census reporting methodology (cell
#     perturbation) that breaks comparability with earlier years.
# See Eckert et al. readme for details.
cbp <- cbp[year >= 1998 & year <= 2016]
cbp <- cbp[!grepl("[-/]", naics12)]   # keep only pure 6-digit codes

# Clip negative employment (imputation artifacts)
cbp[emp < 0, emp := 0]

cat("Rows after filter:", format(nrow(cbp), big.mark = ","), "\n")

# ----- 3. Derive 2-digit sector and county FIPS -------------------
# NAICS convention: 31, 32, 33 all = Manufacturing, so collapse them.
# 44 & 45 = Retail. 48 & 49 = Transportation. Others map 1-to-1.
cbp[, sector2 := substr(naics12, 1, 2)]
cbp[sector2 %in% c("32", "33"), sector2 := "31"]
cbp[sector2 == "45",             sector2 := "44"]
cbp[sector2 == "49",             sector2 := "48"]

cbp[, county_fips := sprintf("%02d%03d", fipstate, fipscty)]

# ----- 4. Sum employment by county-year-sector --------------------
cat("Aggregating to 2-digit sectors...\n")
by_sector <- cbp[, .(emp = sum(emp, na.rm = TRUE)),
                 by = .(county_fips, year, sector2)]

# ----- 5. Sector labels -------------------------------------------
naics_labels <- c(
  "11" = "agriculture",     "21" = "mining",         "22" = "utilities",
  "23" = "construction",    "31" = "manufacturing",  "42" = "wholesale",
  "44" = "retail",          "48" = "transport",      "51" = "info",
  "52" = "finance",         "53" = "realestate",     "54" = "professional",
  "55" = "management",      "56" = "admin_waste",    "61" = "education",
  "62" = "healthcare",      "71" = "arts",           "72" = "accommodation",
  "81" = "other_services",  "92" = "public_admin"
)

by_sector <- by_sector[sector2 %in% names(naics_labels)]
by_sector[, sector := naics_labels[sector2]]

# ----- 6. Pivot wide, compute shares -----------------------------
cbp_wide <- dcast(by_sector,
                  county_fips + year ~ sector,
                  value.var = "emp",
                  fun.aggregate = sum,
                  fill = 0)

# Use only sectors that actually exist in the wide file.
# CBP does not cover public administration (sector 92 = federal govt).
sector_cols <- intersect(unname(naics_labels), names(cbp_wide))
cat("Sectors present:", length(sector_cols), "\n")
cat("Sectors missing from CBP:",
    setdiff(unname(naics_labels), sector_cols), "\n\n")

cbp_wide[, total_emp := rowSums(.SD, na.rm = TRUE), .SDcols = sector_cols]

for (s in sector_cols) {
  cbp_wide[, (paste0("share_", s)) :=
             ifelse(total_emp > 0, 100 * get(s) / total_emp, NA_real_)]
}

share_cols <- paste0("share_", sector_cols)
cbp_final <- cbp_wide[, c("county_fips", "year", "total_emp", share_cols),
                      with = FALSE]

cat("Sector-share panel:", nrow(cbp_final), "rows,",
    n_distinct(cbp_final$year), "years\n")

# ----- 7. Sanity ---------------------------------------------------
cat("\n--- Weighted national shares, selected years ---\n")
national_check <- cbp_final |>
  as_tibble() |>
  select(year, total_emp,
         share_manufacturing, share_healthcare, share_professional,
         share_retail, share_education, share_agriculture) |>
  pivot_longer(cols = starts_with("share_"),
               names_to = "sector",
               names_prefix = "share_",
               values_to = "share_pct") |>
  mutate(sector_emp = share_pct / 100 * total_emp) |>
  group_by(year, sector) |>
  summarise(natl_share = 100 * sum(sector_emp, na.rm = TRUE) /
              sum(total_emp,  na.rm = TRUE),
            .groups = "drop") |>
  filter(year %in% c(1990, 2000, 2010, 2018)) |>
  pivot_wider(names_from = sector, values_from = natl_share)
print(national_check)

# ----- 8. Save standalone --------------------------------------
saveRDS(as_tibble(cbp_final),
        file.path(cleaned_dir, "cbp_sector_shares_1990_2018.rds"))

# ----- 9. Merge into long panel --------------------------------
panel <- readRDS(file.path(cleaned_dir,
                           "us_ed_county_panel_long_1940_2024_full.rds"))
panel_cbp <- panel %>%
  left_join(as_tibble(cbp_final), by = c("county_fips", "year"))

cat("\n--- Coverage after merge ---\n")
panel_cbp %>%
  group_by(year) %>%
  summarise(n_counties = n(),
            n_with_cbp = sum(!is.na(total_emp)),
            pct_missing = round(100 * mean(is.na(total_emp)), 1),
            .groups = "drop") %>%
  print(n = Inf)

# ----- 10. Save -----------------------------------------------------
saveRDS(panel_cbp,
        file.path(cleaned_dir,
                  "us_ed_county_panel_long_1940_2024_full_cbp.rds"))
write_dta(panel_cbp,
          file.path(cleaned_dir,
                    "us_ed_county_panel_long_1940_2024_full_cbp.dta"))

message("Saved:")
message("  ", file.path(cleaned_dir, "cbp_sector_shares_1990_2018.rds"))
message("  ", file.path(cleaned_dir,
                        "us_ed_county_panel_long_1940_2024_full_cbp.rds"))
message("  ", file.path(cleaned_dir,
                        "us_ed_county_panel_long_1940_2024_full_cbp.dta"))


