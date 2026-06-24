# setup.R -----------------------------------------------------------------------
# Shared setup for the dashboard: libraries, data, theme, and the map helpers.
# main.R sources this once. Do not run this file on its own.
# Needs: shiny, sf, dplyr, leaflet, here. The dashboard must live inside the repo
# so here() can find data/ via the root.
# --------------------------------------------------------------------------------

library(shiny)
library(sf)
library(dplyr)
library(leaflet)
library(here)

# ---- Data (read once at app start) ---------------------------------------------
# County polygons (transformed to lat/long for leaflet) + the county attainment panel.
COUNTY_SF <- sf::st_read(here("data", "raw", "cb_2020_us_county_500k.shp"), quiet = TRUE) |>
  dplyr::filter(STATEFP == "21") |>
  sf::st_transform(4326)
COUNTY_PANEL <- readRDS(here("data", "cleaned", "ky_ed_county_panel_1990_2024.rds"))
KY_BBOX <- sf::st_bbox(COUNTY_SF)

# ---- Palette: white + navy only ------------------------------------------------
NAVY     <- "#1d385e"
NAVY_LOW <- "#eef2f8"

# ---- Years offered in the map dropdown -----------------------------------------
MAP_YEARS <- c(1990, 2000, 2012, 2024)

# ---- Color scale: fixed bins so a shade means the same thing every year --------
COUNTY_BINS <- c(0, 10, 20, 30, 40, 50, 100)
COUNTY_PAL  <- leaflet::colorBin(
  palette  = colorRampPalette(c(NAVY_LOW, NAVY))(length(COUNTY_BINS) - 1),
  domain   = c(0, 100),
  bins     = COUNTY_BINS,
  na.color = "grey85"
)

# ---- County data for a given year (geometry + BA+ share) -----------------------
county_map_data <- function(yr) {
  d <- COUNTY_PANEL |> filter(year == yr) |> select(county_fips, county, pct_baplus)
  dplyr::left_join(COUNTY_SF, d, by = c("GEOID" = "county_fips"))
}

# ---- Per-year explanations (county view) ---------------------------------------
MAP_EXPLANATIONS <- list(
  "1990" = "In 1990 college attainment is low across most of Kentucky. Fayette (Lexington) and Jefferson (Louisville) stand out, but most counties sit in the lowest band. Statewide, about 13.6% of adults held a bachelor's degree or higher.",
  "2000" = "By 2000 attainment edged up statewide, and the metro counties (Fayette, Jefferson, and the Northern Kentucky counties of Boone, Kenton, and Campbell) pull away from the rest. Statewide BA+ was about 17.1%.",
  "2012" = "2012 begins the modern annual series. The metro and rural split is clear: the Lexington, Louisville, and Northern Kentucky counties darken while eastern and south-central Kentucky stay pale.",
  "2024" = "By 2024 the divide is at its widest. The metro counties are deep navy, with the Cincinnati and Louisville suburbs growing fastest, while many Appalachian counties remain near the bottom. Attainment rose nearly everywhere, but the gap between counties grew."
)

# ---- Side note on why only certain years ---------------------------------------
YEAR_NOTE <- paste(
  "Why only these years? Attainment data comes from two sources.",
  "1990 and 2000 are from the decennial census long form, which ran once every ten years.",
  "The annual survey series (ACS table B15003) only begins in 2012.",
  "No attainment data exists for 1991 to 1999 or 2001 to 2011; it was never collected.",
  "These four years are shown as snapshots across the full span."
)

# ---- Map intro (top of the visualization page) ---------------------------------
MAP_INTRO <- paste(
  "This interactive map shows the share of adults aged 25 and over who hold a bachelor's",
  "degree or higher (BA+), by Kentucky county. Darker counties have higher attainment.",
  "Hover over any county to see its name and BA+ share, and use the dropdown to change the",
  "year. Every year uses the same color scale, so you can compare across years. The map shows",
  "counties; the finer tract-level detail behind it lives in the project's static figures."
)

# ---- Page header helper --------------------------------------------------------
page_header <- function(title) {
  div(class = "page-header-bar", title)
}

# ---- CSS (white + navy, left nav, big centered header, full-width text) --------
APP_CSS <- "
  body { background:#ffffff; color:#1d385e; font-family:'Helvetica Neue',Arial,sans-serif; }
  .app-title { color:#1d385e; font-weight:700; font-size:18px; padding:14px 8px;
               border-bottom:2px solid #1d385e; margin-bottom:10px; }
  .page-header-bar { background:#1d385e; color:#ffffff; font-size:30px; font-weight:600;
                     padding:28px 22px; margin-bottom:24px; border-radius:4px;
                     text-align:center; }
  .content { padding:0 6px; }
  .nav-pills > li > a, .nav-pills .nav-link { color:#1d385e; border-radius:4px; margin-bottom:4px; }
  .nav-pills > li.active > a, .nav-pills > li.active > a:hover, .nav-pills > li.active > a:focus,
  .nav-pills .nav-link.active {
      background:#1d385e !important; color:#ffffff !important; }
  .sidenote { background:#f4f6fa; border-left:4px solid #1d385e; padding:12px 16px;
              margin-top:20px; font-size:13px; line-height:1.5; color:#1d385e; }
  .map-intro { font-size:15px; color:#1d385e; line-height:1.6; margin-bottom:18px; }
  .map-explain { font-size:15px; color:#1d385e; margin-top:14px; line-height:1.55; }
  .coming-soon { color:#7a8699; font-size:20px; text-align:center; padding:90px 0; }
  .about-body { font-size:15px; line-height:1.6; color:#1d385e; }
  .about-body h3 { color:#1d385e; margin-top:22px; font-size:17px; }
"




