# =============================================================
# 04_map_levels.R
# Project : Kentucky Educational Attainment (ky-ed-attainment)
# Purpose : Map the LEVEL of educational attainment across Kentucky tracts
#           in the most recent year (2024), on 2020 boundaries. No crosswalk
#           needed: 2020-2024 are all already on 2020 tract geography.
# Note    : This is a LEVELS map (where attainment stands now), not a change
#           map. 2020 and 2024 ACS 5-year windows overlap by 4 years, so a
#           5-year "change" would be small and partly mechanical.
# Input   : pulls geometry fresh from the Census API (needs your key set)
#           data/cleaned/ky_ed_panel_2012_2024.rds  (for the attainment shares)
# Output  : output/figures/map_baplus_2024.png
#           output/figures/map_somecoll_2024.png
# =============================================================

# ----- 0. Packages -------------------------------------------------
pkgs <- c("tidycensus", "tidyverse", "sf")
to_install <- pkgs[!pkgs %in% installed.packages()[, "Package"]]
if (length(to_install) > 0) install.packages(to_install)
library(tidycensus)
library(tidyverse)
library(sf)        # handles spatial / map geometry

# ----- 1. Pull tract geometry + total pop for 2024 -----------------
# geometry = TRUE attaches the tract polygons. We only need one variable here
# (total pop, B15003_001) just to have a valid pull; the shares come from our
# own clean panel so the map uses the SAME numbers we already verified.
ky_geo <- get_acs(
  geography = "tract",
  variables = "B15003_001",
  state     = "21",
  year      = 2024,
  survey    = "acs5",
  geometry  = TRUE,
  output    = "wide"
) %>%
  select(geoid = GEOID, geometry)   # keep just the id and the shape

# ----- 2. Attach our verified 2024 shares to the geometry ----------
panel <- readRDS("data/cleaned/ky_ed_panel_2012_2024.rds")

map_data <- panel %>%
  filter(year == 2024) %>%
  select(geoid, pct_baplus, pct_somecoll) %>%
  right_join(ky_geo, by = "geoid") %>%   # right_join keeps every tract polygon
  st_as_sf()                              # make sure it's still a spatial object

# ----- 3. Map 1: BA+ level, 2024 -----------------------------------
m1 <- ggplot(map_data) +
  geom_sf(aes(fill = pct_baplus), color = NA) +
  scale_fill_viridis_c(
    option = "viridis",
    name   = "BA+ share (%)",
    na.value = "grey85"
  ) +
  labs(
    title    = "Bachelor's Degree or Higher Attainment, Kentucky Tracts, 2024",
    subtitle = "Share of adults 25+ with a BA or higher (ACS 5-year, 2020 tract boundaries)",
    caption  = "Source: ACS 2020-2024 5-year estimates, table B15003. Author's calculations."
  ) +
  theme_void() +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"))

# ----- 4. Map 2: Some college / associate level, 2024 --------------
m2 <- ggplot(map_data) +
  geom_sf(aes(fill = pct_somecoll), color = NA) +
  scale_fill_viridis_c(
    option = "mako",
    name   = "Some coll./\nassoc. (%)",
    na.value = "grey85"
  ) +
  labs(
    title    = "Some College or Associate's Attainment, Kentucky Tracts, 2024",
    subtitle = "Share of adults 25+ past high school but below a BA (ACS 5-year, 2020 boundaries)",
    caption  = "Source: ACS 2020-2024 5-year estimates, table B15003. Author's calculations."
  ) +
  theme_void() +
  theme(legend.position = "right",
        plot.title = element_text(face = "bold"))

# ----- 5. Save -----------------------------------------------------
dir.create("output/figures", showWarnings = FALSE, recursive = TRUE)
ggsave("output/figures/map_baplus_2024.png",   m1, width = 10, height = 6, dpi = 300, bg = "white")
ggsave("output/figures/map_somecoll_2024.png", m2, width = 10, height = 6, dpi = 300, bg = "white")

message("Saved two maps to output/figures/")
