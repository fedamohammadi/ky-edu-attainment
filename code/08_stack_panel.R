# 08_stack_panel.R --------------------------------------------------------------
# Stack the 1990/2000 decennial baseline onto the harmonized 2012-2024 ACS panel
# to make the full 1990-2024 spine, all on 2020 tracts. Then compute the
# dispersion-over-time table that answers the research question: did the spatial
# gap in BA+ attainment widen (divergence) or narrow (convergence)?
# -------------------------------------------------------------------------------

library(here)
library(dplyr)
library(ggplot2)
library(haven)

cleaned_dir <- here("data", "cleaned")
fig_dir     <- here("output", "figures")

acs       <- readRDS(file.path(cleaned_dir, "ky_ed_panel_harmonized_2012_2024.rds"))
decennial <- readRDS(file.path(cleaned_dir, "ky_ed_decennial_1990_2000.rds"))

# --- Align the decennial file to the ACS panel's columns -----------------------
decennial_aligned <- decennial |>
  rename(geoid = tr2020ge) |>
  mutate(
    hs_or_less       = pop25plus - ba_plus - somecoll_assoc,   # 3 groups partition pop 25+
    pct_hs_or_less   = if_else(pop25plus > 0, 100 * hs_or_less / pop25plus, NA_real_),
    boundary_vintage = "2020 (harmonized, 2-leg)",
    data_source      = "Decennial"
  )

acs_aligned <- acs |>
  mutate(data_source = "ACS 5-yr")

# --- Confirm the tract keys are the same 2020 universe before binding ----------
common <- intersect(decennial_aligned$geoid, acs_aligned$geoid)
cat(sprintf("geoid overlap: %d tracts (decennial has %d unique, ACS has %d unique)\n",
            length(common),
            dplyr::n_distinct(decennial_aligned$geoid),
            dplyr::n_distinct(acs_aligned$geoid)))
# If overlap is far below ~1306, the tract id formats differ; inspect a few:
if (length(common) < 1300) {
  cat("HEADS UP: low overlap. Sample geoids:\n")
  print(head(sort(unique(decennial_aligned$geoid))))
  print(head(sort(unique(acs_aligned$geoid))))
}

# --- Stack into the full 1990-2024 spine ---------------------------------------
panel <- bind_rows(acs_aligned, decennial_aligned) |>
  arrange(geoid, year)

cat(sprintf("Full panel: %d rows, years %s\n",
            nrow(panel), paste(sort(unique(panel$year)), collapse = ", ")))

saveRDS(panel, file.path(cleaned_dir, "ky_ed_panel_full_1990_2024.rds"))
write_dta(panel, file.path(cleaned_dir, "ky_ed_panel_full_1990_2024.dta"))

# --- THE QUESTION: dispersion of BA+ across tracts, by year --------------------
# P90-P10 is the absolute spread (pp). CV = sd/mean is the RELATIVE spread.
# Watch both: if only the absolute gap grows while CV is flat, the "divergence"
# is partly just the rising mean lifting the whole distribution. If both grow,
# divergence is real in level and in relative terms.
disp <- panel |>
  group_by(year, data_source) |>
  summarise(
    n_tracts = sum(!is.na(pct_baplus)),
    mean_ba  = mean(pct_baplus, na.rm = TRUE),
    sd_ba    = sd(pct_baplus,   na.rm = TRUE),
    p10      = quantile(pct_baplus, 0.10, na.rm = TRUE),
    p90      = quantile(pct_baplus, 0.90, na.rm = TRUE),
    p90_p10  = p90 - p10,
    cv       = sd_ba / mean_ba,
    .groups  = "drop"
  )
print(disp, n = Inf)

# --- Quick exploratory figure (the polished version can go to Stata, ext. 03) --
# Decennial points are colored differently and the line is dashed across the
# 2001-2011 gap, so the figure doesn't pretend we have data we don't.
p <- ggplot(disp, aes(year, p90_p10)) +
  geom_line(linetype = "22", color = "grey55") +
  geom_point(aes(color = data_source), size = 2.6) +
  scale_color_manual(values = c("Decennial" = "#c0392b", "ACS 5-yr" = "#1f4e79"),
                     name = NULL) +
  labs(title    = "Spatial dispersion in BA+ attainment, Kentucky tracts, 1990-2024",
       subtitle = "P90-P10 gap in tract BA+ share (percentage points)",
       x = NULL, y = "P90 - P10 (pp)") +
  theme_minimal(base_size = 12)

ggsave(file.path(fig_dir, "ba_dispersion_1990_2024.png"), p,
       width = 8, height = 5, dpi = 150)



