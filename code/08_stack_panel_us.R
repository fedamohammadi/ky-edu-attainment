# =============================================================
# 08_stack_panel_us.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
#           NATIONAL EXTENSION
# Purpose : Stack the 1990/2000 decennial baseline onto the harmonized
#           2012-2024 ACS panel to make the full 1990-2024 spine, all on
#           2020 tracts. Then compute dispersion-over-time table.
# Inputs  : data/cleaned/us_ed_panel_harmonized_2012_2024.rds  (from 05_us)
#           data/cleaned/us_ed_decennial_1990_2000.rds         (from 07_us)
# Outputs : data/cleaned/us_ed_panel_full_1990_2024.rds
#           data/cleaned/us_ed_panel_full_1990_2024.dta
#           output/figures/us_ba_dispersion_1990_2024.png
#           output/figures/ky_ba_dispersion_1990_2024.png
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidyverse", "haven", "here")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(haven)
library(here)

cleaned_dir <- here("data", "cleaned")
fig_dir     <- here("output", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# ----- 1. Load harmonized inputs -----------------------------------
acs       <- readRDS(file.path(cleaned_dir, "us_ed_panel_harmonized_2012_2024.rds"))
decennial <- readRDS(file.path(cleaned_dir, "us_ed_decennial_1990_2000.rds"))

cat("ACS panel rows:      ", nrow(acs), "\n")
cat("Decennial panel rows:", nrow(decennial), "\n\n")

# ----- 2. Align schemas -------------------------------------------
# Both files should already have the same column names from 05_us and 07_us,
# but be defensive: coerce types, add data_source tag, ensure state_fips
# exists on both sides.
decennial_aligned <- decennial %>%
  mutate(
    data_source = "Decennial",
    state_fips  = substr(geoid, 1, 2)
  )

acs_aligned <- acs %>%
  mutate(
    data_source = "ACS 5-yr",
    state_fips  = substr(geoid, 1, 2)
  )

# ----- 3. Geoid overlap check -------------------------------------
common <- intersect(decennial_aligned$geoid, acs_aligned$geoid)
cat(sprintf("Geoid overlap: %d tracts\n", length(common)))
cat(sprintf("  Decennial unique geoids: %d\n",
            n_distinct(decennial_aligned$geoid)))
cat(sprintf("  ACS unique geoids:       %d\n",
            n_distinct(acs_aligned$geoid)))

# Expected overlap ~84,000 (nearly all 2020 tracts).
# If overlap is far below that, the tract ID formats differ.
if (length(common) < 80000) {
  cat("HEADS UP: low overlap. Sample geoids from each side:\n")
  print(head(sort(unique(decennial_aligned$geoid))))
  print(head(sort(unique(acs_aligned$geoid))))
}

# ----- 4. Stack ---------------------------------------------------
# bind_rows keeps only columns that exist in both. That's fine here.
panel <- bind_rows(acs_aligned, decennial_aligned) %>%
  arrange(geoid, year)

cat(sprintf("\nFull panel: %d rows, years: %s\n",
            nrow(panel),
            paste(sort(unique(panel$year)), collapse = ", ")))

# ----- 5. Save the stacked panel ----------------------------------
saveRDS(panel, file.path(cleaned_dir, "us_ed_panel_full_1990_2024.rds"))
write_dta(panel, file.path(cleaned_dir, "us_ed_panel_full_1990_2024.dta"))

# ----- 6. Dispersion of BA+ across tracts, by year ----------------
# Two dispersion measures, per your KY workflow:
#   P90-P10: absolute spread in percentage points
#   CV:      relative spread (sd/mean), unit-free
# Compute nationally AND for KY, so the KY series serves as a direct
# comparison with your existing report.

compute_disp <- function(df, group_label) {
  df %>%
    group_by(year, data_source) %>%
    summarise(
      n_tracts = sum(!is.na(pct_baplus)),
      mean_ba  = mean(pct_baplus, na.rm = TRUE),
      sd_ba    = sd(pct_baplus,   na.rm = TRUE),
      p10      = quantile(pct_baplus, 0.10, na.rm = TRUE),
      p90      = quantile(pct_baplus, 0.90, na.rm = TRUE),
      p90_p10  = p90 - p10,
      cv       = sd_ba / mean_ba,
      .groups  = "drop"
    ) %>%
    mutate(scope = group_label)
}

disp_us <- compute_disp(panel,                              "United States")
disp_ky <- compute_disp(panel %>% filter(state_fips == "21"), "Kentucky")

cat("\n--- National dispersion by year ---\n")
print(disp_us, n = Inf)

cat("\n--- Kentucky dispersion by year (should match your existing report) ---\n")
print(disp_ky, n = Inf)

# ----- 7. Figures --------------------------------------------------
# One figure per scope: P90-P10 gap over time, decennial vs. ACS
# distinguished by color, dashed line across the 2001-2011 gap.

make_disp_plot <- function(disp_df, title_txt, subtitle_txt) {
  # ACS-only series for the solid line
  acs_only <- disp_df %>% filter(data_source == "ACS 5-yr")
  # Bridge points: last decennial + first ACS, for the dashed segment
  bridge <- disp_df %>%
    filter((data_source == "Decennial" & year == 2000) |
             (data_source == "ACS 5-yr"  & year == 2012))
  
  ggplot(disp_df, aes(year, p90_p10)) +
    # Dashed segment: 1990 -> 2000 -> 2012 (the gap years)
    geom_line(data = disp_df %>% filter(data_source == "Decennial" | year == 2012),
              linetype = "22", color = "grey55") +
    # Solid segment: 2012 onward
    geom_line(data = acs_only, color = "grey40", linewidth = 0.6) +
    geom_point(aes(color = data_source), size = 2.6) +
    scale_color_manual(
      values = c("Decennial" = "#c0392b", "ACS 5-yr" = "#1f4e79"),
      name = NULL
    ) +
    labs(title    = title_txt,
         subtitle = subtitle_txt,
         x = NULL, y = "P90 - P10 (pp)") +
    theme_minimal(base_size = 12)
}

p_us <- make_disp_plot(
  disp_us,
  "Spatial dispersion in BA+ attainment, U.S. tracts, 1990-2024",
  "P90-P10 gap in tract BA+ share (percentage points)"
)

p_ky <- make_disp_plot(
  disp_ky,
  "Spatial dispersion in BA+ attainment, Kentucky tracts, 1990-2024",
  "P90-P10 gap in tract BA+ share (percentage points)"
)

ggsave(file.path(fig_dir, "us_ba_dispersion_1990_2024.png"), p_us,
       width = 8, height = 5, dpi = 150)
ggsave(file.path(fig_dir, "ky_ba_dispersion_1990_2024.png"), p_ky,
       width = 8, height = 5, dpi = 150)

message("Saved:")
message("  ", file.path(cleaned_dir, "us_ed_panel_full_1990_2024.rds"))
message("  ", file.path(cleaned_dir, "us_ed_panel_full_1990_2024.dta"))
message("  ", file.path(fig_dir, "us_ba_dispersion_1990_2024.png"))
message("  ", file.path(fig_dir, "ky_ba_dispersion_1990_2024.png"))



