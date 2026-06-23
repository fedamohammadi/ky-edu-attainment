# 07_harmonize_decennial.R ------------------------------------------------------
# Put the 1990 and 2000 educational-attainment counts onto 2020 census tracts,
# so they stack onto the harmonized 2012-2024 ACS panel.
#
# THE CHAIN (NHGIS anchors on 2010, so we go through it; weights = wt_adult,
# the 18+ proxy used in Phase 2; we always crosswalk COUNTS, shares only at end):
#   1990/2000 block group parts  --wt_adult-->  2010 tracts  --wt_adult-->  2020 tracts
#                 (leg 1: bgp -> tr2010 crosswalk)   (leg 2: your Phase 2 tr2010 -> tr2020 file)
# -------------------------------------------------------------------------------

library(ipumsr)
library(dplyr)
library(readr)
library(here)
library(haven)

raw_dir     <- here("data", "raw")
cleaned_dir <- here("data", "cleaned")

# --- Read the education data back from the NHGIS zip (labels come with it) -----
zip_path <- list.files(raw_dir, pattern = "^nhgis.*csv\\.zip$", full.names = TRUE)[1]
ed_1990  <- read_ipums_agg(zip_path, file_select = matches("1990_blck_grp"))
ed_2000  <- read_ipums_agg(zip_path, file_select = matches("2000_blck_grp"))

# --- Read the three crosswalks; force ID columns to character to be safe -------
cw_1990 <- read_csv(file.path(raw_dir, "nhgis_bgp1990_tr2010_21.csv"),
                    col_types = cols(tr2010ge = col_character()))
cw_2000 <- read_csv(file.path(raw_dir, "nhgis_bgp2000_tr2010_21.csv"),
                    col_types = cols(tr2010ge = col_character()))
# Phase 2 file (the one you harmonized 2012-2024 on). Confirm the exact name.
cw_1020 <- read_csv(file.path(raw_dir, "nhgis_tr2010_tr2020_21.csv"),
                    col_types = cols(tr2010ge = col_character(),
                                     tr2020ge = col_character()))

# --- Column maps (verified against labels just below) --------------------------
ba_1990  <- c("E33006", "E33007")                 # bachelor's, graduate/professional
sc_1990  <- c("E33004", "E33005")                 # some college (no degree), associate
all_1990 <- sprintf("E330%02d", 1:7)              # all 7 categories -> pop 25+

ba_2000  <- c("HD1013","HD1014","HD1015","HD1016", # M: BA, MA, prof, doctorate
              "HD1029","HD1030","HD1031","HD1032") # F: same four
sc_2000  <- c("HD1010","HD1011","HD1012",          # M: some coll <1yr, 1+yr, associate
              "HD1026","HD1027","HD1028")          # F: same three
all_2000 <- sprintf("HD10%02d", 1:32)              # all 32 cells -> pop 25+

# VERIFY THE MAP BEFORE TRUSTING IT. These should read as bachelor/master/prof/
# doctorate and some-college/associate. If any label is off, stop and fix.
cat("\n--- 1990 BA+ and some-college columns ---\n")
ipums_var_info(ed_1990) |> filter(var_name %in% c(ba_1990, sc_1990)) |>
  select(var_name, var_label) |> print(n = Inf)
cat("\n--- 2000 BA+ and some-college columns ---\n")
ipums_var_info(ed_2000) |> filter(var_name %in% c(ba_2000, sc_2000)) |>
  select(var_name, var_label) |> print(n = Inf)

# --- GISJOIN match check: does the data key line up with the crosswalk key? ----
# This is the real risk (blck_grp_598 vs _101 naming). Want ~1.0.
m1990 <- mean(ed_1990$GISJOIN %in% cw_1990$bgp1990gj)
m2000 <- mean(ed_2000$GISJOIN %in% cw_2000$bgp2000gj)
cat(sprintf("\nGISJOIN match rate: 1990 = %.4f, 2000 = %.4f\n", m1990, m2000))
stopifnot(m1990 > 0.95, m2000 > 0.95)   # if this trips, the keys don't align; stop

