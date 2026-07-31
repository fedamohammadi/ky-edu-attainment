# =============================================================
# 23_plot_sector_shares.R
# Purpose : Plot national employment shares for selected NAICS
#           sectors, 1990-2018.
# Inputs  : data/cleaned/cbp_sector_shares_1990_2018.rds
# Output  : output/figures/sector_shares_1990_2018.png
# =============================================================

library(tidyverse)
library(here)

cleaned_dir <- here("data", "cleaned")
fig_dir     <- here("output", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

cbp <- readRDS(file.path(cleaned_dir, "cbp_sector_shares_1990_2018.rds"))

sectors_to_show <- c(
  "manufacturing", "healthcare", "professional",
  "retail", "agriculture", "education"
)

national <- cbp %>%
  select(county_fips, year, total_emp,
         all_of(paste0("share_", sectors_to_show))) %>%
  pivot_longer(cols = starts_with("share_"),
               names_to = "sector",
               names_prefix = "share_",
               values_to = "share_pct") %>%
  mutate(sector_emp = share_pct / 100 * total_emp) %>%
  group_by(year, sector) %>%
  summarise(
    natl_share = 100 * sum(sector_emp, na.rm = TRUE) /
      sum(total_emp,  na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(sector = factor(sector,
                         levels = c("manufacturing", "healthcare",
                                    "professional", "retail",
                                    "education", "agriculture"),
                         labels = c("Manufacturing", "Healthcare",
                                    "Professional services", "Retail",
                                    "Education", "Agriculture")))

p <- ggplot(national, aes(x = year, y = natl_share,
                          color = sector, group = sector)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.8) +
  scale_color_manual(
    values = c(
      "Manufacturing"          = "#c67c1e",
      "Healthcare"             = "#1f4e79",
      "Professional services"  = "#4b7f52",
      "Retail"                 = "#7a3e3e",
      "Education"              = "#7d5497",
      "Agriculture"            = "#606060"
    ),
    name = NULL
  ) +
  scale_x_continuous(breaks = seq(1998, 2016, by = 1)) +
  scale_y_continuous(labels = scales::label_percent(scale = 1, accuracy = 1),
                     limits = c(0, 22),
                     breaks = seq(0, 20, by = 5)) +
  labs(
    title = "U.S. employment shares by industry sector, 1998-2016",
    subtitle = "National shares, weighted by county employment.",
    x        = NULL,
    y        = "Share of total employment",
    caption  = "Source: Eckert et al. harmonized County Business Patterns panel."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position    = "bottom",
    legend.text        = element_text(size = 11),
    plot.title         = element_text(face = "bold"),
    plot.subtitle      = element_text(color = "grey30"),
    plot.caption       = element_text(color = "grey40", size = 9, hjust = 0),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.text.x        = element_text(angle = 45, hjust = 1)
  )

ggsave(file.path(fig_dir, "sector_shares_1990_2018.png"), p,
       width = 11, height = 5.5, dpi = 200)

message("Saved: ", file.path(fig_dir, "sector_shares_1990_2018.png"))
print(p)





















