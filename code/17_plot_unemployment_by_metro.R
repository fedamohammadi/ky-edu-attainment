# =============================================================
# 17_plot_unemployment_by_metro.R
# Purpose : Plot annual unemployment rate by metro status,
#           1990-2024, with recession shading. Save as PNG.
# Inputs  : data/cleaned/us_ed_county_panel_long_1940_2024_rucc_laus.rds
# Output  : output/figures/unemp_by_metro_1990_2024.png
# =============================================================

pkgs <- c("tidyverse", "here", "scales")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidyverse)
library(here)
library(scales)

cleaned_dir <- here("data", "cleaned")
fig_dir     <- here("output", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

panel <- readRDS(file.path(cleaned_dir,
                           "us_ed_county_panel_long_1940_2024_rucc_laus.rds"))

# Population-weighted unemployment rate by metro status and year.
# Using labor_force as the weight, which is the standard way BLS aggregates.
series <- panel %>%
  filter(year >= 1990, !is.na(metro_status), !is.na(unemp_rate)) %>%
  group_by(year, metro_status) %>%
  summarise(
    unemp_rate = 100 * sum(unemployed,  na.rm = TRUE) /
      sum(labor_force, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(metro_status = factor(metro_status,
                               levels = c("Metro",
                                          "Nonmetro with city",
                                          "Rural")))

# NBER recession years (annual averages).
recessions <- tibble(
  start = c(1990, 2001, 2008, 2020),
  end   = c(1991, 2001, 2009, 2020),
  label = c("1990-91", "2001", "2008-09", "COVID")
)

p <- ggplot(series, aes(x = year, y = unemp_rate,
                        color = metro_status, group = metro_status)) +
  geom_rect(data = recessions,
            aes(xmin = start - 0.5, xmax = end + 0.5,
                ymin = -Inf, ymax = Inf),
            inherit.aes = FALSE,
            fill = "grey85", alpha = 0.5) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.6) +
  scale_color_manual(
    values = c("Metro"              = "#1f4e79",
               "Nonmetro with city" = "#c67c1e",
               "Rural"              = "#7a3e3e"),
    name = NULL
  ) +
  scale_x_continuous(breaks = seq(1990, 2024, by = 5)) +
  scale_y_continuous(labels = label_percent(scale = 1, accuracy = 1),
                     limits = c(0, 11),
                     breaks = seq(0, 10, by = 2)) +
  labs(
    title    = "Unemployment rate by metro status, U.S. counties, 1990-2024",
    subtitle = "Population-weighted by labor force. Shaded bands mark recession years.",
    x = NULL,
    y = "Unemployment rate",
    caption = "Source: BLS LAUS annual county averages; USDA RUCC (nearest edition)."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "top",
    legend.text       = element_text(size = 11),
    plot.title        = element_text(face = "bold"),
    plot.subtitle     = element_text(color = "grey30"),
    plot.caption      = element_text(color = "grey40", size = 9, hjust = 0),
    panel.grid.minor  = element_blank(),
    panel.grid.major.x = element_blank()
  )

ggsave(file.path(fig_dir, "unemp_by_metro_1990_2024.png"), p,
       width = 9, height = 5.2, dpi = 200)

message("Saved: ", file.path(fig_dir, "unemp_by_metro_1990_2024.png"))
print(p)