# --- The harmonizer: one function, run once per year ---------------------------
harmonize_one <- function(ed, cw_bgp, src_col, ba_cols, sc_cols, all_cols, yr) {
  
  # 1. Collapse to three counts at the block-group-part level.
  bgp <- ed |>
    transmute(
      gj  = GISJOIN,
      ba  = rowSums(across(all_of(ba_cols))),
      sc  = rowSums(across(all_of(sc_cols))),
      pop = rowSums(across(all_of(all_cols)))
    )
  tot_in <- sum(bgp$pop)
  
  # 2. Leg 1: BGP -> 2010 tract. Move counts with wt_adult, sum onto tr2010.
  leg1 <- bgp |>
    inner_join(cw_bgp, by = c("gj" = src_col)) |>
    mutate(across(c(ba, sc, pop), ~ .x * wt_adult)) |>
    group_by(tr2010ge) |>
    summarise(across(c(ba, sc, pop), ~ sum(.x, na.rm = TRUE)), .groups = "drop")
  
  # 3. Leg 2: 2010 tract -> 2020 tract, reusing the Phase 2 crosswalk + wt_adult.
  leg2 <- leg1 |>
    inner_join(cw_1020, by = "tr2010ge") |>
    mutate(across(c(ba, sc, pop), ~ .x * wt_adult)) |>
    group_by(tr2020ge) |>
    summarise(across(c(ba, sc, pop), ~ sum(.x, na.rm = TRUE)), .groups = "drop")
  
  # 4. Conservation: population should survive both legs (allocation weights sum to 1).
  cat(sprintf("[%d] pop in = %.0f | after leg1 = %.0f | after leg2 = %.0f | drift = %.2e\n",
              yr, tot_in, sum(leg1$pop), sum(leg2$pop),
              abs(sum(leg2$pop) - tot_in) / tot_in))
  
  # 5. Shares only now, on 2020 tracts. Zero-pop tract -> NA, not 0 (codebook rule).
  leg2 |>
    mutate(
      year         = yr,
      pct_baplus   = if_else(pop > 0, 100 * ba / pop, NA_real_),
      pct_somecoll = if_else(pop > 0, 100 * sc / pop, NA_real_)
    ) |>
    rename(ba_plus = ba, somecoll_assoc = sc, pop25plus = pop)
}

panel_1990 <- harmonize_one(ed_1990, cw_1990, "bgp1990gj",
                            ba_1990, sc_1990, all_1990, 1990L)
panel_2000 <- harmonize_one(ed_2000, cw_2000, "bgp2000gj",
                            ba_2000, sc_2000, all_2000, 2000L)

decennial <- bind_rows(panel_1990, panel_2000) |>
  arrange(year, tr2020ge)

cat(sprintf("\n1990 tracts: %d | 2000 tracts: %d (target ~1306)\n",
            nrow(panel_1990), nrow(panel_2000)))
cat(sprintf("Mean BA+ share: 1990 = %.1f%%, 2000 = %.1f%%\n",
            mean(panel_1990$pct_baplus, na.rm = TRUE),
            mean(panel_2000$pct_baplus, na.rm = TRUE)))

# --- Save ----------------------------------------------------------------------
saveRDS(decennial, file.path(cleaned_dir, "ky_ed_decennial_1990_2000.rds"))
write_dta(decennial, file.path(cleaned_dir, "ky_ed_decennial_1990_2000.dta"))


# Pop-weighted statewide BA+ from the raw counts = the true census aggregate
sum(rowSums(ed_1990[ba_1990])) / sum(rowSums(ed_1990[all_1990])) * 100
sum(rowSums(ed_2000[ba_2000])) / sum(rowSums(ed_2000[all_2000])) * 100


